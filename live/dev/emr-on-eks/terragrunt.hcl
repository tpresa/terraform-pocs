include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../..//modules/emr-on-eks"
}

inputs = {
  name = "poc-emr-on-eks-dev"

  # EKS needs at least two subnets in different AZs.
  subnet_ids      = ["subnet-xxxxxxxx", "subnet-yyyyyyyy"] # replace with real subnets
  job_data_bucket = "my-emr-eks-data-change-me"            # replace with a real bucket
}
