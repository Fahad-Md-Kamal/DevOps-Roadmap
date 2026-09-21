variable "region" {
  type        = string
  default     = "ap-south-1"
  description = "AWS region everything is deployed into."
}

variable "profile" {
  type        = string
  default     = "fahad"
  description = "AWS CLI profile to authenticate with."
}

variable "name_prefix" {
  type        = string
  default     = "learning"
  description = "Prefix for the target group and ALB names."
}

variable "container_port" {
  type        = number
  default     = 80
  description = "Port the target group forwards to and the listener accepts on -- must match container_port in the ecs-cluster-service folder."
}

variable "security_group_id" {
  type        = string
  description = "The security group ID from ecs-cluster-service's own security_group_id output -- reused here so the ALB and the tasks share one security group, exactly like the console walkthrough (containers.md step 3's security group, reused again in step 5's ALB)."
}

variable "availability_zones" {
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  description = "AZs to place the ALB's subnets in. An ALB requires at least two -- containers.md step 5's own note on why -- and every AZ the ECS service might place a task in needs to be covered here, or you get exactly the 'Unused' target status containers.md step 5 walks through fixing."
}
