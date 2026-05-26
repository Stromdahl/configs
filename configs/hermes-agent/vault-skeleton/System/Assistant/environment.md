# Assistant — Environment & Technical Setup

Hardware, tools, quirks, and gotchas. Read when troubleshooting or
configuring.

---

## Hardware
- Host: titan-hermes-agent (Debian 13 VM on Proxmox host `titan`, VMID 101)
- Primary workstation: krypton (laptop)

## Services
- Key services, ports, endpoints
- API base URLs

## Key paths

| Resource    | Path                                              |
|-------------|---------------------------------------------------|
| Vault       | `$HOME/hermes-vault/`                             |
| Daily notes | `$HOME/hermes-vault/Daily/YYYY-MM-DD.md`          |
| Hot memory  | `$HOME/.hermes/memories/MEMORY.md`, `USER.md`     |
| Env file    | `$HOME/.hermes/.env`                              |

## Sync
- Vault is a Syncthing folder. Other devices (e.g. krypton) get a
  replicated copy and can edit notes with any markdown editor.
- `~/.hermes/memories/` is **not** synced — hot memory stays local to
  this host.

## Known issues & patterns
- Document recurring problems and their fixes here.

---

*Last updated: YYYY-MM-DD*
