module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "4.0.0"

  name = var.name
  cidr = var.cidr
  azs = ["${var.region}a", "${var.region}b"]

  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]

  enable_dns_hostnames = true
  enable_dns_support = true

  map_public_ip_on_launch = true
}

output "vpc_id" { value = module.vpc.vpc_id }
output "public_subnets" { value = module.vpc.public_subnets }
output "private_subnets" { value = module.vpc.private_subnets }
