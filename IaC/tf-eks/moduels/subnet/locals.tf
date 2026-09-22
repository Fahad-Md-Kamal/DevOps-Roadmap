locals {
  # The kubernetes.io/role/*elb tag differs only by this prefix -- "internal-"
  # for a private subnet's internal load balancers, nothing for a public
  # subnet's internet-facing ones. Computed once here so main.tf's tags block
  # doesn't need an if/else of its own.
  elb_role_prefix = var.type == "public" ? "" : "internal-"
}
