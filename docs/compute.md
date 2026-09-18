---
title: Compute & Scaling
---

# Compute & Scaling: EC2, AMIs & Auto Scaling

## 05 EC2, AMIs & Auto Scaling

### 5.1 Launching an EC2 Instance

An EC2 instance is a virtual server. You choose four things when you launch one:

AMI (Amazon Machine Image)
:   The template — which OS, which pre-installed software. Amazon Linux 2023, Ubuntu 24.04, or your own custom image.

Instance type
:   The hardware — how much CPU and RAM. `t3.micro` (2 vCPU, 1 GB) is free tier. `m5.xlarge` (4 vCPU, 16 GB) is production-grade.

Key pair
:   SSH key for logging in. Create once, reuse. Download the `.pem` file and keep it safe — you can't download it again.

Network settings
:   Which VPC, which subnet, which security group. This determines who can reach the instance and what it can reach.

#### Step 1: Find the latest AMI

AMIs get deprecated regularly. Always search for the current one:

``` bash
# Latest Amazon Linux 2023
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023*-x86_64" \
            "Name=state,Values=available" \
  --query "Images | sort_by(@, &CreationDate) | [-1].{ID:ImageId,Name:Name}" \
  --output table

# Latest Ubuntu 24.04
aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
            "Name=state,Values=available" \
  --query "Images | sort_by(@, &CreationDate) | [-1].{ID:ImageId,Name:Name}" \
  --output table
```

#### Step 2: Check which instance types are free tier

``` bash
aws ec2 describe-instance-types \
  --filters "Name=free-tier-eligible,Values=true" \
  --query "InstanceTypes[].InstanceType" \
  --output table
```

!!! danger "Gotcha"

    `t2.micro` is no longer free tier on newer accounts — it's been replaced by `t3.micro`. Always check with the command above before launching.

#### Step 3: Find your VPC subnets and security groups

``` bash
# List subnets in your hand-built VPC
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0123456789abcdef0" \
  --query "Subnets[].{ID:SubnetId,Name:Tags[?Key=='Name']|[0].Value,CIDR:CidrBlock}" \
  --output table

# List security groups in your hand-built VPC
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=vpc-0123456789abcdef0" \
  --query "SecurityGroups[].{ID:GroupId,Name:GroupName}" \
  --output table
```

!!! danger "Common mistake"

    Using the default VPC subnet (`172.31.x.x`) instead of your hand-built VPC subnet (`10.0.x.x`). Always verify the subnet ID belongs to `vpc-0123456789abcdef0`, not `vpc-0fedcba9876543210` (the default).

#### Step 4: Create security groups if missing

``` bash
# ALB security group
aws ec2 create-security-group \
  --group-name fahad-alb-sg \
  --description "ALB - allows HTTPS/HTTP from internet" \
  --vpc-id vpc-0123456789abcdef0 \
  --query "GroupId" --output text

# App security group
aws ec2 create-security-group \
  --group-name fahad-app-sg \
  --description "App servers - allows traffic from ALB only" \
  --vpc-id vpc-0123456789abcdef0 \
  --query "GroupId" --output text

# DB security group
aws ec2 create-security-group \
  --group-name fahad-db-sg \
  --description "Database - allows traffic from App only" \
  --vpc-id vpc-0123456789abcdef0 \
  --query "GroupId" --output text
```

#### Step 5: Add inbound rules (the chain)

``` bash
# ALB-sg: allow HTTPS and HTTP from internet
aws ec2 authorize-security-group-ingress \
  --group-id <ALB_SG_ID> \
  --protocol tcp --port 443 --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id <ALB_SG_ID> \
  --protocol tcp --port 80 --cidr 0.0.0.0/0

# App-sg: allow 8080 from ALB-sg ONLY
aws ec2 authorize-security-group-ingress \
  --group-id <APP_SG_ID> \
  --protocol tcp --port 8080 \
  --source-group <ALB_SG_ID>

# DB-sg: allow 5432 from App-sg ONLY
aws ec2 authorize-security-group-ingress \
  --group-id <DB_SG_ID> \
  --protocol tcp --port 5432 \
  --source-group <APP_SG_ID>
```

#### Step 6: Launch the instance

``` bash
aws ec2 run-instances \
  --image-id <AMI_ID_FROM_STEP_1> \
  --instance-type t3.micro \
  --key-name devopsKeypair \
  --subnet-id <fahad-private-app-a SUBNET_ID> \
  --security-group-ids <fahad-app-sg ID> \
  --count 1 \
  --tag-specifications 'ResourceType=instance,Tags=[
    {Key=Name,Value=fahad-web-dev},
    {Key=Environment,Value=dev},
    {Key=Owner,Value=fahad},
    {Key=Project,Value=ecommerce-platform},
    {Key=ManagedBy,Value=manual}
  ]'
```

#### Step 7: Verify it landed in the right VPC

``` bash
# Check — IP should be 10.0.10.x, NOT 172.31.x.x
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=fahad-web-dev" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].{ID:InstanceId,IP:PrivateIpAddress,Subnet:SubnetId,VPC:VpcId,State:State.Name}" \
  --output table
```

#### Manage instances

``` bash
# List all running instances (clean table view)
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].{ID:InstanceId,State:State.Name,Type:InstanceType,IP:PrivateIpAddress,Name:Tags[?Key=='Name']|[0].Value}" \
  --output table

# Stop (keeps data, stops billing compute)
aws ec2 stop-instances --instance-ids i-xxxxx

# Start again
aws ec2 start-instances --instance-ids i-xxxxx

# Terminate (permanent delete)
aws ec2 terminate-instances --instance-ids i-xxxxx

# Terminate multiple at once
aws ec2 terminate-instances --instance-ids i-aaa111 i-bbb222 i-ccc333
```

!!! note "Free tier"

    750 hours/month of `t3.micro` for 12 months. One instance 24/7 fits exactly. Two running simultaneously = the second one costs ~$7.50/month. Always check `aws ec2 describe-instances` to know what's running.

### 5.2 User-Data Bootstrap Script

A shell script that runs automatically on first boot, as root. Used to install packages, configure services, and prepare the instance for its role.

``` bash
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello from $(hostname)</h1>" > /var/www/html/index.html
```

Pass it when launching:

``` bash
aws ec2 run-instances \
  --user-data file://bootstrap.sh \
  ...
```

!!! danger "Failure mode"

    User-data runs once on first boot only. If it fails silently, the instance looks "running" but isn't configured. Check `/var/log/cloud-init-output.log` to debug.

!!! success "Best practice"

    Keep user-data short — install an agent, pull config from S3 or Parameter Store. Heavy installs belong in a Golden AMI (next section) for faster boot times.

### 5.3 Golden AMI Pipeline

Instead of installing everything via user-data on every boot, you bake a **Golden AMI** — a pre-configured image with all dependencies already installed. Instances boot in ~30 seconds instead of ~4 minutes.

#### Step 1: Launch a base instance in a public subnet

You need to SSH into this instance to install packages, so it must be in a **public subnet** with internet access and a security group that allows SSH.

``` bash
# Launch in fahad-public-a with ALB security group
aws ec2 run-instances \
  --image-id ami-0aaaaaaaaaaaaaaaa \
  --instance-type t3.micro \
  --key-name devopsKeypair \
  --subnet-id subnet-0aaa1111aaaa11111 \
  --security-group-ids sg-0aaa00001111bbbb \
  --count 1 \
  --tag-specifications 'ResourceType=instance,Tags=[
    {Key=Name,Value=fahad-golden-base},
    {Key=Owner,Value=fahad}
  ]' \
  --profile fahad
```

!!! danger "Don't use an existing project instance"

    Never bake a Golden AMI from an instance running a project (like nsl-ledgerly). It has project-specific code, credentials, logs, and SSH history that would leak into every new instance. Always start from a fresh base AMI.

#### Step 2: Wait for the instance to be running, get its public IP

``` bash
# Wait ~30 seconds, then check (pending → running takes time)
aws ec2 describe-instances \
  --instance-ids <INSTANCE_ID> \
  --query "Reservations[0].Instances[0].{PublicIP:PublicIpAddress,State:State.Name}" \
  --output table \
  --profile fahad
```

!!! note "Why wait 30 seconds?"

    When you launch, the state is `pending` — AWS is finding a server, attaching the EBS volume, starting the VM, and assigning a public IP. Until the state becomes `running`, there's no public IP. That's why `PublicDnsName` is empty in the launch output.

#### Step 3: Ensure SSH access (port 22)

Check if port 22 is open in your security group:

``` bash
# Check existing rules
aws ec2 describe-security-groups \
  --group-ids sg-0aaa00001111bbbb \
  --query "SecurityGroups[0].IpPermissions[].{Port:FromPort}" \
  --output table \
  --profile fahad

# If port 22 is NOT listed, add it temporarily
aws ec2 authorize-security-group-ingress \
  --group-id sg-0aaa00001111bbbb \
  --protocol tcp --port 22 --cidr 0.0.0.0/0 \
  --profile fahad
```

!!! note "Why port 22?"

    Port 22 = SSH, the protocol for remote login to Linux servers. Security groups block everything by default. Without a port 22 rule, your SSH connection is silently dropped — no error, just a timeout. The ALB security group only has 80 (HTTP) and 443 (HTTPS), which is correct for web traffic but doesn't include SSH.

#### Troubleshooting: SSH hangs at "Connecting"

If `ssh -v` shows `debug1: Connecting to x.x.x.x port 22.` and then hangs, check these three things in order:

**Problem 1: Route table not associated with the public subnet**

This is the most common issue. You created `fahad-public-rt` with the IGW route, but forgot to associate it with the public subnets. Without association, the subnet uses the VPC's main route table (which has no internet route).

``` bash
# Check: does the public subnet have a route table?
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=subnet-0aaa1111aaaa11111" \
  --query "RouteTables[].{ID:RouteTableId,Routes:Routes[].{Dest:DestinationCidrBlock,Target:GatewayId}}" \
  --output table \
  --profile fahad

# If empty → no route table associated. Fix:
aws ec2 associate-route-table \
  --route-table-id rtb-0aaa99998888bbbb \
  --subnet-id subnet-0aaa1111aaaa11111 \
  --profile fahad

# Do the same for fahad-public-b
aws ec2 associate-route-table \
  --route-table-id rtb-0aaa99998888bbbb \
  --subnet-id subnet-0bbb2222bbbb22222 \
  --profile fahad
```

**Problem 2: Internet Gateway not attached to VPC**

``` bash
# Check: is the IGW attached?
aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=vpc-0123456789abcdef0" \
  --query "InternetGateways[].{ID:InternetGatewayId,State:Attachments[0].State}" \
  --output table \
  --profile fahad

# If State is "detached" or empty:
aws ec2 attach-internet-gateway \
  --internet-gateway-id igw-0aaa11112222bbbb \
  --vpc-id vpc-0123456789abcdef0 \
  --profile fahad
```

**Problem 3: SSH key file not found**

``` bash
# Error: "Identity file /home/user/.ssh/mymac.pem not accessible: No such file"

# Find the key file on your machine
find ~ -name "*.pem" -type f 2>/dev/null

# If the key is lost (can't re-download from AWS), create a new one:
aws ec2 create-key-pair \
  --key-name devopsKeypair \
  --query "KeyMaterial" \
  --output text \
  --profile fahad > ~/.ssh/devopsKeypair.pem

chmod 400 ~/.ssh/devopsKeypair.pem

# Then terminate the instance and relaunch with the new key
# (you can't change the key of a running instance)
```

**Problem 4: Permission denied on .pem file**

``` bash
# Error: "Permissions 0644 for 'key.pem' are too open"
chmod 400 ~/.ssh/devopsKeypair.pem
```

#### Step 4: SSH in and install packages

``` bash
ssh -i ~/.ssh/devopsKeypair.pem ec2-user@<PUBLIC_IP>

# Inside the instance — run these:

# Update OS
sudo yum update -y

# Install Python 3.12 and pip
sudo yum install -y python3.12 python3.12-pip

# Install Nginx
sudo yum install -y nginx
sudo systemctl enable nginx

# Install app dependencies
sudo pip3.12 install gunicorn django==5.1

# Install CloudWatch agent
sudo yum install -y amazon-cloudwatch-agent

# Harden SSH: disable root login
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Clean up before snapshot (remove temp files, logs, SSH history)
sudo rm -rf /tmp/* /var/log/*.log
history -c

# Exit back to your local machine
exit
```

#### Step 5: Bake the Golden AMI

``` bash
aws ec2 create-image \
  --instance-id <INSTANCE_ID> \
  --name "golden-ecommerce-v1.0-$(date +%Y%m%d)" \
  --description "AL2023 + Python 3.12 + Nginx + Django 5.1 + CW agent" \
  --tag-specifications 'ResourceType=image,Tags=[
    {Key=Name,Value=golden-ecommerce-v1.0},
    {Key=Owner,Value=fahad},
    {Key=Project,Value=ecommerce-platform},
    {Key=BaseAMI,Value=ami-0aaaaaaaaaaaaaaaa}
  ]' \
  --profile fahad

# Check if it's ready (takes 3-5 minutes: pending → available)
aws ec2 describe-images \
  --owners self \
  --query "Images[].{ID:ImageId,Name:Name,State:State}" \
  --output table \
  --profile fahad
```

!!! note "BaseAMI tag"

    Tag the Golden AMI with the base AMI ID it was built from. When Amazon releases a security patch, you know which base to re-bake from.

#### Step 6: Clean up

``` bash
# Terminate the base instance (no longer needed)
aws ec2 terminate-instances \
  --instance-ids <INSTANCE_ID> \
  --profile fahad

# Remove SSH access from ALB security group (security hygiene)
aws ec2 revoke-security-group-ingress \
  --group-id sg-0aaa00001111bbbb \
  --protocol tcp --port 22 --cidr 0.0.0.0/0 \
  --profile fahad
```

!!! danger "Don't forget"

    Always remove the port 22 rule after you're done. SSH from `0.0.0.0/0` means anyone on the internet can attempt to connect. In production, use AWS Systems Manager Session Manager instead — no SSH port needed at all.

#### Step 7: Use the Golden AMI going forward

``` bash
# Our Golden AMI: ami-0bbbbbbbbbbbbbbbb
# Use it instead of the base Amazon AMI in all future launches:

aws ec2 run-instances \
  --image-id ami-0bbbbbbbbbbbbbbbb \
  --instance-type t3.micro \
  --key-name devopsKeypair \
  --subnet-id subnet-0ccc3333cccc33333 \
  --security-group-ids sg-0bbb00002222cccc \
  --profile fahad

# Boot time: ~30 seconds (vs ~4 minutes with user-data bootstrap)
```

#### Managing Golden AMIs

``` bash
# List all your custom AMIs
aws ec2 describe-images \
  --owners self \
  --query "Images[].{ID:ImageId,Name:Name,State:State,Date:CreationDate}" \
  --output table \
  --profile fahad

# Deregister an old AMI you no longer need
aws ec2 deregister-image \
  --image-id ami-xxxxx \
  --profile fahad
```

#### When to re-bake

- **New OS security patch** — Amazon releases an updated base AMI, you rebuild on top of it
- **New system dependency** — adding Redis client, upgrading Python version
- **Configuration change** — new monitoring agent config, updated SSH hardening
- **NOT for app code changes** — your app code is pulled fresh at boot (from S3 or a container registry), so you don't re-bake just for a code deploy

Re-baking uses the same steps as the first bake — the difference is what you start *from*:

```
First bake:       Amazon Linux AMI → install everything → Golden v1.0
Re-bake:          Golden v1.0 → apply changes → Golden v1.1
Security re-bake: NEW Amazon Linux AMI → install everything fresh → Golden v2.0
```

!!! danger "Gotcha"

    Step 6 of the first bake revoked port 22 from `sg-0aaa00001111bbbb` as security hygiene — which means it's *closed by default* every time you come back to re-bake. Both scenarios below re-open it before SSHing and revoke it again during clean-up. Skip that and SSH just hangs at "Connecting", same symptom as the troubleshooting section above, different cause.

#### Scenario 1 — small update (add a package, change a config)

Start from your existing Golden AMI — everything is already installed, you just add the change:

``` bash
# 1. Launch from your EXISTING Golden AMI (not the raw Amazon base)
aws ec2 run-instances \
  --image-id ami-0bbbbbbbbbbbbbbbb \
  --instance-type t3.micro \
  --key-name devopsKeypair \
  --subnet-id subnet-0aaa1111aaaa11111 \
  --security-group-ids sg-0aaa00001111bbbb \
  --tag-specifications 'ResourceType=instance,Tags=[
    {Key=Name,Value=fahad-golden-rebake}
  ]' \
  --profile fahad

# 2. Re-open port 22 — Step 6 of the first bake revoked it, so it's
#    almost certainly closed again. Skipping this = SSH hangs at
#    "Connecting" with no error, same symptom as the troubleshooting
#    section above, just a different cause.
aws ec2 authorize-security-group-ingress \
  --group-id sg-0aaa00001111bbbb \
  --protocol tcp --port 22 --cidr 0.0.0.0/0 \
  --profile fahad

# 3. SSH in — everything from v1.0 is already there
ssh -i ~/.ssh/devopsKeypair.pem ec2-user@<PUBLIC_IP>

# 4. Apply only the change
sudo pip3.12 install redis          # example: adding Redis client
sudo systemctl enable redis         # example: enabling a new service

# 5. Clean up and exit
sudo rm -rf /tmp/* /var/log/*.log
history -c
exit

# 6. Bake as v1.1
aws ec2 create-image \
  --instance-id <INSTANCE_ID> \
  --name "golden-ecommerce-v1.1-$(date +%Y%m%d)" \
  --description "v1.0 + Redis client" \
  --tag-specifications 'ResourceType=image,Tags=[
    {Key=Name,Value=golden-ecommerce-v1.1},
    {Key=Owner,Value=fahad},
    {Key=BaseAMI,Value=ami-0bbbbbbbbbbbbbbbb},
    {Key=ChangeLog,Value=added-redis-client}
  ]' \
  --profile fahad

# 7. Clean up — terminate the instance AND re-revoke port 22
aws ec2 terminate-instances --instance-ids <INSTANCE_ID> --profile fahad
aws ec2 revoke-security-group-ingress \
  --group-id sg-0aaa00001111bbbb \
  --protocol tcp --port 22 --cidr 0.0.0.0/0 \
  --profile fahad
```

#### Scenario 2 — security re-bake (new Amazon base AMI)

Amazon released a patched base AMI — you need to rebuild from scratch on the new base to get the OS-level security fixes:

``` bash
# 1. Find the latest Amazon Linux AMI
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023*-x86_64" \
            "Name=state,Values=available" \
  --query "Images | sort_by(@, &CreationDate) | [-1].{ID:ImageId,Name:Name}" \
  --output table --profile fahad

# 2. Launch from the NEW base (not your old Golden AMI)
aws ec2 run-instances \
  --image-id <NEW_AMAZON_AMI> \
  --instance-type t3.micro \
  --key-name devopsKeypair \
  --subnet-id subnet-0aaa1111aaaa11111 \
  --security-group-ids sg-0aaa00001111bbbb \
  --tag-specifications 'ResourceType=instance,Tags=[
    {Key=Name,Value=fahad-golden-rebake-v2}
  ]' \
  --profile fahad

# 3. Re-open port 22 — same reason as Scenario 1: Step 6 of the first
#    bake revoked it, so it's almost certainly closed right now.
aws ec2 authorize-security-group-ingress \
  --group-id sg-0aaa00001111bbbb \
  --protocol tcp --port 22 --cidr 0.0.0.0/0 \
  --profile fahad

# 4. SSH in and install EVERYTHING from scratch (same as first bake)
ssh -i ~/.ssh/devopsKeypair.pem ec2-user@<PUBLIC_IP>

sudo yum update -y
sudo yum install -y python3.12 python3.12-pip nginx amazon-cloudwatch-agent
sudo pip3.12 install gunicorn django==5.1
sudo systemctl enable nginx
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
# ... plus any packages added since v1.0 (like redis from v1.1)
sudo pip3.12 install redis

sudo rm -rf /tmp/* /var/log/*.log
history -c
exit

# 5. Bake as v2.0 (major version = new base)
aws ec2 create-image \
  --instance-id <INSTANCE_ID> \
  --name "golden-ecommerce-v2.0-$(date +%Y%m%d)" \
  --description "NEW base AL2023 + Python 3.12 + Nginx + Django 5.1 + Redis + CW agent" \
  --tag-specifications 'ResourceType=image,Tags=[
    {Key=Name,Value=golden-ecommerce-v2.0},
    {Key=Owner,Value=fahad},
    {Key=BaseAMI,Value=<NEW_AMAZON_AMI>},
    {Key=ChangeLog,Value=security-rebake-new-base}
  ]' \
  --profile fahad

# 6. Clean up — terminate the instance AND re-revoke port 22
aws ec2 terminate-instances --instance-ids <INSTANCE_ID> --profile fahad
aws ec2 revoke-security-group-ingress \
  --group-id sg-0aaa00001111bbbb \
  --protocol tcp --port 22 --cidr 0.0.0.0/0 \
  --profile fahad
```

#### Which scenario, when?

| Trigger | Approach | Version bump |
|---|---|---|
| Add a package (redis, memcached client) | Scenario 1: build on existing Golden AMI | v1.0 → v1.1 |
| Change a config (Nginx settings, SSH hardening) | Scenario 1: build on existing Golden AMI | v1.1 → v1.2 |
| Upgrade Python (3.12 → 3.13) | Scenario 2: fresh from new base | v1.x → v2.0 |
| Amazon releases OS security patch | Scenario 2: fresh from new base | v1.x → v2.0 |
| Major dependency upgrade (Django 5.1 → 6.0) | Scenario 2: safer to rebuild clean | v1.x → v2.0 |

#### After re-baking: update the launch template

The Golden AMI is useless if your ASG (see [5.5](#55-auto-scaling-groups-asg)) is still pointing to the old one — this uses the launch template mechanics from [5.4](#54-launch-templates):

``` bash
# Create new launch template version with the new AMI
aws ec2 create-launch-template-version \
  --launch-template-name ecommerce-web \
  --version-description "v2.0 - security rebake" \
  --source-version 1 \
  --launch-template-data '{"ImageId": "ami-NEW_GOLDEN_AMI"}' \
  --profile fahad

# Set it as default
aws ec2 modify-launch-template \
  --launch-template-name ecommerce-web \
  --default-version 2 \
  --profile fahad

# ASG picks up the new version on next scale-out
# To force all instances to update NOW:
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name fahad-web-asg \
  --profile fahad
```

The `instance-refresh` command does a rolling replacement — terminates old instances one by one and launches new ones from the updated template. Zero downtime if you have multiple instances across AZs.

#### Keep a version history

``` bash
# List all your Golden AMIs in order
aws ec2 describe-images \
  --owners self \
  --query "Images | sort_by(@, &CreationDate) | [].{ID:ImageId,Name:Name,Date:CreationDate,Base:Tags[?Key=='BaseAMI']|[0].Value}" \
  --output table \
  --profile fahad
```

This gives you a timeline of every Golden AMI you've built, when, and which base it came from. Never delete the currently active AMI — keep at least the previous version as rollback.

#### Lab: v1.0 → v1.1 re-bake (adding Docker)

This is what we actually did — a Scenario 1 re-bake to add Docker and Docker Compose to the Golden AMI.

**Install Docker and Docker Compose inside SSH session:**

``` bash
# Install Docker
sudo yum install -y docker
sudo systemctl enable docker
sudo systemctl start docker

# Add ec2-user to docker group (no sudo needed for docker commands)
sudo usermod -aG docker ec2-user

# Install Docker Compose v2 (as a Docker CLI plugin)
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Verify both
docker --version
docker compose version

# If docker --version gives permission error, the group change hasn't taken effect:
newgrp docker
docker --version
```

!!! danger "Gotcha: Redis client ≠ Redis server"

    `pip install redis` installs the **Python client library** (lets your app talk to a Redis server). `systemctl enable redis` tries to start the **Redis server process** — which you didn't install. These are two different things with the same name.

    For production, use **ElastiCache** (AWS managed Redis) — your Golden AMI only needs the Python client, not the server. If you want a local Redis server for testing:

``` bash
# Only if you need Redis SERVER on the instance (not typical for production)
sudo yum install -y redis6
sudo systemctl enable redis6
sudo systemctl start redis6
redis-cli ping    # returns PONG
```

**Bake result:**

``` bash
# After installing Docker, clean up and exit SSH:
sudo rm -rf /tmp/* /var/log/*.log
history -c
exit

# Bake v1.1 from local machine:
aws ec2 create-image \
  --instance-id i-0eee5555ffff6666 \
  --name "golden-ecommerce-v1.1-$(date +%Y%m%d)" \
  --description "v1.0 + Redis client + Docker + Docker Compose" \
  --tag-specifications 'ResourceType=image,Tags=[
    {Key=Name,Value=golden-ecommerce-v1.1},
    {Key=Owner,Value=fahad},
    {Key=BaseAMI,Value=ami-0bbbbbbbbbbbbbbbb},
    {Key=ChangeLog,Value=added-redis-docker-compose}
  ]' \
  --profile fahad
```

**Current AMI inventory:**

| Version | AMI ID | Contents | Status |
|---|---|---|---|
| v1.0 | `ami-0bbbbbbbbbbbbbbbb` | Python 3.12, Nginx, Django 5.1, CW agent | Rollback (keep) |
| v1.1 | `ami-0ccccccccccccccc` | v1.0 + Redis client + Docker + Docker Compose | Current (active) |

#### Where these AMIs actually live

A Golden AMI is stored as an **EBS snapshot in S3** — but you never see that S3 bucket directly. AWS manages it entirely behind the scenes; the AMI itself is just a pointer to it:

```
Golden AMI (ami-0ccccccccccccccc)
    └── points to → EBS Snapshot (snap-xxxxx)
                        └── stored in → S3 (AWS-managed, invisible to you)
```

See both of our AMIs' snapshots at once:

``` bash
aws ec2 describe-images \
  --image-ids ami-0bbbbbbbbbbbbbbbb ami-0ccccccccccccccc \
  --query "Images[].{AMI:ImageId,Name:Name,Snapshots:BlockDeviceMappings[].Ebs.SnapshotId}" \
  --output table \
  --profile fahad
```

| What | Where | Can you see it? | Cost |
|---|---|---|---|
| AMI metadata (name, tags, config) | EC2 AMI registry (regional) | Yes — `describe-images` | Free |
| EBS snapshot (the actual disk data) | S3 (AWS-managed) | Yes — `describe-snapshots` | ~$0.05/GB/month |
| The S3 bucket itself | AWS's internal infrastructure | No — you can't browse it | Included in snapshot price |

!!! note "Regional, not AZ-specific"

    An AMI exists only in the region you built it in — `ap-south-1` here, not tied to a specific AZ within it. Want to use it in `eu-west-1`? You have to copy it there explicitly:

``` bash
# Copy an AMI to another region (for multi-region deployment)
aws ec2 copy-image \
  --source-image-id ami-0ccccccccccccccc \
  --source-region ap-south-1 \
  --region eu-west-1 \
  --name "golden-ecommerce-v1.1-copy" \
  --profile fahad
```

The AMI registration itself is free — it's just a pointer. The snapshot behind it is what actually costs money, which is why deleting an AMI takes two steps (see below): deregistering alone leaves the snapshot billing forever. At this point you should see two snapshots — one for v1.0, one for v1.1 — roughly 8GB each, about $0.80/month total. Minimal cost, but worth knowing where it comes from.

#### Troubleshooting: forgot the instance ID

If you launched an instance but didn't save the ID, find it by searching running instances:

``` bash
# Find all running instances (not just yours)
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].{ID:InstanceId,Name:Tags[?Key=='Name']|[0].Value,IP:PrivateIpAddress,VPC:VpcId}" \
  --output table \
  --profile fahad

# If you know the IP from your SSH prompt (e.g. ec2-user@ip-10-0-1-164):
# Look for IP 10.0.1.164 in the table — that row has your instance ID
```

!!! note "Tip"

    If you filtered by `tag:Owner,Values=fahad` and got nothing, the instance might not have an Owner tag. Drop the tag filter and search all running instances. The SSH prompt always shows the private IP — match it to the table.

#### When and how to delete old Golden AMIs

| Situation | Action |
|---|---|
| v1.1 just created (now) | Keep v1.0 as rollback |
| v1.1 tested and stable for a few days | Safe to delete v1.0 |
| v2.0 created (security re-bake) | Keep v1.1, delete v1.0 |
| **General rule** | **Always keep current + one previous version** |

**Deleting an AMI — two steps (not one!):**

Deregistering the AMI alone isn't enough — the EBS snapshot behind it keeps charging ~$0.05/GB/month.

``` bash
# Step 1: Find the snapshot backing the AMI
aws ec2 describe-images \
  --image-ids ami-0bbbbbbbbbbbbbbbb \
  --query "Images[0].BlockDeviceMappings[].Ebs.SnapshotId" \
  --output text \
  --profile fahad

# Step 2: Deregister the AMI (removes it from your AMI list)
aws ec2 deregister-image \
  --image-id ami-0bbbbbbbbbbbbbbbb \
  --profile fahad

# Step 3: Delete the orphan snapshot (stops the storage charge)
aws ec2 delete-snapshot \
  --snapshot-id <SNAPSHOT_ID_FROM_STEP_1> \
  --profile fahad
```

!!! danger "Don't skip step 3"

    If you only deregister without deleting the snapshot, the snapshot sits in your account silently charging. Check for orphan snapshots periodically:

``` bash
# Find all snapshots you own
aws ec2 describe-snapshots \
  --owner-ids self \
  --query "Snapshots[].{ID:SnapshotId,Size:VolumeSize,Date:StartTime,Desc:Description}" \
  --output table \
  --profile fahad
```

!!! success "Immutable infra"

    Golden AMIs are the foundation of immutable infrastructure: you never SSH into a production server to patch it. Build a new AMI with the fix, replace the old instances via the ASG. This prevents configuration drift — every instance is identical, built from the same image.

### 5.4 Launch Templates

A **launch template** is a versioned configuration blueprint: AMI, instance type, security groups, user-data, IAM role — everything needed to launch an instance, saved as a reusable template.

``` bash
# Create launch template using our Golden AMI v1.1 (with Docker)
aws ec2 create-launch-template \
  --launch-template-name ecommerce-web \
  --version-description "v1 - golden AMI v1.1 with Python+Nginx+Django+Docker" \
  --launch-template-data '{
    "ImageId": "ami-0ccccccccccccccc",
    "InstanceType": "t3.micro",
    "KeyName": "devopsKeypair",
    "SecurityGroupIds": ["sg-0bbb00002222cccc"],
    "TagSpecifications": [{
      "ResourceType": "instance",
      "Tags": [
        {"Key": "Name", "Value": "fahad-web"},
        {"Key": "Environment", "Value": "dev"},
        {"Key": "Owner", "Value": "fahad"},
        {"Key": "Project", "Value": "ecommerce-platform"},
        {"Key": "ManagedBy", "Value": "manual"}
      ]
    }]
  }' \
  --profile fahad
```

Templates are versioned. When you update (new Golden AMI, different instance type), create a new version — the old version stays as rollback:

``` bash
# Create a new version (e.g. updated Golden AMI)
aws ec2 create-launch-template-version \
  --launch-template-name ecommerce-web \
  --version-description "v2 - updated golden AMI" \
  --source-version 1 \
  --launch-template-data '{
    "ImageId": "ami-NEW_GOLDEN_AMI_ID"
  }' \
  --profile fahad

# List versions
aws ec2 describe-launch-template-versions \
  --launch-template-name ecommerce-web \
  --query "LaunchTemplateVersions[].{Version:VersionNumber,Desc:VersionDescription,AMI:LaunchTemplateData.ImageId}" \
  --output table \
  --profile fahad

# Set default version
aws ec2 modify-launch-template \
  --launch-template-name ecommerce-web \
  --default-version 2 \
  --profile fahad
```

Auto Scaling Groups reference a template version — `$Latest` (always newest), `$Default` (the one you set), or a specific number.

### 5.5 Auto Scaling Groups (ASG)

An ASG maintains a fleet of instances — it ensures you always have the right number running, replaces unhealthy ones, and spreads them across AZs.

#### Three capacity settings

| Setting | What it means | Example |
|---|---|---|
| **Minimum** | Never go below this, even during scale-in | 1 (always at least 1 running) |
| **Desired** | How many to run right now — ASG launches/terminates to match | 1 (free tier safe with nsl-ledgerly running) |
| **Maximum** | Never go above this, even under heavy load | 3 (budget ceiling) |

#### How it works with AZs

If you set desired=4 across 2 AZs, ASG places 2 in each AZ. If AZ-a goes down, ASG launches 2 replacements in AZ-b (up to the max). This is automatic fault tolerance — you don't write any code for it.

#### Health checks

ASG checks if instances are healthy. Two types:

- **EC2 health check:** is the instance running? (default — catches crashes and hardware failures)
- **ELB health check:** is the ALB's health check passing? (catches app-level failures — process running but returning 500s)

Always use ELB health checks when you have a load balancer. An instance can be "running" (EC2 healthy) but serving errors (ELB unhealthy). Without ELB health checks, ASG won't replace it.

#### Step 1: Create the launch template (prerequisite)

The ASG needs a launch template to know what to launch. We created this in [5.4](#54-launch-templates):

``` bash
# Verify your launch template exists
aws ec2 describe-launch-templates \
  --launch-template-names ecommerce-web \
  --query "LaunchTemplates[0].{ID:LaunchTemplateId,Name:LaunchTemplateName,Version:LatestVersionNumber}" \
  --output table \
  --profile fahad

# Our template: lt-0aaa77778888bbbb (ecommerce-web, references Golden AMI v1.1)
```

#### Step 2: Create the ASG

``` bash
# Create with desired=1 to stay within free tier
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name fahad-web-asg \
  --launch-template LaunchTemplateName=ecommerce-web,Version='$Latest' \
  --min-size 1 \
  --max-size 3 \
  --desired-capacity 1 \
  --vpc-zone-identifier "subnet-0ccc3333cccc33333,subnet-0ddd4444dddd44444" \
  --tags Key=Name,Value=fahad-web-asg,PropagateAtLaunch=true \
         Key=Environment,Value=dev,PropagateAtLaunch=true \
         Key=Owner,Value=fahad,PropagateAtLaunch=true \
  --profile fahad
```

!!! note "vpc-zone-identifier"

    This specifies which subnets the ASG launches instances into. Using both private app subnets (`fahad-private-app-a` + `fahad-private-app-b`) across two AZs gives automatic fault tolerance.

!!! danger "Free tier warning"

    Using `desired-capacity 1` (not 2) because `nsl-ledgerly` is already using the free tier t3.micro allowance. Two t3.micro running simultaneously = the second one costs ~$0.01/hr (~$7.50/month).

#### Step 3: Verify the ASG launched an instance

``` bash
# Check ASG status (wait ~30 seconds after creation)
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names fahad-web-asg \
  --query "AutoScalingGroups[0].{Min:MinSize,Max:MaxSize,Desired:DesiredCapacity,Instances:Instances[].{ID:InstanceId,AZ:AvailabilityZone,Health:HealthStatus,State:LifecycleState}}" \
  --output table \
  --profile fahad
```

#### Troubleshooting: instances array is empty

If the ASG shows `"Instances": []`, either it's still launching (wait 30 seconds) or something failed. Check the scaling activity log:

``` bash
# Shows WHY a launch failed (wrong subnet, SG not in VPC, quota hit, etc.)
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name fahad-web-asg \
  --query "Activities[0].{Status:StatusCode,Desc:Description,Cause:Cause}" \
  --profile fahad

# If this returns null, the ASG hasn't even attempted yet — just wait longer

# Full ASG dump (use when --query hides the problem)
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names fahad-web-asg \
  --profile fahad
```

#### Lab: testing scale-out and scale-in

This is the powerful part — manually scaling to see the ASG distribute instances across AZs:

``` bash
# Scale up to 2 instances
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name fahad-web-asg \
  --desired-capacity 2 \
  --profile fahad

# Wait 30 seconds, then check — should see 2 instances in different AZs
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names fahad-web-asg \
  --query "AutoScalingGroups[0].Instances[].{ID:InstanceId,AZ:AvailabilityZone,Health:HealthStatus}" \
  --output table \
  --profile fahad
```

**What we observed:**

```
After scale-out to desired=2:
+--------------+----------+-----------------------+
|      AZ      | Health   |          ID           |
+--------------+----------+-----------------------+
|  ap-south-1b |  Healthy |  i-0ccc3333dddd4444  |
|  ap-south-1a |  Healthy |  i-0aaa1111bbbb2222  |
+--------------+----------+-----------------------+
→ ASG automatically placed one in each AZ for fault tolerance
```

#### Why it landed one per AZ — the actual mechanism

It comes down to this one line from the `create-auto-scaling-group` command:

``` bash
--vpc-zone-identifier "subnet-0ccc3333cccc33333,subnet-0ddd4444dddd44444"
```

That gave the ASG two subnets in two different AZs:

```
subnet-0ccc3333cccc33333 = fahad-private-app-a → ap-south-1a
subnet-0ddd4444dddd44444 = fahad-private-app-b → ap-south-1b
```

The ASG automatically distributes instances across whichever subnets it's given, balancing AZs as it goes:

```
desired=2, 2 subnets → 1 in ap-south-1a, 1 in ap-south-1b
desired=4, 2 subnets → 2 in ap-south-1a, 2 in ap-south-1b
```

!!! danger "One subnet = no fault tolerance"

    If `--vpc-zone-identifier` had listed only `subnet-0ccc3333cccc33333`, every instance would land in `ap-south-1a` alone — if that AZ goes down, everything goes down. There's no separate "spread across AZs" setting to remember: the ASG only ever launches into the subnets you hand it, so AZ coverage is really a side effect of which subnets you listed.

!!! success "The whole trick"

    Give the ASG subnets in multiple AZs, and it handles the distribution automatically. No extra config, no code — just listing two subnet IDs.

``` bash
# Scale back down to 1 (save money!)
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name fahad-web-asg \
  --desired-capacity 1 \
  --profile fahad

# Wait 30 seconds, check which one was terminated
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names fahad-web-asg \
  --query "AutoScalingGroups[0].Instances[].{ID:InstanceId,AZ:AvailabilityZone}" \
  --output table \
  --profile fahad
```

**What we observed:**

```
After scale-in to desired=1:
+--------------+-----------------------+
|      AZ      |          ID           |
+--------------+-----------------------+
|  ap-south-1a |  i-0aaa1111bbbb2222  |
+--------------+-----------------------+
→ ASG terminated the ap-south-1b instance automatically
→ Default termination policy: pick the AZ with more instances, terminate the oldest
```

#### ASG termination policies

When the ASG needs to remove an instance during scale-in, it follows a policy:

| Policy | How it picks | Use when |
|---|---|---|
| **Default** | Balance AZs first → oldest launch template → closest to next billing hour | Most cases (what we used) |
| **OldestInstance** | Terminate the longest-running instance | Rolling AMI updates — replace old images first |
| **NewestInstance** | Terminate the most recently launched | Testing — keep the stable old instances |
| **OldestLaunchTemplate** | Terminate instances using the oldest template version | After launch template update — phase out old config |

#### Manage ASG lifecycle

``` bash
# Check all ASG details
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names fahad-web-asg \
  --query "AutoScalingGroups[0].{Name:AutoScalingGroupName,Min:MinSize,Max:MaxSize,Desired:DesiredCapacity,HealthCheck:HealthCheckType,Instances:Instances[].{ID:InstanceId,AZ:AvailabilityZone,Health:HealthStatus}}" \
  --profile fahad

# Update settings (e.g. change max from 3 to 6)
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name fahad-web-asg \
  --max-size 6 \
  --profile fahad

# Force replace all instances with new launch template version (rolling update)
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name fahad-web-asg \
  --profile fahad

# Protect a specific instance from scale-in (e.g. running a long job)
aws autoscaling set-instance-protection \
  --auto-scaling-group-name fahad-web-asg \
  --instance-ids i-xxxxx \
  --protected-from-scale-in \
  --profile fahad

# Delete ASG entirely (terminates all its instances)
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name fahad-web-asg \
  --force-delete \
  --profile fahad
```

#### End-of-session cleanup

!!! danger "Budget rule"

    Since `nsl-ledgerly` uses your free tier t3.micro, any ASG instance costs real money. Delete the ASG at the end of each study session. The launch template and Golden AMI stay (free) — recreating the ASG next session is one command.

``` bash
# Delete ASG (terminates its instances automatically)
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name fahad-web-asg \
  --force-delete \
  --profile fahad

# Verify no extra instances left running
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].{ID:InstanceId,Name:Tags[?Key=='Name']|[0].Value,Type:InstanceType}" \
  --output table \
  --profile fahad
# Should show only nsl-ledgerly
```

#### Quick recreation next session

``` bash
# One command to bring the ASG back (template + AMI already exist)
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name fahad-web-asg \
  --launch-template LaunchTemplateName=ecommerce-web,Version='$Latest' \
  --min-size 1 \
  --max-size 3 \
  --desired-capacity 1 \
  --vpc-zone-identifier "subnet-0ccc3333cccc33333,subnet-0ddd4444dddd44444" \
  --tags Key=Name,Value=fahad-web-asg,PropagateAtLaunch=true \
         Key=Owner,Value=fahad,PropagateAtLaunch=true \
  --profile fahad
```

### 5.6 Scaling Policies

#### Target tracking (simplest, most common)

Set a target metric, ASG adjusts automatically. You don't define thresholds or step sizes — AWS handles the math:

``` bash
# Keep average CPU at 60%
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name fahad-web-asg \
  --policy-name cpu-target-60 \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ASGAverageCPUUtilization"
    },
    "TargetValue": 60.0
  }' \
  --profile fahad
```

#### What AWS auto-creates for you

When you set a target tracking policy, AWS automatically creates **two CloudWatch alarms**:

| Alarm | What it does | Auto-created name |
|---|---|---|
| **AlarmHigh** | CPU > 60% → scale OUT (add instances) | `TargetTracking-fahad-web-asg-AlarmHigh-xxxxx` |
| **AlarmLow** | CPU drops well below 60% → scale IN (remove instances) | `TargetTracking-fahad-web-asg-AlarmLow-xxxxx` |

You set one target (60% CPU) and AWS created the entire feedback loop — monitoring, decision logic, and actions — automatically. This is why target tracking is the recommended starting point.

``` bash
# See the auto-created alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix "TargetTracking-fahad-web-asg" \
  --query "MetricAlarms[].{Name:AlarmName,State:StateValue,Threshold:Threshold}" \
  --output table \
  --profile fahad
```

#### Lab output — what we got

```
Policy created:
  PolicyARN: arn:aws:autoscaling:ap-south-1:111122223333:scalingPolicy:...

Auto-created alarms:
  AlarmHigh: TargetTracking-fahad-web-asg-AlarmHigh-7cd8afbb-...
  AlarmLow:  TargetTracking-fahad-web-asg-AlarmLow-173efae5-...

→ One put-scaling-policy command = policy + 2 CloudWatch alarms + auto-scaling logic
→ No manual alarm configuration needed
```

#### Predefined metric types for target tracking

| PredefinedMetricType | What it tracks | Use when |
|---|---|---|
| `ASGAverageCPUUtilization` | Average CPU across all instances | General purpose — most common choice |
| `ASGAverageNetworkIn` | Average bytes received per instance | Network-bound workloads (streaming, file uploads) |
| `ASGAverageNetworkOut` | Average bytes sent per instance | Network-bound workloads (API responses, downloads) |
| `ALBRequestCountPerTarget` | Requests per target from the ALB | Web apps — scale by traffic volume, not CPU |

``` bash
# Example: scale based on requests per target (needs ALB target group ARN)
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name fahad-web-asg \
  --policy-name requests-per-target-1000 \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ALBRequestCountPerTarget",
      "ResourceLabel": "app/fahad-web-alb/xxxxx/targetgroup/fahad-web-tg/xxxxx"
    },
    "TargetValue": 1000.0
  }' \
  --profile fahad
```

#### Step scaling (more granular control)

Define explicit thresholds and actions — you control exactly how many instances to add at each level:

``` bash
# First create a CloudWatch alarm that triggers the policy
aws cloudwatch put-metric-alarm \
  --alarm-name fahad-cpu-high-70 \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 70 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=AutoScalingGroupName,Value=fahad-web-asg \
  --profile fahad

# Then create the step scaling policy
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name fahad-web-asg \
  --policy-name cpu-step-scale-out \
  --policy-type StepScaling \
  --adjustment-type ChangeInCapacity \
  --step-adjustments '[
    {"MetricIntervalLowerBound": 0, "MetricIntervalUpperBound": 20, "ScalingAdjustment": 1},
    {"MetricIntervalLowerBound": 20, "ScalingAdjustment": 3}
  ]' \
  --profile fahad
```

This means: if CPU > 70% → add 1 instance. If CPU > 90% (70+20) → add 3 instances. More control than target tracking, but more to configure.

| CPU level | Action | How the step adjustment reads |
|---|---|---|
| 70% – 90% | Add 1 instance | Lower bound 0, upper bound 20 (above the alarm threshold of 70) |
| > 90% | Add 3 instances | Lower bound 20, no upper bound (20+ above threshold) |
| < 30% | Remove 1 instance | Separate scale-in policy (not shown) |

#### Scheduled scaling

Scale based on time, not metrics. Good for predictable traffic patterns:

``` bash
# Scale up to 3 instances at 8am Dhaka time (2am UTC) on weekdays
aws autoscaling put-scheduled-update-group-action \
  --auto-scaling-group-name fahad-web-asg \
  --scheduled-action-name morning-scale-up \
  --recurrence "0 2 * * MON-FRI" \
  --desired-capacity 3 \
  --profile fahad

# Scale back to 1 instance at 10pm Dhaka time (4pm UTC) on weekdays
aws autoscaling put-scheduled-update-group-action \
  --auto-scaling-group-name fahad-web-asg \
  --scheduled-action-name evening-scale-down \
  --recurrence "0 16 * * MON-FRI" \
  --desired-capacity 1 \
  --profile fahad

# List scheduled actions
aws autoscaling describe-scheduled-actions \
  --auto-scaling-group-name fahad-web-asg \
  --query "ScheduledUpdateGroupActions[].{Name:ScheduledActionName,Recurrence:Recurrence,Desired:DesiredCapacity}" \
  --output table \
  --profile fahad

# Delete a scheduled action
aws autoscaling delete-scheduled-action \
  --auto-scaling-group-name fahad-web-asg \
  --scheduled-action-name morning-scale-up \
  --profile fahad
```

!!! note "Cron format"

    The recurrence uses cron syntax: `minute hour day-of-month month day-of-week`. All times are UTC. Dhaka is UTC+6, so 8am Dhaka = 2am UTC.

#### Scale-in protection

Prevents specific instances from being terminated during scale-in. Use for instances running long jobs that shouldn't be interrupted:

``` bash
# Protect a specific instance
aws autoscaling set-instance-protection \
  --auto-scaling-group-name fahad-web-asg \
  --instance-ids i-xxxxx \
  --protected-from-scale-in \
  --profile fahad

# Remove protection
aws autoscaling set-instance-protection \
  --auto-scaling-group-name fahad-web-asg \
  --instance-ids i-xxxxx \
  --no-protected-from-scale-in \
  --profile fahad
```

#### Which policy type to choose?

| Policy type | Complexity | Best for | You manage |
|---|---|---|---|
| **Target tracking** | Simplest | Most workloads — set target, AWS handles the rest | Just the target value |
| **Step scaling** | Medium | Workloads with sudden spikes — need different responses at different levels | Alarms + step adjustments |
| **Scheduled** | Simplest | Predictable traffic patterns — business hours, batch windows | Cron schedules + desired counts |
| **Combined** | Most complex | Production — scheduled as baseline + target tracking for unexpected spikes | All of the above |

!!! success "Start here"

    For the ramp plan, target tracking on CPU is enough. Add step scaling or scheduled scaling only if Manager asks "what would you do for a flash sale?" — that's when you'd combine scheduled (pre-scale before the sale) + target tracking (handle unexpected spikes during).

#### Manage scaling policies

``` bash
# List all policies on an ASG
aws autoscaling describe-policies \
  --auto-scaling-group-name fahad-web-asg \
  --query "ScalingPolicies[].{Name:PolicyName,Type:PolicyType,Target:TargetTrackingConfiguration.TargetValue}" \
  --output table \
  --profile fahad

# Delete a scaling policy
aws autoscaling delete-policy \
  --auto-scaling-group-name fahad-web-asg \
  --policy-name cpu-target-60 \
  --profile fahad

# Note: deleting a target tracking policy also deletes its auto-created CloudWatch alarms
```

## Checkpoint: 09 Build Day + Checkpoint 1

This is the integration day. Everything you built in Days 5–8 comes together into a single working stack:

```
Route 53 (DNS)
  └── ALB (HTTPS, TLS from ACM)
        ├── Target group → ASG → EC2 instances (app)
        │                         ├── reads secrets from Secrets Manager
        │                         ├── reads/writes S3 (static assets)
        │                         └── connects to RDS (PostgreSQL)
        │
        └── RDS Multi-AZ (PostgreSQL)
              ├── automated daily backups
              └── CloudWatch alarms on connections, CPU, storage

CloudWatch: dashboard + alarms + log groups for every component
```

### Checkpoint 1 deliverables

- **Full stack running:** a request hits the DNS name, reaches the ALB, is forwarded to an EC2 instance, which queries RDS and returns a response.
- **Architecture diagram:** draw every component, subnet, AZ, security group, and data flow path.
- **Cost estimate:** document expected monthly cost. Compare against the $60 budget. Identify the top cost drivers.
- **Manager's review:** walk through the architecture, demonstrate each component, explain every design choice and its trade-off.

!!! danger "Common failures"

    Security group not allowing ALB → EC2 traffic. RDS in a public subnet. No health check endpoint. Secrets hardcoded in user-data. No tags. No monitoring. Manager will check all of these.
