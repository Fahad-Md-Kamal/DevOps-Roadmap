# The ALB half of containers.md's console walkthrough, as a separate
# Terraform state from ecs-cluster-service on purpose -- see that folder's
# own main.tf for the full two-phase apply order, the new-revision hint,
# and the teardown order. Splitting these into two states instead of one
# root module mirrors the same reasoning as jenkins.md 20.16's multi-agent
# pipeline split, just applied to Terraform state boundaries instead of
# Jenkins agents: this folder never needs ECS permissions, and the ECS
# folder never needs ELB permissions.

provider "aws" {
  region  = var.region
  profile = var.profile
}

data "aws_vpc" "default" {
  default = true
}

# The same default VPC's subnets, filtered down to the AZs actually wanted
# -- deliberately explicit, since containers.md step 5's whole "Unused"
# target bug came from the ALB and the service disagreeing on which AZs
# were in play.
data "aws_subnets" "alb" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = var.availability_zones
  }
}

# type = "ip", not "instance" -- a Fargate task has no instance ID to
# register by, only an IP on its own ENI (containers.md's own explanation
# of why this is the only target type that can represent a Fargate task).
resource "aws_lb_target_group" "app" {
  name        = "${var.name_prefix}-tg-tf"
  target_type = "ip"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id

  health_check {
    path = "/"
  }
}

resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = data.aws_subnets.alb.ids
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.container_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
