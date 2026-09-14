output "instance_info" {
  value = aws_instance.ec2_mod_2.instance_type
  description = "Instance Type"
}