# Security policy

## Reporting a vulnerability

Don't report security vulnerabilities in a public issue or a public pull
request.

Use [GitHub private vulnerability reporting](https://github.com/P4uLT/homelab-ops/security/advisories/new)
when it's available. Include the affected path, the impact, and reproduction
steps. Remove secrets from logs before you attach the logs.

If private reporting isn't available, contact the repository owner through
their GitHub profile. Don't include credentials or other sensitive values in
the first message.

## Secret-handling rules

- Never commit credentials, private keys, host inventories, or rendered
  secrets.
- Use SOPS with age keys for secrets that the repository stores. The SOPS
  workflow isn't implemented yet.
- If someone may have exposed a credential, revoke and rotate it immediately.
