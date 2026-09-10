# Target groups first -- a load balancer never points at instances directly
# (week4.html 18.8, section 10).
resource "aws_lb_target_group" "public" {
  name        = "${var.name_prefix}-tg-public"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
}

resource "aws_lb_target_group" "private" {
  name     = "${var.name_prefix}-tg-private"
  port     = 80
  protocol = "TCP"
  vpc_id   = var.vpc_id
}

# Same instances, registered into both -- one pool of servers, two
# independent paths, not two separate pools.
resource "aws_lb_target_group_attachment" "public" {
  for_each         = var.instance_ids
  target_group_arn = aws_lb_target_group.public.arn
  target_id        = each.value
  port             = 80
}

resource "aws_lb_target_group_attachment" "private" {
  for_each         = var.instance_ids
  target_group_arn = aws_lb_target_group.private.arn
  target_id        = each.value
  port             = 80
}

resource "aws_alb" "this" {
  name               = "${var.name_prefix}-alb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_alb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.public.arn
  }
}

# No security_groups argument here -- an NLB is pure Layer 4 passthrough and
# has no security group of its own. Access control for this path lives
# entirely on the targets' own security group instead.
resource "aws_lb" "nlb" {
  name               = "${var.name_prefix}-nlb-tf"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids
}

resource "aws_lb_listener" "tcp" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.private.arn
  }
}
