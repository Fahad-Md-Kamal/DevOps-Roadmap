output "id" {
  value       = aws_internet_gateway.igw.id
  description = "ID of the Internet Gateway created by this module -- referenced as module.vpc.id from the root."
}
