output "alb_dns_name" {
  value       = aws_alb.this.dns_name
  description = "Public DNS name of the ALB."
}

output "nlb_dns_name" {
  value       = aws_lb.nlb.dns_name
  description = "Public DNS name of the NLB."
}
