variable "vpc_id" {
  type        = string
  description = "VPC both target groups are created in."
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Subnets both the ALB and the NLB are launched into. Needs at least two, in different AZs."
}

variable "security_group_id" {
  type        = string
  description = "Security group attached to the ALB. The NLB gets none -- it has no security group of its own (week4.html 18.8, section 11)."
}

variable "instance_ids" {
  type        = map(string)
  description = "Instances to register into both target groups -- the same pool of servers, reachable through two independent paths."
}

variable "name_prefix" {
  type        = string
  default     = "fmk"
  description = "Prefix applied to every resource name this module creates."
}
