provider "aws" {
  region  = var.availability_zone
  profile = "fahad"
}

locals {
  usernames = [for i in range(3) : "${var.app_env}-usr-${var.username_prefix}-${i + 1}"]
}

resource "aws_iam_user" "iam_users" {
  count = 3
  name  = local.usernames[count.index]
  tags  = merge(var.project_environment, { Name = local.usernames[count.index] })
}

resource "aws_instance" "ec2_example" {
  ami                         = var.ami_image
  instance_type               = var.instance_type
  count                       = var.instance_count
  associate_public_ip_address = var.enable_public_ip

  tags = merge(
    var.project_environment,
    { Name = "${var.app_env}-${var.project_environment["Name"]}-${count.index + 1}" }
  )
}

output "print_all_users" {
  value = { for k, v in aws_iam_user.iam_users : k => v.arn }
  sensitive = false
}

output "print_all_instances" {
  value = { for k, v in aws_instance.ec2_example : k => v.id }
}