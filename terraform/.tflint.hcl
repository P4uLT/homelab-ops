# TFLint config for the OpenTofu roots. Run through `task tf:lint`.
# The bundled terraform plugin needs no download.

plugin "terraform" {
  enabled = true
  preset  = recommended
}

# Enforce snake_case and a name prefix that matches the existing roots.
rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}
