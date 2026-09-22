provider "aws" {
  region  = local.region
  profile = var.profile
}


module "vpc" {
  source = "./moduels/vpc"
  env    = var.env
}


module "igw" {
  source = "./moduels/igw"

  vpc_id = module.vpc.id
  env    = local.env
}



module "private_sn_zone1" {
  source = "./moduels/subnet"
  vpc_id = module.vpc.id

  az         = local.zone1
  cidr_block = "10.0.0.0/19"
  env        = local.env
  type       = "private"
  eks_name   = local.eks_name
}


module "private_sn_zone2" {
  source     = "./moduels/subnet"
  vpc_id     = module.vpc.id
  type       = "private"
  az         = local.zone2
  cidr_block = "10.0.32.0/19"
  env        = local.env
  eks_name   = local.eks_name
}


module "public_sn_zone1" {
  source                  = "./moduels/subnet"
  vpc_id                  = module.vpc.id
  type                    = "public"
  az                      = local.zone1
  cidr_block              = "10.0.64.0/19"
  env                     = local.env
  eks_name                = local.eks_name
  map_public_ip_on_launch = true
}


module "public_sn_zone2" {
  source                  = "./moduels/subnet"
  vpc_id                  = module.vpc.id
  type                    = "public"
  az                      = local.zone1
  cidr_block              = "10.0.96.0/19"
  env                     = local.env
  eks_name                = local.eks_name
  map_public_ip_on_launch = true
}

module "nat" {
  source             = "./moduels/nat"
  env                = local.env
  subnet_az_id       = module.public_sn_zone1.id
  depends_on_igw_ids = [module.igw.id]
}

module "private_routes" {
  source         = "./moduels/routes"
  env            = local.env
  vpc_id         = module.vpc.id
  nat_gateway_id = module.nat.id
  type           = "private"
}

module "public_routes" {
  source     = "./moduels/routes"
  env        = local.env
  vpc_id     = module.vpc.id
  gateway_id = module.igw.id
  type       = "public"
}


resource "aws_route_table_association" "private_zone1" {
  subnet_id      = module.private_sn_zone1.id
  route_table_id = module.private_routes.id
}

resource "aws_route_table_association" "private_zone2" {
  subnet_id      = module.private_sn_zone2.id
  route_table_id = module.private_routes.id
}

resource "aws_route_table_association" "public_zone1" {
  subnet_id      = module.public_sn_zone1.id
  route_table_id = module.public_routes.id
}

resource "aws_route_table_association" "public_zone2" {
  subnet_id      = module.public_sn_zone2.id
  route_table_id = module.public_routes.id
}