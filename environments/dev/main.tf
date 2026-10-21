###############################################################################
# dev environment - composition root
# Wires the modules into a single-account first stand-up of the platform.
###############################################################################

module "network" {
  source   = "../../modules/network"
  name     = var.name
  vpc_cidr = "10.80.0.0/16"
  az_count = 2
}

module "discovery" {
  source = "../../modules/discovery"
  name   = var.name
}

module "waf" {
  source = "../../modules/waf"
  name   = var.name
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}

module "reporting" {
  source              = "../../modules/reporting"
  name                = var.name
  notification_emails = var.notification_emails
}

module "remediation" {
  source         = "../../modules/remediation"
  name           = var.name
  auto_remediate = var.auto_remediate
  sns_topic_arn  = module.reporting.sns_topic_arn
}

module "vectr" {
  source              = "../../modules/vectr"
  name                = "${var.name}-vectr"
  vpc_id              = module.network.vpc_id
  private_subnet_id   = module.network.private_subnet_ids[0]
  public_subnet_ids   = module.network.public_subnet_ids
  vectr_hostname      = var.vectr_hostname
  create_alb          = var.vectr_acm_certificate_arn != ""
  acm_certificate_arn = var.vectr_acm_certificate_arn
  allowed_cidrs       = var.vectr_allowed_cidrs
}

# Associate the regional WAF with the VECTR ALB (when the ALB exists).
resource "aws_wafv2_web_acl_association" "vectr_alb" {
  count        = (var.vectr_acm_certificate_arn != "" && module.waf.regional_web_acl_arn != null) ? 1 : 0
  resource_arn = module.vectr.alb_arn
  web_acl_arn  = module.waf.regional_web_acl_arn
}

module "neph" {
  source            = "../../modules/neph"
  name              = "${var.name}-neph"
  vpc_id            = module.network.vpc_id
  private_subnet_id = module.network.private_subnet_ids[0]
}

module "timberlake" {
  count                      = var.deploy_timberlake ? 1 : 0
  source                     = "../../modules/timberlake"
  name                       = "${var.name}-timberlake"
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  target_account_id          = var.timberlake_target_account_id
  allowed_target_account_ids = var.timberlake_allowed_target_account_ids
  vectr_host                 = "https://${var.vectr_hostname}"
}
