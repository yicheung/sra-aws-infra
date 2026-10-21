output "regional_web_acl_arn" {
  value = var.create_regional ? aws_wafv2_web_acl.regional[0].arn : null
}
output "cloudfront_web_acl_arn" {
  value = var.create_cloudfront ? aws_wafv2_web_acl.cloudfront[0].arn : null
}
