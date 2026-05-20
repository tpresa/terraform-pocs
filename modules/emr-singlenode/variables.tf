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
