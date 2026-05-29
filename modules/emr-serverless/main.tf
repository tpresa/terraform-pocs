terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# EMR Serverless assumes this role to run job steps. Unlike a provisioned
# cluster there is no service role or EC2 instance profile — the runtime role is
# passed at StartJobRun time, not on the application. Production setups should
# also scope the trust policy with aws:SourceArn / aws:SourceAccount conditions.
data "aws_iam_policy_document" "job_runtime_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["emr-serverless.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "job_runtime" {
  name               = "${var.name}-emr-serverless-job"
  assume_role_policy = data.aws_iam_policy_document.job_runtime_assume.json
}

# Minimal runtime permissions: read scripts/input and write output + logs to one
# bucket. Catalog-backed jobs would also need glue:* on the relevant resources.
data "aws_iam_policy_document" "job_runtime" {
  statement {
    sid = "ReadWriteJobBucket"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::${var.job_data_bucket}",
      "arn:aws:s3:::${var.job_data_bucket}/*",
    ]
  }
}

resource "aws_iam_role_policy" "job_runtime" {
  name   = "${var.name}-emr-serverless-job"
  role   = aws_iam_role.job_runtime.name
  policy = data.aws_iam_policy_document.job_runtime.json
}

resource "aws_emrserverless_application" "this" {
  name          = var.name
  release_label = var.release_label
  type          = var.type
  architecture  = var.architecture

  # No instance groups to keep alive: capacity is created on demand and released
  # when idle, so the application costs nothing while no job is running.
  auto_start_configuration {
    enabled = true
  }

  auto_stop_configuration {
    enabled              = true
    idle_timeout_minutes = var.idle_timeout_minutes
  }

  # Upper bound on the aggregate resources the application may scale up to.
  maximum_capacity {
    cpu    = var.max_cpu
    memory = var.max_memory
  }

  # VPC access is opt-in. Jobs that only touch S3/Glue need no networking — a key
  # contrast with the cluster variants, which always launch into a subnet.
  dynamic "network_configuration" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }
}
