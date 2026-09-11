# Printed once at apply time. Copy both values to .env right after the
# apply, then keep copies in the off-site recovery kit.

output "s3_access_key" {
  description = "S3 access key for the state bucket. Copy to OVH_S3_ACCESS_KEY."
  value       = ovh_cloud_project_user_s3_credential.state.access_key_id
}

output "s3_secret_key" {
  description = "S3 secret key for the state bucket. Copy to OVH_S3_SECRET_KEY."
  value       = ovh_cloud_project_user_s3_credential.state.secret_access_key
  sensitive   = true
}
