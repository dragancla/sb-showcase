output "helm_release_status" {
  description = "Deployment status of the Helm Release"
  value       = helm_release.sb.status
}

output "nomad_job_id" {
  description = "Registration ID of the Nomad Job"
  value       = nomad_job.sb.id
}

output "generated_db_password" {
  description = "Dynamically generated database secret (masked)"
  value       = random_password.db_password.result
  sensitive   = true
}
