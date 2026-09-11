# The state bucket, its cross-region replica, and the access chain.
# Every resource here is idempotent: a second apply converges.
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
# OVH has no GetObjectVersion or DeleteObjectVersion action: versioned
# reads and deletes ride on GetObject and DeleteObject, and
# ListBucketVersions covers the listing.
#
# Scope is the primary bucket only. The replica stays out of reach: a
# writer that can reach both can diverge them. Restore uses the OVH API
# through the CLI instead. See BACKEND.md.
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

# The primary bucket. SSE protects objects at rest; OpenTofu state adds
# its own client-side encryption on top (see backend.tf).
#
# The replication rule mirrors every write to the replica region. It is
# a disaster-recovery copy, not a second backend: the S3 backend still
# talks to this bucket only, and BACKEND.md documents the restore path.
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

  replication = {
    rules = [
      {
        id     = "state-replica-all"
        status = "enabled"

        # A delete on the primary must not destroy the copy. Without
        # this, an accidental or malicious removal reaches the replica.
        delete_marker_replication = "disabled"

        destination = {
          name   = ovh_cloud_project_storage.replica.name
          region = ovh_cloud_project_storage.replica.region_name

          # Keep the replica when the primary is deleted. The prime
          # case for the replica assumes the primary is gone.
          remove_on_main_bucket_deletion = false
        }
      },
    ]
  }

  lifecycle {
    prevent_destroy = true
  }
}

# The replica bucket, in a second region. Versioning is required on
# both sides before a replication rule applies.
resource "ovh_cloud_project_storage" "replica" {
  service_name = var.project_id
  name         = var.replica_bucket_name
  region_name  = var.replica_region

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

# Keep 90 days of noncurrent object versions on the primary. Versioning
# plus this rule is the state recovery path. See BACKEND.md.
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

# The same rule on the replica, so its noncurrent versions stay bounded
# and stay useful as a restore source.
resource "ovh_cloud_project_storage_object_bucket_lifecycle_configuration" "replica" {
  service_name   = var.project_id
  container_name = ovh_cloud_project_storage.replica.name
  region_name    = ovh_cloud_project_storage.replica.region_name

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