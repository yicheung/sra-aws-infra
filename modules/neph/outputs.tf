output "instance_id" { value = aws_instance.neph.id }
output "role_arn" {
  value       = aws_iam_role.neph.arn
  description = "Read-only role Steampipe uses for discovery."
}
output "secret_arn" { value = aws_secretsmanager_secret.neph.arn }
