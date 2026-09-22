output "id" {
  value       = aws_subnet.sn.id
  description = "ID of the subnet created by this module -- referenced as module.<name>.id from the root."
}

output "arn" {
  value       = aws_subnet.sn.arn
  description = "ARN of the subnet created by this module -- referenced as module.<name>.arn from the root."
}
