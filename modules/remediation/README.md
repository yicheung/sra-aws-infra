# Remediation module (counter-defense)

Two layers:

1. **Detect** — managed AWS Config rules (public S3, open SSH, unencrypted EBS,
   public RDS, IMDSv2, console MFA, CloudTrail on, …). Add custom rules as you go.
2. **Respond** — a Python Lambda invoked by EventBridge on Security Hub /
   GuardDuty findings. It applies bounded fixes (S3 public-access block, revoke
   `0.0.0.0/0` ingress on sensitive ports) and notifies SNS.

**Dry-run by default.** `auto_remediate = false` logs intended actions without
mutating anything. Flip to `true` only once you've reviewed the dry-run output.

Extend `functions/remediate.py` with more handlers (quarantine IAM keys, attach
WAF, isolate instances) and widen the scoped IAM policy to match — keep each
action explicit and least-privilege.
