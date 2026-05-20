output "cluster_id" {
  value = aws_emr_cluster.this.id
}

output "cluster_arn" {
  value = aws_emr_cluster.this.arn
}
