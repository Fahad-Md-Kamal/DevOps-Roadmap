
# Depricated
# resource "template_file" "policy" {
#   template = file("${path.module}/policy.tpl")
#   vars = {
#     name = "FMK"
#   }
# }



locals {
  policy = templatefile("${path.module}/policy.tpl", { name = "FMK" })
}

data "null_data_source" "policy" {
  inputs = {
    policy = templatefile("${path.module}/policy.tpl", {
      name = "FMK"
    })
  }
}

# resource "aws_iam_policy" "default" {
#     policy = tempfi
# }


output "policy" {
  value = "${local.policy}"
}