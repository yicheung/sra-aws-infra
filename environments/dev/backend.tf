# Populate from `global/backend` output, then `terraform init`.
# terraform {
#   backend "s3" {
#     bucket         = "<your-state-bucket>"
#     key            = "dev/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "<your-state-bucket>-lock"
#     encrypt        = true
#   }
# }
