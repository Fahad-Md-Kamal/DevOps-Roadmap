provider "aws" {
  region  = "ap-south-1"
  profile = "fahad"
}

resource "aws_instance" "ec2_example" {
  ami           = "ami-08188a5a4dfdbd573"
  instance_type = "t3.micro"

  tags = {
    Name = "nsl-ledgerly"
  }
}

data "aws_instance" "aws-ami"{
  filter {
    name = "tag:Name"
    values = ["nsl-ledgerly"]
  }

  depends_on = [ aws_instance.ec2_example ]
}

output "fetched_info_from_aws" {
  value = data.aws_instance.aws-ami.public_ip
}