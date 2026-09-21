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
  description = "Prefix for the cluster, task family, service, and security group -- matches the console walkthrough's learning-cluster / learning-app / learning-service names."
}

variable "container_image" {
  type        = string
  default     = "public.ecr.aws/nginx/nginx:latest"
  description = "The image the container runs. Change this (e.g. to the :stable tag) and re-apply to register a new task definition revision and roll the service onto it -- the Terraform equivalent of containers.md step 6's 'Create new revision' console click."
}

variable "container_port" {
  type        = number
  default     = 80
  description = "Port the container listens on, and the port mapped through to it."
}

variable "cpu" {
  type        = number
  default     = 256
  description = "Task-level vCPU units (256 = 0.25 vCPU) -- the smallest Fargate size, matching the console walkthrough."
}

variable "memory" {
  type        = number
  default     = 512
  description = "Task-level memory in MiB (512 = 0.5 GB) -- the smallest size compatible with 256 CPU units."
}

variable "desired_count" {
  type        = number
  default     = 2
  description = "How many tasks the service keeps running. 2, not 1, so a rolling deploy (or manually killing one task) has something to actually observe."
}

variable "target_group_arn" {
  type        = string
  default     = null
  description = "ARN of the target group to attach as a load balancer, from the ecs-alb folder's own target_group_arn output. Leave null on the very first apply -- the service is created without a load balancer, exactly like containers.md step 4 before step 5's ALB exists. Set it and re-apply once ecs-alb has been applied, to attach it -- the Terraform equivalent of step 5 Part C's 'Update service' console click."
}
