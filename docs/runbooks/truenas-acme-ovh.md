# Issue TrueNAS certificates on the Gen8

Use this runbook after applying the [base Gen8 bootstrap](bootstrap-truenas.md). On a fresh NAS, bootstrap storage and provisioning access with certificate issuance disabled.

This procedure uses OVH DNS and Let's Encrypt. For design and sample names, see [TLS for TrueNAS administration and applications](../truenas-tls.md).

Get owner approval before any live plan, apply, DNS operation, or endpoint check. Approve application redeployments and the administration restart separately.

## Prepare DNS and credentials

1. Choose certificate names in your OVH-managed public DNS zone. Use an exact name for the administration interface.
2. Use private DNS to resolve each service name to the NAS or to its reverse proxy. If clients need both paths, you can use separate names. Each TLS endpoint needs a certificate that covers the name its clients use.
3. Check the public authority for each challenge. Check certification authority authorization (`CAA`) records if present.

### Create the OVH credential manually

Don't reuse the state backend credential. Create a dedicated credential for TrueNAS. Limit write access to the authoritative DNS zone.

1. Open [Create API keys for OVH Europe](https://eu.api.ovh.com/createToken/) or [Create API keys for OVH Canada](https://ca.api.ovh.com/createToken/). Sign in to the account that manages the zone.
2. Enter an application name such as `TrueNAS ACME`. If you choose a token expiry, schedule rotation before it expires. TrueNAS needs the credential for every renewal.
3. In **Rights**, add the five rules below. Replace `<zone>` with the OVH zone name, not a certificate hostname or wildcard.

   | Method | Path |
   | --- | --- |
   | `GET` | `/domain/zone/` |
   | `GET` | `/domain/zone/<zone>/*` |
   | `PUT` | `/domain/zone/<zone>/*` |
   | `POST` | `/domain/zone/<zone>/*` |
   | `DELETE` | `/domain/zone/<zone>/*` |

   These [single-zone rules](https://certbot-dns-ovh.readthedocs.io/en/stable/#credentials) allow zone discovery and changes within the selected zone. They don't limit changes to the challenge records. Don't add `/domain/zone/*`.

4. Click **Create keys**. Save all three values in your password manager.
5. Fill the ignored `terraform/bootstrap/truenas/gen8/gen8.local.auto.tfvars` from its example. Restrict access to that file to its owner. In `acme_ovh_credentials`, set:
   - `application_key` to the application key (AK).
   - `application_secret` to the application secret (AS).
   - `consumer_key` to the consumer key (CK).
6. Set `acme.ovh_endpoint` to `ovh-eu` for Europe or `ovh-ca` for Canada. Review the Let's Encrypt terms before setting `acme.accept_terms = true`.

Keep `acme.name_prefix` at its neutral default or set a site label in the local file. The prefix names TrueNAS objects. It doesn't change the DNS names.

Leave `acme.dns_authenticator_id` unset for managed OVH. To change authenticators after issuance, plan a separate certificate migration. The provider treats certificate DNS mappings as immutable.

## Choose certificate entries

Each `acme_certificates` entry has a stable `name` and a DNS `common_name`. OpenTofu includes the common name in the certificate's Subject Alternative Names (SANs). Use `san` only for additional names. To share a certificate, use one entry:

```hcl
acme_certificates = [
  { name = "shared", common_name = "nas.example.net", san = ["*.apps.example.net"] },
]
```

To use separate keys, give the administration and application certificates separate entries:

```hcl
acme_certificates = [
  { name = "admin", common_name = "nas.example.net" },
  { name = "apps", common_name = "*.apps.example.net" },
]
```

## Issue before changing any bindings

Use the existing bootstrap administrator key. Don't grant certificate or network management roles to `terraform-prov`. If you need to test DNS first, use separate temporary certificates against the [Let's Encrypt staging service](https://letsencrypt.org/docs/staging-environment/). Don't assign those certificates to consumers.

1. Set `acme_enabled = true`. Leave the current administration selector unchanged or unset for a first install.
2. Run `task tf:truenas-gen8-bootstrap-plan`. Expect one signing request and one certificate per new entry. Expect a new OVH authenticator only if the bootstrap needs to create it. Stop if the plan changes the pool, accounts, services, or administration binding.
3. After approval, run `task tf:truenas-gen8-bootstrap-apply`. Review the fresh plan before confirming.
4. In TrueNAS, verify each new certificate's names and expiry. Check that the challenge records were cleaned up.

Read only the certificate ID map. The bootstrap also has a sensitive provisioning key output. For example, select the ID for `shared`:

```sh
task tf:truenas-gen8-bootstrap-output -- -json acme_certificate_ids | jq -er '.shared'
```

## Switch RustFS

If RustFS is enabled, select a certificate that covers its HTTPS name.

1. Record the previous certificate ID and HTTPS endpoint for RustFS.
2. Set `rustfs_app_certificate_id` to the selected ID in the storage root's local input file.
3. Run `task tf:truenas-gen8-plan`. Stop unless the plan only changes the intended RustFS configuration. After approval, run `task tf:truenas-gen8-apply`.
4. Verify the certificate chain and name on the RustFS HTTPS port. If you use a proxy, verify a signed S3 request through it as well. If the endpoint changes, update `rustfs_endpoint`. Keep TLS verification on.
5. Verify RustFS health. If RustFS fails, restore its previous certificate ID and matching client endpoint. Preview and obtain approval before applying that rollback.

The storage root needs only certificate IDs. Read the named output rather than the whole bootstrap state. Don't use a certificate data source for this handoff. It can store the certificate's private key in the storage root's state if TrueNAS returns it.

## Switch administration separately

1. Record the current administration certificate ID, hostname, and trust settings. Confirm local console access before the restart.
2. Confirm that the same `truenas_host` hostname matches both the current and issued certificates. If the old name differs, arrange a separate operator-led cutover through the [TrueNAS interface](https://www.truenas.com/docs/scale/credentials/certificates/settingupletsencryptcertificates/#set-the-gui-ssl-certificate).
3. If `truenas_ca_cert` is set, use a local bundle that trusts both chains. The provider uses this bundle **instead of** the system trust store. A trust bundle can't fix a hostname mismatch.
4. Set `acme_admin_certificate_name` to the selected entry's name. The certificate must include the exact management hostname. Run `task tf:truenas-gen8-bootstrap-plan` and verify that only the administration certificate assignment changes. After approval, apply the fresh plan. This restarts the web server and closes open sessions.
5. Verify the new chain and login over HTTPS. Check that both OpenTofu roots can connect with verified TLS before removing transitional trust settings.

If the apply reports a reconnect failure, inspect the active certificate before retrying. The restart may have succeeded. Restore the old ID through the verified interface or the prepared console recovery path if access fails. Set `acme_admin_certificate_name` back to the old entry if the bootstrap manages it. Otherwise set the selector to `null` to leave the binding unmanaged. Clearing the selector by itself **doesn't** restore the old certificate.

## Retire superseded certificates

Keep the old entries until you verify the new certificate on every consumer. Removing an entry alone is blocked by destruction protection. Review a separate retirement plan for the unused signing requests and certificates. Keep the active entries and authenticator protected.

## Verify renewal and rotate credentials

- Record the certificate IDs, served fingerprints, and expiry dates. After renewal, confirm the IDs are unchanged and each endpoint presents the new certificate.
- If the stored certificate renewed but a consumer still serves the old one, inspect the TrueNAS restart or redeploy job. Get approval before restarting that consumer.
- Verify delivery of TrueNAS certificate expiry notices. Monitor the served certificates rather than relying on the certificate records alone.
- To rotate the OVH credential, replace all three credential inputs and increment `acme_ovh_credentials_version`. Review the plan for an authenticator update only. Retain the old credential until the new one works.
- Renewal doesn't rotate the TLS keys. To replace a key or change names, issue a parallel certificate under a new name. Switch consumers before retiring the previous one.

Don't turn off `acme_enabled` to roll back a binding. The bootstrap protects the authenticator, signing requests, and certificates from destruction.
