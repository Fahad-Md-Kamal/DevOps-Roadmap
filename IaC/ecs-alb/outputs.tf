output "target_group_arn" {
  value       = aws_lb_target_group.app.arn
  description = "Feed this back into ecs-cluster-service's target_group_arn variable, then re-apply that folder to attach the load balancer -- the Terraform equivalent of containers.md step 5 Part C's 'Update service' console click."
}

output "alb_dns_name" {
  value       = aws_lb.this.dns_name
  description = "Open this in a browser once ecs-cluster-service has been re-applied with target_group_arn set."
}
