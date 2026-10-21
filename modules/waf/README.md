# WAF module

Regional and CloudFront WAFv2 web ACLs sharing AWS-managed rule groups (common,
known-bad inputs, SQLi, IP reputation, anonymous IP), an IP rate-based rule, and
optional geo-blocking.

## Usage
- Associate `regional_web_acl_arn` with an ALB (e.g. the VECTR ALB) via
  `aws_wafv2_web_acl_association`.
- Set `web_acl_id = cloudfront_web_acl_arn` on your `aws_cloudfront_distribution`.

The CloudFront ACL **must** be created in `us-east-1`; this module takes a
`aws.us_east_1` provider alias for that. Add `CloudFront response headers
policies` (HSTS, CSP, X-Frame-Options) on the distribution for the "CloudFront
rules" hardening layer.
