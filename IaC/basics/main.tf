provider "aws" {
  region  = var.availability_zone
  profile = "fahad"
}

# resource "aws_instance" "ec2_file_provisionar" {
#   ami                    = var.ami_image
#   instance_type          = var.instance_type
#   key_name               = "aws_key"
#   vpc_security_group_ids = [aws_security_group.main.id]
#   associate_public_ip_address = true

#   provisioner "file" {
#     source      = "./provishoned_file.txt"
#     destination = "/tmp/provishoned_file.txt"
#   }
#   connection {
#     type        = "ssh"
#     host        = self.public_ip
#     user        = "ec2-user"
#     private_key = file("/home/bjit/Desktop/devops-syllabus/IaC/basics/pub-ssh.txt")
#     timeout     = "4m"
#   }

#   tags = var.project_environment
# }

resource "aws_instance" "ec2_local_provisionar" {
  ami                    = var.ami_image
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.main.id]

  provisioner "local-exec" {
    command = "touch hello.txt"
  }
  provisioner "remote-exec" {
    inline = [ 
      "touch hello.txt",
      "echo hello world remote provisioner >> hello.txt"
    ]
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
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC4Gu2P4XO9ON6WpQ21TznSh31ip1hw4y462eTXhklZzHvJWeKlKVu76aaxngFlAMkVkDmNBbYeA1OZFB8UksQlX4l+O1oZtZl140T8OtF3KSumcbBBLGY7ik9qbKQC9muF2nbtL5QTPAK2tb7/HfwlMm37hO2FMTBNFA49HxKVDuWXhxBRBktcHw5Q2Petvtu6D4g8wGPcq8Nx8MVlJ/NL4c5/Z+ecoMdMEnQ5gXluanoek5dPIxLZCicZjkp6wOoZa8Ma9tg3DCIyBqsKm2u8UphTOrtlS6WeouxTJFEuJstFMdEzELXFzBKARtCDo70pM8NclIevyLX/B52aP9sJ bjit@11713-fahad.kamal"
}