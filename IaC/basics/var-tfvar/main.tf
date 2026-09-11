provider "aws" {
  region  = var.availability_zone
  profile = "fahad"
}

locals {
  usernames = [for i in range(3) : "usr-${var.username_prefix}-${i + 1}"]
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
    { Name = "${var.project_environment["Name"]} - ${count.index + 1}" }
  )
}
