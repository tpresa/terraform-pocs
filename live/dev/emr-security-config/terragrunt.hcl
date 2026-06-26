include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../..//modules/emr-security-config"
}

inputs = {
  name      = "poc-emr-security-config-dev"
  subnet_id = "subnet-xxxxxxxx" # replace with a real subnet
  log_uri   = "s3://my-emr-logs-bucket-change-me/dev/"

  # At-rest encryption (S3 + local disk) is always on. To also turn on
  # node-to-node TLS, supply a PEM bundle and flip the flag:
  #   enable_in_transit      = true
  #   tls_certificate_s3_uri = "s3://my-bucket/certs/emr-tls.zip"
}
