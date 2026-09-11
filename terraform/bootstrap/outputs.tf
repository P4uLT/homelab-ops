# Read after the apply, not from the apply transcript: the two keys are
# sensitive and print masked. Use the recipe, then copy the values into
# .env and into the off-site recovery kit.
#
#   task tf:bootstrap-output -- -raw s3_access_key
#   task tf:bootstrap-output -- -raw s3_secret_key

output "s3_access_key" {
  description = "S3 access key for the state bucket. Copy to OVH_S3_ACCESS_KEY."
  value       = ovh_cloud_project_user_s3_credential.state.access_key_id
  sensitive   = true
}

output "s3_secret_key" {
  description = "S3 secret key for the state bucket. Copy to OVH_S3_SECRET_KEY."
  value       = ovh_cloud_project_user_s3_credential.state.secret_access_key
  sensitive   = true
}

output "primary_bucket_name" {
  description = "Primary state bucket name. Check with `ovhcloud cloud storage object bucket get`."
  value       = ovh_cloud_project_storage.state.name
}

output "replica_bucket_name" {
  description = "Replica bucket name in the second region. The restore source. See BACKEND.md."
  value       = ovh_cloud_project_storage.replica.name
}