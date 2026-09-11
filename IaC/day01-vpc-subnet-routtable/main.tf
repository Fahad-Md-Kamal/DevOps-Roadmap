# =============================================================================
# 1. PROVIDER -- connect Terraform to your real AWS account
# =============================================================================
# Why we need it: every resource below has to know WHICH AWS account and
# region to actually talk to. Nothing else in this file works without this
# block -- it's the connection everything else rides on.
provider "aws" {
  region  = "ap-south-1"
  profile = "fahad"
}
# What we did: told Terraform to use the "fahad" AWS CLI profile, in the
# ap-south-1 (Mumbai) region.
# What's next: before anything can be created, it needs somewhere to live.
# That "somewhere" is the VPC -- a private network boundary, isolated from
# every other AWS customer's traffic, that you fully control.


# =============================================================================
# 2. VPC -- the network boundary everything else lives inside
# =============================================================================
# Why we need it: every other resource in this file -- subnets, the load
# balancers, the EC2 instances -- has to be created inside some VPC. This is
# that container. 11.0.0.0/16 gives ~65,000 usable private IP addresses to
# carve up between everything you build below.
resource "aws_vpc" "fmk_vpc" {
  cidr_block = "11.0.0.0/16"
}
# What we did: reserved the 11.0.0.0/16 address range as your own private
# network inside AWS. Right now it's empty -- no subnets, no route tables,
# nothing can be launched into it yet.
# What's next: a VPC on its own is too big and undifferentiated to launch
# anything into directly. It needs to be divided into subnets -- smaller
# slices of that address range, each pinned to one Availability Zone.


# =============================================================================
# 3. SUBNETS -- dividing the VPC into public and private zones
# =============================================================================
# Why we need them: "public" and "private" aren't a property of the VPC as a
# whole -- they're a property of which route table a subnet ends up
# associated with (section 5/6 decide that). For now, these four blocks just
# carve out four non-overlapping address ranges: two intended for public
# resources (spread across two AZs for fault tolerance), two for private.
resource "aws_subnet" "fmk_public_1a" {
  vpc_id            = aws_vpc.fmk_vpc.id
  cidr_block        = "11.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name  = "fmk-public-1a"
    Owner = "fahad"
    Event = "IaC-learning"
  }
}

resource "aws_subnet" "fmk_public_1b" {
  vpc_id            = aws_vpc.fmk_vpc.id
  cidr_block        = "11.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name  = "fmk-public-1b"
    Owner = "fahad"
    Event = "IaC-learning"
  }
}

resource "aws_subnet" "fmk_private_1a" {
  vpc_id            = aws_vpc.fmk_vpc.id
  cidr_block        = "11.0.3.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name  = "fmk-private-1a"
    Owner = "fahad"
    Event = "IaC-learning"
  }
}

resource "aws_subnet" "fmk_private_1b" {
  vpc_id            = aws_vpc.fmk_vpc.id
  cidr_block        = "11.0.4.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name  = "fmk-private-1b"
    Owner = "fahad"
    Event = "IaC-learning"
  }
}
# What we did: sliced 11.0.0.0/16 into four /24 ranges (256 addresses each)
# -- two tagged "public", two tagged "private". Those tags are just labels
# for humans right now; nothing about a subnet is actually public yet.
# What's next: a subnet needs a door to the internet before anything in it
# can be reached from outside AWS. That door is the Internet Gateway.


# =============================================================================
# 4. INTERNET GATEWAY -- the VPC's door to the internet
# =============================================================================
# Why we need it: a VPC is fully isolated by default -- nothing inside it can
# reach the internet, and nothing on the internet can reach it. An Internet
# Gateway is what makes that possible, but only for whichever subnets are
# explicitly routed through it (section 5 does that routing).
resource "aws_internet_gateway" "fmk_igw" {
  vpc_id = aws_vpc.fmk_vpc.id

  tags = {
    Name  = "fmk-igw"
    Owner = "fahad"
    Event = "IaC-learning"
  }
}
# What we did: created an Internet Gateway and attached it to fmk_vpc (the
# `vpc_id` argument here does the attaching -- no separate resource needed).
# What's next: attaching the gateway to the VPC doesn't route any traffic to
# it yet. Each subnet still needs its own route table telling it "send
# internet-bound traffic here" -- that's the actual public/private switch.


# =============================================================================
# 5. PUBLIC ROUTING -- the route table, its route to the IGW, and its subnets
# =============================================================================
# Why we need it: this is the piece that actually makes "public" mean
# something. A route table is a list of "if traffic is headed here, send it
# through this" rules; every table gets a rule for in-VPC traffic for free.
# Adding a 0.0.0.0/0 -> Internet Gateway rule, then associating a subnet with
# this table, is the entire mechanism that makes that subnet public --
# nothing else about the subnet itself changes.
resource "aws_route_table" "fmk_public_rt" {
  vpc_id = aws_vpc.fmk_vpc.id

  tags = {
    Name  = "fmk-public-rt"
    Owner = "fahad"
    Event = "IaC-learning"
  }
}

resource "aws_route" "fmk_public_default" {
  route_table_id         = aws_route_table.fmk_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.fmk_igw.id
}

resource "aws_route_table_association" "fmk_public_1a" {
  subnet_id      = aws_subnet.fmk_public_1a.id
  route_table_id = aws_route_table.fmk_public_rt.id
}

resource "aws_route_table_association" "fmk_public_1b" {
  subnet_id      = aws_subnet.fmk_public_1b.id
  route_table_id = aws_route_table.fmk_public_rt.id
}
# What we did: created a route table, gave it one rule ("anything not bound
# for inside this VPC goes to the Internet Gateway"), then associated both
# public subnets with it. fmk_public_1a and fmk_public_1b are now genuinely
# public -- anything launched into them can reach, and be reached from, the
# internet (once a security group allows it).
# What's next: the private subnets need routing too -- just without that
# 0.0.0.0/0 rule, so they stay unreachable from the internet.


# =============================================================================
# 6. PRIVATE ROUTING -- a route table with no path to the internet
# =============================================================================
# Why we need it: every subnet needs a route table association, or it falls
# back to the VPC's default (main) route table, which is implicit and easy
# to lose track of. Giving the private subnets their own explicit table --
# with no internet route added -- makes "these are private" a visible,
# deliberate fact in the code, not an accident of what wasn't configured.
resource "aws_route_table" "fmk_private_rt" {
  vpc_id = aws_vpc.fmk_vpc.id

  tags = {
    Name  = "fmk-private-rt"
    Owner = "fahad"
    Event = "IaC-learning"
  }
}

resource "aws_route_table_association" "fmk_private_1a" {
  subnet_id      = aws_subnet.fmk_private_1a.id
  route_table_id = aws_route_table.fmk_private_rt.id
}

resource "aws_route_table_association" "fmk_private_1b" {
  subnet_id      = aws_subnet.fmk_private_1b.id
  route_table_id = aws_route_table.fmk_private_rt.id
}
# What we did: gave the private subnets their own route table, associated
# both of them with it, and added no internet route. They still get the
# automatic in-VPC "local" route every table has, so resources here can
# still talk to the rest of the VPC -- just never directly to or from the
# internet.
# What's next: the network layout (VPC, subnets, routing) is complete. Next
# is security -- deciding exactly what traffic is allowed to reach what,
# regardless of how the network is routed.


# =============================================================================
# 7. SECURITY GROUP -- the firewall in front of the EC2 instances
# =============================================================================
# Why we need it: routing (sections 5/6) decides whether traffic CAN reach a
# subnet at all. A security group decides whether it's actually ALLOWED to
# reach a specific resource, port by port. AWS denies all inbound traffic by
# default -- without this, the EC2 instances below would be unreachable even
# though they sit in a public, internet-routed subnet.
resource "aws_security_group" "fmk_tls_sg" {
  name        = "fmk_tls_sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.fmk_vpc.id

  tags = {
    Name  = "fmk-tls-sg"
    Owner = "fahad"
    Event = "IaC-learning"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.fmk_tls_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.fmk_tls_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
# What we did: created one security group and gave it two rules -- allow
# inbound TCP on port 80 (the port the EC2 instances' Apache server actually
# listens on) from anywhere, and allow all outbound traffic. This one group
# gets reused for the ALB, the NLB's targets, and the EC2 instances
# themselves -- there's no separate "front door" vs "instance" group here.
# What's next: the network and the firewall both exist. Now the actual
# compute -- the EC2 instances that will serve real traffic -- and the AMI
# they're built from.


# =============================================================================
# 8. AMI LOOKUP -- which OS image the EC2 instances boot from
# =============================================================================
# Why we need it: an EC2 instance needs an AMI (Amazon Machine Image) to
# boot from -- it's the disk image containing the OS. Rather than hardcode
# one specific AMI ID (which goes stale the moment AWS ships a new patched
# version), this queries AWS for whichever Amazon Linux 2023 AMI is
# currently newest, every time you plan or apply.
data "aws_ami" "amzn_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}
# What we did: nothing created yet -- `data` blocks only read, they don't
# create (Day 15.3 of week4.html covers this distinction in depth). This
# just resolves, at plan/apply time, to today's latest Amazon Linux 2023 AMI
# ID for ap-south-1.
# What's next: with an AMI resolved and a security group ready, the actual
# EC2 instances can be declared.


# =============================================================================
# 9. EC2 INSTANCES -- the actual servers
# =============================================================================
# Why we need them: these are the real compute -- the two servers that will
# sit behind both load balancers and actually answer HTTP requests. Each one
# launches into a different public subnet (1a vs 1b) so the pair survives a
# single Availability Zone failure.
resource "aws_instance" "ec2-A" {
  ami                    = data.aws_ami.amzn_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.fmk_public_1a.id
  user_data              = file("${path.module}/userdata.sh")
  vpc_security_group_ids = [aws_security_group.fmk_tls_sg.id]

  tags = {
    Name  = "fmk-ec2-A"
    Owner = "fahad"
    Event = "IaC-learning"
  }
}

resource "aws_instance" "ec2-B" {
  ami                    = data.aws_ami.amzn_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.fmk_public_1b.id
  user_data              = file("${path.module}/userdata.sh")
  vpc_security_group_ids = [aws_security_group.fmk_tls_sg.id]

  tags = {
    Name  = "fmk-ec2-B"
    Owner = "fahad"
    Event = "IaC-learning"
  }
}
# What we did: launched two EC2 instances, one per public subnet, each
# bootstrapped by userdata.sh (installs Apache, writes /, /foo, and /bar
# index pages showing that instance's own hostname and IP), and each
# attached to fmk_tls_sg so port 80 traffic can actually reach them.
# What's next: the servers exist and are individually reachable if you knew
# their IPs -- but nothing distributes traffic across the two of them yet.
# That's the load balancers' job, starting with the ALB path.


# =============================================================================
# 10. ALB PATH -- target group, then the ALB, then its listener
# =============================================================================
# Why we need a target group first: an ALB never points at EC2 instances
# directly. A target group is the indirection layer in between -- a named,
# health-checked pool of targets that the ALB forwards to. Declaring the
# group and its membership (the attachments) separately from the ALB itself
# means instances can be added or removed without touching the ALB at all.
resource "aws_lb_target_group" "fmk-tg-public" {
  name        = "fmk-tg-public-1a"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.fmk_vpc.id
}

resource "aws_lb_target_group_attachment" "ec2_a" {
  target_group_arn = aws_lb_target_group.fmk-tg-public.arn
  target_id        = aws_instance.ec2-A.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "ec2_b" {
  target_group_arn = aws_lb_target_group.fmk-tg-public.arn
  target_id        = aws_instance.ec2-B.id
  port             = 80
}
# What we did so far: created an HTTP target group and registered both EC2
# instances as its members. It's still not receiving any traffic -- nothing
# points at it yet.
# What's next: the ALB itself, which is what actually receives requests from
# the internet before forwarding them into this target group.

# Why we need the ALB: this is the actual internet-facing entry point --
# what a user's browser connects to. It needs to know which subnets to run
# in (the public ones, so it's reachable from the internet) and which
# security group governs what can reach it.
resource "aws_alb" "fmk_alb" {
  name               = "fmk-alb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.fmk_tls_sg.id]
  subnets            = [aws_subnet.fmk_public_1a.id, aws_subnet.fmk_public_1b.id]
}
# What we did: created an internet-facing Application Load Balancer, running
# in both public subnets, protected by fmk_tls_sg. It exists now, but it has
# no open port yet -- an ALB with no listener accepts no connections at all.
# What's next: a listener, to actually open port 80 and tell the ALB what to
# do with what arrives on it.

# Why we need the listener: this is the piece that opens an actual port on
# the ALB and defines the action to take -- without it, the ALB has nothing
# listening, and every connection attempt just times out.
resource "aws_lb_listener" "fmk_alb_http" {
  load_balancer_arn = aws_alb.fmk_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fmk-tg-public.arn
  }
}
# What we did: opened port 80 on the ALB and told it to forward every
# request straight into fmk-tg-public. The ALB path of the diagram is
# complete: internet -> ALB:80 -> fmk-tg-public -> ec2-A / ec2-B. `/foo` and
# `/bar` don't need separate listener rules here -- both instances already
# serve those paths themselves (userdata.sh), so a single forward action
# reaches either path on whichever instance the ALB picks.
# What's next: the second path from the diagram -- the same two instances,
# reached through an NLB instead of an ALB.


# =============================================================================
# 11. NLB PATH -- a second target group, the NLB, and its listener
# =============================================================================
# Why a second target group: an ALB target group and an NLB target group
# aren't interchangeable -- this one is TCP, not HTTP, matching what an NLB
# actually forwards (raw connections, no awareness of HTTP at all). The same
# two EC2 instances are registered here too -- one pool of servers, reachable
# through two independent paths, not two separate pools.
resource "aws_lb_target_group" "fmk-tg-private" {
  name     = "fmk-tg-private-1a"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.fmk_vpc.id
}

resource "aws_lb_target_group_attachment" "ec2_a_nlb" {
  target_group_arn = aws_lb_target_group.fmk-tg-private.arn
  target_id        = aws_instance.ec2-A.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "ec2_b_nlb" {
  target_group_arn = aws_lb_target_group.fmk-tg-private.arn
  target_id        = aws_instance.ec2-B.id
  port             = 80
}
# What we did so far: created a TCP target group and registered both
# instances in it, exactly like the ALB's target group.
# What's next: the NLB itself.

# Why we need the NLB: same role as the ALB -- the actual entry point --
# but operating at Layer 4 (raw TCP) instead of Layer 7 (HTTP). Notice there
# is no `security_groups` argument here at all: an NLB has no security group
# of its own to attach, since it's pure passthrough. Access control for this
# path lives entirely on the target's own security group (fmk_tls_sg,
# section 7), which is why that rule had to allow 0.0.0.0/0 rather than
# being scoped to one specific load balancer.
resource "aws_lb" "fmk_nlb" {
  name               = "fmk-nlb-tf"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.fmk_public_1a.id, aws_subnet.fmk_public_1b.id]
}
# What we did: created an internet-facing Network Load Balancer in both
# public subnets. Like the ALB, it has no open port yet.
# What's next: a listener, to open port 80 and forward into fmk-tg-private.

# Why we need this listener: identical reasoning to the ALB's listener --
# without it, the NLB has nothing to do with an incoming connection.
resource "aws_lb_listener" "fmk_nlb_tcp" {
  load_balancer_arn = aws_lb.fmk_nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fmk-tg-private.arn
  }
}
# What we did: opened port 80 on the NLB and told it to forward every raw
# TCP connection into fmk-tg-private. Both paths from the diagram are now
# complete: internet -> ALB:80 -> fmk-tg-public -> ec2-A/ec2-B, and
# internet -> NLB:80 -> fmk-tg-private -> the same ec2-A/ec2-B.
# Nothing left to declare -- `terraform plan` from here should show exactly
# the 28 resources this file creates, and nothing more.
