# State backend bootstrap

One-time setup of the S3 bucket + DynamoDB lock table backing all remote state.

```bash
terraform init
terraform apply -var state_bucket_name=my-org-sec-tfstate -var region=us-east-1
```

Copy the `backend_config` output into each `environments/<env>/backend.tf`,
replacing `ENV_NAME` with the environment key.
