provider "aws" {
  region  = "ap-south-1"
  profile = "fahad"
}

module "fmk_web_server_1" {
  source = ".//module-1"

  web_instance_type = var.web_instance_type
}

output "fmk_web_server_1_output" {
  value = module.fmk_web_server_1.instance_info
  description = "Instance Information of web server one"
}

module "fmk_web_server_2" {
  source = ".//module-2"
}

output "fmk_web_server_2_output" {
  value = module.fmk_web_server_2.instance_info
  description = "Instance Information of web server two"
}
