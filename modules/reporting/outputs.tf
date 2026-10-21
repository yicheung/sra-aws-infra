output "sns_topic_arn" { value = aws_sns_topic.alerts.arn }
output "tracker_table_name" { value = aws_dynamodb_table.tracker.name }
output "advisor_function_name" {
  value = var.enable_ai_advisor ? aws_lambda_function.advisor[0].function_name : null
}
