locals {
  # Reviewed actions per workload. Keep each list narrow: no s3:* and no
  # bucket administration. The backup tool for k8s-backups is still open, so
  # it gets list, read, and write only. Revisit it before onboarding it.
  # Adding a bucket means adding its action list here.
  client_actions = {
    k8s-backups = {
      bucket = ["s3:GetBucketLocation", "s3:ListBucket"]
      object = ["s3:AbortMultipartUpload", "s3:GetObject", "s3:ListMultipartUploadParts", "s3:PutObject"]
    }
    wal-g = {
      bucket = ["s3:GetBucketLocation", "s3:ListBucket"]
      object = ["s3:AbortMultipartUpload", "s3:DeleteObject", "s3:GetObject", "s3:ListMultipartUploadParts", "s3:PutObject"]
    }
    loki = {
      bucket = ["s3:GetBucketLocation", "s3:ListBucket"]
      object = ["s3:AbortMultipartUpload", "s3:DeleteObject", "s3:GetObject", "s3:ListMultipartUploadParts", "s3:PutObject"]
    }
  }
}

resource "rustfs_bucket" "this" {
  for_each = var.buckets
  name     = each.key
}

resource "rustfs_bucket_versioning" "this" {
  for_each = { for name, bucket in var.buckets : name => bucket if bucket.versioning != null }
  bucket   = rustfs_bucket.this[each.key].name
  status   = each.value.versioning ? "Enabled" : "Suspended"
}

resource "rustfs_quota" "this" {
  for_each = var.buckets
  bucket   = rustfs_bucket.this[each.key].name
  quota    = each.value.quota_bytes
}

resource "rustfs_user" "this" {
  for_each   = var.buckets
  access_key = var.bucket_credentials[each.key].access_key
  secret_key = var.bucket_credentials[each.key].secret_key
  name       = "${each.key} writer"
  status     = "enabled"
}

resource "rustfs_policy" "this" {
  for_each = var.buckets
  name     = "${each.key}-writer"
  statement = [
    {
      effect   = "Allow"
      action   = local.client_actions[each.key].bucket
      resource = ["arn:aws:s3:::${rustfs_bucket.this[each.key].name}"]
    },
    {
      effect   = "Allow"
      action   = local.client_actions[each.key].object
      resource = ["arn:aws:s3:::${rustfs_bucket.this[each.key].name}/*"]
    },
  ]
}

resource "rustfs_user_policy_attachment" "this" {
  for_each = rustfs_user.this
  user     = rustfs_user.this[each.key].access_key
  policy   = rustfs_policy.this[each.key].name
}
