resource "aws_route_table" "this" {
  vpc_id = var.vpc_id

  # Exactly one of these is ever actually set -- the other resolves to null
  # and is omitted, since a route can't target both a NAT Gateway and an
  # Internet Gateway at once. Which one depends entirely on var.type.
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.type == "private" ? var.nat_gateway_id : null
    gateway_id     = var.type == "public" ? var.gateway_id : null
  }

  tags = {
    Name = "${var.env}-${var.type}"
  }
}
