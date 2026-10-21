variable "name" {
  type    = string
  default = "timberlake"
}
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }

variable "target_account_id" {
  type        = string
  description = "Account TimberLake emulation fires against. MUST be non-prod."
}

variable "allowed_target_account_ids" {
  type        = list(string)
  description = "Allowlist of non-prod accounts emulation may target. Guard rail."
  validation {
    condition     = length(var.allowed_target_account_ids) > 0
    error_message = "Provide at least one explicitly-approved non-prod target account."
  }
}

variable "target_role_name" {
  type        = string
  default     = "TimberLakeEmulationTarget"
  description = "Role name TimberLake assumes IN the target account (deploy separately there)."
}

variable "vectr_host" {
  type        = string
  description = "VECTR base URL for GraphQL result upload."
}

variable "vectr_assessment" {
  type    = string
  default = "AWS Emulation"
}
variable "vectr_database" {
  type    = string
  default = "default"
}
variable "testcases_repo" {
  type        = string
  default     = ""
  description = "Git URL of YOUR authored test-case repo (not bundled here)."
}

variable "tags" {
  type    = map(string)
  default = {}
}