###############################################################################
# TimberLake - adversary emulation runner  (OFFENSIVE TOOL)
# Runs authored test cases against a NON-PROD target account and pushes
# detection/prevention outcomes to VECTR via its GraphQL API.
#
# GUARD RAILS:
#  * target_account_id must appear in allowed_target_account_ids (precondition).
#  * target_account_id must NOT equal the account this runner is deployed in.
#  * The runner holds NO attack permissions itself; it only assumes a scoped
#    role (target_role_name) that YOU provision in the target account.
#  * Test cases are supplied from your own repo; none are bundled here.
###############################################################################

locals {
  tags = merge({ Component = "timberlake" }, var.tags)
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Hard guard: refuse to build if the target isn't allowlisted or is this account.
resource "terraform_data" "guard" {
  lifecycle {
    precondition {
      condition     = contains(var.allowed_target_account_ids, var.target_account_id)
      error_message = "target_account_id ${var.target_account_id} is not in allowed_target_account_ids."
    }
    precondition {
      condition     = var.target_account_id != data.aws_caller_identity.current.account_id
      error_message = "Refusing to target the account the runner itself runs in. Use a dedicated non-prod account."
    }
  }
}

# VECTR API credentials (populate after creating an API key in VECTR).
resource "aws_secretsmanager_secret" "vectr_api" {
  name = "${var.name}/vectr-api"
  tags = local.tags
}

# --- Runner task role: can assume ONLY the scoped role in the target account -
data "aws_iam_policy_document" "task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy" "task" {
  name = "assume-target-and-read-secret"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AssumeTargetRoleOnly"
        Effect   = "Allow"
        Action   = ["sts:AssumeRole"]
        Resource = "arn:aws:iam::${var.target_account_id}:role/${var.target_role_name}"
      },
      {
        Sid      = "ReadVectrApiKey"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.vectr_api.arn
      }
    ]
  })
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-exec"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = local.tags
}
resource "aws_iam_role_policy_attachment" "exec" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_cluster" "this" {
  name = var.name
  tags = local.tags
}

resource "aws_cloudwatch_log_group" "task" {
  name              = "/${var.name}/runner"
  retention_in_days = 90
  tags              = local.tags
}

resource "aws_security_group" "task" {
  name        = "${var.name}-task"
  description = "TimberLake runner egress"
  vpc_id      = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.tags, { Name = "${var.name}-task" })
}

# Fargate task definition. The image is a thin runner that:
#   pip install timberlake py-attire-schema; git clone <testcases_repo>;
#   assume target role; timberlake -c config.yml
# Build/push that image to ECR; reference it via container_image at apply time.
resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name      = "runner"
    image     = "public.ecr.aws/docker/library/python:3.12-slim" # replace with your built runner image
    essential = true
    environment = [
      { name = "TARGET_ACCOUNT_ID", value = var.target_account_id },
      { name = "TARGET_ROLE_NAME", value = var.target_role_name },
      { name = "VECTR_HOST", value = var.vectr_host },
      { name = "VECTR_ASSESSMENT", value = var.vectr_assessment },
      { name = "VECTR_DATABASE", value = var.vectr_database },
      { name = "TESTCASES_REPO", value = var.testcases_repo },
      { name = "VECTR_API_SECRET_ARN", value = aws_secretsmanager_secret.vectr_api.arn },
      { name = "TIMBERLAKE_LOGFILE", value = "/tmp/timberlake.log" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.task.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "runner"
      }
    }
  }])
  tags = local.tags
}
