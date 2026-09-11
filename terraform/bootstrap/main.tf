# The state bucket and its access chain. Every resource here is
# idempotent: a second apply converges to the same state.
#
# The root is frozen, so every resource carries prevent_destroy. A
# destroy must be a deliberate code change. See BACKEND.md.

# Dedicated API user for the state bucket. The main OVH account keeps
# full control; this user never gets the DeleteBucket permission.
# objectstore_operator is required before an S3 policy can attach
# (OVHcloud Object Storage IAM guide).
resource "ovh_cloud_project_user" "state" {
  service_name = var.project_id
  description  = "terraform state backend"
  role_names   = ["objectstore_operator"]

  lifecycle {
    prevent_destroy = true
  }
}

resource "ovh_cloud_project_user_s3_credential" "state" {
  service_name = var.project_id
  user_id      = ovh_cloud_project_user.state.id

  lifecycle {
    prevent_destroy = true
  }
}

# Allowlist for the S3 backend. Two statements, one per resource type.
# DeleteBucket is absent on purpose: the user cannot remove the bucket.
# DeleteObjectVersion is absent too: the S3 backend never needs it, and
# it would let the state writer purge the versions that BACKEND.md
# relies on for recovery. DeleteObject stays for `use_lockfile` cleanup.
#
# Keep this list to the actions the OVH API stores back verbatim. It
# drops s3:GetObjectVersion, which would show a diff on every plan.
# The backend reads the current version only.
resource "ovh_cloud_project_user_s3_policy" "state" {
  service_name = var.project_id
  user_id      = ovh_cloud_project_user.state.id

  policy = jsonencode({
    Statement = [
      {
        Sid    = "StateBucketListing"
        Effect = "Allow"
        Action = ["s3:ListBucket", "s3:ListBucketVersions", "s3:GetBucketLocation", "s3:GetBucketVersioning"]
        Resource = [
          "arn:aws:s3:::${var.bucket_name}"
        ]
      },
      {
        Sid    = "StateObjectReadWrite"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload"]
        Resource = [
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      },
    ]
  })

  lifecycle {
    prevent_destroy = true
  }
}

# The bucket itself. SSE protects objects at rest; OpenTofu state adds
# its own client-side encryption on top (see backend.tf).
#
# The bucket lives in a 3-AZ region. See BACKEND.md for the region
# choice and the failure domains it does and does not cover.
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

  lifecycle {
    prevent_destroy = true
  }
}
