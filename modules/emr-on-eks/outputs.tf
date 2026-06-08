output "virtual_cluster_id" {
  description = "Pass to StartJobRun --virtual-cluster-id to run jobs."
  value       = aws_emrcontainers_virtual_cluster.this.id
}

output "virtual_cluster_arn" {
  value = aws_emrcontainers_virtual_cluster.this.arn
}

output "eks_cluster_name" {
  value = aws_eks_cluster.this.name
}

output "job_execution_role_arn" {
  description = "Pass to StartJobRun --execution-role-arn to run jobs."
  value       = aws_iam_role.job_exec.arn
}

output "namespace" {
  value = var.namespace
}
