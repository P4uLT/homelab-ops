# Security policy

## Reporting a vulnerability

Please do not report security vulnerabilities in a public issue or pull request.

Use [GitHub's private vulnerability reporting](https://github.com/P4uLT/homelab-ops/security/advisories/new)
when available. Include the affected path, impact, reproduction steps, and any
relevant logs with secrets removed.

If private reporting is unavailable, contact the repository owner through their
GitHub profile and do not include credentials or other sensitive values in the
initial message.

## Secret-handling rules

- Never commit credentials, private keys, host inventories, or rendered secrets.
- Use SOPS/age for repository-managed secrets once the corresponding workflow is
  implemented.
- Revoke and rotate any credential that may have been exposed immediately.
