# servers/unifi — agent notes

## The network

Sensative office network, one UniFi site ("Default") behind a **UDM Pro SE**
("Sensative AB") at `10.0.0.1` (LAN) / `89.255.244.242` (WAN). Full topology,
VLANs, Wi-Fi, and firewall/ACL detail live in the **separate**
`~/sensative/Sensative-Network` repo's `network-topology.md` — that's the
docs deliverable; this file is CLI/API operational notes.

## `unifi` CLI — use this first

`bin/unifi` (symlink → `bin/unifi-cli/unifi.ts`, then symlinked to
`~/.local/bin/unifi` by the `base` module) wraps the UniFi Network
**Integration API** (`developer.ui.com/network`, `X-API-KEY` auth) — the
same official REST API `ha` wraps for Home Assistant, same layered structure
(`transport.ts` → `api.ts` → `commands/*.ts`), same strict tsconfig +
typescript-eslint (complexity cap 8). Run `unifi --help` for the full verb
reference — it's also the `USAGE` constant in `bin/unifi-cli/unifi.ts`. Node
22+ runs the `.ts` file natively; `npm --prefix bin/unifi-cli run check` to
typecheck + lint.

**Auth:** `~/.unifi-token.json`, shape `{apiKey, baseUrl?, siteId?}`. Mint the
key in UniFi OS → Settings → Control Plane → Integrations. `baseUrl` defaults
to `https://10.0.0.1`; `siteId` for this site is
`88f7af54-98f8-306a-a1c7-c9349722b1f6` (there is only one site on this
controller — `unifi site list` re-derives it if the token file is rebuilt).
`UNIFI_BASE` / `UNIFI_SITE` env vars override either, mirroring `ha`'s
`HA_BASE`.

**The API surface is uniformly RESTful** (`GET/POST /v1/sites/{siteId}/<coll>`,
`GET/PUT/DELETE .../<coll>/{id}`, all list endpoints paginated at
`limit<=200`) — `api.ts` is a table of one-liners over generic transport
helpers rather than 300 hand-transcribed schemas. `transport.ts`'s `listAll()`
loops pages until `offset+count >= totalCount`; nothing truncates silently at
25 rows (the API's default page size) the way a naive single-page fetch would.

Three sharp edges worth knowing before touching this CLI again:

- **The controller's TLS cert is self-signed and CNs to the UDM's own
  hostname, never `10.0.0.1`** — so `NODE_EXTRA_CA_CERTS` still fails
  hostname verification even if you trusted the CA. `transport.ts` uses a
  scoped `https.Agent({rejectUnauthorized: false})` via Node's built-in
  `node:https`, not global fetch. **Do not switch this to `fetch` +
  undici's `Agent`/`dispatcher`** — Node 22 bundles undici 6.x internally,
  and passing a dispatcher built from the npm `undici@8.x` package (what
  `npm install undici` gives you today) throws `invalid onRequestStart
  method` from an internal version mismatch. Pinning `undici@6.22.0` (Node
  22.21's exact bundled version) does work if `node:https` ever needs
  replacing — but that pin breaks the moment Node's bundled version moves,
  which `node:https` never will. This is why the tool has zero runtime
  dependencies, matching `ha-cli`.
- **`PUT` replaces the whole resource, it does not merge.**
  `unifi network update <id> '{"name":"x"}'` would wipe DHCP config on
  whichever network you pointed it at if that's literally all you pass — the
  command's own usage text says so, but there is no client-side merge
  safety net. `unifi network refs <id>` (GET `.../networks/{id}/references`)
  is the pre-delete/pre-edit check the API hands you for free; use it.
- **`unifi device restart` / `unifi device cycle-port` require `--yes`.**
  Restarting the gateway device (`af536149-4191-31cd-b0e6-761bf7bd29e7`,
  "Sensative AB") drops the whole office's internet for the reboot. This is
  the one write path in the tool with a confirmation gate built in — other
  writes (network/wifi/firewall/acl CRUD) don't gate, because they're
  scoped edits, not "take down shared infrastructure" actions.

**Zone-based firewall is not enabled on this site** — every
`unifi firewall zone|policy ...` call answers `HTTP 400
api.firewall.zone-based-firewall-not-configured`, not an empty list. This
site still uses the legacy per-network rule model, which the Integration API
exposes as `unifi acl ...` (currently empty — no ACL rules configured either).

**DNS policies has live data** (`unifi dns list`) — local A-records under
`*.sensative.infra`, not something to delete/edit without checking what
resolves through it first.

### Where things live

- `unifi.ts` — entry point + USAGE + dispatcher (mirrors `ha.ts`).
- `transport.ts` — `X-API-KEY` auth, the self-signed-cert `https.Agent`,
  pagination loop.
- `api.ts` — one named function per endpoint, each a one-line wrapper over
  generic `list/getOne/create/update/patchOne/remove` helpers.
- `commands/*.ts` — one file per resource group (`device`, `client`,
  `network`, `wan`, `wifi`, `firewall`, `acl`, `dns`, `tml` [traffic-matching
  lists], `voucher`, `vpn`, `switching`, `misc` [device-tags/radius/dpi/country]),
  plus `core.ts` for `site`/`info`/`raw`.
- `unifi raw <METHOD> <path> ['<json>']` — escape hatch for anything not
  wired as a verb yet; `path` accepts the shorthand `/sites/current/...` for
  the configured siteId (mirrors `ha ws` for HA).

### Credential hygiene

The API key currently in `~/.unifi-token.json` passed through a shell
transcript once during initial setup (2026-08-11, read from a `.env` in
`~/sensative/Sensative-Network` that a prior session used for raw `curl`
calls). If that transcript's exposure is a concern, rotate the key in
UniFi OS → Settings → Control Plane → Integrations and update the token
file — nothing else references the old value.
