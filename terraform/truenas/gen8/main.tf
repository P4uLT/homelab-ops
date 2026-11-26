module "dataset" {
  for_each = var.datasets
  source   = "../modules/dataset"

  dataset            = each.value
  encryption_secrets = lookup(var.dataset_encryption_secrets, each.key, { key = null, passphrase = null })
}
