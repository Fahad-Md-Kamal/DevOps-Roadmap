variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
}

variable "public_subnets" {
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
  description = "Public subnets, keyed by an AZ suffix such as \"1a\"."
}

variable "private_subnets" {
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
  description = "Private subnets, keyed by an AZ suffix such as \"1a\". Left unassociated with anything by this module -- no compute lands here yet."
}

variable "name_prefix" {
  type        = string
  default     = "fmk"
  description = "Prefix applied to every resource name and tag this module creates."
}
