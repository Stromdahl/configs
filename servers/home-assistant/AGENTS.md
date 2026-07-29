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
ha flow <handler> '<step1>' ['<step2>'…] # drive multi-step config_entries flow → create_entry
ha entry list [domain]|get|delete|reload|flows  # config_entries CRUD + in-progress flows
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

`ha helper create input_*` still goes via WS (collection helpers); only config-flow helpers need `ha flow`. Manage the resulting config entries with `ha entry list <domain>` / `ha entry delete <entry_id>` / `ha entry reload <entry_id>`. Note: `options` (the per-entry config payload from a flow's `create_entry`) is not exposed by `entry get` — HA only surfaces it during an options flow.

### Where things live

- `configs/home-assistant/themes/sensative.yaml` — repo source for the Sensative theme; deployed copy is `/config/themes/sensative.yaml` on the host.
- `configs/home-assistant/template.yaml` — repo source for template entities (e.g. `vacuum.leonardo_smart`); deployed copy is `/config/template.yaml` on the host.
- `configs/home-assistant/recorder.yaml` — repo source for the recorder scope (issue 046: keeps docker2mqtt's per-container byte counters out of the database); deployed copy is `/config/recorder.yaml`, pulled in by a `recorder: !include recorder.yaml` line added to `/config/configuration.yaml`. Recorder options are **not reloadable** — changing this needs `ha core restart`, and `ha core check` first is worth the ten seconds.
- `servers/home-assistant/exports/` — version-controlled snapshots of dashboards / automations / helpers / entities. Diff-edit these instead of round-tripping over the network. Re-export with the loop in `bin/ha`'s recipes.
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
