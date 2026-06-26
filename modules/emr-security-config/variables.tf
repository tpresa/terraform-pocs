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

variable "enable_in_transit" {
  type        = bool
  default     = false
  description = "Turn on node-to-node TLS encryption. Requires tls_certificate_s3_uri."
}

variable "tls_certificate_s3_uri" {
  type        = string
  default     = ""
  description = "s3:// URI of a zip with privateKey.pem + certificateChain.pem. Only used when enable_in_transit = true."
}
