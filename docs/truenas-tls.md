# TLS for TrueNAS administration and applications

TrueNAS can serve publicly trusted certificates on a private network. Use public DNS to prove control of the names. Use private DNS to send clients to the NAS. These jobs don't require the same DNS records.

## Example naming scheme

| Use | Certificate name in DNS | Client address |
| --- | --- | --- |
| Administration | `nas.example.net` | `https://nas.example.net` |
| Applications | `*.apps.example.net` | `s3.apps.example.net`, over HTTPS on the configured port |

`example.net` is a reserved example domain. The wildcard covers one label, such as `s3.apps.example.net`. It doesn't cover `apps.example.net` or `bucket.s3.apps.example.net`.

Use one certificate with both names or issue separate certificates. A shared certificate uses the same private key and renews both names together. Separate certificates keep the administration key out of the applications.

## Issuance and access follow different paths

For [DNS-01 validation](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge), TrueNAS uses the DNS provider's API to publish temporary records. In this example, the challenge names are `_acme-challenge.nas.example.net` and `_acme-challenge.apps.example.net`. Let's Encrypt reads the records from public DNS. The NAS needs outbound access, but no public address record or inbound port. Certificate names appear in public certificate transparency logs.

For direct access, private DNS resolves the service name to the NAS. Clients still use the published port. For proxied access, use a name that resolves to the proxy. A proxy that terminates TLS needs its own certificate. A certificate doesn't make a service reachable or replace authentication.

## Bootstrap owns certificates, applications consume IDs

The privileged OpenTofu bootstrap issues certificates from the named list and can bind one to the web interface. An application receives only its selected numeric certificate ID. It doesn't need the OVH credential or access to the bootstrap state.

Names displayed in TrueNAS are separate from DNS names. The optional `acme.name_prefix` defaults to `truenas`. For example, `truenas-admin-csr` names a signing request in TrueNAS but isn't a hostname. Use a local override if you need a different label.

TrueNAS renews each certificate in place. Applications keep the same ID on normal renewal. Check the certificate each endpoint serves after renewal, since a failed reload can leave an old certificate in use.

Certificate issuance needs a TrueNAS DNS authenticator ID, not a provider name. For a preconfigured authenticator, set `acme.dns_authenticator_id` and omit the OVH endpoint and credentials. TrueNAS still needs a working credential for that authenticator.

This repository's deployment creates the authenticator for OVH. See [Issue TrueNAS certificates on the Gen8](runbooks/truenas-acme-ovh.md).
