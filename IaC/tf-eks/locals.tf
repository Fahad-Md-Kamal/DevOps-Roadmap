locals {
  env         = var.env
  region      = var.region
  zone1       = "${var.region}a"
  zone2       = "${var.region}b"
  eks_name    = "learning-eks"
  eks_version = "1.36"
}
