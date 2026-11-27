locals {
  bytes_per_gib   = pow(2, 30)
  quota_limit_gib = pow(2, 63) / local.bytes_per_gib

  bucket_quotas_bytes = {
    for name, bucket in var.buckets : name => try(bucket.quota_gib * local.bytes_per_gib, null)
  }
  bucket_versioning = {
    for name, bucket in var.buckets : name => bucket.versioning ? "Enabled" : "Suspended"
    if try(bucket.versioning != null, false)
  }

  default_bucket_actions = toset([
    "s3:GetBucketLocation",
    "s3:ListBucket",
  ])
  default_object_actions = toset([
    "s3:AbortMultipartUpload",
    "s3:GetObject",
    "s3:ListMultipartUploadParts",
    "s3:PutObject",
  ])

  # Keep extra permissions scoped to data operations, not bucket administration.
  allowed_bucket_actions = setunion(local.default_bucket_actions, [
    "s3:ListBucketMultipartUploads",
    "s3:ListBucketVersions",
  ])
  allowed_object_actions = setunion(local.default_object_actions, [
    "s3:DeleteObject",
    "s3:DeleteObjectVersion",
    "s3:GetObjectTagging",
    "s3:GetObjectVersion",
    "s3:PutObjectTagging",
  ])

  bucket_arns = {
    for name, bucket in rustfs_bucket.this : name => "arn:aws:s3:::${bucket.name}"
  }
}
