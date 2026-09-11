# Read these through the recipe. The apply masks them:
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

output "bucket_name" {
  description = "State bucket name. Check with `ovhcloud cloud storage object bucket get`."
  value       = ovh_cloud_project_storage.state.name
}

