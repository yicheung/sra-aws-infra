terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws     = { source = "hashicorp/aws", version = ">= 5.40.0" }
    random  = { source = "hashicorp/random", version = ">= 3.5.0" }
    archive = { source = "hashicorp/archive", version = ">= 2.4.0" }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project   = "aws-security-platform"
      ManagedBy = "terraform"
      Env       = "dev"
    }
  }
}

# CloudFront-scoped WAF must live in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags {
    tags = {
      Project   = "aws-security-platform"
      ManagedBy = "terraform"
      Env       = "dev"
    }
  }
}
