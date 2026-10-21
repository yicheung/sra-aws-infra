output "remediator_function_name" { value = aws_lambda_function.remediator.function_name }
output "remediator_role_arn" { value = aws_iam_role.fn.arn }
output "config_rule_names" { value = [for r in aws_config_config_rule.managed : r.name] }
