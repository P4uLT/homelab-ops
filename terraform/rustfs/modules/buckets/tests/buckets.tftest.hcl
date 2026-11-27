mock_provider "rustfs" {}

variables {
  admin_access_key = "mockadmin"
  buckets = {
    test-archive = { quota_gib = 50, versioning = true }
    test-data = {
      quota_gib                      = 1.5
      versioning                     = false
      additional_bucket_actions      = ["s3:ListBucketMultipartUploads", "s3:ListBucket"]
      additional_object_actions      = ["s3:DeleteObject", "s3:PutObject"]
      bucket_namespace               = "global"
      object_ownership               = "BucketOwnerEnforced"
      object_lock_enabled_for_bucket = false
      create_bucket_configuration    = { tags = { purpose = "test" } }
      user_name                      = "Test data writer"
      user_status                    = "disabled"
    }
    test-logs = { quota_gib = 10 }
  }
  bucket_credentials = {
    test-archive = { access_key = "mock-archive", secret_key = "mock-archive-secret" }
    test-data    = { access_key = "mock-data", secret_key = "mock-data-secret" }
    test-logs    = { access_key = "mock-logs", secret_key = "mock-logs-secret" }
  }
}

run "plans_arbitrary_buckets_and_preserves_identity_mapping" {
  command = plan

  assert {
    condition = (
      toset(keys(rustfs_bucket.this)) == toset(keys(var.buckets)) &&
      toset(keys(rustfs_quota.this)) == toset(keys(var.buckets)) &&
      toset(keys(rustfs_user.this)) == toset(keys(var.buckets)) &&
      toset(keys(rustfs_policy.this)) == toset(keys(var.buckets)) &&
      toset(keys(rustfs_user_policy_attachment.this)) == toset(keys(var.buckets)) &&
      alltrue([
        for name, attachment in rustfs_user_policy_attachment.this :
        attachment.user == nonsensitive(var.bucket_credentials[name].access_key) &&
        attachment.policy == "${name}-writer"
      ])
    )
    error_message = "Each declared bucket must keep its own user and policy attachment."
  }

  assert {
    condition = (
      rustfs_quota.this["test-archive"].quota == 53687091200 &&
      rustfs_quota.this["test-data"].quota == 1610612736 &&
      rustfs_bucket_versioning.this["test-archive"].status == "Enabled" &&
      rustfs_bucket_versioning.this["test-data"].status == "Suspended" &&
      !contains(keys(rustfs_bucket_versioning.this), "test-logs")
    )
    error_message = "Quotas must convert to bytes and versioning must preserve all three states."
  }
}

run "passes_optional_bucket_and_user_settings" {
  command = plan

  assert {
    condition = (
      rustfs_bucket.this["test-data"].bucket_namespace == "global" &&
      rustfs_bucket.this["test-data"].object_ownership == "BucketOwnerEnforced" &&
      rustfs_bucket.this["test-data"].object_lock_enabled_for_bucket == false &&
      rustfs_bucket.this["test-data"].create_bucket_configuration.tags["purpose"] == "test" &&
      !rustfs_bucket.this["test-data"].force_destroy &&
      rustfs_user.this["test-data"].name == "Test data writer" &&
      rustfs_user.this["test-data"].status == "disabled" &&
      rustfs_user.this["test-logs"].name == "test-logs writer" &&
      rustfs_user.this["test-logs"].status == "enabled"
    )
    error_message = "Bucket and user options must reach the provider without unsafe defaults."
  }
}

run "scopes_the_shared_policy_and_its_additions" {
  command = plan

  assert {
    condition = alltrue([
      for name, policy in rustfs_policy.this :
      policy.statement[0].effect == "Allow" &&
      policy.statement[1].effect == "Allow" &&
      toset(policy.statement[0].resource) == toset(["arn:aws:s3:::${name}"]) &&
      toset(policy.statement[1].resource) == toset(["arn:aws:s3:::${name}/*"]) &&
      toset(policy.statement[0].action) == setunion(
        ["s3:GetBucketLocation", "s3:ListBucket"],
        name == "test-data" ? ["s3:ListBucketMultipartUploads"] : []
      ) &&
      toset(policy.statement[1].action) == setunion(
        ["s3:AbortMultipartUpload", "s3:GetObject", "s3:ListMultipartUploadParts", "s3:PutObject"],
        name == "test-data" ? ["s3:DeleteObject"] : []
      )
    ])
    error_message = "Only explicitly requested actions may extend the shared policy on the bucket's own ARN."
  }
}
