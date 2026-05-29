variable "name" {
  type = string
}

variable "release_label" {
  type    = string
  default = "emr-7.2.0"
}

variable "type" {
  type        = string
  default     = "spark"
  description = "Application type: \"spark\" or \"hive\" (lowercase — the provider normalizes it)."
}

variable "architecture" {
  type        = string
  default     = "X86_64"
  description = "CPU architecture: X86_64 or ARM64 (Graviton)."
}

variable "idle_timeout_minutes" {
  type        = number
  default     = 15
  description = "Minutes of inactivity before the application stops and releases capacity."
}

variable "max_cpu" {
  type        = string
  default     = "16 vCPU"
  description = "Upper bound on total vCPUs across all running workers."
}

variable "max_memory" {
  type        = string
  default     = "64 GB"
  description = "Upper bound on total memory across all running workers."
}

variable "job_data_bucket" {
  type        = string
  description = "S3 bucket name the job runtime role may read/write (scripts, input, output, logs)."
}

variable "subnet_ids" {
  type        = list(string)
  default     = []
  description = "Optional VPC subnets for jobs that reach private resources. Empty = no VPC."
}

variable "security_group_ids" {
  type        = list(string)
  default     = []
  description = "Security groups to attach when subnet_ids is set."
}
