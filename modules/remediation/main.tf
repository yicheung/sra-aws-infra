###############################################################################
# Counter-defense / auto-remediation
# Managed AWS Config rules flag drift; findings from Config/GuardDuty/Security
# Hub route through EventBridge to a remediation Lambda that applies bounded,
# auditable fixes (dry-run unless auto_remediate = true).
###############################################################################

locals {
  tags = merge({ Component = "remediation" }, var.tags)
}

# --- Managed Config rules (detect) -----------------------------------------
locals {
  managed_rules = var.enable_managed_config_rules ? {
    s3-public-read  = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
    s3-public-write = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
    s3-sse          = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
    sg-open-ssh     = "INCOMING_SSH_DISABLED"
    ebs-encrypted   = "ENCRYPTED_VOLUMES"
    rds-public      = "RDS_INSTANCE_PUBLIC_ACCESS_CHECK"
    iam-mfa-console = "MFA_ENABLED_FOR_IAM_CONSOLE_ACCESS"
    imdsv2          = "EC2_IMDSV2_CHECK"
    cloudtrail-on   = "CLOUD_TRAIL_ENABLED"
  } : {}
}

resource "aws_config_config_rule" "managed" {
  for_each = local.managed_rules
  name     = "${var.name}-${each.key}"
  source {
    owner             = "AWS"
    source_identifier = each.value
  }
  tags = local.tags
}

# --- Remediation Lambda (respond) ------------------------------------------
data "archive_file" "fn" {
  type        = "zip"
  source_file = "${path.module}/functions/remediate.py"
  output_path = "${path.module}/functions/remediate.zip"
}

data "aws_iam_policy_document" "fn_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fn" {
  name               = "${var.name}-remediator"
  assume_role_policy = data.aws_iam_policy_document.fn_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "fn_logs" {
  role       = aws_iam_role.fn.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Narrowly scoped remediation permissions.
resource "aws_iam_role_policy" "fn" {
  name = "remediation-actions"
  role = aws_iam_role.fn.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid      = "S3PublicBlock"
        Effect   = "Allow"
        Action   = ["s3:PutBucketPublicAccessBlock", "s3:GetBucketPublicAccessBlock"]
        Resource = "*"
      },
      {
        Sid      = "SGRevoke"
        Effect   = "Allow"
        Action   = ["ec2:DescribeSecurityGroups", "ec2:RevokeSecurityGroupIngress"]
        Resource = "*"
      }
      ], var.sns_topic_arn != "" ? [{
        Sid      = "Notify"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = var.sns_topic_arn
    }] : [])
  })
}

resource "aws_lambda_function" "remediator" {
  function_name    = "${var.name}-remediator"
  role             = aws_iam_role.fn.arn
  runtime          = "python3.12"
  handler          = "remediate.handler"
  filename         = data.archive_file.fn.output_path
  source_code_hash = data.archive_file.fn.output_base64sha256
  timeout          = 60
  environment {
    variables = {
      AUTO_REMEDIATE = tostring(var.auto_remediate)
      SNS_TOPIC_ARN  = var.sns_topic_arn
    }
  }
  tags = local.tags
}

# --- EventBridge routing (findings -> Lambda) ------------------------------
resource "aws_cloudwatch_event_rule" "findings" {
  name        = "${var.name}-findings-to-remediator"
  description = "Route Security Hub + GuardDuty findings to the remediator."
  event_pattern = jsonencode({
    source = ["aws.securityhub", "aws.guardduty"]
    detail-type = [
      "Security Hub Findings - Imported",
      "GuardDuty Finding"
    ]
  })
  tags = local.tags
}

resource "aws_cloudwatch_event_target" "fn" {
  rule      = aws_cloudwatch_event_rule.findings.name
  target_id = "remediator"
  arn       = aws_lambda_function.remediator.arn
}

resource "aws_lambda_permission" "events" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.findings.arn
}
