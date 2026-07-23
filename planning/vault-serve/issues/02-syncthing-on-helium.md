# Decide the Syncthing-on-helium approach & full-vault security posture

Type: grilling
Status: open
Blocked by: —

## Question

How should the vault land on helium via Syncthing, and is the resulting posture
acceptable? Resolve:

- **Deploy method:** a reusable dotfiles/ansible Syncthing setup (matches
  helium's IaC) vs a one-off manual pairing. Where does the vault live (which
  user's home, which path) and with what filesystem ownership/permissions?
- **Security posture:** confirm the full vault (incl. finance/health/people/
  journal) physically resting on helium — a LAN-reachable, household-accessible
  box — is acceptable, and decide any disk-level hardening (perms, dedicated
  user) beyond the serve-layer allowlist.
- **Sync-halt gotcha:** how to avoid the `.stfolder` deletion silent-halt failure
  mode (see `project_hermes_vault_sync`); which peer is authoritative on first
  reconcile.

The actual install/pairing is execution that follows this decision — this ticket
settles the approach, not the doing.
