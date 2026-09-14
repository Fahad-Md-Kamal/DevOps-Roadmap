provider "aws" {
  region  = "ap-south-1"
  profile = "fahad"
}

locals {
  instance_name = "${terraform.workspace}-instance"
}

resource "aws_instance" "ec2_example" {
  ami           = "ami-08188a5a4dfdbd573"
  instance_type = "t3.micro"
  tags = {
    Name = local.instance_name
  }
}
