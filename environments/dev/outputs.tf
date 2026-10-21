output "vpc_id" { value = module.network.vpc_id }
output "vectr_url" { value = module.vectr.url }
output "vectr_secret_arn" { value = module.vectr.secret_arn }
output "neph_instance_id" { value = module.neph.instance_id }
output "security_log_bucket" { value = module.discovery.log_bucket }
output "sns_alerts_topic" { value = module.reporting.sns_topic_arn }
output "remediation_tracker_table" { value = module.reporting.tracker_table_name }
output "config_rules" { value = module.remediation.config_rule_names }
output "timberlake_vectr_api_secret_arn" {
  value = var.deploy_timberlake ? module.timberlake[0].vectr_api_secret_arn : null
}
