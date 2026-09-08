# Security policy

## Reporting a vulnerability

Do not report security vulnerabilities in a public issue or a public pull
request.

Use [GitHub private vulnerability reporting](https://github.com/P4uLT/homelab-ops/security/advisories/new)
when it is available. Include the affected path, the impact, and reproduction
steps. Remove secrets from logs before you attach the logs.

If private reporting is not available, contact the repository owner through
their GitHub profile. Do not include credentials or other sensitive values in
the first message.

## Secret-handling rules

- Never commit credentials, private keys, host inventories, or rendered
  secrets.
- Use SOPS with age keys for secrets that the repository stores. The SOPS
  workflow is not implemented yet.
- Immediately revoke and rotate any credential that may have been exposed.
