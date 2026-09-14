provider "aws" {
  region  = var.availability_zone
  profile = "fahad"
}

locals {
  ingress_rules = [
    {
      port        = 443
      description = "Ingress rules for port 443"
    },
    {
      port        = 22
      description = "Ingress rules for port 22"
    },
  ]
}

resource "aws_instance" "ec2_example" {
  ami                    = "ami-08188a5a4dfdbd573"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.main.id]
}

resource "aws_security_group" "main" {

  egress = [
    {
      cidr_blocks      = ["0.0.0.0/0", ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    }

  ]

  dynamic "ingress" {
    for_each = local.ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "aws_key"
  public_key = var.pub_key_value
}