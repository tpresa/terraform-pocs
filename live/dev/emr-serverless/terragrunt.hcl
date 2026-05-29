include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../..//modules/emr-serverless"
}

inputs = {
  name            = "poc-emr-serverless-dev"
  job_data_bucket = "my-emr-serverless-data-change-me" # replace with a real bucket
}
