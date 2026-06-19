variable "name" {
  type = string
}

variable "release_label" {
  type    = string
  default = "emr-7.2.0"
}

variable "applications" {
  type    = list(string)
  default = ["Spark", "Hadoop"]
}

variable "subnet_id" {
  type = string
}

variable "log_uri" {
  type        = string
  description = "S3 URI for EMR logs, e.g. s3://my-bucket/emr-logs/"
}

variable "master_instance_type" {
  type    = string
  default = "m5.xlarge"
}

variable "core_instance_type" {
  type    = string
  default = "m5.xlarge"
}

variable "core_instance_count" {
  type    = number
  default = 2
}

variable "sparkpi_partitions" {
  type        = number
  default     = 100
  description = "SparkPi partitions — higher values make the step run longer."
}

variable "step_action_on_failure" {
  type        = string
  default     = "TERMINATE_CLUSTER"
  description = "What EMR does if the step fails: TERMINATE_CLUSTER, CONTINUE, or CANCEL_AND_WAIT."
}

variable "spark_examples_jar" {
  type        = string
  default     = "/usr/lib/spark/examples/jars/spark-examples.jar"
  description = "On-cluster path to the Spark examples JAR; may differ across EMR releases."
}
