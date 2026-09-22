variable "env" {
  type        = string
  description = "Environment name, passed in from the root module's locals."
}

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
