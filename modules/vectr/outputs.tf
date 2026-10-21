output "instance_id" { value = aws_instance.vectr.id }
output "private_ip" { value = aws_instance.vectr.private_ip }
output "secret_arn" {
  value       = aws_secretsmanager_secret.vectr.arn
  description = "Secrets Manager ARN holding VECTR runtime secrets."
}
output "host_security_group_id" { value = aws_security_group.host.id }
output "alb_dns_name" {
  value = var.create_alb ? aws_lb.vectr[0].dns_name : null
}
output "url" {
  value = var.create_alb ? "https://${var.vectr_hostname}" : "https://${aws_instance.vectr.private_ip}:${var.vectr_port} (via SSM port-forward)"
}
output "alb_arn" {
  value = var.create_alb ? aws_lb.vectr[0].arn : null
}
