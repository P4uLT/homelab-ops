mock_provider "rustfs" {}

variables {
  state_passphrase  = "mock-only-passphrase"
  rustfs_endpoint   = "https://nas.example.invalid:30292"
  rustfs_access_key = "mockadmin"
  rustfs_secret_key = "mocksecret"
  buckets = {
    k8s-backups = { quota_bytes = 53687091200, versioning = true }
    wal-g       = { quota_bytes = 21474836480 }
    loki        = { quota_bytes = 10737418240 }
  }
  bucket_credentials = {
    k8s-backups = { access_key = "mock-backups", secret_key = "mock-backups-secret" }
    wal-g       = { access_key = "mock-walg", secret_key = "mock-walg-secret" }
    loki        = { access_key = "mock-loki", secret_key = "mock-loki-secret" }
  }
}

run "plans_buckets_users_policies_and_quotas" {
  command = plan

  assert {
    condition = (
      toset(keys(rustfs_bucket.this)) == toset(["k8s-backups", "wal-g", "loki"]) &&
      toset(keys(rustfs_quota.this)) == toset(keys(var.buckets)) &&
      alltrue([for name, quota in rustfs_quota.this : quota.quota == var.buckets[name].quota_bytes]) &&
      length(rustfs_bucket_versioning.this) == 1 &&
      rustfs_bucket_versioning.this["k8s-backups"].status == "Enabled" &&
      toset(keys(rustfs_user.this)) == toset(keys(var.buckets)) &&
      alltrue([for name, user in rustfs_user.this : user.access_key == nonsensitive(var.bucket_credentials[name].access_key)]) &&
      toset(keys(rustfs_policy.this)) == toset(keys(var.buckets)) &&
      toset(keys(rustfs_user_policy_attachment.this)) == toset(keys(var.buckets))
    )
    error_message = "The three buckets must plan their users, policies, and attachments."
  }

  assert {
    condition = (
      alltrue([
        for name, attachment in rustfs_user_policy_attachment.this :
        attachment.user == rustfs_user.this[name].access_key &&
        attachment.policy == rustfs_policy.this[name].name
      ]) &&
      alltrue([for name, user in rustfs_user.this : user.status == "enabled"]) &&
      alltrue([for name, policy in rustfs_policy.this : policy.name == "${name}-writer"])
    )
    error_message = "Each user must attach the policy named for its bucket."
  }

  assert {
    condition = (
      toset(rustfs_policy.this["k8s-backups"].statement[0].action) == toset(["s3:ListBucket", "s3:GetBucketLocation"]) &&
      toset(rustfs_policy.this["k8s-backups"].statement[0].resource) == toset(["arn:aws:s3:::k8s-backups"]) &&
      toset(rustfs_policy.this["k8s-backups"].statement[1].action) == toset(["s3:GetObject", "s3:PutObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"]) &&
      toset(rustfs_policy.this["k8s-backups"].statement[1].resource) == toset(["arn:aws:s3:::k8s-backups/*"]) &&
      rustfs_policy.this["k8s-backups"].statement[0].effect == "Allow" &&
      rustfs_policy.this["k8s-backups"].statement[1].effect == "Allow"
    )
    error_message = "k8s-backups takes its provisional list and read-write object policy."
  }

  assert {
    condition = (
      toset(rustfs_policy.this["wal-g"].statement[0].action) == toset(["s3:ListBucket", "s3:GetBucketLocation"]) &&
      toset(rustfs_policy.this["wal-g"].statement[0].resource) == toset(["arn:aws:s3:::wal-g"]) &&
      toset(rustfs_policy.this["wal-g"].statement[1].action) == toset(["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"]) &&
      toset(rustfs_policy.this["wal-g"].statement[1].resource) == toset(["arn:aws:s3:::wal-g/*"])
    )
    error_message = "wal-g must list its bucket and read, write, and delete its objects."
  }

  assert {
    condition = (
      toset(rustfs_policy.this["loki"].statement[0].action) == toset(["s3:ListBucket", "s3:GetBucketLocation"]) &&
      toset(rustfs_policy.this["loki"].statement[0].resource) == toset(["arn:aws:s3:::loki"]) &&
      toset(rustfs_policy.this["loki"].statement[1].action) == toset(["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"]) &&
      toset(rustfs_policy.this["loki"].statement[1].resource) == toset(["arn:aws:s3:::loki/*"])
    )
    error_message = "loki must list its bucket and read, write, and delete its objects."
  }
}
