# Shared partial backend for every root that stores state on the OVH S3
# bucket. The tf tasks pass this file to init with -backend-config. The
# bucket name stays in .env.tf, and the per-root key stays in each
# root's backend.tf. See BACKEND.md.

region                      = "eu-west-par"
endpoints                   = { s3 = "https://s3.eu-west-par.io.cloud.ovh.net" }
skip_region_validation      = true
skip_credentials_validation = true
use_lockfile                = true
