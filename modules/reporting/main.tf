###############################################################################
# Reporting / tracking
# SNS alerting, a DynamoDB remediation tracker (one row per finding with status
# + AI guidance), and a Bedrock-backed advisor Lambda that drafts remediation
# plans for human review. The advisor only writes guidance; it never mutates.
###############################################################################

locals {
  tags = merge({ Component = "reporting" }, var.tags)
}

# --- SNS -------------------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"
  tags = local.tags
}
resource "aws_sns_topic_subscription" "email" {
  for_each  = toset(var.notification_emails)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# --- Remediation tracker ---------------------------------------------------
resource "aws_dynamodb_table" "tracker" {
  name         = "${var.name}-remediation-tracker"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "finding_id"
  attribute {
    name = "finding_id"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
  tags = local.tags
}

# --- AI advisor Lambda -----------------------------------------------------
data "archive_file" "advisor" {
  count       = var.enable_ai_advisor ? 1 : 0
  type        = "zip"
  source_file = "${path.module}/functions/advisor.py"
  output_path = "${path.module}/functions/advisor.zip"
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "advisor" {
  count              = var.enable_ai_advisor ? 1 : 0
  name               = "${var.name}-advisor"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = local.tags
}
resource "aws_iam_role_policy_attachment" "advisor_logs" {
  count      = var.enable_ai_advisor ? 1 : 0
  role       = aws_iam_role.advisor[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy" "advisor" {
  count = var.enable_ai_advisor ? 1 : 0
  name  = "advisor"
  role  = aws_iam_role.advisor[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Tracker"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:GetItem"]
        Resource = aws_dynamodb_table.tracker.arn
      },
      {
        Sid      = "Bedrock"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "*"
      },
      {
        Sid      = "Notify"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

resource "aws_lambda_function" "advisor" {
  count            = var.enable_ai_advisor ? 1 : 0
  function_name    = "${var.name}-advisor"
  role             = aws_iam_role.advisor[0].arn
  runtime          = "python3.12"
  handler          = "advisor.handler"
  filename         = data.archive_file.advisor[0].output_path
  source_code_hash = data.archive_file.advisor[0].output_base64sha256
  timeout          = 120
  environment {
    variables = {
      TRACKER_TABLE    = aws_dynamodb_table.tracker.name
      BEDROCK_MODEL_ID = var.bedrock_model_id
      ENABLE_AI        = tostring(var.enable_ai_advisor)
    }
  }
  tags = local.tags
}

resource "aws_cloudwatch_event_rule" "to_advisor" {
  count       = var.enable_ai_advisor ? 1 : 0
  name        = "${var.name}-findings-to-advisor"
  description = "Security Hub findings to the AI remediation advisor."
  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
  })
  tags = local.tags
}
resource "aws_cloudwatch_event_target" "advisor" {
  count     = var.enable_ai_advisor ? 1 : 0
  rule      = aws_cloudwatch_event_rule.to_advisor[0].name
  target_id = "advisor"
  arn       = aws_lambda_function.advisor[0].arn
}
resource "aws_lambda_permission" "advisor_events" {
  count         = var.enable_ai_advisor ? 1 : 0
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.advisor[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.to_advisor[0].arn
}
