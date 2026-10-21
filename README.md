# AWS Security Platform (SRA Toolchain)

Infrastructure-as-Code (Terraform) for hardening, discovering, locking down, and
reporting on AWS environments, integrating the Security Risk Advisors (SRA)
purple-team toolchain alongside native AWS security controls and an
AI-assisted remediation path.

## What this deploys

| Layer | Component | Purpose |
|-------|-----------|---------|
| **Purple-team** | **VECTR** | Central tracking of detection/prevention test results (Docker, GraphQL API). |
| **Discovery** | **Neph** | AWS attack-path graphing (Steampipe + Neo4j). Read-only. |
| **Emulation** | **TimberLake** | Runs adversary-emulation test cases, pushes results to VECTR. **Non-prod accounts only.** |
| **Posture** | AWS Config, CloudTrail, GuardDuty, Security Hub, IAM Access Analyzer | Continuous discovery + compliance. |
| **Counter-defense** | Config rules + remediation Lambdas, WAF, CloudFront rules | Auto-harden and block on finding. |
| **Reporting** | Security Hub → S3/Athena, SNS, DynamoDB tracking, Bedrock advisor | Findings, remediation tracking, AI recommendations. |

## Layout

```
global/backend/        One-time bootstrap of the S3 + DynamoDB state backend.
modules/
  network/             VPC, subnets, security platform SGs.
  vectr/               VECTR server (EC2 + Docker Compose, ALB/TLS optional).
  neph/                Neph graphing stack (EC2 + Docker Compose) + read-only IAM.
  timberlake/          Emulation runner (ECS/EC2) + scoped non-prod IAM.
  discovery/           Config, CloudTrail, GuardDuty, Security Hub, Access Analyzer.
  remediation/         Config rules, remediation Lambdas, EventBridge routing.
  waf/                 Regional + CloudFront WAF web ACLs and rules.
  reporting/           Findings pipeline, remediation-tracking table, AI advisor.
environments/dev/      Composition root wiring the modules together.
docs/ARCHITECTURE.md   Architecture + data flows + threat model notes.
```

## Quick start

```bash
# 1. Bootstrap remote state (run once per account/region)
cd global/backend
terraform init && terraform apply

# 2. Deploy the dev environment
cd ../../environments/dev
cp terraform.tfvars.example terraform.tfvars   # then edit values
terraform init
terraform plan
terraform apply
```

## Prerequisites

- Terraform >= 1.6, AWS provider >= 5.40
- AWS account with admin (first apply creates org-wide security services)
- A registered domain / Route53 zone if you want TLS on VECTR (recommended)
- SRA tool sources: VECTR runtime zip (`ce-9.14.1`), `neph` and `timberlake`
  are pulled onto their hosts at deploy time (see each module README).

## Safety notes

- **TimberLake runs offensive test cases.** Point it only at a dedicated
  non-production account. The module enforces an account-id guard variable.
- VECTR and Neph default to private subnets reached via the ALB / SSM Session
  Manager — no public ingress unless you explicitly set `allowed_cidrs`.
- All secrets are generated into AWS Secrets Manager / SSM Parameter Store,
  never written to state as plaintext where avoidable.
