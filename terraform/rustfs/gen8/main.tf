module "buckets" {
  source = "../modules/buckets"

  buckets            = var.buckets
  bucket_credentials = var.bucket_credentials
  admin_access_key   = var.rustfs_access_key
}
