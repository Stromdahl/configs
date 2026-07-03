# Ansible — fleet control layer

A multi-host Ansible control layer, grown from the helium pilot. The rest of the
fleet (krypton, argon, the PVE hosts) stays on the custom dotfiles bash modules;
this tree is the path off them. Two inventory groups, each with its own play in
`site.yml`:

- **`nas`** — private NAS/services hosts (helium): base + docker + storage +
  compose stack + restic backup.
- **`edge`** — public-facing hosts: base + docker only. Empty until radon joins
  it (issue 022); its public `edge_stack` role arrives in issue 024.

Playbooks are **pushed from krypton over SSH** as each host's admin user. Managed
hosts hold no GitHub key, no deploy key, and no age key — they never run the
dotfiles installer and never decrypt their own secrets.

## Layout

```
ansible.cfg                       control config (inventory, sops vars plugin)
requirements.yml                  galaxy collections + roles
inventory/hosts.yml               nas (helium) + edge (empty) groups
group_vars/all.yml                fleet-wide vars (timezone, shared docker opts)
group_vars/edge.yml               edge-group placeholder (radon vars land in host_vars)
host_vars/helium/vars.yml         helium-specific vars (storage, compose stack)
host_vars/helium/secrets.sops.yml sops-encrypted vars (ansible_become_password)
site.yml                          one play per group: nas (full) + edge (base+docker)
roles/base/                       host-agnostic hardening (ssh/ufw/fail2ban/uu)
```

## Secrets (sops + age)

Encrypted vars are decrypted **on krypton at run-time** by the
`community.sops.sops` vars plugin, using the admin age key at
`~/.config/sops/age/keys.txt`. Decrypted values are passed to the connection in
memory — they never land on the target. The `.sops.yaml` creation rule for
`ansible/host_vars/**.sops.yml` lists the **admin key only** (helium has no
per-host key), so only an admin workstation can decrypt.

The sudo/become password is the foundation's demonstrator secret. Create it
without printing the password to the terminal:

```sh
cd ansible
sops --input-type yaml --output-type yaml \
     -e /dev/stdin > host_vars/helium/secrets.sops.yml <<'EOF'
ansible_become_password: <the sudo password set during the Debian install>
EOF
# or edit interactively (opens $EDITOR, encrypts on save):
#   sops host_vars/helium/secrets.sops.yml
```

## First run

```sh
cd ansible
ansible-galaxy collection install -r requirements.yml -p galaxy/collections
ansible-galaxy role install -r requirements.yml -p galaxy/roles
ansible-playbook site.yml
```

A second run must report **no changes** (idempotent). Useful checks:

```sh
ansible-playbook site.yml --syntax-check
ansible-inventory --list
ansible nas -m ping
```

> **Prerequisite:** helium needs a **pinned DHCP reservation** (keyed to its NIC
> MAC) so `ansible_host` stays stable. This is a one-time manual router step.
