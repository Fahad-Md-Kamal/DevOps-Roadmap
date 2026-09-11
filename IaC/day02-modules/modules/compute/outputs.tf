output "instance_ids" {
  value       = { for k, i in aws_instance.this : k => i.id }
  description = "Instance IDs, keyed the same way as the subnet_ids input."
}
