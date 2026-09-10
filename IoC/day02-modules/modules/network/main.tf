resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  tags = {
    Name  = "${var.name_prefix}-vpc"
    Owner = "fahad"
    Event = "IoC-learning"
  }
}

resource "aws_subnet" "public" {
  for_each          = var.public_subnets
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    Name  = "${var.name_prefix}-public-${each.key}"
    Owner = "fahad"
    Event = "IoC-learning"
  }
}

resource "aws_subnet" "private" {
  for_each          = var.private_subnets
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    Name  = "${var.name_prefix}-private-${each.key}"
    Owner = "fahad"
    Event = "IoC-learning"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name  = "${var.name_prefix}-igw"
    Owner = "fahad"
    Event = "IoC-learning"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name  = "${var.name_prefix}-public-rt"
    Owner = "fahad"
    Event = "IoC-learning"
  }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private subnets get their own table, associated, with no route to the IGW --
# that absence is what keeps them private (week4.html Day 15/18.8, section 6).
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name  = "${var.name_prefix}-private-rt"
    Owner = "fahad"
    Event = "IoC-learning"
  }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
