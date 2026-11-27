"""Exercise Terraform task wrappers with a fake CLI and synthetic secrets."""

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOTS = {
    "ovh-bootstrap": ("bootstrap/ovh", "ovh"),
    "pve-jarvis-bootstrap": ("bootstrap/pve/jarvis", "jarvis"),
    "proxmox-jarvis": ("proxmox/jarvis", "jarvis"),
    "truenas-gen8-bootstrap": ("bootstrap/truenas/gen8", "gen8"),
    "truenas-gen8": ("truenas/gen8", "gen8"),
    "rustfs-gen8": ("rustfs/gen8", "gen8"),
}

ALIASES = {
    "bootstrap": "ovh-bootstrap",
    "pve-jarvis": "pve-jarvis-bootstrap",
    "jarvis": "proxmox-jarvis",
}


class TerraformTasks(unittest.TestCase):
    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory(prefix="tf-task-contract-")
        self.addCleanup(self.workspace.cleanup)
        self.root = Path(self.workspace.name)
        (self.root / ".taskfiles").mkdir()
        source = Path(__file__).resolve().parents[1] / ".taskfiles/tf.yml"
        shutil.copyfile(source, self.root / ".taskfiles/tf.yml")
        (self.root / "Taskfile.yml").write_text(
            'version: "3"\nincludes:\n  tf: .taskfiles/tf.yml\n', encoding="utf-8"
        )
        (self.root / ".env.tf").write_text(
            "TF_VAR_state_passphrase=fixture-passphrase\n"
            "OVH_CLOUD_PROJECT_SERVICE=fixture-project\n", encoding="utf-8"
        )
        (self.root / ".env.account.ovh.tf").write_text(
            "OVH_APPLICATION_KEY=fixture-account\n", encoding="utf-8"
        )
        for directory, name in ROOTS.values():
            path = self.root / "terraform" / directory
            path.mkdir(parents=True)
            (path / f"{name}.local.auto.tfvars").write_text("# fixture\n", encoding="utf-8")
        binary = self.root / "bin"
        binary.mkdir()
        fake = binary / "tofu"
        fake.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, sys\n"
            "from pathlib import Path\n"
            "keys = ['TF_VAR_state_passphrase', 'TF_VAR_project_id', "
            "'OVH_APPLICATION_KEY', 'RUSTFS_ENDPOINT', 'RUSTFS_USER', 'RUSTFS_SECRET']\n"
            "Path(os.environ['TF_TASK_RECORD']).write_text(json.dumps({"
            "'args': sys.argv[1:], 'env': {k: os.environ.get(k) for k in keys}}))\n",
            encoding="utf-8",
        )
        fake.chmod(0o755)
        self.record = self.root / "call.json"
        self.env = dict(os.environ)
        for key in list(self.env):
            if key.startswith(("TF_VAR_", "OVH_", "TASK_", "RUSTFS_")):
                self.env.pop(key)
        self.env.update(
            PATH=f"{binary}{os.pathsep}{os.environ['PATH']}",
            TF_TASK_RECORD=str(self.record),
            RUSTFS_ENDPOINT="ambient-endpoint",
            RUSTFS_USER="ambient-user",
            RUSTFS_SECRET=os.urandom(16).hex(),
        )

    def invoke(self, task, args=(), success=True):
        self.record.unlink(missing_ok=True)
        result = subprocess.run(
            ["task", "--silent", "--dir", str(self.root), f"tf:{task}", "--", *args],
            env=self.env, text=True, capture_output=True, check=False,
        )
        if not success:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertFalse(self.record.exists(), "A rejected task must not invoke tofu")
            return {}
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self.record.exists(), result.stdout + result.stderr)
        return json.loads(self.record.read_text(encoding="utf-8"))

    def test_every_root_exposes_the_same_cli_contract(self):
        for scope, (directory, _) in ROOTS.items():
            for action, args in (
                ("plan", ("-out=review file;draft.tfplan",)),
                ("apply", ("review file.tfplan",)),
                ("output", ("-json",)),
            ):
                with self.subTest(scope=scope, action=action):
                    call = self.invoke(f"{scope}-{action}", args)
                    expected = [f"-chdir=terraform/{directory}", action]
                    if action != "output":
                        expected.append("-input=false")
                    self.assertEqual(call["args"], expected + list(args))
                    self.assertEqual(call["env"]["TF_VAR_state_passphrase"], "fixture-passphrase")
                    if scope == "ovh-bootstrap":
                        self.assertEqual(call["env"]["OVH_APPLICATION_KEY"], "fixture-account")
                        self.assertEqual(call["env"]["TF_VAR_project_id"], "fixture-project")
                    else:
                        self.assertIsNone(call["env"]["OVH_APPLICATION_KEY"])
                    if scope == "rustfs-gen8":
                        for key in ("RUSTFS_ENDPOINT", "RUSTFS_USER", "RUSTFS_SECRET"):
                            self.assertIsNone(call["env"][key])

    def test_legacy_aliases_keep_the_same_behavior(self):
        for old, new in ALIASES.items():
            for action in ("plan", "apply", "output"):
                with self.subTest(old=old, action=action):
                    canonical = self.invoke(f"{new}-{action}", ("-no-color",))
                    self.assertEqual(self.invoke(f"{old}-{action}", ("-no-color",)), canonical)
        canonical = self.invoke("ovh-bootstrap-state-list")
        self.assertEqual(self.invoke("bootstrap-state-list"), canonical)
        self.assertIsNone(canonical["env"]["OVH_APPLICATION_KEY"])

    def test_plan_and_apply_require_root_credentials(self):
        for scope, (directory, name) in ROOTS.items():
            (self.root / "terraform" / directory / f"{name}.local.auto.tfvars").unlink()
            for action in ("plan", "apply"):
                with self.subTest(scope=scope, action=action):
                    self.invoke(f"{scope}-{action}", success=False)
            self.invoke(f"{scope}-output", ("-json",))

    def test_every_root_requires_shared_environment(self):
        (self.root / ".env.tf").unlink()
        for scope in ROOTS:
            with self.subTest(scope=scope):
                self.invoke(f"{scope}-output", success=False)

    def test_only_ovh_bootstrap_requires_the_account_file(self):
        (self.root / ".env.account.ovh.tf").unlink()
        for scope in ROOTS:
            with self.subTest(scope=scope):
                self.invoke(f"{scope}-output", success=scope != "ovh-bootstrap")
        self.invoke("ovh-bootstrap-state-list")


if __name__ == "__main__":
    unittest.main()
