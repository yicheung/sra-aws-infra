variable "name" {
  type    = string
  default = "sec-platform"
}
variable "notification_emails" {
  type    = list(string)
  default = []
}
variable "enable_ai_advisor" {
  type        = bool
  default     = true
  description = "Bedrock-backed Lambda that drafts remediation guidance for findings."
}
variable "bedrock_model_id" {
  type    = string
  default = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}
variable "tags" {
  type    = map(string)
  default = {}
}