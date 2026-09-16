provider "aws" {
  region = "ap-south-1"
  profile = "fahad"
}

resource "aws_s3_bucket" "tf_s3_bucket" {
  bucket = "tf-s3-bucket-for-depends"
  tags = {
    Name = "tf-s3-bucket-for-depends"
  }
}

resource "aws_instance" "ec2_example" {
  ami           = "ami-08188a5a4dfdbd573"
  instance_type = "t3.micro"
  
  vpc_security_group_ids = [aws_security_group.main.id]
  key_name = aws_key_pair.deployer.key_name

  user_data = "${file("install_apache.sh")}"

  tags = {
    Name  = "tf-states"
    Owner = "fahad"
    Event = "learning tf"
  }

  depends_on = [ aws_s3_bucket.tf_s3_bucket, aws_security_group.main ]
}


resource "aws_security_group" "main" {
  egress = [
    {
      cidr_blocks      = ["0.0.0.0/0"]
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
  ingress = [
    {
      cidr_blocks      = ["0.0.0.0/0"]
      description      = ""
      from_port        = 22
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 22
    }
  ]

}

resource "aws_key_pair" "deployer" {
  key_name   = "aws_key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDsECtbtPSxJ9w+dCTnVSQ8c+ZE/p7kLYKTmXLldmIo/6riPz3NIiBYzd+yO9rTkTYqsQxD+rfEj/8xqR1g99hiGjOeifRwHzI4BnW/pkI681FtpHgMcwKpocaMNxGCBNdeqFZP9biIc10ryeoPhz0XYGF0ICt+VZW+tXxynvoCMPAT4kck4fApPzHIy24VCwzQkoNJBi4haWQcK2T6ZVnwHiEN/9+jwPviyYX+qfyvPPoV4kcg03swOxhW+cCxx1FnFnQmBoD8Mwde/CBfaPwDL5fv/qKFgecf6mZ+ekxk6OAbAZkN9UMFrmW0Q3psh76BI2VdtQh+GKDvzGkNKHNT bjit@11713-fahad.kamal"
}