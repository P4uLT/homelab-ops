# The state bucket and its access chain. The root is frozen: every
# resource carries prevent_destroy. See BACKEND.md.

# Dedicated API user. objectstore_operator is required before an S3
# policy can attach (OVHcloud Object Storage IAM guide).
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

# Allowlist for the S3 backend. No DeleteBucket: the user cannot remove
# the bucket. No DeleteObjectVersion: the backend never needs it, and it
# would let the writer purge the versions recovery depends on.
# DeleteObject stays for use_lockfile cleanup.
#
# Keep only actions the OVH API stores back. It drops
# s3:GetObjectVersion, which would diff on every plan.
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

# The bucket. SSE protects objects at rest; OpenTofu state encryption
# adds a second layer (see backend.tf). Region: see BACKEND.md.
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

# 90 days of noncurrent versions: the state recovery path. See BACKEND.md.
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
