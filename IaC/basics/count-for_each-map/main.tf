provider "aws" {
  region  = "ap-south-1"
  profile = "fahad"
}


variable "instance_type" {
  description = "Instace type is t3.micro free tier"
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "EC2 instance count"
  type        = number
  default     = 2
}

variable "enable_public_ip" {
  description = "Enable public IP Address"
  type        = bool
  default     = false
}

# resource "aws_iam_user" "iam_users" {
#   count = length(var.user_names)
#   name  = var.user_names[count.index]
# }

# variable "user_names" {
#   description = "IAM users"
#   type        = list(string)
#   default     = ["fmk-tf-1", "fmk-tf-2", "fmk-tf-3"]
# }

variable "username_prefix" {
  description = "username's general prefix"
  type        = string
  default     = "fmk-tf"
}

locals {
  usernames = [for i in range(3) : "usr-${var.username_prefix}-${i + 1}"]
}

resource "aws_iam_user" "iam_users" {
  count = 3
  name  = local.usernames[count.index]
  tags  = merge(var.project_environment, { Name = local.usernames[count.index] })
}

variable "project_environment" {
  description = "Project name and envrionment"
  type        = map(string)
  default = {
    Name  = "TF Instance"
    Owner = "fahad"
    Event = "learning-devops-tf"
  }
}

# resource "aws_instance" "ec2_example" {
#   ami = "ami-08188a5a4dfdbd573"
#   instance_type = var.instance_type
#   count = var.instance_count
#   associate_public_ip_address = var.enable_public_ip

#   tags = var.project_environment
# }


resource "aws_instance" "ec2_example" {
  ami                         = "ami-08188a5a4dfdbd573"
  instance_type               = var.instance_type
  count                       = var.instance_count
  associate_public_ip_address = var.enable_public_ip

  tags = merge(
    var.project_environment,
    { Name = "${var.project_environment["Name"]} - ${count.index + 1}" }
  )
}