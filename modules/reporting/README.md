# Reporting module

- **SNS** `*-alerts` topic (email subscriptions) for notifications.
- **DynamoDB** `*-remediation-tracker` — one row per finding: severity, resource,
  `status` (OPEN/IN_PROGRESS/CLOSED), and `ai_guidance`. PITR + encryption on.
- **AI advisor Lambda** — on each Security Hub finding, asks Bedrock
  (`bedrock_model_id`) for a concise root-cause + least-privilege fix + a
  Terraform/Config-rule sketch, and records it against the finding.

**The advisor only advises.** It has no mutating permissions; a human reviews
the guidance and promotes accepted fixes into this repo. This keeps AI in an
advisory seat per the architecture's "AI proposes, human applies" principle.

Enable Bedrock model access for `bedrock_model_id` in the account/region first.
Point Athena at the discovery module's S3 log bucket for ad-hoc finding queries.
