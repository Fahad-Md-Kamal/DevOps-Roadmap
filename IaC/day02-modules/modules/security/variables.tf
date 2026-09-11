variable "vpc_id" {
  type        = string
  description = "VPC to create the security group in. No default -- callers must be explicit."
}

variable "ingress_port" {
  type        = number
  default     = 80
  description = "Port the ALB, NLB, and EC2 instances all share -- must match whatever the app actually serves."
}

variable "name_prefix" {
  type        = string
  default     = "fmk"
  description = "Prefix applied to the security group's name and tags."
}
