resource "rustfs_user" "this" {
  for_each   = var.buckets
  access_key = var.bucket_credentials[each.key].access_key
  secret_key = var.bucket_credentials[each.key].secret_key
  name       = coalesce(each.value.user_name, "${each.key} writer")
  status     = each.value.user_status
}

resource "rustfs_policy" "this" {
  for_each = var.buckets
  name     = "${each.key}-writer"
  statement = [
    {
      effect   = "Allow"
      action   = setunion(local.default_bucket_actions, each.value.additional_bucket_actions)
      resource = [local.bucket_arns[each.key]]
    },
    {
      effect   = "Allow"
      action   = setunion(local.default_object_actions, each.value.additional_object_actions)
      resource = ["${local.bucket_arns[each.key]}/*"]
    },
  ]
}

resource "rustfs_user_policy_attachment" "this" {
  for_each = rustfs_user.this
  user     = rustfs_user.this[each.key].access_key
  policy   = rustfs_policy.this[each.key].name
}
