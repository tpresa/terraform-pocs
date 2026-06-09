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
  type        = number
  default     = 1
  description = "Initial core nodes. Managed scaling grows the cluster from here, so start at the floor."
}

variable "min_capacity_units" {
  type        = number
  default     = 2
  description = "Lower scaling bound. With unit_type=Instances this counts the master too, so >= 1 + initial core nodes."
}

variable "max_capacity_units" {
  type        = number
  default     = 10
  description = "Upper scaling bound across master, core, and task nodes."
}

variable "max_core_capacity_units" {
  type        = number
  default     = null
  description = "Optional cap on core (HDFS-carrying) nodes. Capacity beyond this is added as task nodes."
}
