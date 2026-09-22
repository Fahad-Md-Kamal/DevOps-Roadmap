resource "aws_subnet" "sn" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.cidr_block
  availability_zone       = var.az
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = {
    Name                                               = "sn-${var.env}-${var.type}-${var.az}"
    "kubernetes.io/role/${local.elb_role_prefix}elb"   = "1"
    "kubernetes.io/cluster/${var.env}-${var.eks_name}" = "owned"
  }
}

