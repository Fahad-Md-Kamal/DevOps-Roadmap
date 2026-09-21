---
title: Load Balancing & DNS
icon: lucide/route
---

# Load Balancing & DNS

## Overview

### 6.1 Application Load Balancer (ALB) Deep Dive

The ALB operates at Layer 7 (HTTP/HTTPS). Think of it as a smart receptionist — every request arrives at the front desk, the receptionist checks what's needed (path, host, headers) and sends the guest to the right team (target group). It also checks which team members are healthy — if someone failed their health check, no traffic goes their way.

#### Where the ALB sits in the network

```
Internet
   │
   │  HTTPS :443 — TLS terminates here (cert from ACM, see 6.3)
   ▼
Internet Gateway  (fahad-igw)
   │
   ▼
┌─────────────────────────────────────────────────┐
│  ALB — public subnets, both AZs                  │
│  fahad-public-a (10.0.1.0/24)                    │
│  fahad-public-b (10.0.2.0/24)                    │
└─────────────────────┬─────────────────────────────┘
                       │  HTTP :80 — plain, never leaves the VPC
                       ▼
┌─────────────────────────────────────────────────┐
│  Target group → EC2 (Auto Scaling Group)         │
│  fahad-private-app-a (10.0.10.0/24)              │
│  fahad-private-app-b (10.0.11.0/24)              │
└─────────────────────┬─────────────────────────────┘
                       │  :5432
                       ▼
┌─────────────────────────────────────────────────┐
│  RDS — private DB subnets                        │
│  fahad-private-db-a (10.0.20.0/24)               │
│  fahad-private-db-b (10.0.21.0/24)               │
└─────────────────────────────────────────────────┘
```

Same three-tier VPC from Week 1 (4.9) — the ALB is the only new resource sitting in the public tier. Everything below it, including the instances it forwards to, stays in private subnets with no route to the internet.

#### Key components

```
Listener → Rule → Target Group → Instances

Listener:      "I'm listening on port 443 for HTTPS traffic"
Rule:          "If the path starts with /api, forward to target group A"
Target group:  "Here are 2 healthy EC2 instances that can handle this"
```

Listener
:   Listens on a port (80 for HTTP, 443 for HTTPS). Each listener has rules that determine where to send traffic.

Rule
:   Conditions (path, host, headers) + an action (forward to target group, redirect, fixed response).

Target group
:   A group of instances (or IPs, or Lambda functions) that receive traffic. Each has its own health check. **You cannot change a target group's traffic port after creation** — if you need a different port, create a new target group.

#### Path-based routing

```
ALB :443
├── /api/*      → target-group-api (EC2 instances running Django)
├── /static/*   → target-group-static (S3 via redirect)
├── /health     → fixed response: 200 "OK"
└── default     → target-group-web (EC2 instances running Nginx)
```

One ALB replaces what would otherwise be multiple Nginx reverse proxy configurations. You define the routing in the AWS console or CLI, not in config files.

#### ALB + target group for an ECS Fargate service, from the console

The fastest way to see an ALB actually work is through the console, before ever touching the CLI — the same "build it by hand first" order the rest of this project follows. This version targets an ECS Fargate service (containers.md 11); the CLI-based lab right below covers the EC2-instance-target version in full, with the exact same underlying concepts, just a different registration mechanism. Three parts, done through the console, in this order, since each one needs the previous to already exist.

**Part A — create the target group first**

- **EC2 console → Target Groups → Create target group**
- Target type: **IP addresses** — not "Instances." A Fargate task has no instance ID to register by, only an IP — the one setting that differs from the EC2-instance target group in the lab below.
- Name it, protocol HTTP, port matching whatever the container listens on, health check path `/`.
- Skip "Register targets" on this screen — leave it empty. An ECS service registers and deregisters targets automatically once it's attached in Part C; nothing needs to be added here by hand.

**Part B — create the ALB**

- **EC2 console → Load Balancers → Create load balancer → Application Load Balancer**
- Scheme **Internet-facing**, same VPC, at least two **public** subnets (an ALB requires subnets in at least two Availability Zones).
- Security group: one that allows inbound traffic on whatever port the listener below uses.
- Listener: HTTP on the port the app expects → forward to the target group from Part A.
- Create it. It takes a minute or two to reach the **Active** state — that's normal, not a failure.

**Part C — attach it to the ECS service**

- Once the ALB shows **Active**, go to **ECS console → (the service) → Update service**.
- Under **Load balancing**, attach the ALB's listener and the target group from Part A, mapping the container name to the port it listens on.
- Update the service, then wait for its tasks to show **healthy** in the target group (EC2 console → Target Groups → the target group → Targets tab) — the `initial` / `healthy` / `unhealthy` / `draining` states covered in full below, in the CLI lab's own target-health table.
- Open the ALB's own DNS name (EC2 console → Load Balancers → the ALB → copy the DNS name) in a browser — that's the stable URL to use from now on, not any one task's own IP.

!!! note "Only the target type actually changes"

    Everything else about the ALB — the listener, the health check states, the ALB-vs-NLB distinction, weighted target groups for canary — is identical to the EC2-instance version covered next. The one real difference is registration: an EC2 target group is registered manually (or by an ASG on launch), while a Fargate service registers and deregisters its own IP targets automatically as tasks start and stop.

#### Lab: build the ALB step by step

**Step 1: Create the ALB** — must be in public subnets (both AZs) with the ALB security group. AWS requires at least 2 AZs for redundancy.

``` bash
aws elbv2 create-load-balancer \
  --name fahad-web-alb \
  --subnets subnet-0aaa1111aaaa11111 subnet-0bbb2222bbbb22222 \
  --security-groups sg-0aaa1111aaaa11111 \
  --scheme internet-facing \
  --type application \
  --query "LoadBalancers[0].{ARN:LoadBalancerArn,DNS:DNSName,State:State.Code}" \
  --output table \
  --profile fahad
```

Save the **ALB ARN** and **DNS name** from the output. The DNS name is what users hit in their browser.

**Step 2: Create a target group** — tells the ALB where to forward traffic.

``` bash
aws elbv2 create-target-group \
  --name fahad-web-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id vpc-0123456789abcdef0 \
  --target-type instance \
  --health-check-path / \
  --health-check-port 80 \
  --health-check-interval-seconds 30 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text \
  --profile fahad
```

!!! danger "Port must match"

    The target group port must match what your app actually listens on. If Nginx listens on port 80, use port 80. If Django listens on 8080, use 8080. The health check port should also match — a mismatch is the #1 cause of "unhealthy" targets.

**Step 3: Create a listener** — connects the ALB to the target group.

``` bash
aws elbv2 create-listener \
  --load-balancer-arn <ALB_ARN> \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=<TARGET_GROUP_ARN> \
  --profile fahad
```

!!! danger "Gotcha: swapped ARNs"

    The ALB ARN and target group ARN look similar. Putting the wrong one in `--load-balancer-arn` gives: *"is not a valid load balancer ARN"*. Tell them apart by the middle of the string: `.../loadbalancer/app/...` = ALB, `.../targetgroup/...` = target group.

**Step 4: Attach the ASG to the target group**

``` bash
aws autoscaling attach-load-balancer-target-groups \
  --auto-scaling-group-name fahad-web-asg \
  --target-group-arns <TARGET_GROUP_ARN> \
  --profile fahad
```

!!! danger "Existing instances don't auto-register"

    Attaching a target group to an ASG only affects **future launches**. Instances already running must be registered manually:

``` bash
# Manually register an existing instance
aws elbv2 register-targets \
  --target-group-arn <TARGET_GROUP_ARN> \
  --targets Id=i-0aaa1111aaaa11111 \
  --profile fahad

# Or force the ASG to replace all instances (rolling update)
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name fahad-web-asg \
  --profile fahad
```

**Step 5: Verify target health**

``` bash
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --query "TargetHealthDescriptions[].{ID:Target.Id,Health:TargetHealth.State,Reason:TargetHealth.Reason}" \
  --output table \
  --profile fahad
```

| State | What it means | Action |
|---|---|---|
| `initial` | Just registered, first health checks running | Wait 30–60 seconds |
| `healthy` | Health checks passing, ALB sends traffic here | You're good — try the browser |
| `unhealthy` | Health checks failing, ALB stops sending traffic | Check the Reason field — see troubleshooting below |
| `draining` | Instance being removed, finishing in-flight requests | Normal during scale-in or deregistration |

**Step 6: Test in browser**

```
http://fahad-web-alb-XXXXXXXXXX.ap-south-1.elb.amazonaws.com

Expected results:
  ✓ Nginx welcome page  → full path working (internet → ALB → EC2 → Nginx)
  ✗ 502 Bad Gateway     → target unhealthy or traffic port mismatch
  ✗ 503 Service Unavail → no healthy targets registered in the target group
```

#### Weighted target groups (canary deployments)

One rule, two target groups, adjustable weights:

``` bash
aws elbv2 modify-rule \
  --rule-arn <RULE_ARN> \
  --actions '[{
    "Type": "forward",
    "ForwardConfig": {
      "TargetGroups": [
        {"TargetGroupArn": "<TG_V1_ARN>", "Weight": 90},
        {"TargetGroupArn": "<TG_V2_ARN>", "Weight": 10}
      ]
    }
  }]' \
  --profile fahad
```

90% of traffic to v1, 10% to v2. Change weights to shift traffic during canary deploys — no server restart needed.

#### Manage ALB

``` bash
# List all ALBs
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}" \
  --output table \
  --profile fahad

# List all target groups
aws elbv2 describe-target-groups \
  --query "TargetGroups[].{Name:TargetGroupName,Port:Port,HealthPort:HealthCheckPort,HealthPath:HealthCheckPath}" \
  --output table \
  --profile fahad

# List listeners on an ALB
aws elbv2 describe-listeners \
  --load-balancer-arn <ALB_ARN> \
  --query "Listeners[].{Port:Port,Protocol:Protocol}" \
  --output table \
  --profile fahad
```

#### End-of-session cleanup

!!! danger "ALB costs ~$16/month"

    Delete the ALB and target groups at the end of each study session. Recreating takes 3 commands.

``` bash
# Delete ALB (stops the charge)
aws elbv2 delete-load-balancer \
  --load-balancer-arn <ALB_ARN> \
  --profile fahad

# Delete target groups (free, but cleanup)
aws elbv2 delete-target-group \
  --target-group-arn <TG_ARN> \
  --profile fahad

# Delete ASG (stops extra EC2 charge)
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name fahad-web-asg \
  --force-delete \
  --profile fahad
```

### 6.2 Health Checks — Debugging Guide

The ALB periodically sends an HTTP request to each target. If the response is healthy, traffic flows. If unhealthy, the target is removed from rotation.

| Setting | What it does | Recommended |
|---|---|---|
| **Path** | URL the ALB hits | `/health` — a lightweight endpoint that checks DB connectivity |
| **Port** | Which port to check on | Same as traffic port (avoid mismatches) |
| **Interval** | How often to check | 30 seconds |
| **Timeout** | How long to wait for a response | 5 seconds |
| **Healthy threshold** | Consecutive successes to mark healthy | 2 |
| **Unhealthy threshold** | Consecutive failures to mark unhealthy | 3 |
| **Success codes** | Which HTTP status codes count as healthy | `200` (or `200-299`) |

``` bash
# Modify health check settings on an existing target group
aws elbv2 modify-target-group \
  --target-group-arn <TARGET_GROUP_ARN> \
  --health-check-path /health \
  --health-check-port 80 \
  --health-check-interval-seconds 30 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --profile fahad
```

#### Troubleshooting by error reason

**Reason: `Target.FailedHealthChecks`**

The ALB reached the instance but got an unexpected HTTP response (not 200).

- Health check path (`/health`) doesn't exist — app returns 404
- App redirects the path (e.g. `/` → `/login` returns 302, not 200)
- Nothing listening on the health check port — app crashed or wrong port

``` bash
# Fix: change health check to a path that returns 200
aws elbv2 modify-target-group \
  --target-group-arn <TARGET_GROUP_ARN> \
  --health-check-path / \
  --profile fahad
```

**Reason: `Target.Timeout`**

The ALB sent the health check but got **no response at all**. Packets were silently dropped. Almost always a security group issue.

```
What we experienced:
  ALB health check → port 80 → App-sg → BLOCKED (only port 8080 was allowed)
  Result: Target.Timeout

  The security group had:
    ✓ port 8080 from ALB-sg    (traffic port)
    ✗ port 80 from ALB-sg      (health check port — MISSING)
  
  The health check packets arrived at the instance but the security group
  silently dropped them → ALB never got a response → timeout
```

``` bash
# Check what the security group allows
aws ec2 describe-security-groups \
  --group-ids <APP_SG_ID> \
  --query "SecurityGroups[0].IpPermissions[].{Port:FromPort,Source:UserIdGroupPairs[0].GroupId}" \
  --output table \
  --profile fahad

# If the health check port isn't listed, add it
aws ec2 authorize-security-group-ingress \
  --group-id <APP_SG_ID> \
  --protocol tcp --port 80 \
  --source-group <ALB_SG_ID> \
  --profile fahad
```

!!! note "Rule"

    The health check port must be explicitly allowed in the target's security group with the ALB security group as the source. Same VPC doesn't matter — security groups still apply.

**Reason: `Elb.RegistrationInProgress`**

The target was just registered. Wait 30–60 seconds for the first health checks to complete.

**Reason: `Elb.InternalError`**

ALB internal error. Rare and usually transient. Wait a few minutes and check again.

#### Troubleshooting: 502 Bad Gateway (healthy target, wrong port)

Health check passes but browser shows 502. This means the health check port and traffic port are different:

```
What we experienced:
  Target group created on port 8080 (nothing listening there)
  Health check changed to port 80 (Nginx responds → target shows "healthy")
  
  Browser → ALB forwards to port 8080 → connection refused → 502

  The fix: can't change a target group's traffic port after creation.
  Must create a new target group on port 80.
```

``` bash
# Create new target group on the correct port
aws elbv2 create-target-group \
  --name fahad-web-tg-80 \
  --protocol HTTP \
  --port 80 \
  --vpc-id vpc-0123456789abcdef0 \
  --target-type instance \
  --health-check-path / \
  --health-check-port 80 \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text \
  --profile fahad

# Update the listener to use the new target group
aws elbv2 modify-listener \
  --listener-arn <LISTENER_ARN> \
  --default-actions Type=forward,TargetGroupArn=<NEW_TG_ARN> \
  --profile fahad

# Swap ASG attachment
aws autoscaling detach-load-balancer-target-groups \
  --auto-scaling-group-name fahad-web-asg \
  --target-group-arns <OLD_TG_ARN> \
  --profile fahad

aws autoscaling attach-load-balancer-target-groups \
  --auto-scaling-group-name fahad-web-asg \
  --target-group-arns <NEW_TG_ARN> \
  --profile fahad

# Register existing instances (attach only affects future launches)
aws elbv2 register-targets \
  --target-group-arn <NEW_TG_ARN> \
  --targets Id=i-0aaa1111aaaa11111 \
  --profile fahad

# Clean up old target group
aws elbv2 delete-target-group \
  --target-group-arn <OLD_TG_ARN> \
  --profile fahad
```

#### Troubleshooting: 503 Service Unavailable

The ALB has no healthy targets at all.

``` bash
# Check if any targets are registered
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --profile fahad

# Empty = no targets registered → attach ASG + register instances (see 6.1 step 4)
# All unhealthy = follow the debugging steps above
```

#### Summary: the debugging decision tree

```
Browser shows error
├── 502 Bad Gateway
│   ├── Target unhealthy? → check Reason field (FailedHealthChecks / Timeout)
│   └── Target healthy but 502? → traffic port ≠ health check port → new TG
├── 503 Service Unavailable
│   ├── No targets? → register-targets or attach ASG
│   └── All unhealthy? → fix the health check (see above)
└── Timeout (page never loads)
    └── ALB in wrong subnets (private instead of public) or SG missing 80/443
```

!!! danger "Django tip"

    Don't set the health check path to `/` on a Django app that redirects `/` to `/login` (302). The ALB sees a 302, not a 200, and marks the target unhealthy. Always create a dedicated `/health` endpoint that returns 200 directly.

### 6.3 TLS Termination with ACM

**ACM (AWS Certificate Manager)** provides free, auto-renewing TLS/SSL certificates. The ALB terminates TLS — meaning it handles encryption/decryption, and forwards plain HTTP to your backend instances.

```
User → HTTPS (encrypted) → ALB → HTTP (plain) → EC2 instances
                                    ↑ TLS terminates here
                                    Certificate from ACM
```

Benefits: your EC2 instances don't need to handle TLS certificates, reducing complexity and CPU overhead. The certificate auto-renews — no more expired cert emergencies.

#### Key concepts

Certificate
:   A public/private key pair issued by ACM for a domain name (or a wildcard like `*.example.com`). ACM holds the private key — you never download it, which is exactly why the ALB can use it without you handling key files.

Domain validation
:   **DNS validation** (recommended): ACM gives you a CNAME record to add to your DNS zone, proving you control the domain. **Email validation**: ACM emails the domain's registered contacts — slower, and breaks auto-renewal if no one clicks the link next time. Always use DNS validation.

Region requirement
:   An ACM certificate can only be attached to resources **in the same region it was issued in**. A cert for an ALB in `ap-south-1` must be requested in `ap-south-1` — this is the single most common ACM mistake. (CloudFront is the one exception: it always needs its certs in `us-east-1`, regardless of where your other resources live.)

Certificate ARN
:   What you actually reference when creating the HTTPS listener — not the domain name, not the certificate ID by itself.

SSL security policy
:   A named bundle of allowed TLS versions and cipher suites, attached to the HTTPS listener (not the certificate). Older policies still allow TLS 1.0/1.1; pick a modern one (`ELBSecurityPolicy-TLS13-1-2-2021-06`) unless you have a legacy client that genuinely needs an older protocol.

#### The lifecycle

```
1. Request certificate (ACM)              — status: PENDING_VALIDATION
2. Add CNAME validation record (Route 53) — proves you own the domain
3. ACM validates the record               — status: ISSUED (few minutes)
4. Attach cert ARN to ALB HTTPS listener  — port 443 now serves HTTPS
5. Redirect HTTP → HTTPS on port 80       — no unencrypted path left
6. ACM auto-renews ~60 days before expiry — as long as the CNAME still exists
```

#### Lab: request a certificate and wire it to the ALB

**Step 1: Request the certificate — DNS validation, same region as the ALB**

``` bash
aws acm request-certificate \
  --domain-name app.example.com \
  --validation-method DNS \
  --tags Key=Name,Value=fahad-app-cert Key=Owner,Value=fahad \
  --query "CertificateArn" \
  --output text \
  --profile fahad
```

!!! danger "Wrong region = invisible certificate"

    ACM certificates don't show up across regions in the console or CLI by default. If `describe-certificates` comes back empty, check `--region` matches where you actually requested it — this alone accounts for most "my certificate disappeared" moments.

**Step 2: Get the DNS validation record ACM wants**

``` bash
aws acm describe-certificate \
  --certificate-arn <CERT_ARN> \
  --query "Certificate.DomainValidationOptions[0].ResourceRecord" \
  --output table \
  --profile fahad
# Returns a Name (CNAME record name), Type (CNAME), and Value (the target)
```

**Step 3: Add that record to Route 53**

``` bash
aws route53 change-resource-record-sets \
  --hosted-zone-id <HOSTED_ZONE_ID> \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "<VALIDATION_RECORD_NAME>",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "<VALIDATION_RECORD_VALUE>"}]
      }
    }]
  }' \
  --profile fahad
```

!!! note "Don't delete this record later"

    ACM re-checks this CNAME every time it auto-renews. Deleting it after issuance "to tidy up" is what silently breaks renewal 13 months later — leave it in place for the life of the certificate.

**Step 4: Wait for validation, then confirm ISSUED**

``` bash
aws acm wait certificate-validated --certificate-arn <CERT_ARN> --profile fahad

aws acm describe-certificate \
  --certificate-arn <CERT_ARN> \
  --query "Certificate.Status" \
  --output text \
  --profile fahad
# PENDING_VALIDATION → ISSUED, usually within a few minutes once DNS propagates
```

**Step 5: Create the HTTPS listener on the ALB**

``` bash
aws elbv2 create-listener \
  --load-balancer-arn <ALB_ARN> \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=<CERT_ARN> \
  --ssl-policy ELBSecurityPolicy-TLS13-1-2-2021-06 \
  --default-actions Type=forward,TargetGroupArn=<TARGET_GROUP_ARN> \
  --profile fahad
```

**Step 6: Redirect the existing HTTP listener to HTTPS**

``` bash
# Modify the port-80 listener's default action from "forward" to "redirect"
aws elbv2 modify-listener \
  --listener-arn <HTTP_LISTENER_ARN> \
  --default-actions '[{
    "Type": "redirect",
    "RedirectConfig": {
      "Protocol": "HTTPS",
      "Port": "443",
      "StatusCode": "HTTP_301"
    }
  }]' \
  --profile fahad
```

!!! success "Best practice"

    Every HTTP request now gets a 301 straight to HTTPS instead of being forwarded to a target group. Nobody can reach your app unencrypted, even by typing `http://` by hand.

**Step 7: Point DNS at the ALB, then test**

``` bash
# Alias record — same ALB, now serving HTTPS
aws route53 change-resource-record-sets \
  --hosted-zone-id <HOSTED_ZONE_ID> \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "app.example.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "<ALB_HOSTED_ZONE_ID>",
          "DNSName": "<ALB_DNS_NAME>",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }' \
  --profile fahad

# Inspect the handshake and certificate chain directly
curl -vI https://app.example.com 2>&1 | grep -A5 "Server certificate"
```

| Symptom | Likely cause |
|---|---|
| Certificate stuck at `PENDING_VALIDATION` | CNAME record missing, in the wrong hosted zone, or not yet propagated — re-check Step 3 |
| `describe-certificates` returns nothing | Wrong `--region` — certificate was requested somewhere else |
| Browser shows `NET::ERR_CERT_COMMON_NAME_INVALID` | Requested domain doesn't match the URL — a cert for `example.com` doesn't cover `app.example.com` unless requested as a SAN or wildcard |
| Renewal fails after ~13 months | The validation CNAME was deleted from Route 53 after issuance |

#### Manage certificates

``` bash
# List all certificates in this region
aws acm list-certificates \
  --query "CertificateSummaryList[].{Domain:DomainName,ARN:CertificateArn,Status:Status}" \
  --output table \
  --profile fahad

# Full detail on one certificate (validation status, expiry, in-use resources)
aws acm describe-certificate \
  --certificate-arn <CERT_ARN> \
  --query "Certificate.{Domain:DomainName,Status:Status,NotAfter:NotAfter,InUseBy:InUseBy}" \
  --output table \
  --profile fahad
```

!!! success "Cleanup note"

    Unlike the ALB or NAT Gateway, an ACM certificate costs nothing to leave alone — there's no per-hour charge. You only need to delete one if it's actually `InUseBy` nothing and you're tidying up; leaving it (and its validation CNAME) in place between study sessions is fine and saves you re-validating next time.

### 6.4 Network Load Balancer (NLB)

The NLB operates at Layer 4 (TCP/UDP). It doesn't inspect HTTP headers or paths — it just forwards TCP connections extremely fast.

![ALB routing HTTP path-based traffic and NLB routing raw TCP traffic, both to the same EC2 target group inside fahad-devops-vpc](images/alb-nlb-diagram.png)

*ALB (path-based, HTTP) vs NLB (TCP passthrough) — both landing on the same target group*

| Feature | ALB | NLB |
|---|---|---|
| **Layer** | 7 (HTTP/HTTPS) | 4 (TCP/UDP) |
| **Routing** | Path, host, header, query string | Port-based only |
| **Performance** | Good (thousands of req/sec) | Extreme (millions of req/sec) |
| **Static IP** | No (DNS name only) | Yes (Elastic IP per AZ) |
| **TLS termination** | Yes | Yes (TLS listener) |
| **Use when** | HTTP APIs, web apps | Non-HTTP protocols, extreme perf, static IPs needed |

For your ramp plan: use ALB for everything HTTP. NLB is for when you need TCP pass-through (database proxies, gRPC, gaming servers) or static IPs for firewall allowlisting.

#### Two behaviors that surprise people coming from ALB

Client IP is preserved by default
:   An ALB always shows your instance its own IP as the source (you read the real client IP from the `X-Forwarded-For` header). An NLB, by default, preserves the original client IP at the TCP layer — your instance sees the actual visitor IP directly, which matters if your app does IP-based logic (rate limiting, geo-blocking) without an HTTP layer to read headers from.

Cross-zone load balancing is off by default
:   An ALB always balances evenly across every AZ's targets. An NLB defaults to keeping traffic *within* the AZ it arrived in — if AZ-a has 1 healthy target and AZ-b has 5, an NLB won't rebalance across zones unless you explicitly enable cross-zone load balancing (which then also starts charging inter-AZ data transfer).

#### Lab: create an NLB with a TCP listener

``` bash
# 1. Allocate a static Elastic IP per AZ (this is what gives the NLB a fixed IP)
aws ec2 allocate-address --domain vpc --profile fahad

# 2. Create the NLB, one EIP per public subnet
aws elbv2 create-load-balancer \
  --name fahad-tcp-nlb \
  --type network \
  --scheme internet-facing \
  --subnet-mappings SubnetId=subnet-0aaa1111aaaa11111,AllocationId=<EIP_ALLOC_A> \
                     SubnetId=subnet-0bbb2222bbbb22222,AllocationId=<EIP_ALLOC_B> \
  --query "LoadBalancers[0].{ARN:LoadBalancerArn,DNS:DNSName}" \
  --output table \
  --profile fahad

# 3. Target group — note the protocol is TCP, not HTTP
aws elbv2 create-target-group \
  --name fahad-tcp-tg \
  --protocol TCP \
  --port 5432 \
  --vpc-id vpc-0123456789abcdef0 \
  --target-type instance \
  --health-check-protocol TCP \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text \
  --profile fahad

# 4. Listener — forwards raw TCP, no path/header awareness at all
aws elbv2 create-listener \
  --load-balancer-arn <NLB_ARN> \
  --protocol TCP \
  --port 5432 \
  --default-actions Type=forward,TargetGroupArn=<TARGET_GROUP_ARN> \
  --profile fahad
```

!!! note "TCP health checks are shallower"

    A TCP health check only confirms the port accepts a connection — it can't tell you the app behind it is actually healthy (a hung process still accepts TCP connections). For anything where that distinction matters, add an HTTP health check on a different port even though the listener itself stays TCP.

#### Manage & cleanup

``` bash
# List NLBs
aws elbv2 describe-load-balancers --query "LoadBalancers[?Type=='network']" --profile fahad

# Delete — same commands as ALB cleanup
aws elbv2 delete-load-balancer --load-balancer-arn <NLB_ARN> --profile fahad
aws ec2 release-address --allocation-id <EIP_ALLOC_A> --profile fahad
aws ec2 release-address --allocation-id <EIP_ALLOC_B> --profile fahad
```

!!! danger "Elastic IPs cost money when idle"

    An unattached Elastic IP is billed hourly. Release both EIPs right after deleting the NLB — it's easy to delete the load balancer and forget the IPs are still sitting there charging.

### 6.5 Route 53 — DNS Records & Routing

#### Record types

| Type | Points to | Example |
|---|---|---|
| **A** | IPv4 address | `api.example.com → 203.0.113.10` |
| **AAAA** | IPv6 address | `api.example.com → 2600:1f18:...` |
| **CNAME** | Another domain name | `www.example.com → example.com` |
| **Alias** | AWS resource (ALB, S3, CloudFront) | `api.example.com → my-alb-123.elb.amazonaws.com` |

!!! success "Use Alias"

    Alias records are free (no query charge), support zone apex (`example.com`, not just subdomains), and automatically resolve to the current IP of the AWS resource. Always use Alias over CNAME for AWS resources.

#### Routing policies

| Policy | How it routes | Use for |
|---|---|---|
| **Simple** | One record, one answer | Single-region, single endpoint |
| **Weighted** | Split traffic by percentage | Canary at DNS level, gradual migration |
| **Latency** | Route to lowest-latency region | Active-active multi-region |
| **Failover** | Primary + secondary, auto-switch on health check failure | Active-passive DR |
| **Geolocation** | Route by user's country/continent | Data residency compliance, localized content |

#### Public vs private hosted zones

Public hosted zone
:   Resolvable from the internet. This is what you use for a real domain — `example.com`, delegated to Route 53's name servers at your registrar.

Private hosted zone
:   Only resolvable from inside VPCs you attach it to. Useful for internal service discovery (`db.internal`) without exposing internal names publicly.

#### Lab: create a hosted zone and point it at the ALB

``` bash
# 1. Create the public hosted zone
aws route53 create-hosted-zone \
  --name example.com \
  --caller-reference "fahad-$(date +%s)" \
  --query "HostedZone.Id" \
  --output text \
  --profile fahad

# 2. Get the 4 name servers Route 53 assigned — these go at your domain registrar
aws route53 get-hosted-zone \
  --id <HOSTED_ZONE_ID> \
  --query "DelegationSet.NameServers" \
  --output table \
  --profile fahad

# 3. Alias record pointing the apex domain straight at the ALB (no CNAME needed)
aws route53 change-resource-record-sets \
  --hosted-zone-id <HOSTED_ZONE_ID> \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "example.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "<ALB_HOSTED_ZONE_ID>",
          "DNSName": "<ALB_DNS_NAME>",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }' \
  --profile fahad

# 4. Verify resolution
dig example.com +short
nslookup example.com
```

!!! danger "NS delegation is the step people skip"

    Creating the hosted zone alone does nothing for a live domain — until you copy Route 53's 4 name servers into your registrar's NS records, the internet has no idea Route 53 is authoritative for your domain. This is the single most common "why doesn't my domain resolve" cause, and it can take up to 48 hours to propagate (usually much faster).

#### TTL — the trade-off you're actually making

Time-to-live controls how long resolvers cache a record before re-checking. Low TTL (60s) means changes propagate fast but you pay more DNS query volume and clients feel any Route 53 blip. High TTL (3600s+) is cheaper and steadier but a bad record takes longer to fix everywhere. **Drop the TTL to 60 seconds before a planned cutover** (like switching to a new ALB), then raise it back afterward.

#### Manage & cleanup

``` bash
# List all hosted zones
aws route53 list-hosted-zones --query "HostedZones[].{Name:Name,Id:Id}" --output table --profile fahad

# List records in a zone
aws route53 list-resource-record-sets --hosted-zone-id <HOSTED_ZONE_ID> --output table --profile fahad

# Delete the hosted zone (all records must be removed first, except the default NS/SOA)
aws route53 delete-hosted-zone --id <HOSTED_ZONE_ID> --profile fahad
```

!!! success "Cost"

    A hosted zone is $0.50/month regardless of traffic — the one thing in this whole lab that isn't free to leave idle, though it's small enough that most people just keep the zone and delete the records pointing at expensive resources (ALB, NLB) instead.
