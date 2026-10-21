# Discovery module

Stands up the posture/discovery layer: multi-region CloudTrail (log-file
validation on), AWS Config recorder + delivery, GuardDuty, Security Hub with
FSBP + CIS standards, and IAM Access Analyzer. All write to one encrypted,
versioned, access-blocked S3 log bucket.

Findings from GuardDuty/Config/Security Hub are consumed by the `remediation`
and `reporting` modules via EventBridge.

For multi-account, designate this the delegated administrator and enable the
org auto-enroll features; the single-account defaults here are the first step.
