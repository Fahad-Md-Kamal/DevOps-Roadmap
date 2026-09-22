output "id" {
  value       = aws_vpc.vpc.id
  description = "ID of the VPC created by this module -- referenced as module.vpc.id from the root."
}
