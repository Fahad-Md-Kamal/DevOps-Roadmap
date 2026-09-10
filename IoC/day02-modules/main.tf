provider "aws" {
  region  = var.region
  profile = var.profile
}

# The network layer: VPC, four subnets (two AZs x public/private), IGW, both
# route tables. Nothing about this module knows it's being used for an
# ALB/NLB demo -- it just builds a network.
module "network" {
  source = "./modules/network"

  vpc_cidr    = var.vpc_cidr
  name_prefix = var.name_prefix

  public_subnets = {
    "1a" = { cidr_block = "11.0.1.0/24", availability_zone = "${var.region}a" }
    "1b" = { cidr_block = "11.0.2.0/24", availability_zone = "${var.region}b" }
  }
  private_subnets = {
    "1a" = { cidr_block = "11.0.3.0/24", availability_zone = "${var.region}a" }
    "1b" = { cidr_block = "11.0.4.0/24", availability_zone = "${var.region}b" }
  }
}

# The firewall layer. Depends on the network only for vpc_id.
module "security" {
  source = "./modules/security"

  vpc_id      = module.network.vpc_id
  name_prefix = var.name_prefix
}

# The compute layer: one EC2 instance per public subnet, keyed the same way
# the network module keys its subnets ("1a", "1b") so the two line up.
module "compute" {
  source = "./modules/compute"

  subnet_ids        = { for az, subnet in module.network.public_subnets : az => subnet.id }
  security_group_id = module.security.security_group_id
  name_prefix       = var.name_prefix
}

# The load-balancing layer: both target groups, both attachments, the ALB
# and the NLB, both listeners. Depends on all three modules above.
module "loadbalancing" {
  source = "./modules/loadbalancing"

  vpc_id            = module.network.vpc_id
  public_subnet_ids = [for subnet in module.network.public_subnets : subnet.id]
  security_group_id = module.security.security_group_id
  instance_ids      = module.compute.instance_ids
  name_prefix       = var.name_prefix
}
