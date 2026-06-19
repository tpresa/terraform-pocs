include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../..//modules/emr-steps"
}

inputs = {
  name      = "poc-emr-steps-dev"
  subnet_id = "subnet-xxxxxxxx" # replace with a real subnet
  log_uri   = "s3://my-emr-logs-bucket-change-me/dev/"
}
