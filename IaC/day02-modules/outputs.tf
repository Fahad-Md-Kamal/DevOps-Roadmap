output "vpc_id" {
  value       = module.network.vpc_id
  description = "ID of the VPC created by the network module."
}

output "alb_dns_name" {
  value       = module.loadbalancing.alb_dns_name
  description = "Public DNS name of the ALB -- hit /foo and /bar on this."
}

output "nlb_dns_name" {
  value       = module.loadbalancing.nlb_dns_name
  description = "Public DNS name of the NLB."
}
