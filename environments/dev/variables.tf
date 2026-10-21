variable "region" {
  type    = string
  default = "us-east-1"
}
variable "name" {
  type    = string
  default = "sec-platform"
}
# VECTR
variable "vectr_hostname" {
  type        = string
  description = "DNS name for VECTR (point at the ALB)."
}
variable "vectr_acm_certificate_arn" {
  type    = string
  default = ""
}
variable "vectr_allowed_cidrs" {
  type    = list(string)
  default = []
}

# TimberLake (offensive — non-prod only)
variable "deploy_timberlake" {
  type    = bool
  default = false
}
variable "timberlake_target_account_id" {
  type    = string
  default = ""
}
variable "timberlake_allowed_target_account_ids" {
  type    = list(string)
  default = []
}

# Remediation
variable "auto_remediate" {
  type    = bool
  default = false
}
# Reporting
variable "notification_emails" {
  type    = list(string)
  default = []
}
