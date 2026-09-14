provider "aws" {
  region = "ap-south-1"
  profile = "fahad"
}

resource "aws_instance" "nsl_ledgerly" {
  ami = "ami-0685bcc683dadb6b9"
  instance_type = "t3.micro"
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name  = "nsl-ledgerly"
    Owner = "fahad"
  }
}