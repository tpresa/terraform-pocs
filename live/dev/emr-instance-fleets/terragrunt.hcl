include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../..//modules/emr-instance-fleets"
}

inputs = {
  name       = "poc-emr-instance-fleets-dev"
  subnet_ids = ["subnet-xxxxxxxx", "subnet-yyyyyyyy"] # replace with real subnets in different AZs
  log_uri    = "s3://my-emr-logs-bucket-change-me/dev/"
}
