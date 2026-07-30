# servers/home-assistant — agent notes

## Home Assistant

**Host:** `ha.home.stromdahl.tech` (HTTPS, via helium Traefik) / `192.168.1.99:8123` (LAN, HTTP). HAOS, version in `exports/` if exported. (The apex `home.stromdahl.tech` is the helium homepage dashboard, not HA.)

**SSH:** `root@192.168.1.99:22` (Terminal & SSH add-on, key already authorized). `/config/` is HA's config dir.

**Token:** `~/.ha-token.json` — shape `{headers:{Authorization:"Bearer ..."}}`. The user is admin; the token works for REST and WS. **Not for supervisor:** `/api/hassio/...` answers 401 to a long-lived token, so add-on management goes over SSH with HAOS's own `ha` CLI on the box (`ha apps info core_mosquitto`; `apps` is the current name, `addons` is deprecated but aliased). That CLI has no `options` subcommand — to set add-on options, POST to `http://supervisor/addons/<slug>/options` from the box with `$SUPERVISOR_TOKEN`, which the SSH add-on has in its environment.

### MQTT broker (Mosquitto add-on) — the metrics sink for issue 046

**Mosquitto add-on, `boot: auto`, on this box** — not a container in helium's stack, deliberately: helium going down then produces a clean MQTT last-will and HA flips its entities to `unavailable`, whereas a broker living on helium would die *with* helium and leave HA showing stale values with no signal.

Publishers authenticate as the add-on `logins` user **`helium`** (password `mqtt_password` in helium's `secrets.sops.yml`). A `logins` entry, not a Home Assistant user account, on purpose: it can only speak MQTT, whereas an HA account could also log in to the UI.

**This is the one piece of that slice Ansible does not manage** — the add-on install, its `logins` option and the MQTT config entry were set up by hand. If HA is ever rebuilt, redo those three things and both publishers reconnect on their own.

Two things that will bite:

- **Address the broker by IP (`192.168.1.99:1883`) from helium, never by name.** `*.home.stromdahl.tech` is a *wildcard* pointing at helium's own Traefik (192.168.1.191) — `ha.home.stromdahl.tech` reaches Traefik, which speaks only HTTP, so a hostname here fails in a confusing way.
- **A cleared retained discovery topic deletes the entity, but HA remembers its `entity_id`** and hands it back when the same `unique_id` reappears. So re-registering after a naming fix keeps the *old* ugly id; only changing the `unique_id` (for docker2mqtt, its topic prefix) mints a clean one. Use `ha entity remove` for one-off orphans.

To inspect or clear retained topics, run mosquitto clients on helium with the stack's env file so no password lands in a transcript:

```bash
ssh helium.home.stromdahl.tech 'sudo docker run --rm --env-file /opt/helium/.env eclipse-mosquitto:2 \
  sh -c "mosquitto_sub -h \$MQTT_BROKER_HOST -u \$MQTT_USERNAME -P \$MQTT_PASSWORD -t \"homeassistant/#\" -W 4 -v"'
```

**Clearing a retained discovery topic (publish an empty payload to it) is how you delete an MQTT entity** — that is the documented mechanism, not a hack.

#### Sweeping orphaned container entities

docker2mqtt **never reconciles retained discovery against reality on startup**: it expires only containers it personally watched being destroyed. So anything orphaned across its own restart — a one-off `docker run --rm`, or a service removed while it was down — leaves twelve dangling entities that persist indefinitely. Compose's transient `<12 hex>_<name>` recreate ghosts are filtered by its `CONTAINER_BLACKLIST`, but random one-off names cannot be.

Find them by diffing HA against reality, then clear those topics:

```bash
# containers HA thinks exist, vs containers that do
diff <(ha entities 'binary_sensor.helium_containers_*_state' | tail -n +2 \
        | sed 's/.*containers_//;s/_state.*//' | sort) \
     <(ssh helium.home.stromdahl.tech 'docker ps --format "{{.Names}}"' | tr '-' '_' | sort)
```

Anything only on the HA side is an orphan; feed those names to a `grep -E` over the retained `homeassistant/#` topics and publish an empty retained payload to each. **Two traps, both hit in practice:**

- **Entity ids are underscore-normalised; topics are not.** `binary_sensor.helium_containers_protonmail_bridge_state` comes from a container named `protonmail-bridge`, so grepping topics with the name lifted from the entity id silently matches nothing and reports a confident `cleared=N` for the other names. Convert back to hyphens, or match on a structural pattern instead — for compose recreate ghosts, `grep -E '[0-9a-f]{12}_'` over both `homeassistant/#` and `containers/#` catches every one regardless of separators.
- **The sweep container registers itself.** Any `docker run --rm` shows up as a container and mints its own twelve entities. Name it to match the blacklist — `--name 000000000000_mqtt_sweep` — and docker2mqtt ignores it entirely.

**HACS + card-mod installed.** Custom Lovelace cards via HACS UI (Settings → HACS).

### `ha` CLI — use this first

`bin/ha` (symlink → `bin/ha-cli/ha.ts`, then symlinked to `~/.local/bin/ha` by the `base` module) wraps the patterns. Always prefer it over hand-rolled scripts. Run `ha --help` (or `ha` with no args) for the full verb/flag/env reference; the same text is the `USAGE` constant in `bin/ha-cli/ha.ts`. The script lives in an isolated TypeScript Node project at `bin/ha-cli/` with strict tsconfig (`noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, etc.), typescript-eslint (cyclomatic complexity capped at 8), and a layered structure: `transport.ts` (get/post/del/wsCall) → `api.ts` (typed wrappers per endpoint) → `commands/*.ts` (CLI verbs). Node 22+ runs the `.ts` file natively via built-in type-stripping — no build step. Run `npm --prefix bin/ha-cli run check` to typecheck + lint.

```
ha state <entity>                       # GET /states/<entity> (slim: no last_*/context)
ha call domain.service '<json>'         # POST service call
ha template '<jinja>'                   # render Jinja
ha entities [pattern]                   # glob (e.g. 'sensor.*temp*') or /regex/
ha services [domain[.service]]          # introspect /api/services
ha dash list|get|save                   # lovelace WS API
ha auto list|get|save|delete            # /config/automation/config/<id> + reload
ha scene list|get|save|delete           # /config/scene/config/<id> + reload
ha entity list|get|update|remove|disable|enable  # config/entity_registry/* via WS
ha device list|update                   # config/device_registry/{list,update} via WS
ha area list|create|delete              # config/area_registry/{list,create,delete} via WS
ha helper list|create|delete            # input_*/{create,delete} via WS
ha flow <handler> ['<step1>' ['<step2>'…]] # drive multi-step config_entries flow → create_entry
                                        # with no steps: print the first step's schema, then abort
ha entry list [domain]|get|delete|reload|flows  # config_entries CRUD + in-progress flows
ha entry options <entry_id> ['<json>']  # drive an entry's options flow; no json = print schema
ha ws '<json>'                          # raw WS command, prints the result payload
```

**Global flags** (any position):
- `--pretty` — pretty-print JSON output. Default is compact single-line (smaller in transcripts).
- `--quiet` / `-q` — silence "saved" / "deleted" / "saved + reloaded" chatter on writes.
- `-o <key.path>` / `--output <key.path>` — extract a field from JSON output; print scalar if leaf is primitive. E.g. `ha state sensor.foo -o state` prints just the value; `ha flow … -o result` prints just the new entry_id.

`HA_BASE` env var overrides the host. Default `https://ha.home.stromdahl.tech`; set e.g. `HA_BASE=http://192.168.1.99:8123` from environments without public DNS (sandboxes, LAN-only hosts). `http://` switches WS to `ws://` automatically.

`ha flow` is the verb for config-flow-based integrations and helpers (history_stats, utility_meter, derivative, threshold, integration, switch_as_x, …). Each positional arg is one step's JSON, submitted in order. Example:

```
ha flow history_stats \
  '{"name":"Time at work today","entity_id":"person.mattias","type":"time"}' \
  '{"state":["Work Mattias"]}' \
  '{"start":"{{ today_at() }}","end":"{{ now() }}","state_class":"total_increasing"}'
```

**Run `ha flow <handler>` with no step payloads before writing one.** It starts the flow
only to print the first step's `data_schema`, then aborts it so nothing lingers in
`ha entry flows`. Two things this settles that guesswork gets wrong: whether the handler
exists at all (a non-core integration answers `HTTP 404: Invalid handler specified` — this
is how `prowlarr`, `jellyseerr`, `bazarr`, `traefik`, `cleanuparr` and `profilarr` were
found to have **no** core integration, contrary to reasonable assumption), and the exact
field names, which differ per integration — see the `sonarr` `more_options` section below.

`ha helper create input_*` still goes via WS (collection helpers); only config-flow helpers need `ha flow`. Manage the resulting config entries with `ha entry list <domain>` / `ha entry delete <entry_id>` / `ha entry reload <entry_id>`. Note: `options` (the per-entry config payload from a flow's `create_entry`) is not exposed by `entry get` — HA only surfaces it during an options flow.

### Where things live

- `configs/home-assistant/themes/sensative.yaml` — repo source for the Sensative theme; deployed copy is `/config/themes/sensative.yaml` on the host.
- `configs/home-assistant/template.yaml` — repo source for template entities (e.g. `vacuum.leonardo_smart`); deployed copy is `/config/template.yaml` on the host.
- `configs/home-assistant/recorder.yaml` — repo source for the recorder scope (issue 046: keeps docker2mqtt's per-container byte counters out of the database); deployed copy is `/config/recorder.yaml`, pulled in by a `recorder: !include recorder.yaml` line added to `/config/configuration.yaml`. Recorder options are **not reloadable** — changing this needs `ha core restart`, and `ha core check` first is worth the ten seconds.
- `servers/home-assistant/exports/` — version-controlled snapshots of dashboards / automations / helpers / entities. Diff-edit these instead of round-tripping over the network. Re-export with the loop in `bin/ha`'s recipes.
- `exports/dashboards/helium-stack.json` — the helium NAS dashboard (issue 046's follow-on). Its **Home** view is the replacement for `homepage.home.stromdahl.tech` (issue 018): it mirrors homepage's six service groups and every `href` in `ansible/roles/compose_stack/files/homepage/services.yaml`, with tap-to-open, container-liveness status dots, tier gauges, and live API data. Keep the two in sync — if a service is added to `services.yaml`, add it here too. Then three more views: Overview (host vitals, storage gauges, thermals, seven drives), Services (28 containers in six functional groups), Trends. Deploy with `ha dash save helium-stack <file>`. **The Services view is a hardcoded list of 28 containers, but the Overview hero counts them by scanning `binary_sensor.helium_containers_*_state`** — so adding a service to the stack needs a card added here by hand, and the tell that it was forgotten is the hero reading e.g. 29/29 while Services shows 28 cards. Nothing errors. Two further constraints any edit must respect: **graph cards may only reference recorded entities** — `configs/home-assistant/recorder.yaml` excludes `sensor.helium_containers_*_block_*` and `*_network_*`, so those render blank on a `mini-graph-card` despite having live states; and **liveness is `_state`, not `_health`** — eight containers declare no healthcheck and sit at `_health: unknown` forever, so `_health` is only good for an "unhealthy" badge (`on` = healthy, `off` = unhealthy).
- `/config/custom_components/hacs/` on host — HACS install (zip-extracted from `hacs/integration` releases).
- `/config/www/community/` on host — HACS-managed custom Lovelace JS lives here.

### REST vs WS — which for what

| Task                                  | API |
|---------------------------------------|-----|
| Read state, call service              | REST `/api/states`, `/api/services/...` |
| Render Jinja template                 | REST `POST /api/template` |
| Automations CRUD                      | REST `/api/config/automation/config/<id>` (`<id>` = the `attributes.id`, not the entity_id slug) |
| Scenes CRUD                           | REST `/api/config/scene/config/<id>` + `POST /api/services/scene/reload` |
| Lovelace dashboards                   | WS `lovelace/config`, `lovelace/config/save`, `lovelace/dashboards/{list,create,update,delete}` |
| Device registry (rename, reassign area) | WS `config/device_registry/{list,update}` |
| Area registry CRUD                    | WS `config/area_registry/{list,create,update,delete}` |
| Zones (storage-collection)            | WS `zone/{list,create,update,delete}` (note: `zone.home` is implicit from core lat/lng, not in the collection) |
| Helpers (input_*) CRUD                | WS `input_number/create`, `input_button/delete`, etc. |
| Template helpers (sensors, binary)    | REST config-flow at `/api/config/config_entries/flow` (handler=`template`, multi-step) |
| Entity registry (rename, disable, reassign area) | WS `config/entity_registry/{list,get,update,remove}` |
| Config entries (list/delete/reload)   | REST `/api/config/config_entries/entry[/<id>[/reload]]` — `entry/<id>` only supports `DELETE` |
| In-progress config flows              | WS `config_entries/flow/progress` |
| Service introspection                 | REST `GET /api/services` |
| Reload themes                         | REST `POST /api/services/frontend/reload_themes` |

Lovelace dashboard `url_path` **must contain a hyphen** (HA validation).

### Roborock / Leonardo gotchas

- Per-room cleaning: `vacuum.send_command` with `command: app_segment_clean` and `params: [<segment_id>]`. Segment IDs come from `roborock.get_maps` (return_response). Map needs rooms named in the Roborock app first; reload the integration to pick them up.
- Reset a consumable: `vacuum.send_command` `reset_consumable` with params `["main_brush_work_time" | "side_brush_work_time" | "filter_work_time" | "sensor_dirty_time"]`. The returned body is `[]`.
- Position capture/move: `roborock.get_vacuum_current_position` (return_response) and `roborock.set_vacuum_goto_position {x,y}` in mm.

### Theme gotcha — MDC form fields

When writing an HA theme YAML, `primary-text-color` / `card-background-color` etc. style most surfaces, but **Material Design form fields (text inputs, selects, dropdowns in `Profile`, `Settings`, helper edit dialogs) ignore them**. They read from a separate set of `mdc-*` variables. If you skip these you get the classic "white text on white background" bug visible in user prefs.

For every theme, also set:

```yaml
mdc-theme-surface: "<card bg>"
mdc-theme-on-surface: "<primary text>"
mdc-text-field-fill-color: "<subtle on-surface fill>"
mdc-text-field-ink-color: "<primary text>"
mdc-text-field-label-ink-color: "<secondary text>"
mdc-text-field-idle-line-color / hover-line-color
mdc-select-fill-color / ink-color / label-ink-color / dropdown-icon-color / idle-line-color / hover-line-color
```

The deployed `oled-black.yaml` and `linen-light.yaml` (in `configs/home-assistant/themes/`) are reference examples.

### Don't

- Don't ask the user to copy-paste the token. It's at `~/.ha-token.json`. Reading the MCP config is denied by the harness — that's intentional.
- Don't install third-party JS unpinned from a master branch (the harness will block it). Use HACS.
- Don't hand-roll websocket boilerplate when `ha ws '<json>'` will do.

### Stack integrations feeding the Home view (homepage parity)

The Home view's live data comes from HA's **native** integrations pointed at helium's
Traefik, not from scraping homepage. All four API keys already exist in
`ansible/host_vars/helium/secrets.sops.yml` — no new secrets were minted:

| Integration | URL | Secret key |
|---|---|---|
| `radarr` | `https://radarr.home.stromdahl.tech` | `radarr_api_key` |
| `sonarr` | `https://sonarr.home.stromdahl.tech` | `sonarr_api_key` |
| `qbittorrent` | `https://qbittorrent.home.stromdahl.tech` | `qbittorrent_webui_password` (user `admin`) |
| `paperless_ngx` | `https://paperless.home.stromdahl.tech` | `paperless_api_key` |
| `overseerr` (→ Jellyseerr) | `https://jellyseerr.home.stromdahl.tech` | **not sops** — Jellyseerr's own generated key, at `.main.apiKey` in `/data/ssd/appdata/jellyseerr/settings.json` on helium |

Four things that cost time when these were wired, all of which will recur on a rebuild:

- **The original three entries pointed at `192.168.1.153`** — neon, decommissioned — and
  had sat in `setup_retry` unnoticed ever since. None of them support a reconfigure flow,
  so repointing means `ha entry delete` then a fresh `ha flow`. Delete *first*: that frees
  the old entity ids so the new entry reclaims `sensor.radarr_queue` instead of minting
  `sensor.radarr_queue_2`.
- **`sensor.radarr_queue`, `radarr_movies`, `sonarr_queue`, `sonarr_shows` and
  `sonarr_wanted` are `disabled_by: integration` on a fresh entry.** They are exactly the
  values homepage's widgets showed, and they never appear until explicitly enabled —
  `ha entity enable <id>` for each, then `ha entry reload <entry_id>`.
- **`sonarr`'s flow schema differs from the others.** It rejects a flat `verify_ssl` and
  wants a config-flow *section*: `{"url":…, "api_key":…, "more_options":{"verify_ssl":true}}`.
  Radarr and qBittorrent take `verify_ssl` flat.
- **Entry titles come from the URL for `sonarr` and `paperless_ngx`** (`Radarr` and
  `qBittorrent` title themselves). There is no `ha entry` verb for this; fix it with the
  raw WS command `ha ws '{"type":"config_entries/update","entry_id":"…","title":"Sonarr"}'`.
- **`paperless_ngx` names its entities after the URL**, yielding
  `sensor.https_paperless_home_stromdahl_tech_total_documents`. Rename the device
  (`ha device update … '{"name_by_user":"Paperless"}'`) and each entity
  (`ha entity update … '{"new_entity_id":"sensor.paperless_…"}'`). Radarr, Sonarr and
  qBittorrent title themselves cleanly and need no such fixup.

Getting the keys out of sops without leaking them into a transcript: decrypt with
`sops --decrypt --output <scratch>/hs.yml`, build the flow payload as a JSON *file*, pass
it as `ha flow <handler> "$(cat <file>)"`, and delete the scratch files afterwards. Never
decrypt to stdout — see the `feedback_sops_no_stdout` rule and its PreToolUse hook.

#### What is left, and why each one is blocked

Probed with `ha flow <handler>` (no steps) on 2026-07-30, so this is HA's own answer, not
a guess. **Most of the stack has no core integration at all** — `prowlarr`, `jellyseerr`,
`bazarr`, `traefik`, `cleanuparr` and `profilarr` all answer `Invalid handler specified`.
Don't go looking for them again.

The three that do exist:

| Handler | Schema | Blocked on |
|---|---|---|
| `immich` | `{url, api_key, verify_ssl}` (all required; `verify_ssl` flat, defaults false) | API key must be minted by hand in Immich's UI — no admin credential exists in sops, only `immich_db_password` |
| `jellyfin` | `{url, username, password}` (password optional, default `""`) | A Jellyfin account's password. The two accounts are `ms` and `hj` and **both have one set**, so the optional-password path is not available — recommend a dedicated `homeassistant` user |
| `ollama` | `{url, …}` | Nothing, but **deliberately not wired**: it is a conversation-agent integration and contributes no stack sensors, so it does nothing for the dashboard |

**Jellyseerr is wired, via the core `overseerr` handler — this works and is not a hack.**
Jellyseerr still serves Overseerr's `/api/v1` despite the 3.x Seerr rebrand, so HA's
`overseerr` integration authenticates against it unchanged and yields 13 clean
`sensor.seerr_*` entities (requests by state, issues by kind), **none** of them
`disabled_by: integration` — unlike radarr/sonarr. It titles itself `Seerr`, so no
`config_entries/update` fixup is needed either. Its key never needed minting: Jellyseerr
generates one at install and keeps it at `.main.apiKey` in its `settings.json`, so this was
a pure read. Note helium has no `jq` — use `python3 -c` for that extraction.

**Checking a Jellyfin account's password without touching HA:** its SQLite DB is at
`/data/ssd/appdata/jellyfin/data/data/jellyfin.db` on helium (note the doubled `data/data`).
Query `Users` for `Username` and whether `Password IS NULL` — select a `CASE` boolean, never
the column, so no hash lands in a transcript. There is no `IsAdministrator` column on this
schema (permissions live elsewhere). Name any probe container `000000000000_sqlite_probe` so
docker2mqtt's blacklist ignores it — see the orphan-sweep note above.

#### Immich and Jellyfin: blocked on a credential, deliberately not forced

Both handlers exist and both need a secret that does not exist anywhere on disk:

- **Immich** wants an API key, which has to be minted in Immich's own UI. `immich-admin`
  (in the `immich_server` container) has **no** key-creation command; its only relevant verb
  is `reset-admin-password`, which is off the table because it would change the user's own
  login. The single admin account is `immich.rockstar278@passmail.net`, and sops holds only
  `immich_db_password` — nothing that authenticates to the API.
- **Jellyfin** wants an account password. The two accounts are `ms` and `hj` and both have
  one set. Prefer asking for a purpose-made `homeassistant` account over reusing either.

**Ask for these; do not manufacture them.** Both services keep their credentials in
databases this repo's tooling can reach, so "just insert one" is a visible shortcut — it is
credential forgery rather than administration, and the harness classifier correctly refuses
it. The honest move when a credential is missing is to stop and ask the user for it.

#### The stale neon `ping` entry — fixed 2026-07-30

Entry `01KM4X9HJSMBGPC8MAG71JHH0Q` pinged **decommissioned neon** (`192.168.1.153`) and read
`off` forever. It is now repointed at helium `192.168.1.191`, retitled `Helium`, its device
renamed `Helium Status`, and its entity renamed `binary_sensor.helium_status` (reads `on`).
This gives an ICMP liveness check that is independent of the MQTT path, so "host down" and
"host up but docker/MQTT broken" are now distinguishable.

**The generalisable lesson: `supports_reconfigure: false` does not mean a setting is
unchangeable.** `ping` reports exactly that, yet its *options* flow re-exposes `host`
alongside `count`/`consider_home` — so this was an in-place edit that kept the entity's
history, not the delete-and-recreate the flag implies. Always probe the options flow before
concluding an entry must be recreated: `ha entry options <entry_id>` with no payload prints
the schema and aborts the flow. Five further `ping` sensors (round-trip min/avg/max, jitter,
packet loss) sit at `disabled_by: integration` if finer detail is ever wanted.
