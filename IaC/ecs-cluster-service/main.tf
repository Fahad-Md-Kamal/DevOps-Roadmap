# Terraform version of containers.md's own hands-on console walkthrough --
# split across this folder and the sibling ecs-alb folder, on purpose, the
# same way that walkthrough builds the ECS side and the networking side as
# two separate diagrams. The two-phase apply below exists because the
# dependency between them is real, not just how the console happened to
# ask for it:
#
#   1. `terraform apply` here first, with target_group_arn left at its
#      default (null). Creates the cluster, task definition, and service
#      with no load balancer attached -- exactly containers.md step 4,
#      before step 5's ALB exists yet.
#   2. Copy this apply's `security_group_id` output into ecs-alb's own
#      security_group_id variable, then `terraform apply` in that folder.
#      It creates the target group and ALB, reusing this same security
#      group -- containers.md step 5's "reuse the security group from
#      step 3" note.
#   3. Copy *that* apply's `target_group_arn` output back into this
#      folder's target_group_arn variable, and `terraform apply` here
#      again. The dynamic load_balancer block below activates and the
#      service gets updated to attach the ALB -- containers.md step 5
#      Part C's "Update service" console click, done from code instead.
#
# Adding a new task definition revision (containers.md step 6): change
# container_image (or cpu/memory/port) and `terraform apply` again. A new
# revision is registered and the service rolls onto it automatically --
# the same launch-healthy-then-drain sequence the console version shows,
# just triggered by `apply` instead of a click.
#
# Deleting everything: `terraform destroy` in *this* folder first -- it
# stops the service and cleanly detaches the load balancer -- then
# `terraform destroy` in ecs-alb. That's the reverse of containers.md
# step 8's console order (ALB deleted first there), because here it's two
# separate Terraform states doing the ordering, not one cascaded "Delete
# cluster" button that already knows about both.

provider "aws" {
  region  = var.region
  profile = var.profile
}

# Reused, not created -- the console walkthrough never built a new VPC for
# this either (containers.md's own "why the default, not a new one" note).
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_vpc" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Just a namespace -- free, nothing running yet (containers.md step 1's
# own framing, word for word).
resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"
}

# Created fresh, not the account's own `default` security group -- that
# one only allows traffic between resources that already share it, nothing
# inbound from outside (containers.md step 3's exact reasoning).
resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-sg-tf"
  description = "Allow inbound on the app port, all outbound"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_app_port" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = var.container_port
  to_port           = var.container_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Lets Fargate itself pull the image and ship logs -- the "task execution
# role" containers.md distinguishes from a task role (an application's own
# AWS API permissions, not needed here at all).
resource "aws_iam_role" "execution" {
  name = "${var.name_prefix}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.name_prefix}-app"
  retention_in_days = 7
}

# The blueprint -- image, CPU/memory, ports, roles. Changing container_image
# and re-applying registers a new revision without touching anything else.
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.name_prefix}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn

  container_definitions = jsonencode([{
    name      = "app"
    image     = var.container_image
    essential = true
    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# What actually keeps tasks alive -- a cluster with no service in it does
# nothing at all (containers.md's own framing).
resource "aws_ecs_service" "app" {
  name            = "${var.name_prefix}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default_vpc.ids
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true
  }

  # Only attached once ecs-alb's target_group_arn is actually supplied --
  # on the very first apply this block doesn't exist at all, matching
  # containers.md step 4 (service created, no load balancer yet).
  dynamic "load_balancer" {
    for_each = var.target_group_arn == null ? [] : [var.target_group_arn]
    content {
      target_group_arn = load_balancer.value
      container_name   = "app"
      container_port   = var.container_port
    }
  }

  # A manual scale-to-0 in the console (containers.md step 4's cost-pause
  # trick) shouldn't get fought back to desired_count on the next apply.
  lifecycle {
    ignore_changes = [desired_count]
  }
}
