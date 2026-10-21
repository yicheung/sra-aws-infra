###############################################################################
# WAF web ACLs (regional + CloudFront)
# Shared managed rule groups (common, known-bad inputs, SQLi, IP reputation,
# anonymous IP), a rate-based rule, and optional geo-block. Associate the
# regional ACL with ALBs; use the CloudFront ACL on distributions.
###############################################################################

locals {
  tags = merge({ Component = "waf" }, var.tags)

  managed_groups = [
    { name = "AWSManagedRulesCommonRuleSet", priority = 10 },
    { name = "AWSManagedRulesKnownBadInputsRuleSet", priority = 20 },
    { name = "AWSManagedRulesSQLiRuleSet", priority = 30 },
    { name = "AWSManagedRulesAmazonIpReputationList", priority = 40 },
    { name = "AWSManagedRulesAnonymousIpList", priority = 50 },
  ]
}

# --- Regional ACL ----------------------------------------------------------
resource "aws_wafv2_web_acl" "regional" {
  count       = var.create_regional ? 1 : 0
  name        = "${var.name}-regional"
  description = "Regional WAF for ALB/API Gateway"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = local.managed_groups
    content {
      name     = rule.value.name
      priority = rule.value.priority
      override_action {
        none {}
      }
      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = "AWS"
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "rate-limit"
    priority = 100
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = var.rate_limit
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = length(var.blocked_countries) > 0 ? [1] : []
    content {
      name     = "geo-block"
      priority = 110
      action {
        block {}
      }
      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "geo-block"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-regional"
    sampled_requests_enabled   = true
  }
  tags = local.tags
}

# --- CloudFront ACL (us-east-1) --------------------------------------------
resource "aws_wafv2_web_acl" "cloudfront" {
  count       = var.create_cloudfront ? 1 : 0
  provider    = aws.us_east_1
  name        = "${var.name}-cloudfront"
  description = "CloudFront WAF"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = local.managed_groups
    content {
      name     = rule.value.name
      priority = rule.value.priority
      override_action {
        none {}
      }
      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = "AWS"
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "rate-limit"
    priority = 100
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = var.rate_limit
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-cloudfront"
    sampled_requests_enabled   = true
  }
  tags = local.tags
}
