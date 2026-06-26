output "cluster_id" {
  value = aws_emr_cluster.this.id
}

output "cluster_arn" {
  value = aws_emr_cluster.this.arn
}

output "security_configuration_name" {
  value = aws_emr_security_configuration.this.name
}

output "kms_key_arn" {
  value = aws_kms_key.emr.arn
}
