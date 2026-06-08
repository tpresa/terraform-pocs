variable "name" {
  type = string
}

variable "subnet_ids" {
  type        = list(string)
  description = "At least two subnets in different AZs for the EKS control plane and node group."
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "namespace" {
  type        = string
  default     = "emr"
  description = "Kubernetes namespace the EMR virtual cluster is registered against."
}

variable "node_instance_type" {
  type    = string
  default = "m5.xlarge"
}

variable "node_count" {
  type        = number
  default     = 2
  description = "Desired size of the managed node group that runs job pods."
}

variable "release_label" {
  type        = string
  default     = "emr-7.2.0-latest"
  description = "EMR on EKS release label. Note the -latest (or dated) suffix, unlike provisioned EMR."
}

variable "job_data_bucket" {
  type        = string
  description = "S3 bucket the job execution role may read scripts/input from and write output to."
}
