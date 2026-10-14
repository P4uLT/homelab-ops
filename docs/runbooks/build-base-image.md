# Build and qualify the golden images

The build tasks are operational, but the pinned `proxmox-lxc` plugin hasn't
passed the proposed release-safety qualification. Get owner approval before
node contact. Treat the limits below as accepted build risks.

Use the [Packer reference](../../packer/README.md) for the layout,
image contents, and local checks.

## 1. Review the plugin limits

The current plugin doesn't enforce all these controls:

- Verify the actual parent digest before container creation.
  Protect the verified bytes against substitution during consumption.
- Refuse existing unowned containers, including concurrent claims.
  Restrict cleanup to resources created by the invocation.
- Select only the dump produced by this invocation.
- Reject unknown or changed SSH host keys on both connection paths.
- Publish a complete archive atomically on the actual NAS storage.
  Reject destination collisions without changing existing bytes.

A normal build may proceed after owner approval, but don't describe these
controls as implemented. Record the selected binary's path, digest, and
version with qualification evidence. A local binary carrying the upstream
version label isn't upstream-release evidence.

The current Ansible image connection enables host-key auto-add for paramiko.
Preverify its key as described in [Pin a host key](pin-host-keys.md).
Plugin hardening and its Go tests remain separate work.

## 2. Approve the live scope

Get owner approval for each build and qualification scope.
Record the PVE node, scratch identifiers, storage, test network,
failure injection, and cleanup limits.
Exclude production workloads and retained archives.

The compatibility build identifiers are `900` for base and `901` for
Docker. They don't authorize container reuse.
On failure, stop and prove resource ownership before approved cleanup.
Don't resume an unowned container.

Before node contact, check the local play targets:

```sh
task ansible:playbook -- -i inventory/builders playbooks/image.yml --list-hosts --limit builder-base
task ansible:playbook -- -i inventory/builders playbooks/image.yml --list-hosts --limit builder-docker
```

Expect only `builder-base` or `builder-docker`, respectively.
The inventory needs the local age key. Don't log decrypted variables.
Use a pseudo-terminal if Ansible requires one.

## 3. Select inputs

1. Use the public `packer/hosts/jarvis.pkrvars.hcl` for storage and bridge facts.
2. Create `packer/hosts/jarvis.local.pkrvars.hcl`, mode 600.
   Keep its connection values private.
3. Supply `pve_ssh_host`, `pve_ssh_user`, and an absolute `pve_ssh_key_path`.
   A protected key or loaded agent must work on both qualified connection paths.
   A password-only plugin connection doesn't establish Ansible access.
4. Select the exact Debian 13 vendor parent basename for base.
   Obtain its digest from trusted vendor evidence and verify the stored bytes.
   A checksum computed from an untrusted download alone doesn't establish trust.
5. For Docker, select an already qualified base archive and its retained digest.
   Keep the full parent basename, including its build ID.

Keep parent and output archives on the node's configured artifact storage.
Don't infer a child product ID from its parent filename.

## 4. Check the local configuration

Run `task verify`. Review `git status --short` before a build.
Confirm that the selected recipe contains the intended exact parent basename.
The repository doesn't enforce a clean source tree for builds.

Don't add automatic `.auto.pkrvars.hcl` or `.auto.pkrvars.json` files to the
loaded Packer directories. Clear unintended `PKR_VAR_*` overrides.
Extra arguments after `--` reach `packer build`, so review them before use.

## 5. Run an approved build

Build one selected recipe:

```sh
task packer:build RECIPE=debian-13/lxc/base HOST=jarvis
```

During development, build every discovered LXC recipe on one node:

```sh
task packer:build-all HOST=jarvis
```

`build-all` sorts recipes by selector and stops on the first failure.
Each recipe gets a new immutable build ID and private native manifest.
Extra arguments after `--` reach each `packer build` invocation.

The parent comes from each selected recipe file.
The batch command doesn't change a later recipe's committed parent.
Update `docker.pkrvars.hcl` deliberately before Docker consumes a newer base.
After an approved build, retain `packer/manifests/<build-id>/packer.json`.

## 6. Qualify the candidate archive

Don't adopt the candidate until every check passes.

1. Verify that the published archive is complete and readable.
   Compute its digest from the published bytes, not a temporary dump.
   Save it beside `packer.json`:

   ```sh
   sha256sum -- "$ARCHIVE_PATH" > "$EVIDENCE/archive.sha256"
   ```

   Set both paths from the approved private storage scope.
2. Inspect the sealed archive before booting clones.
   Check that `/etc/machine-id` is empty and `/etc/ssh/ssh_host_*` is absent.
   Check that `/var/lib/apt/lists/` has no package lists.
   Check for temporary connection files and private keys.
   First-boot state isn't a substitute for archive inspection.
3. Create and start two approved throwaway clones from the exact archive.
   Use separate approved identifiers and network settings.
   Record both identifiers against the archive digest.
4. In each clone, compare `/etc/image-build-info` with the manifest.
   Require the exact image ID, build ID, and parent volume identifier.
5. Verify Debian 13 and `amd64` with `/etc/os-release` and
   `dpkg --print-architecture`.
   Check the workload interface's expected address, routes, and name resolution.
6. Verify fleet-account login using a preverified clone host key.
   Check the expected sudo policy and `passwd -S root`.
   Require the root password to remain locked.
7. Compare both clones' machine IDs and SSH host-key fingerprints.
   Require distinct, nonempty identities.
8. For Docker, run `docker version`, `docker buildx version`, and
   `docker compose version`.
   Require `docker info --format '{{.LoggingDriver}}'` to report `journald`.
9. Run an owner-approved, preloaded Docker test image with bounded resources:

   ```sh
   docker run --rm --pull=never --network none --memory 64m --cpus 0.25 "$TEST_IMAGE"
   ```

   Record its expected result and exit code.
10. Stop and remove only the approved clones whose ownership is proven.
    Leave failed candidates unqualified.

## 7. Retain evidence and select releases

Record every check in private `qualification.md`, beside the checksum and
native manifest. Include:

- Archive name, build ID, output digest, and parent reference/digest.
- Source revision and the actual tool/plugin binary identity.
- Clone identifiers, check results, and qualified or failed outcome.
- The approved durable evidence location.

Copy that evidence to an owner-approved private durable location with the
retained archives. An ignored workstation directory isn't a recovery copy.
Review manifests and logs for private connection data before sharing them.

Retain N and N−1 for each image kind, product, and architecture.
N−1 is the previous selected qualified release.
Failed builds and failed qualifications don't change the pair.
A first qualified release has no qualified predecessor yet.
Repeat approved builds and qualification with fresh build IDs to establish
both versions. Retain referenced older archives and required parents too.
This procedure doesn't prune archives.

Terraform selects the exact immutable `template` string.
Changing it can replace an LXC workload.
Don't change or apply production pins during image qualification.

Image selection doesn't restore application data.
Application backups, data-volume lifecycle, schema compatibility, and
restoration need a separate recovery procedure.

## Next steps

- [Provision an LXC workload](provision-pve-ct.md): explicit Terraform selection.
- [Add a Proxmox VE node](onboard-pve.md): node onboarding.
- [Override the installed plugin](override-packer-plugin.md): development validation only.
