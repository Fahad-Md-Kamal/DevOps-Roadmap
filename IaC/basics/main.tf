provider "aws" {
  region  = var.availability_zone
  profile = "fahad"
}

resource "aws_instance" "ec2_creation" {
  ami                    = var.ami_image
  instance_type          = var.instance_type
  key_name               = "aws_key"
  vpc_security_group_ids = [aws_security_group.main.id]

  provisioner "file" {
    source      = "./provishoned_file.txt"
    destination = "/tmp/provishoned_file.txt"
  }
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file("/home/bjit/Desktop/devops-syllabus/IaC/basics/pub-ssh.txt")
    timeout     = "4m"
  }

  tags = var.project_environment
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

# output "print_all_instances" {
#   value = { for k, v in aws_instance.ec2_creation : k => v.id }
# }

resource "aws_key_pair" "deployer" {
  key_name   = "aws_key"
  public_key = "ssh-rsa <poblic-key>"
}