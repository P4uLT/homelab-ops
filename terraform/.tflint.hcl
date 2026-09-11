# TFLint configuration for the OpenTofu roots. Run through `task tf:lint`.
# tflint --recursive runs from terraform/ and applies this config to
# every root. The bundled terraform plugin needs no download; add
# provider plugins only when a root starts using them.

plugin "terraform" {
  enabled = true
  preset  = recommended
}

# Enforce snake_case and a resource type prefix discipline that matches
# the existing roots.
rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}
