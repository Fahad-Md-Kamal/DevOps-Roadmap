output "id" {
  value       = aws_route_table.this.id
  description = "ID of the Route Table created by this module -- referenced as module.<name>.id from the root."
}

output "arn" {
  value       = aws_route_table.this.arn
  description = "ARN of the Route Table created by this module -- referenced as module.<name>.arn from the root."
}
