output "application_id" {
  value = aws_emrserverless_application.this.id
}

output "application_arn" {
  value = aws_emrserverless_application.this.arn
}

output "job_role_arn" {
  description = "Pass to StartJobRun --execution-role-arn to run jobs."
  value       = aws_iam_role.job_runtime.arn
}
