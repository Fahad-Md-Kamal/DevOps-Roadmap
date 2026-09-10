output "vpc_id" {
  value       = aws_vpc.this.id
  description = "ID of the VPC."
}

output "public_subnets" {
  value       = aws_subnet.public
  description = "Full public subnet objects, keyed the same way as the public_subnets input (e.g. \"1a\")."
}

output "private_subnets" {
  value       = aws_subnet.private
  description = "Full private subnet objects, keyed the same way as the private_subnets input."
}
