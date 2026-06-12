terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# IAM is identical to the group-based variants: fleets change how capacity is
# provisioned, not how the cluster authenticates.
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

  # Fleets take a *list* of subnets, one per AZ. EMR still launches the whole
  # cluster into a single AZ — it picks whichever one can best satisfy the
  # requested capacity/price mix. The group-based variants pin one subnet (and
  # therefore one AZ) up front.
  ec2_attributes {
    subnet_ids       = var.subnet_ids
    instance_profile = aws_iam_instance_profile.emr_ec2.arn
  }

  # Exactly one master is provisioned, but listing several candidate types lets
  # EMR fall back if the first choice has no capacity in the chosen AZ.
  master_instance_fleet {
    name                      = "master"
    target_on_demand_capacity = 1

    dynamic "instance_type_configs" {
      for_each = var.master_instance_types
      content {
        instance_type = instance_type_configs.value
      }
    }
  }

  core_instance_fleet {
    name = "core"

    # Fleet targets are counted in capacity *units*, not instances: each
    # instance fulfils its weighted_capacity (below), so a 2xlarge with weight 2
    # covers two units. EMR mixes types and purchase options until both targets
    # are met — this is the dimension instance groups (one type, one count)
    # don't have. The on-demand units are the baseline that survives Spot
    # reclamation; HDFS lives on core nodes, so don't run this fleet all-Spot.
    target_on_demand_capacity = var.core_on_demand_capacity
    target_spot_capacity      = var.core_spot_capacity

    dynamic "instance_type_configs" {
      for_each = var.worker_instance_types
      content {
        instance_type     = instance_type_configs.value.instance_type
        weighted_capacity = instance_type_configs.value.weighted_capacity
        # Spot bids default to 100% of the on-demand price — you pay the (lower)
        # market price, the cap just bounds it. Set
        # bid_price_as_percentage_of_on_demand_price to bid below that.
      }
    }

    launch_specifications {
      on_demand_specification {
        allocation_strategy = "lowest-price"
      }

      # price-capacity-optimized weighs Spot pool depth against price — the
      # strategy AWS recommends to minimise interruptions. If Spot can't be
      # filled within the timeout, falling back to on-demand keeps the cluster
      # usable (TERMINATE_CLUSTER is the strict-budget alternative).
      spot_specification {
        allocation_strategy      = "price-capacity-optimized"
        timeout_action           = "SWITCH_TO_ON_DEMAND"
        timeout_duration_minutes = 10
      }
    }
  }

  keep_job_flow_alive_when_no_steps = true
  visible_to_all_users              = true
}

# Task fleets live in their own resource, not a block on the cluster — the
# provider only models master/core inline. Task nodes carry no HDFS, so losing
# one only costs recomputation; that makes the task fleet the natural place for
# an all-Spot stretch tier on top of the core baseline.
resource "aws_emr_instance_fleet" "task" {
  count = var.task_spot_capacity > 0 ? 1 : 0

  cluster_id = aws_emr_cluster.this.id
  name       = "task"

  target_spot_capacity = var.task_spot_capacity

  dynamic "instance_type_configs" {
    for_each = var.worker_instance_types
    content {
      instance_type     = instance_type_configs.value.instance_type
      weighted_capacity = instance_type_configs.value.weighted_capacity
    }
  }

  launch_specifications {
    spot_specification {
      allocation_strategy = "price-capacity-optimized"
      # There is no "give up and stay smaller" timeout action — the only
      # options are falling back to on-demand or terminating the whole cluster,
      # and TERMINATE_CLUSTER over optional stretch capacity would be absurd.
      timeout_action           = "SWITCH_TO_ON_DEMAND"
      timeout_duration_minutes = 10
    }
  }
}
