# Issue TrueNAS certificates on the Gen8

Use this runbook after applying the [base Gen8 bootstrap](bootstrap-truenas.md). On a fresh NAS, bootstrap storage and provisioning access with certificate issuance disabled.

This procedure uses OVH DNS and Let's Encrypt. For design and sample names, see [TLS for TrueNAS administration and applications](../truenas-tls.md).

Get owner approval before any live plan, apply, DNS operation, or endpoint check. Approve application redeployments and the administration restart separately.

## Prepare DNS and credentials

1. Choose an administration name and an application domain in your OVH-managed public DNS zone. Set `acme.admin_hostname` and `acme.apps_domain` in the bootstrap's local input file.
2. Resolve each service name through private DNS. Check that each application name fits the wildcard before switching it.
3. Check the public authority for both challenges. Check certification authority authorization (`CAA`) records if present.

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

## Issue before changing any bindings

Use the existing bootstrap administrator key. Don't grant certificate or network management roles to `terraform-prov`. If you need to test DNS first, use separate temporary certificates against the [Let's Encrypt staging service](https://letsencrypt.org/docs/staging-environment/). Don't assign those certificates to consumers.

1. Set `acme_enabled = true` and leave `acme_assign_admin = false`.
2. Run `task tf:truenas-gen8-bootstrap-plan`. Expect one OVH authenticator, two signing requests, and two issued certificates. Stop if the plan changes the pool, accounts, services, or administration binding.
3. After approval, run `task tf:truenas-gen8-bootstrap-apply`. Review the fresh plan before confirming.
4. In TrueNAS, verify both certificates, their names, and their expiry. Compare the public keys to confirm they differ. Check that the challenge records were cleaned up.

Read only the named numeric IDs. The bootstrap also has a sensitive provisioning key output.

```sh
task tf:truenas-gen8-bootstrap-output -- -raw acme_admin_certificate_id
task tf:truenas-gen8-bootstrap-output -- -raw acme_apps_certificate_id
```

## Switch RustFS

If RustFS is enabled, switch it to the wildcard certificate.

1. Record the previous certificate ID and HTTPS endpoint for RustFS.
2. Set `rustfs_app_certificate_id` to the wildcard ID in the storage root's local input file.
3. Run `task tf:truenas-gen8-plan`. Stop unless the plan only changes the intended RustFS configuration. After approval, run `task tf:truenas-gen8-apply`.
4. Verify the certificate chain and name on the RustFS HTTPS port. If the name changes, update `rustfs_endpoint`. Keep TLS verification on.
5. Verify RustFS health. If RustFS fails, restore its previous certificate ID and matching client endpoint. Preview and obtain approval before applying that rollback.

The storage root needs only certificate IDs. Don't add a certificate data source or read the whole bootstrap state for this handoff.

## Switch administration separately

1. Record the current administration certificate ID, hostname, and trust settings. Confirm local console access before the restart.
2. Confirm that the same `truenas_host` hostname matches both the current and issued certificates. If the old name differs, arrange a separate operator-led cutover through the [TrueNAS interface](https://www.truenas.com/docs/scale/credentials/certificates/settingupletsencryptcertificates/#set-the-gui-ssl-certificate).
3. If `truenas_ca_cert` is set, use a local bundle that trusts both chains. The provider uses this bundle **instead of** the system trust store. A trust bundle can't fix a hostname mismatch.
4. Set `acme_assign_admin = true`. Run `task tf:truenas-gen8-bootstrap-plan` and verify that only the administration certificate assignment changes. After approval, apply the fresh plan. This restarts the web server and closes open sessions.
5. Verify the new chain and login over HTTPS. Check that both OpenTofu roots can connect with verified TLS before removing transitional trust settings.

If the apply reports a reconnect failure, inspect the active certificate before retrying. The restart may have succeeded. Restore the old ID through the verified interface or the prepared console recovery path if access fails. Set `acme_assign_admin = false` to stop managing the binding before the next bootstrap apply. Turning the flag off by itself **doesn't** restore the old certificate.

## Verify renewal and rotate credentials

- Record the certificate IDs, served fingerprints, and expiry dates. After renewal, confirm the IDs are unchanged and each endpoint presents the new certificate.
- If the stored certificate renewed but a consumer still serves the old one, inspect the TrueNAS restart or redeploy job. Get approval before restarting that consumer.
- Verify delivery of TrueNAS certificate expiry notices. Monitor the served certificates rather than relying on the certificate records alone.
- To rotate the OVH credential, replace all three credential inputs and increment `acme_ovh_credentials_version`. Review the plan for an authenticator update only. Retain the old credential until the new one works.
- Renewal doesn't rotate the TLS keys. To replace a key or change names, issue a parallel certificate under a new name. Switch consumers before retiring the previous one.

Don't turn off `acme_enabled` to roll back a binding. The bootstrap protects the authenticator, signing requests, and certificates from destruction.
