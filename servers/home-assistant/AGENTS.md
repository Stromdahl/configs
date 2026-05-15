# servers/home-assistant — agent notes

## Home Assistant

**Host:** `home.stromdahl.tech` (HTTPS) / `192.168.1.99` (LAN). HAOS, version in `exports/` if exported.

**SSH:** `root@192.168.1.99:22` (Terminal & SSH add-on, key already authorized). `/config/` is HA's config dir.

**Token:** `~/.ha-token.json` — shape `{headers:{Authorization:"Bearer ..."}}`. The user is admin; the token works for REST, WS, supervisor.

**HACS + card-mod installed.** Custom Lovelace cards via HACS UI (Settings → HACS).

### `ha` CLI — use this first

`bin/ha` (symlinked to `~/.local/bin/ha` by the `base` module) wraps the patterns. Always prefer it over hand-rolled scripts.

```
ha state <entity>                       # GET /states/<entity>
ha call domain.service '<json>'         # POST service call
ha template '<jinja>'                   # render Jinja
ha entities                             # tab-separated dump (cached in exports/entities.tsv)
ha dash list|get|save                   # lovelace WS API
ha auto list|get|save|delete            # /config/automation/config/<id> + reload
ha scene list|get|save|delete           # /config/scene/config/<id> + reload
ha device list|update                   # config/device_registry/{list,update} via WS
ha area list|create|delete              # config/area_registry/{list,create,delete} via WS
ha helper list|create|delete            # input_*/{create,delete} via WS
ha ws '<json>'                          # raw WS command, prints result.result
```

### Where things live

- `configs/home-assistant/themes/sensative.yaml` — repo source for the Sensative theme; deployed copy is `/config/themes/sensative.yaml` on the host.
- `configs/home-assistant/template.yaml` — repo source for template entities (e.g. `vacuum.leonardo_smart`); deployed copy is `/config/template.yaml` on the host.
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
