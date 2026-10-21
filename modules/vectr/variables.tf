variable "name" {
  type    = string
  default = "vectr"
}
variable "vpc_id" { type = string }
variable "private_subnet_id" { type = string }
variable "public_subnet_ids" {
  type        = list(string)
  description = "For the ALB when create_alb = true."
  default     = []
}

variable "instance_type" {
  type        = string
  default     = "t3a.medium"
  description = "VECTR docs recommend t3a.medium or larger (x86-64 only)."
}

variable "data_volume_gb" {
  type    = number
  default = 120 # docs: 100GB+
}

variable "vectr_version" {
  type        = string
  default     = "ce-9.14.1"
  description = "VECTR CE release tag to pull the runtime zip from."
}

variable "vectr_hostname" {
  type        = string
  description = "DNS name clients use to reach VECTR (must resolve to the ALB/host)."
}

variable "vectr_port" {
  type    = number
  default = 8081
}

variable "create_alb" {
  type        = bool
  default     = true
  description = "Front VECTR with an internet-facing ALB + ACM TLS."
}

variable "acm_certificate_arn" {
  type        = string
  default     = ""
  description = "ACM cert for the ALB HTTPS listener (required when create_alb)."
}

variable "allowed_cidrs" {
  type        = list(string)
  default     = []
  description = "CIDRs allowed to reach VECTR (ALB or host). Empty = SSM-only."
}

variable "key_name" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
