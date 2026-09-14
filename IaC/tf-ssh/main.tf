provider "aws" {
  region = "ap-south-1"
  profile = "fahad"
}


terraform {
  required_version = ">= 1.2"
}

resource "aws_instance" "ec2_mod_1" {
  ami                    = "ami-08188a5a4dfdbd573"
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.main.id]

  user_data = <<-EOF
        #!bin/sh
        sudo apt-get update
        sudo apt install -y apache2
        sudo systemctl status apache2
        sudo systemctl start apache2
        sudo chown -R $USER:$USER /var/www/html
        sudo echo <html><body><h1>Hello this is module-1 at </h1></body></html>
      EOF

}


locals {
  ingress_rules = [
    {
      port        = 443
      cidr_blocks = ["0.0.0.0/0"]
      protocol    = "TCP"
      description = "Ingress rules for port 443"
    },
    {
      port        = 22
      cidr_blocks = ["203.0.113.10/32"]
      protocol    = "TCP"
      description = "Ingress rules for port 22"
    },
    {
      port        = 80
      cidr_blocks = ["203.0.113.10/32"]
      protocol    = "TCP"
      description = "Ingress rules for port 22"
    },
  ]
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
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
}


resource "aws_key_pair" "deployer" {
  key_name   = "tf-keypair"
  public_key = var.ssh-key
}