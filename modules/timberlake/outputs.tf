output "cluster_arn" { value = aws_ecs_cluster.this.arn }
output "task_definition_arn" { value = aws_ecs_task_definition.this.arn }
output "task_role_arn" { value = aws_iam_role.task.arn }
output "vectr_api_secret_arn" {
  value       = aws_secretsmanager_secret.vectr_api.arn
  description = "Put the VECTR API key here after creating it in VECTR."
}
output "security_group_id" { value = aws_security_group.task.id }
output "subnet_ids" { value = var.private_subnet_ids }
