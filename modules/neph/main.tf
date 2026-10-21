###############################################################################
# Neph - AWS attack-path graphing
# EC2 host running the Neph docker-compose stack (simulator, steampipe, neo4j).
# Steampipe reads AWS through the instance profile below, which is READ-ONLY
# (SecurityAudit + ViewOnlyAccess). No write permissions are granted anywhere.
# Private subnet; browse Neo4j (7474) / JupyterLab (8888) via SSM port-forward.
###############################################################################

locals {
  tags = merge({ Component = "neph" }, var.tags)
}

data "aws_region" "current" {}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "random_password" "neo4j" {
  length  = 28
  special = false
}
resource "random_password" "steampipe" {
  length  = 28
  special = false
}

resource "aws_secretsmanager_secret" "neph" {
  name = "${var.name}/runtime"
  tags = local.tags
}
resource "aws_secretsmanager_secret_version" "neph" {
  secret_id = aws_secretsmanager_secret.neph.id
  secret_string = jsonencode({
    neo4j_password     = random_password.neo4j.result
    steampipe_password = random_password.steampipe.result
  })
}

# --- READ-ONLY IAM for discovery -------------------------------------------
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "neph" {
  name               = "${var.name}-readonly"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = local.tags
}

# Steampipe/Neph only ever read. Attach AWS-managed read-only policies.
resource "aws_iam_role_policy_attachment" "security_audit" {
  role       = aws_iam_role.neph.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}
resource "aws_iam_role_policy_attachment" "view_only" {
  role       = aws_iam_role.neph.name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.neph.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy" "read_secret" {
  name = "read-neph-secret"
  role = aws_iam_role.neph.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.neph.arn
    }]
  })
}
# Org read for load_aws_org mode (Organizations list/describe only).
resource "aws_iam_role_policy" "org_read" {
  count = var.load_aws_org ? 1 : 0
  name  = "org-read"
  role  = aws_iam_role.neph.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "organizations:List*",
        "organizations:Describe*",
        "sso:List*",
        "sso:Describe*",
        "identitystore:List*",
        "identitystore:Describe*"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "neph" {
  name = "${var.name}-readonly"
  role = aws_iam_role.neph.name
}

resource "aws_security_group" "neph" {
  name        = "${var.name}-host"
  description = "Neph host (SSM-only ingress)"
  vpc_id      = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.tags, { Name = "${var.name}-host" })
}

locals {
  user_data = templatefile("${path.module}/userdata.sh.tftpl", {
    secret_arn   = aws_secretsmanager_secret.neph.arn
    region       = data.aws_region.current.name
    scan_regions = jsonencode(var.scan_regions)
    load_aws_org = var.load_aws_org ? "True" : "False"
  })
}

resource "aws_instance" "neph" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.neph.id]
  iam_instance_profile        = aws_iam_instance_profile.neph.name
  key_name                    = var.key_name
  user_data_replace_on_change = true
  user_data                   = local.user_data

  root_block_device {
    volume_size = var.data_volume_gb
    volume_type = "gp3"
    encrypted   = true
  }
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }
  tags = merge(local.tags, { Name = var.name })
}
