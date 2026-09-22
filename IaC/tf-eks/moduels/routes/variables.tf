
variable "env" {
  type        = string
  description = "Environment variable"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "nat_gateway_id" {
  type        = string
  default     = null
  description = "NAT Gateway ID -- required when type is \"private\", ignored otherwise."
}

variable "gateway_id" {
  type        = string
  default     = null
  description = "Internet Gateway ID -- required when type is \"public\", ignored otherwise."
}

variable "type" {
  type        = string
  description = "\"public\" or \"private\" -- picks whether the default route targets the Internet Gateway or the NAT Gateway."
}