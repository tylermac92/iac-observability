resource "aws_s3_bucket" "loki" {
  bucket = "${var.cluster_name}-loki-logs"
  acl = "private"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id = "expire-logs"
    enabled = true
    expiration {
      days = 30
    }
  }
}

output "loki_bucket" {
  value = aws_s3_bucket.loki.id
}
