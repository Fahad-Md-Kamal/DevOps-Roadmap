# One group, reused by the ALB, the NLB's targets, and the EC2 instances
# themselves -- no separate "front door" vs "instance" group (same choice
# made in week4.html 18.8, section 7).
resource "aws_security_group" "this" {
  name        = "${var.name_prefix}_tls_sg"
  description = "Allow inbound traffic on the app port and all outbound traffic"
  vpc_id      = var.vpc_id

  tags = {
    Name  = "${var.name_prefix}-tls-sg"
    Owner = "fahad"
    Event = "IaC-learning"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_app_port_ipv4" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = var.ingress_port
  ip_protocol       = "tcp"
  to_port           = var.ingress_port
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
