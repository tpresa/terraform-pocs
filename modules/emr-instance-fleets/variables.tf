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

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets in different AZs. EMR launches the cluster into the single AZ with the best capacity/price for the requested mix."
}

variable "log_uri" {
  type        = string
  description = "S3 URI for EMR logs, e.g. s3://my-bucket/emr-logs/"
}

variable "master_instance_types" {
  type        = list(string)
  default     = ["m5.xlarge", "m5a.xlarge"]
  description = "Candidate types for the master fleet; exactly one instance is provisioned."
}

variable "worker_instance_types" {
  type = list(object({
    instance_type     = string
    weighted_capacity = number
  }))
  default = [
    { instance_type = "m5.xlarge", weighted_capacity = 1 },
    { instance_type = "m5a.xlarge", weighted_capacity = 1 },
    { instance_type = "m5.2xlarge", weighted_capacity = 2 },
  ]
  description = "Diversified pool shared by the core and task fleets. weighted_capacity is how many units one instance of that type fulfils toward a fleet's targets."
}

variable "core_on_demand_capacity" {
  type        = number
  default     = 1
  description = "On-demand units in the core fleet — the baseline that survives Spot reclamation."
}

variable "core_spot_capacity" {
  type        = number
  default     = 2
  description = "Spot units in the core fleet."
}

variable "task_spot_capacity" {
  type        = number
  default     = 2
  description = "Spot units in the all-Spot task fleet. Set to 0 to skip the task fleet."
}
