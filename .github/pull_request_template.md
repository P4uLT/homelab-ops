## What and why

<!-- One short paragraph: what this change does and why it matters. -->
<!-- Link the phase (PROGRESS.md) or the issue (#N). -->

## Changes

<!-- Bullet the notable changes, grouped by area when the diff is wide. -->

-

## Validation

<!-- Commands you ran and what they showed. Ran none? Say why. -->

```text
task -d <namespace> verify
```

## Checklist

- [ ] No secrets, credentials, hostnames, LAN IPs, or rendered
      inventories in the diff
- [ ] Encrypted files stay encrypted (`.sops.yaml` rules untouched)
- [ ] Lint passes for the touched tooling (ansible-lint, yamllint,
      tflint, checkov, ...)
- [ ] `CHANGELOG.md` and `PROGRESS.md` updated when phase state moves
- [ ] Docs and comments stay in plain language
