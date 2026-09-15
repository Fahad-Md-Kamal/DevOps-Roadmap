terraform {
  backend "s3" {
    bucket = "fmk-terraform-backup"
    key    = "key/terraform.tfstate"
    region = "ap-south-1"
    profile = "fahad"
  }
}

provider "aws" {
  region  = "ap-south-1"
  profile = "fahad"
}


resource "aws_instance" "ec2_example" {
  ami           = "ami-08188a5a4dfdbd573"
  instance_type = "t3.micro"
  tags = {
    Name  = "tf-states"
    Owner = "fahad"
    Event = "learning tf"
  }
}

output "print_working" {
  value = aws_instance.ec2_example.arn
}