provider "aws" {
  region  = "ap-south-1"
  profile = "fahad"
}

# data "aws_ami" "ubuntu" {
#   most_recent = true

#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
#   }

#   owners = ["099720109477"] # Canonical
# }

# # Create ec2 instance
# resource "aws_instance" "app_server" {
#   ami           = data.aws_ami.ubuntu.id
#   instance_type = "t3.micro"
#   count = 1

#   tags = {
#     Name  = "learn-terraform"
#     Owner = "fahad"
#     Event = "Learning"
#   }
# }


# variable "user_names" {
#   description = "IAM usernames"
#   type = list(string)
#   default = [ "fmk-tf-1", "fmk-tf-2", "fmk-tf-3"]
# }


# resource "aws_iam_user" "example" {
#   count = length(var.user_names)
#   name = var.user_names[count.index]
# }


# variable "user_names" {
#   description = "IAM usernames"
#   type = set(string)
#   default = [ "fmk-tf-1", "fmk-tf-2", "fmk-tf-3"]
# }
# resource "aws_iam_user" "example" {
#   for_each = var.user_names
#   name = each.value
# }


variable "user_names" {
  description = "IAM usernames"
  type = list(string)
  default = [ "fmk-tf-1", "fmk-tf-2", "fmk-tf-3"]
}

output "print_the_names" {
  value = [for name in var.user_names : name]
}