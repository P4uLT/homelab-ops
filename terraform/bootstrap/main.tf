# The state bucket and its access chain. Every resource here is
# idempotent: a second apply converges to the same state.

# Dedicated API user for the state bucket. The main OVH account keeps
# full control; this user never gets the DeleteBucket permission.
resource "ovh_cloud_project_user" "state" {
  service_name = var.project_id
  description  = "terraform state backend"
}

resource "ovh_cloud_project_user_s3_credential" "state" {
  service_name = var.project_id
  user_id      = ovh_cloud_project_user.state.id
}

# Allowlist for the S3 backend. Two statements, one per resource type.
# DeleteBucket is absent on purpose: the user cannot remove the bucket.
resource "ovh_cloud_project_user_s3_policy" "state" {
  service_name = var.project_id
  user_id      = ovh_cloud_project_user.state.id

  policy = jsonencode({
    statement = [
      {
        sid      = "StateBucketListing"
        effect   = "Allow"
        action   = ["s3:ListBucket", "s3:ListBucketVersions", "s3:GetBucketLocation", "s3:GetBucketVersioning"]
        resource = ["arn:aws:s3:::${var.bucket_name}"]
      },
      {
        sid      = "StateObjectReadWrite"
        effect   = "Allow"
        action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:GetObjectVersion", "s3:DeleteObjectVersion", "s3:AbortMultipartUpload"]
        resource = ["arn:aws:s3:::${var.bucket_name}/*"]
      },
    ]
  })
}

# The bucket itself. SSE protects objects at rest; OpenTofu state adds
# its own client-side encryption on top (see backend.tf).
resource "ovh_cloud_project_storage" "state" {
  service_name = var.project_id
  name         = var.bucket_name
  region_name  = var.region

  versioning = {
    status = "enabled"
  }

  encryption = {
    sse_algorithm = "AES256"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Keep 90 days of noncurrent object versions. Versioning plus this rule
# is the state recovery path. See BACKEND.md.
resource "ovh_cloud_project_storage_object_bucket_lifecycle_configuration" "state" {
  service_name   = var.project_id
  container_name = ovh_cloud_project_storage.state.name
  region_name    = ovh_cloud_project_storage.state.region_name

  rules = [
    {
      id     = "expire-noncurrent-90d"
      status = "enabled"

      noncurrent_version_expiration = {
        noncurrent_days = 90
      }
    },
  ]
}
