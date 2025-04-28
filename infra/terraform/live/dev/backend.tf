terraform {
  required_version = ">= 1.2"
  backend "s3" {
    bucket         = "tmac-tf-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-state-locks"
    encrypt        = true
  }
}

