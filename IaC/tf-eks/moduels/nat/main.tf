resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.env}-nat"
  }
}


resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = var.subnet_az_id

  tags = {
    Name = "${var.env}-nat"
  }

  depends_on = [var.depends_on_igw_ids]
}