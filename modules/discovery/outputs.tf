output "log_bucket" { value = aws_s3_bucket.logs.id }
output "log_bucket_arn" { value = aws_s3_bucket.logs.arn }
output "guardduty_detector_id" {
  value = var.enable_guardduty ? aws_guardduty_detector.this[0].id : null
}
output "securityhub_enabled" { value = var.enable_securityhub }
