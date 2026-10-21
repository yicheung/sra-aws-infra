# Architecture

## Goal

A platform to **harden, discover, lock down, and report** on AWS, combining the
Security Risk Advisors (SRA) purple-team toolchain with native AWS security
services and an AI-assisted remediation loop.

## Component map

```
                         ┌────────────────────────────────────────────┐
                         │                AWS Account(s)               │
                         │                                             │
  Purple team / humans   │   ┌──────────────┐      ┌───────────────┐   │
        │                │   │   VECTR       │◄─────┤  TimberLake   │   │
        │  HTTPS (ALB)   │   │  (tracking,   │ GQL  │  (emulation   │   │
        └───────────────►│   │   GraphQL)    │ API  │   runner)     │   │
                         │   └──────┬───────┘      └───────┬───────┘   │
                         │          │ findings             │ assume    │
                         │          │                      ▼ role      │
                         │   ┌──────▼───────┐      ┌───────────────┐   │
                         │   │  Neph        │      │ NON-PROD tgt  │   │
                         │   │ (attack-path │      │   account     │   │
                         │   │  graph:      │      └───────────────┘   │
                         │   │  Steampipe + │                          │
                         │   │  Neo4j)      │  read-only (SecurityAudit)│
                         │   └──────────────┘                          │
                         │                                             │
   ┌─────────────────────┴─────────────────────────────────────────┐  │
   │  DISCOVERY / POSTURE                                           │  │
   │  CloudTrail · Config · GuardDuty · Security Hub · Access       │  │
   │  Analyzer  ───► findings ───►  EventBridge                     │  │
   └───────────────────────────────────────────┬───────────────────┘  │
                                                │                       │
   ┌────────────────────────────────────────────▼──────────────────┐  │
   │  COUNTER-DEFENSE (auto-remediation)                            │  │
   │  Config rules → remediation Lambda │ WAF web ACL (regional +   │  │
   │  CloudFront) │ CloudFront response/security headers            │  │
   └───────────────────────────────────────────┬───────────────────┘  │
                                                │                       │
   ┌────────────────────────────────────────────▼──────────────────┐  │
   │  REPORTING / TRACKING                                          │  │
   │  Security Hub → S3 (Athena) │ DynamoDB remediation tracker │   │  │
   │  SNS alerts │ Bedrock advisor Lambda (AI remediation guidance) │  │
   └────────────────────────────────────────────────────────────────┘ │
                         └────────────────────────────────────────────┘
```

## Data flows

1. **Discover** — CloudTrail + Config record state; GuardDuty/Access Analyzer
   generate findings; Neph graphs IAM/resource relationships to surface
   privilege-escalation paths.
2. **Emulate** — TimberLake executes authored test cases against a *non-prod*
   target and records detection/prevention outcomes in VECTR via GraphQL.
3. **Report** — Security Hub aggregates; findings land in S3 (queryable via
   Athena) and a DynamoDB remediation tracker; SNS notifies.
4. **Remediate (counter-defense)** — EventBridge routes findings to remediation
   Lambdas (e.g. revoke public S3, quarantine SG, attach WAF). The Bedrock
   advisor Lambda drafts remediation Terraform/Config-rule suggestions for
   human review before they are promoted into this repo.

## Design principles

- **Private by default** — SRA tools sit in private subnets; access via ALB
  with TLS or SSM Session Manager. Public ingress is opt-in per CIDR.
- **Least privilege** — Neph gets read-only (`SecurityAudit`/`ViewOnlyAccess`);
  TimberLake assumes a scoped role in a guarded non-prod account; remediation
  Lambdas get narrowly scoped action lists.
- **Separation of the offensive tool** — TimberLake cannot target the account
  it runs in without an explicit account-id allowlist.
- **AI in an advisory seat** — the Bedrock advisor proposes; a human applies.
  No model output directly mutates production infrastructure.

## Account topology (recommended)

| Account | Runs | Notes |
|---------|------|-------|
| `security` | VECTR, Neph, discovery aggregation, reporting | Delegated admin for Security Hub/GuardDuty. |
| `nonprod-target` | TimberLake target | Where emulation actually fires. |
| `workloads-*` | Config rules, WAF, remediation | Member accounts, controls pushed in. |

The dev environment in this repo collapses these into one account for a first
stand-up; split them via provider aliases / `for_each` as you mature.
