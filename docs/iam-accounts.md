---
title: AWS Accounts & IAM
icon: fontawesome/brands/aws
---

# AWS Accounts & IAM

## Overview

### 3.1 AWS Global Infrastructure

#### Regions

A region (e.g. `ap-south-1` for Mumbai, `us-east-1` for N. Virginia) is a cluster of data centres in a geographic area. Your data stays in the region you choose unless you explicitly replicate it. Not every region has every service, and pricing varies.

For the ramp plan: `ap-south-1` (Mumbai) is close to Dhaka, has all major services, and is cheaper than US regions. `us-east-1` gets new services first and has the most documentation.

#### Availability Zones

Each region has 2–6 AZs — physically separate buildings with independent power, cooling, and networking, connected by low-latency (<1ms) redundant fiber. If AZ-a loses power, AZ-b and AZ-c keep serving.

!!! danger "Critical detail"

    AZ naming is randomized per account. Your `ap-south-1a` might be a different physical data centre than another account's `ap-south-1a` — AWS does this to prevent everyone piling into the "first" AZ. Use AZ IDs (`aps1-az1`) for cross-account coordination.

#### Service scope

| Scope | Services | Implication |
|---|---|---|
| **Global** | IAM, Route 53, CloudFront, WAF (global), S3 (namespace) | Created once, works in all regions |
| **Regional** | VPC, S3 (data), Lambda, RDS, ECS, Secrets Manager, ALB | Created per region — a VPC in Mumbai doesn't exist in London |
| **AZ-scoped** | EC2 instances, EBS volumes, Subnets, NAT Gateways | Tied to a specific building — an EBS volume in AZ-a can't attach to an instance in AZ-b |

Why this matters: when an EC2 instance in AZ-a dies and Auto Scaling launches a replacement in AZ-b, the old EBS volume is stranded. Stateful data should go in RDS or S3 (regional services), not local EBS.

### 3.2 Shared Responsibility Model

| Layer | Your responsibility | AWS's responsibility |
|---|---|---|
| Application code | ✓ |  |
| IAM policies | ✓ |  |
| Security group / firewall rules | ✓ |  |
| Encryption settings | ✓ |  |
| OS patching (EC2) | ✓ |  |
| OS patching (Fargate, Lambda, RDS) |  | ✓ |
| Network configuration (VPC, subnets) | ✓ |  |
| Physical data centre security |  | ✓ |
| Hypervisor / host OS |  | ✓ |
| Network infrastructure between AZs |  | ✓ |

**The spectrum:** more managed service = less your responsibility.

- EC2: you manage everything from the OS up
- ECS Fargate: AWS manages the host OS; you manage the container
- Lambda: AWS manages everything except your function code and IAM
- RDS: AWS patches the engine; you manage access and encryption

If your RDS database gets breached because the password was `admin123`, that's on you. If the underlying hardware fails, that's on AWS.

### 3.3 Service Quotas

Default limits that will bite you during the ramp plan:

| Service | Default limit | Risk |
|---|---|---|
| VPCs per region | 5 | Shared account with teammate, easy to hit |
| Elastic IPs per region | 5 | NAT Gateways each need one |
| EC2 On-Demand vCPU limit | Varies by family | Auto Scaling silently fails if you hit this |
| S3 buckets per account | 100 | Rarely hit during learning |
| IAM roles per account | 1,000 | Not an issue now, critical at enterprise scale |

Check your limits: `aws service-quotas list-service-quotas --service-code ec2`

!!! danger "Watch out"

    Hitting a quota doesn't always produce a clear error. Auto Scaling may silently fail to launch instances during a traffic spike.

### 3.4 Tagging Strategy

Set a convention on day one:

``` tags
Environment  = dev | staging | prod
Project      = ecommerce-platform
Owner        = fahad
CostCenter   = ramp-plan-2026
ManagedBy    = terraform | manual
```

#### Why tags matter

- **Cost tracking:** see exactly how much dev costs vs staging in the billing console
- **IAM scoping:** write policies like "this role can only manage resources tagged `Environment: dev`"
- **Automation:** scripts can find and stop all instances tagged `Environment: dev` every evening to save money
- **Accountability:** "who left this running?" → check the `Owner` tag

### 3.5 Budget Alarm Setup

$60 per engineer. Set alerts at 50% and 80%.

#### Top cost traps during learning

- Forgetting to stop EC2 instances overnight (~$0.10/hr × 12 hours = $1.20/night)
- NAT Gateways running 24/7 ($0.045/hr = ~$32/month each)
- RDS instances left running on weekends
- Forgotten Elastic IPs not attached to a running instance ($0.005/hr each)

**Cost-saving habit:** at the end of each day, check the billing console or run:

``` bash
aws ce get-cost-and-usage \
  --time-period Start=2026-08-27,End=2026-08-31 \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --profile sandbox
```

### 3.6 AWS CLI with Named Profiles

``` bash
# Configure
aws configure --profile sandbox
# Enter access key, secret key, region (ap-south-1), output format (json)

# Verify identity
aws sts get-caller-identity --profile sandbox
# Shows: Account ID, ARN, User ID — the "whoami" of AWS

# Set a default to avoid typing --profile every time
export AWS_PROFILE=sandbox
```

!!! success "Debugging tip"

    `get-caller-identity` is your best debugging friend. Whenever something returns AccessDenied, run it first — it tells you who AWS thinks you are.

#### How long does `export AWS_PROFILE` last?

`export AWS_PROFILE=sandbox` only applies to the **current shell session** — every `aws` command you run afterward in that same terminal uses it automatically, with no `--profile` flag needed. Close the terminal or open a new tab, and it's gone; that new session falls back to the CLI's default profile again.

``` bash
# Make it permanent — every new terminal, not just this session
echo 'export AWS_PROFILE=sandbox' >> ~/.zshrc   # zsh
echo 'export AWS_PROFILE=sandbox' >> ~/.bashrc  # bash

# Apply it to the terminal you already have open, without restarting
source ~/.zshrc
```

!!! note "Override"

    Setting `AWS_PROFILE` doesn't lock you in — passing `--profile other-name` on any single command still overrides the environment variable for just that one call. Useful when you're mostly working in one account but need a one-off command against another.

### 3.7 IAM — Identity and Access Management

#### Principals: Users, Groups, and Roles

IAM User
:   A permanent identity with long-lived credentials (access key + secret, or console password). Used for human console login. Prefer roles wherever possible — long-lived credentials can be leaked.

IAM Group
:   A collection of users. Policies attached to the group are inherited by every member. Never attach policies directly to a user — put the user in a group, attach the policy to the group. Keeps onboarding/offboarding clean.

IAM Role
:   A temporary identity that anything can assume — an EC2 instance, a Lambda function, an ECS task, a user from another account. No permanent credentials; issues short-lived tokens (typically 1 hour) via `sts:AssumeRole`. The preferred way to grant access to services.

#### Policy documents — reading them line by line

``` json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowReadOnlyS3",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-app-bucket",
        "arn:aws:s3:::my-app-bucket/*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "ap-south-1"
        }
      }
    }
  ]
}
```

Read it aloud: "Allow getting objects and listing contents, but only in this specific bucket, and only when the request comes from ap-south-1."

#### The five fields

- **Effect:** `Allow` or `Deny`. Deny always wins over Allow.
- **Action:** the specific API call(s). Never use `*` in production.
- **Resource:** which specific thing, by ARN. `*` means all resources — avoid it.
- **Condition:** optional constraints — IP range, MFA required, region, tag values.
- **Principal** (resource-based policies only): who is granted access.

#### Identity-based vs resource-based policies

**Identity-based policies** attach to a user, group, or role — "What can this identity do?" **Resource-based policies** attach to a resource (S3 bucket policy, SQS queue policy) — "Who can access this resource?" They include a `Principal` field. AWS evaluates both together. For cross-account access you typically need both: a resource policy on the target allowing the external account, and an identity policy on the external role allowing the action.

#### Policy evaluation logic

When an API call is made, AWS evaluates in order:

1. **Explicit deny check:** if any policy anywhere says Deny for this action, it's denied. Game over. Always wins.
2. **SCP check** (AWS Organizations): organization-level guardrails. If the SCP doesn't allow it, denied.
3. **Permission boundary check:** the maximum ceiling for this role. Outside the boundary → denied.
4. **Allow check:** is there at least one identity-based or resource-based policy that explicitly Allows? If yes, allowed; if no, implicit deny.

!!! success "90% of debugging"

    - Default deny: no Allow → denied
    - Explicit Deny always wins, even over Allow
    - Allow must be explicit for the specific action on the specific resource

#### Trust policies vs permission policies

Every role has two halves. **Trust policy** — "Who can assume this role?"

``` json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ecs-tasks.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
```

This says: "ECS tasks can assume this role." No human, no Lambda, no EC2 can. The **permission policy** is "What can this role do once assumed?" — the standard document with Actions and Resources. For cross-account, the trust policy says `"Principal": { "AWS": "arn:aws:iam::OTHER_ACCOUNT:role/auditor" }` — the auditor role from the other account can assume this role.

#### Permission boundaries

A policy that sets the maximum a role can ever do, regardless of what other policies are attached:

```
Boundary says:  "At most S3 and CloudWatch"
Identity policy says: "Allow s3:*, ec2:*, cloudwatch:*"
Effective permissions: s3:* and cloudwatch:* only (ec2:* is outside the boundary)
```

Useful when you let developers create their own roles but want to guarantee they can never exceed a defined scope.

#### Instance profiles and IMDSv2

An **instance profile** is the wrapper that attaches a role to an EC2 instance. The instance gets temporary credentials by calling the Instance Metadata Service.

!!! danger "IMDSv1 — insecure"

    ```
    curl http://169.254.169.254/latest/meta-data/iam/security-credentials/my-role
    # Returns credentials — no authentication required
    # This is how the 2019 Capital One breach happened (SSRF → metadata → credentials)
    ```

!!! success "IMDSv2 — current"

    ```
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    curl -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/iam/security-credentials/my-role
    # Requires PUT (SSRF attacks typically can't do PUT) + token
    ```

Always enforce IMDSv2: `--metadata-options "HttpTokens=required,HttpEndpoint=enabled"`

#### Debugging AccessDenied with CloudTrail

1. Run `aws sts get-caller-identity` — confirm who you are
2. Check CloudTrail event history for the denied API call
3. The event shows: userIdentity, eventName, resources, errorCode, errorMessage
4. Ask four questions:
                
Does my identity policy Allow this exact action on this exact resource?
Does the resource policy (if any) allow my principal?
Is there an explicit Deny anywhere overriding the Allow?
Am I failing a Condition? (wrong region, no MFA, wrong tag, wrong source IP)

### 3.8 The Three IAM Roles for Assignment A1

#### Role 1 — Application Role (ECS Tasks)

``` json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadAppAssets",
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::ecommerce-assets-prod/*"
    },
    {
      "Sid": "ReadSecrets",
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:ap-south-1:*:secret:ecommerce/prod/*"
    },
    {
      "Sid": "WriteAppLogs",
      "Effect": "Allow",
      "Action": ["logs:CreateLogStream", "logs:PutLogEvents"],
      "Resource": "arn:aws:logs:ap-south-1:*:log-group:/ecs/ecommerce-prod:*"
    }
  ]
}
```

!!! success "Justification"

    The app reads assets from S3, reads database credentials from Secrets Manager, and writes its own logs. It does NOT get PutObject, DeleteObject, any IAM actions, or any EC2/infra actions. If this container is compromised, the attacker can read assets and secrets for this one service — they cannot modify infrastructure, delete data, or escalate privileges.

#### Role 2 — Operator Role (Human Engineers)

``` json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ManageCompute",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*", "ec2:StartInstances", "ec2:StopInstances",
        "ecs:UpdateService", "ecs:DescribeServices", "ecs:RegisterTaskDefinition"
      ],
      "Resource": "*",
      "Condition": { "StringEquals": { "aws:RequestedRegion": "ap-south-1" } }
    },
    {
      "Sid": "ManageSecrets",
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue"],
      "Resource": "arn:aws:secretsmanager:ap-south-1:*:secret:ecommerce/*"
    },
    {
      "Sid": "DenyIAMChanges",
      "Effect": "Deny",
      "Action": "iam:*",
      "Resource": "*"
    }
  ]
}
```

!!! success "Justification"

    Operators deploy (update ECS services, register task definitions), manage instances, and rotate secrets. The explicit Deny on `iam:*` prevents operators from modifying permissions. The region condition prevents accidental cross-region operations.

#### Role 3 — Read-Only Auditor

``` json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadEverything",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*", "s3:GetObject", "s3:ListBucket",
        "rds:Describe*", "ecs:Describe*", "ecs:List*",
        "logs:GetLogEvents", "logs:DescribeLogGroups",
        "cloudtrail:LookupEvents", "iam:Get*", "iam:List*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DenyAllWrites",
      "Effect": "Deny",
      "Action": [
        "ec2:Run*", "ec2:Terminate*", "ec2:Create*", "ec2:Delete*",
        "s3:PutObject", "s3:DeleteObject",
        "iam:Create*", "iam:Delete*", "iam:Put*", "iam:Attach*"
      ],
      "Resource": "*"
    }
  ]
}
```

!!! success "Justification"

    Auditors see everything (logs, configs, IAM, CloudTrail) to verify compliance. Explicit Deny on all mutations ensures that even if someone attaches an additional policy, the role still can't modify anything.

### 3.9 ARNs — Amazon Resource Names

An ARN is the unique address of any resource in all of AWS — like a postal address for your house, but for AWS resources.

Every ARN follows the same pattern:

```
arn:aws:s3:::my-app-bucket
 │   │   │ │ │  └── Resource name (the bucket itself)
 │   │   │ │ └── Account ID (empty for S3 — buckets are globally unique)
 │   │   │ └── Region (empty for S3 — it's a global namespace)
 │   │   └── Service (s3)
 │   └── Partition (aws = standard, aws-cn = China, aws-us-gov = GovCloud)
 └── Prefix (always "arn")
```

The full format is:

``` format
arn:aws:service:region:account-id:resource
```

#### Real examples from your account

| Resource | ARN |
|---|---|
| Your S3 bucket | `arn:aws:s3:::my-app-bucket` |
| An object inside it | `arn:aws:s3:::my-app-bucket/images/logo.png` |
| Your EC2 instance | `arn:aws:ec2:ap-south-1:111122223333:instance/i-0123456789abcdef0` |
| An IAM role | `arn:aws:iam::111122223333:role/my-app-role` |
| An RDS database | `arn:aws:rds:ap-south-1:111122223333:db:my-database` |

Some fields are empty for global services:

S3
:   No region, no account ID — bucket names are globally unique across all of AWS, so nobody else can have the same bucket name as you.

IAM
:   No region — IAM is global, your roles work in every region.

EC2, RDS
:   All fields filled — they exist in a specific region, in a specific account.

#### Why ARNs matter for you

Remember the IAM policies from [3.7](#37-iam-identity-and-access-management)? The `Resource` field uses ARNs to say exactly *which* thing the policy applies to:

``` json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::my-app-bucket/*"
}
```

This says "allow reading objects, but **only** from this specific bucket." The `/*` at the end means "all objects inside it." Without the ARN, AWS wouldn't know which bucket you're talking about — there could be millions of S3 buckets across all AWS accounts.

#### Finding a resource's ARN

Usually shown at the top of its detail page in the console, or via CLI:

``` bash
# Your EC2 instance's ARN
aws ec2 describe-instances \
  --instance-ids i-0123456789abcdef0 \
  --query "Reservations[].Instances[].{ARN:InstanceId}" \
  --output text
```

### 3.10 Condition Keys in Practice — Restricting by Location

Say the goal is "only allow access from Bangladesh." You'd use the `aws:SourceIp` condition with Bangladesh's public IP ranges:

``` json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowOnlyFromBangladesh",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "NotIpAddress": {
          "aws:SourceIp": [
            "103.0.0.0/8",
            "114.128.0.0/10",
            "202.4.96.0/19",
            "103.48.16.0/20"
          ]
        }
      }
    }
  ]
}
```

Read it aloud: *"Deny everything if the request is NOT coming from these IP ranges."*

!!! success "Why Deny + NotIpAddress"

    Explicit Deny always wins. An Allow-based rule could be bypassed by attaching another policy that allows access from anywhere. A Deny-based rule can't be overridden — it blocks non-BD traffic no matter what other policies exist.

!!! danger "Country-level filtering"

    Bangladesh doesn't have one clean CIDR block. IP ranges are scattered across many blocks assigned to ISPs like Grameenphone, Banglalink, Robi, etc. The example above is simplified — a real implementation would need dozens of CIDR ranges that change over time.

#### A better approach for "only from Bangladesh"

Instead of tracking IP ranges, AWS has cleaner options.

**Option 1 — VPN, the production answer.** All access goes through a VPN; no public IP filtering needed. If you're on the VPN, you're authorized — if not, you can't reach anything:

```
Your laptop (Dhaka) → VPN → AWS VPC (private network)
```

**Option 2 — restrict to specific known IPs**, more practical than "all of Bangladesh": your office network and home ISP, two known, stable IPs instead of an entire country's worth of ranges.

``` json
{
  "Condition": {
    "IpAddress": {
      "aws:SourceIp": [
        "103.123.45.0/24",
        "114.56.78.0/24"
      ]
    }
  }
}
```

**Option 3 — region restriction**, if the real goal is "keep my resources in the nearest region" rather than "control who connects":

``` json
{
  "Condition": {
    "StringEquals": {
      "aws:RequestedRegion": "ap-south-1"
    }
  }
}
```

This prevents anyone — even you — from accidentally creating resources in `us-east-1` or `eu-west-1`. It doesn't restrict who can access; it restricts *where* resources can exist.

#### Other useful conditions you'll use in the ramp plan

| Condition | What it does | Example use |
|---|---|---|
| `aws:SourceIp` | Restrict by IP address | Office network only |
| `aws:RequestedRegion` | Restrict by region | Only ap-south-1 |
| `aws:MultiFactorAuthPresent` | Require MFA | Sensitive operations need 2FA |
| `aws:PrincipalTag` | Check user's tags | Only team=devops can access |
| `ec2:ResourceTag` | Check resource's tags | Can only manage resources tagged Environment=dev |
| `aws:CurrentTime` | Restrict by time | No deploys outside business hours |

**Worth noting:** a policy that says "operators can deploy only between 10am and 6pm Bangladesh time," using `aws:CurrentTime`, is a real pattern for reducing late-night risky changes.

### 3.11 IAM Actions Reference

Every distinct `Action` string used across the three IAM roles in [3.8](#38-the-three-iam-roles-for-assignment-a1), grouped by service — what each one does, and whether it shows up as an Allow or an explicit Deny.

| Service | Action | What it does | Effect | Used in |
|---|---|---|---|---|
| S3 | `s3:GetObject` | Read an object | Allow | [3.7](#37-iam-identity-and-access-management), [Role 1](#38-the-three-iam-roles-for-assignment-a1) |
| S3 | `s3:ListBucket` | List a bucket's contents | Allow | [3.7](#37-iam-identity-and-access-management), [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| S3 | `s3:PutObject` | Write an object | Deny | [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| S3 | `s3:DeleteObject` | Delete an object | Deny | [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| Secrets Manager | `secretsmanager:GetSecretValue` | Read a secret | Allow | [Role 1](#38-the-three-iam-roles-for-assignment-a1), [Role 2](#38-the-three-iam-roles-for-assignment-a1) |
| Secrets Manager | `secretsmanager:PutSecretValue` | Write / rotate a secret | Allow | [Role 2](#38-the-three-iam-roles-for-assignment-a1) |
| CloudWatch Logs | `logs:CreateLogStream` | Open a new log stream | Allow | [Role 1](#38-the-three-iam-roles-for-assignment-a1) |
| CloudWatch Logs | `logs:PutLogEvents` | Write log lines | Allow | [Role 1](#38-the-three-iam-roles-for-assignment-a1) |
| CloudWatch Logs | `logs:GetLogEvents` | Read log lines | Allow | [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| CloudWatch Logs | `logs:DescribeLogGroups` | List log groups | Allow | [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| EC2 | `ec2:Describe*` | Any read-only Describe call | Allow | [Role 2](#38-the-three-iam-roles-for-assignment-a1), [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| EC2 | `ec2:StartInstances` | Start a stopped instance | Allow | [Role 2](#38-the-three-iam-roles-for-assignment-a1) |
| EC2 | `ec2:StopInstances` | Stop a running instance | Allow | [Role 2](#38-the-three-iam-roles-for-assignment-a1) |
| EC2 | `ec2:Run*` | Launch new instances (RunInstances) | Deny | [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| EC2 | `ec2:Terminate*` | Terminate instances | Deny | [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| EC2 | `ec2:Create*` | Create EC2 resources (volumes, snapshots, etc.) | Deny | [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| EC2 | `ec2:Delete*` | Delete EC2 resources | Deny | [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| ECS | `ecs:Describe*` | Any read-only Describe call | Allow | [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| ECS | `ecs:List*` | Any read-only List call | Allow | [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| ECS | `ecs:DescribeServices` | Read service status | Allow | [Role 2](#38-the-three-iam-roles-for-assignment-a1) |
| ECS | `ecs:UpdateService` | Roll out a new task definition to a service | Allow | [Role 2](#38-the-three-iam-roles-for-assignment-a1) |
| ECS | `ecs:RegisterTaskDefinition` | Register a new task definition revision | Allow | [Role 2](#38-the-three-iam-roles-for-assignment-a1) |
| IAM | `iam:*` | Every IAM action, no exceptions | Deny | [Role 2](#38-the-three-iam-roles-for-assignment-a1) |
| IAM | `iam:Get*` | Read a single IAM resource | Allow | [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| IAM | `iam:List*` | List IAM resources | Allow | [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| IAM | `iam:Create*` | Create IAM resources (users, roles, policies) | Deny | [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| IAM | `iam:Delete*` | Delete IAM resources | Deny | [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| IAM | `iam:Put*` | Write inline policies / config | Deny | [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| IAM | `iam:Attach*` | Attach a managed policy to a principal | Deny | [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| RDS | `rds:Describe*` | Any read-only Describe call | Allow | [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| CloudTrail | `cloudtrail:LookupEvents` | Search the audit log | Allow | [Role 3](#38-the-three-iam-roles-for-assignment-a1) |
| STS | `sts:AssumeRole` | Assume a role and get temporary credentials | Allow | [3.7, Trust policies](#37-iam-identity-and-access-management) |

!!! note "Reading tip"

    A trailing `*` is a wildcard within that action namespace — `ec2:Describe*` covers `DescribeInstances`, `DescribeVolumes`, every Describe call EC2 has, present or future. `iam:*` is the widest wildcard here: every action in the entire IAM service.
