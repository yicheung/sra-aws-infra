variable "name" {
  type    = string
  default = "neph"
}
variable "vpc_id" { type = string }
variable "private_subnet_id" { type = string }
variable "instance_type" {
  type    = string
  default = "t3a.large" # Neo4j + Steampipe + simulator
}
variable "data_volume_gb" {
  type    = number
  default = 60
}
variable "load_aws_org" {
  type        = bool
  default     = false
  description = "Set true only when run from the AWS Organizations management account."
}
variable "scan_regions" {
  type        = list(string)
  default     = ["us-east-1", "us-east-2"]
  description = "Regions Steampipe collects from."
}
variable "key_name" {
  type    = string
  default = null
}
variable "tags" {
  type    = map(string)
  default = {}
}