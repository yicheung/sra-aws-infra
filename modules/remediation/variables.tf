variable "name" {
  type    = string
  default = "sec-platform"
}
variable "enable_managed_config_rules" {
  type    = bool
  default = true
}
variable "auto_remediate" {
  type        = bool
  default     = false
  description = "If true, the remediation Lambda enforces fixes. If false, it only reports (dry-run)."
}
variable "sns_topic_arn" {
  type        = string
  default     = ""
  description = "Optional SNS topic to notify on remediation actions."
}
variable "tags" {
  type    = map(string)
  default = {}
}