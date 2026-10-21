variable "name" {
  type        = string
  description = "Name prefix for network resources."
  default     = "sec-platform"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.80.0.0/16"
  description = "CIDR for the security platform VPC."
}

variable "az_count" {
  type        = number
  default     = 2
  description = "Number of AZs to span."
}

variable "enable_nat_gateway" {
  type        = bool
  default     = true
  description = "NAT so private hosts can pull Docker images / SRA sources."
}

variable "single_nat_gateway" {
  type        = bool
  default     = true
  description = "One NAT for all AZs (cheaper, non-HA). Set false for prod."
}

variable "tags" {
  type    = map(string)
  default = {}
}
