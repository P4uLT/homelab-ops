# Move each collection so existing instance keys need no migration list.
moved {
  from = rustfs_bucket.this
  to   = module.buckets.rustfs_bucket.this
}

moved {
  from = rustfs_bucket_versioning.this
  to   = module.buckets.rustfs_bucket_versioning.this
}

moved {
  from = rustfs_quota.this
  to   = module.buckets.rustfs_quota.this
}

moved {
  from = rustfs_user.this
  to   = module.buckets.rustfs_user.this
}

moved {
  from = rustfs_policy.this
  to   = module.buckets.rustfs_policy.this
}

moved {
  from = rustfs_user_policy_attachment.this
  to   = module.buckets.rustfs_user_policy_attachment.this
}
