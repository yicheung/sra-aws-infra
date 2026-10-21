###############################################################################
# VECTR purple-team tracking server
# Ubuntu 22.04 EC2 host that installs Docker + the VECTR CE runtime via Docker
# Compose. Secrets (Postgres, data/JWT keys, admin) are generated into Secrets
# Manager and injected through the .env at boot. Private subnet; reach it via an
# optional ALB (TLS) or SSM Session Manager port-forward.
###############################################################################

locals {
  tags = merge({ Component = "vectr" }, var.tags)
}

data "aws_ssm_parameter" "ubuntu" {
  # Canonical Ubuntu 22.04 LTS amd64 (x86-64 required by VECTR).
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

# --- Generated secrets -----------------------------------------------------
resource "random_password" "postgres" {
  length  = 32
  special = false
}
resource "random_password" "data_key" {
  length  = 32
  special = false
}
resource "random_password" "jws_key" {
  length  = 24
  special = false
}
resource "random_password" "jwe_key" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "vectr" {
  name = "${var.name}/runtime"
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "vectr" {
  secret_id = aws_secretsmanager_secret.vectr.id
  secret_string = jsonencode({
    POSTGRES_PASSWORD = random_password.postgres.result
    POSTGRES_USER     = "vectr"
    POSTGRES_DB       = "vectr"
    VECTR_DATA_KEY    = random_password.data_key.result
    JWS_KEY           = random_password.jws_key.result
    JWE_KEY           = random_password.jwe_key.result
  })
}

# --- IAM: host can read its own secret + be managed by SSM -----------------
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vectr" {
  name               = "${var.name}-host"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.vectr.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "secret" {
  name = "read-vectr-secret"
  role = aws_iam_role.vectr.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.vectr.arn
    }]
  })
}

resource "aws_iam_instance_profile" "vectr" {
  name = "${var.name}-host"
  role = aws_iam_role.vectr.name
}

# --- Security groups -------------------------------------------------------
resource "aws_security_group" "host" {
  name        = "${var.name}-host"
  description = "VECTR host"
  vpc_id      = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.tags, { Name = "${var.name}-host" })
}

resource "aws_security_group" "alb" {
  count       = var.create_alb ? 1 : 0
  name        = "${var.name}-alb"
  description = "VECTR ALB"
  vpc_id      = var.vpc_id
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = length(var.allowed_cidrs) > 0 ? var.allowed_cidrs : ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.tags, { Name = "${var.name}-alb" })
}

# ALB -> host on VECTR port
resource "aws_security_group_rule" "host_from_alb" {
  count                    = var.create_alb ? 1 : 0
  type                     = "ingress"
  from_port                = var.vectr_port
  to_port                  = var.vectr_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.host.id
  source_security_group_id = aws_security_group.alb[0].id
}

# Direct host access only if CIDRs given and no ALB
resource "aws_security_group_rule" "host_direct" {
  count             = (!var.create_alb && length(var.allowed_cidrs) > 0) ? 1 : 0
  type              = "ingress"
  from_port         = var.vectr_port
  to_port           = var.vectr_port
  protocol          = "tcp"
  security_group_id = aws_security_group.host.id
  cidr_blocks       = var.allowed_cidrs
}

# --- User data: install Docker + VECTR runtime -----------------------------
locals {
  user_data = templatefile("${path.module}/userdata.sh.tftpl", {
    vectr_version  = var.vectr_version
    vectr_hostname = var.vectr_hostname
    vectr_port     = var.vectr_port
    secret_arn     = aws_secretsmanager_secret.vectr.arn
    region         = data.aws_region.current.name
  })
}

data "aws_region" "current" {}

resource "aws_instance" "vectr" {
  ami                         = data.aws_ssm_parameter.ubuntu.value
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.host.id]
  iam_instance_profile        = aws_iam_instance_profile.vectr.name
  key_name                    = var.key_name
  user_data_replace_on_change = true
  user_data                   = local.user_data

  root_block_device {
    volume_size = var.data_volume_gb
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens   = "required" # IMDSv2
    http_endpoint = "enabled"
  }

  tags = merge(local.tags, { Name = var.name })
}

# --- Optional ALB + TLS ----------------------------------------------------
resource "aws_lb" "vectr" {
  count              = var.create_alb ? 1 : 0
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = var.public_subnet_ids
  tags               = local.tags
}

resource "aws_lb_target_group" "vectr" {
  count       = var.create_alb ? 1 : 0
  name        = "${var.name}-tg"
  port        = var.vectr_port
  protocol    = "HTTPS"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check {
    protocol            = "HTTPS"
    path                = "/"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 10
    interval            = 30
  }
  tags = local.tags
}

resource "aws_lb_target_group_attachment" "vectr" {
  count            = var.create_alb ? 1 : 0
  target_group_arn = aws_lb_target_group.vectr[0].arn
  target_id        = aws_instance.vectr.id
  port             = var.vectr_port
}

resource "aws_lb_listener" "https" {
  count             = var.create_alb ? 1 : 0
  load_balancer_arn = aws_lb.vectr[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vectr[0].arn
  }
}
