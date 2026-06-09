terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "emr_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["elasticmapreduce.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "emr_service" {
  name               = "${var.name}-emr-service"
  assume_role_policy = data.aws_iam_policy_document.emr_assume.json
}

resource "aws_iam_role_policy_attachment" "emr_service" {
  role       = aws_iam_role.emr_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEMRServicePolicy_v2"
}

resource "aws_iam_role" "emr_ec2" {
  name               = "${var.name}-emr-ec2"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "emr_ec2" {
  role       = aws_iam_role.emr_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

resource "aws_iam_instance_profile" "emr_ec2" {
  name = "${var.name}-emr-ec2"
  role = aws_iam_role.emr_ec2.name
}

resource "aws_emr_cluster" "this" {
  name          = var.name
  release_label = var.release_label
  applications  = var.applications

  service_role         = aws_iam_role.emr_service.arn
  log_uri              = var.log_uri
  ebs_root_volume_size = 20

  ec2_attributes {
    subnet_id        = var.subnet_id
    instance_profile = aws_iam_instance_profile.emr_ec2.arn
  }

  master_instance_group {
    instance_type  = var.master_instance_type
    instance_count = 1
  }

  # Only the initial core capacity. Managed scaling (below) takes over sizing
  # from here — there is no autoscaling_policy on the group itself.
  core_instance_group {
    instance_type  = var.core_instance_type
    instance_count = var.core_instance_count
  }

  keep_job_flow_alive_when_no_steps = true
  visible_to_all_users              = true
}

# Managed scaling resizes the cluster automatically between the limits below,
# driven by YARN resource pressure. Unlike the legacy per-instance-group
# autoscaling_policy, it needs no CloudWatch alarms or custom rules — EMR owns
# the scaling decisions and adds/removes task (and core) nodes as load changes.
resource "aws_emr_managed_scaling_policy" "this" {
  cluster_id = aws_emr_cluster.this.id

  compute_limits {
    # "Instances" counts whole nodes including the master; use "VCPU" to bound by
    # core count instead. (Instance-fleet clusters use "InstanceFleetUnits".)
    unit_type              = "Instances"
    minimum_capacity_units = var.min_capacity_units
    maximum_capacity_units = var.max_capacity_units

    # When set, caps the HDFS-carrying core nodes; any capacity above this is
    # satisfied with task nodes, which scale down faster and carry no HDFS data.
    maximum_core_capacity_units = var.max_core_capacity_units
  }
}
