provider "aws" { region = var.region }

resource "tls_private_key" "monitor" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "monitor" {
  key_name   = "${var.cluster_name}-monitor-"
  public_key = tls_private_key.monitor.public_key_openssh
}

resource "local_sensitive_file" "monitor_key" {
  filename        = "${path.module}/monitor_key.pem"
  content         = tls_private_key.monitor.private_key_pem
  file_permission = "0600"
}

output "ssh_private_key_path" {
  value = local_sensitive_file.monitor_key.filename
}

module "vpc" {
  source = "../../modules/vpc"
  name   = "obs-vpc"
  cidr   = "10.0.0.0/16"
  region = var.region
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

module "monitor_node" {
  source        = "../../modules/monitor-node"
  ami_id        = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id     = module.vpc.public_subnets[0]
  ssh_key_name  = aws_key_pair.monitor.key_name
  vpc_id        = module.vpc.vpc_id
}

output "grafana_url" {
  value = "http://${module.monitor_node.public_ip}:3000"
}
