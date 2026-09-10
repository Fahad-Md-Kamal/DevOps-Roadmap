variable "subnet_ids" {
  type        = map(string)
  description = "One EC2 instance is launched per entry -- key is just a label (e.g. \"1a\"), value is the subnet ID to launch into."
}

variable "security_group_id" {
  type        = string
  description = "Security group attached to every instance this module creates."
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type."
}

variable "name_prefix" {
  type        = string
  default     = "fmk"
  description = "Prefix applied to every instance's Name tag."
}
