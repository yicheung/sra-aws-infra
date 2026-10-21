variable "name" {
  type    = string
  default = "sec-platform"
}
variable "enable_guardduty" {
  type    = bool
  default = true
}
variable "enable_securityhub" {
  type    = bool
  default = true
}
variable "enable_config" {
  type    = bool
  default = true
}
variable "enable_access_analyzer" {
  type    = bool
  default = true
}
variable "log_retention_days" {
  type    = number
  default = 365
}
variable "tags" {
  type    = map(string)
  default = {}
}