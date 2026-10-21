variable "name" {
  type    = string
  default = "sec-platform"
}
variable "create_regional" {
  type        = bool
  default     = true
  description = "Regional web ACL for ALB/API Gateway/AppSync."
}
variable "create_cloudfront" {
  type        = bool
  default     = true
  description = "CLOUDFRONT-scoped web ACL (must be in us-east-1)."
}
variable "rate_limit" {
  type    = number
  default = 2000
}
variable "blocked_countries" {
  type        = list(string)
  default     = []
  description = "ISO country codes to geo-block (optional)."
}
variable "tags" {
  type    = map(string)
  default = {}
}