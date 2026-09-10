provider "aws" {
  region  = "ap-south-1"
  profile = "fahad"
}

resource "aws_vpc" "fmk_vpc" {
  cidr_block = "11.0.0.0/16"
}

resource "aws_subnet" "fmk_public_1a" {
  vpc_id     = aws_vpc.fmk_vpc.id
  cidr_block = "11.0.1.0/24"

  tags = {
    Name  = "fmk-public-1a"
    Owner = "fahad"
    Event = "IoC-learning"
  }
}

resource "aws_subnet" "fmk_public_1b" {
  vpc_id     = aws_vpc.fmk_vpc.id
  cidr_block = "11.0.2.0/24"

  tags = {
    Name  = "fmk-public-1b"
    Owner = "fahad"
    Event = "IoC-learning"
  }
}

resource "aws_subnet" "fmk_private_1a" {
  vpc_id     = aws_vpc.fmk_vpc.id
  cidr_block = "11.0.3.0/24"

  tags = {
    Name  = "fmk-private-1a"
    Owner = "fahad"
    Event = "IoC-learning"
  }
}

resource "aws_subnet" "fmk_private_1b" {
  vpc_id     = aws_vpc.fmk_vpc.id
  cidr_block = "11.0.4.0/24"

  tags = {
    Name  = "fmk-private-1b"
    Owner = "fahad"
    Event = "IoC-learning"
  }
}

resource "aws_internet_gateway" "fmk_igw" {
  vpc_id = aws_vpc.fmk_vpc.id

  tags = {
    Name  = "fmk-igw"
    Owner = "fahad"
    Event = "IoC-learning"
  }
}

resource "aws_route_table" "fmk_public_rt" {
  vpc_id = aws_vpc.fmk_vpc.id

  tags = {
    Name  = "fmk-public-rt"
    Owner = "fahad"
    Event = "IoC-learning"
  }
}

resource "aws_route_table" "fmk_private_rt" {
  vpc_id = aws_vpc.fmk_vpc.id

  tags = {
    Name  = "fmk-private-rt"
    Owner = "fahad"
    Event = "IoC-learning"
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

resource "aws_route_table_association" "fmk_private_1a" {
  subnet_id      = aws_subnet.fmk_private_1a.id
  route_table_id = aws_route_table.fmk_private_rt.id
}

resource "aws_route_table_association" "fmk_private_1b" {
  subnet_id      = aws_subnet.fmk_private_1b.id
  route_table_id = aws_route_table.fmk_private_rt.id
}


resource "aws_lb_target_group" "fmk-tg-public" {
  name        = "fmk-tg-public-1a"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.fmk_vpc.id
}

resource "aws_lb_target_group" "fmk-tg-private" {
  name     = "fmk-tg-private-1a"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.fmk_vpc.id
}

data "aws_ami" "amzn_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

}

resource "aws_security_group" "fmk_tls_sg" {
  name        = "fmk_tls_sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.fmk_vpc.id

  tags = {
    Name  = "fmk-tls-sg"
    Owner = "fahad"
    Event = "IoC-learning"
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

resource "aws_alb" "fmk_alb" {
  name               = "fmk-alb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.fmk_tls_sg.id]
  subnets            = [aws_subnet.fmk_public_1a.id, aws_subnet.fmk_public_1b.id]
}

resource "aws_instance" "ec2-A" {
  ami                    = data.aws_ami.amzn_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.fmk_public_1a.id
  user_data              = file("${path.module}/userdata.sh")
  vpc_security_group_ids = [aws_security_group.fmk_tls_sg.id]

  tags = {
    Name  = "fmk-ec2-A"
    Owner = "fahad"
    Event = "IoC-learning"
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
    Event = "IoC-learning"
  }
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

resource "aws_lb_listener" "fmk_alb_http" {
  load_balancer_arn = aws_alb.fmk_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fmk-tg-public.arn
  }
}

resource "aws_lb" "fmk_nlb" {
  name               = "fmk-nlb-tf"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.fmk_public_1a.id, aws_subnet.fmk_public_1b.id]
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

resource "aws_lb_listener" "fmk_nlb_tcp" {
  load_balancer_arn = aws_lb.fmk_nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fmk-tg-private.arn
  }
}