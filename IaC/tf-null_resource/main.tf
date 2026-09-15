provider "aws" {
  region = "ap-south-1"
  profile = "fahad"
}

resource "aws_instance" "ec2_example" {
  ami           = "ami-08188a5a4dfdbd573"
  instance_type = "t3.micro"

  tags = {
    Name = "nsl-ledgerly"
  }
}

resource "null_resource" "null_resource_sample" {
  triggers = {
    id = aws_instance.ec2_example.id #timestamp()
  }

  provisioner "local-exec" {
    command = "echo Hello World"
  }
}
