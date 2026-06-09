include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../..//modules/emr-managed-scaling"
}

inputs = {
  name      = "poc-emr-managed-scaling-dev"
  subnet_id = "subnet-xxxxxxxx" # replace with a real subnet
  log_uri   = "s3://my-emr-logs-bucket-change-me/dev/"

  min_capacity_units = 2
  max_capacity_units = 10
}
