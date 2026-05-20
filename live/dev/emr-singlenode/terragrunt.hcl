include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../..//modules/emr-singlenode"
}

inputs = {
  name      = "poc-emr-singlenode-dev"
  subnet_id = "subnet-xxxxxxxx" # replace with a real subnet
  log_uri   = "s3://my-emr-logs-bucket-change-me/dev/"
}
