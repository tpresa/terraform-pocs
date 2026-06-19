terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# IAM is identical to the long-lived variants: a transient cluster runs a step
# and then terminates, but it authenticates the same way while it's alive.
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

  core_instance_group {
    instance_type  = var.core_instance_type
    instance_count = var.core_instance_count
  }

  # The whole point of this variant. Every other cluster in this repo sets this
  # to true and idles waiting for work; here it's false, so EMR terminates the
  # cluster as soon as the last step finishes. That's the transient ("batch")
  # pattern: you pay for the run, not for an idle cluster.
  keep_job_flow_alive_when_no_steps = false
  visible_to_all_users              = true

  # One step submitted at launch. SparkPi ships in the Spark examples JAR that's
  # already on the cluster, so this runs end-to-end with no script to stage in
  # S3 — same prerequisites as emr-multinode (a subnet + a log bucket).
  #
  # command-runner.jar + spark-submit is the real submission path for EMR steps.
  # To run your own job instead, swap the args for a script in S3, e.g.
  #   ["spark-submit", "--deploy-mode", "cluster",
  #    "s3://my-bucket/jobs/my_job.py", "s3://.../in", "s3://.../out"]
  # The EC2 role (AmazonElasticMapReduceforEC2Role) already grants the S3 access
  # to read that script and write its output, so no extra IAM is needed.
  step {
    name = "sparkpi"

    # TERMINATE_CLUSTER is the sane default for a transient cluster: if the job
    # fails, don't leave a cluster running. CONTINUE (move to the next step) and
    # CANCEL_AND_WAIT (keep the cluster up for debugging) are the alternatives.
    action_on_failure = var.step_action_on_failure

    hadoop_jar_step {
      jar = "command-runner.jar"
      args = [
        "spark-submit", "--deploy-mode", "cluster",
        "--class", "org.apache.spark.examples.SparkPi",
        var.spark_examples_jar,
        tostring(var.sparkpi_partitions),
      ]
    }
  }

  # Terraform lifecycle caveat — read this before you `apply`:
  #
  # The apply succeeds because the provider's create-waiter is satisfied once
  # the cluster reaches RUNNING (which it does while the step runs). After the
  # step completes the cluster terminates itself, so the next `plan`/`refresh`
  # reads it as TERMINATED and wants to recreate it. That's expected: Terraform
  # models persistent desired state, and a truly ephemeral job cluster isn't
  # that. For repeatable one-off submissions you'd normally drive this from a
  # scheduler (Step Functions / Airflow / `aws emr create-cluster`) rather than
  # Terraform — this POC exists to show the pattern and that mismatch.
}
