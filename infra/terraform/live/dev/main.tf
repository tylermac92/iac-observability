provider "aws" { region = var.region }

resource "tls_private_key" "monitor" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "monitor" {
  key_name   = "${var.cluster_name}-monitor-key"
  public_key = tls_private_key.monitor.public_key_openssh

  lifecycle {
    ignore_changes = [public_key]
  }
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

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitor_ssm" {
  name               = "${var.cluster_name}-monitor-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "monitor_ssm_ssm" {
  role       = aws_iam_role.monitor_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_iam_instance_profile" "monitor_ssm" {
  name = "${var.cluster_name}-monitor-ssm-profile"
  role = aws_iam_role.monitor_ssm.name
}

data "aws_iam_policy_document" "ssm_put" {
  statement {
    actions = ["ssm:PutParameter"]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/monitoring/slack_webhook"]
  }
}

resource "aws_iam_role_policy" "monitor_ssm_put" {
  name = "${var.cluster_name}-monitor-ssm-put"
  role = aws_iam_role.monitor_ssm.name
  policy = data.aws_iam_policy_document.ssm_put.json
}

module "monitor_node" {
  source               = "../../modules/monitor-node"
  ami_id               = data.aws_ami.amazon_linux.id
  instance_type        = "t3.micro"
  subnet_id            = module.vpc.public_subnets[0]
  ssh_key_name         = aws_key_pair.monitor.key_name
  vpc_id               = module.vpc.vpc_id
  iam_instance_profile = aws_iam_instance_profile.monitor_ssm.name
}

output "grafana_url" {
  value = "http://${module.monitor_node.public_ip}:3000"
}
