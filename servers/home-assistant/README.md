# Home Assistant

## Sensative theme

A custom dark theme using the Sensative palette (teal #6EABAE / mustard #D7B26D).

### Install

1. Copy `configs/home-assistant/themes/sensative.yaml` to your HA config dir under `themes/sensative.yaml`. On HAOS:
   - via the **Studio Code Server** add-on, or **Samba Backup** add-on, or
   - via SSH: `scp configs/home-assistant/themes/sensative.yaml root@<hass-host>:/config/themes/sensative.yaml`

2. Ensure `configuration.yaml` enables the themes folder (only needed once):
   ```yaml
   frontend:
     themes: !include_dir_merge_named themes
   ```

3. Reload themes:
   - **Settings → System → Restart → Reload theme** (UI), **or**
   - call service `homeassistant.reload_themes`.

4. Activate per user:
   **Profile → Theme → Sensative** (set "Default" too if desired).

## Template entities

`template.yaml` defines wrapper entities loaded via `template: !include template.yaml` in `/config/configuration.yaml`. Currently:

- `vacuum.leonardo_smart` — wraps `vacuum.leonardo` so that the standard `vacuum-commands` tile feature's start_pause button calls `script.leonardo_clean_enabled_rooms` (cleans only segments whose `input_boolean.leonardo_auto_<room>` is on). Dock, locate, pause, stop, and fan speed pass through to the real entity unchanged.

### Deploy

```sh
scp configs/home-assistant/template.yaml root@192.168.1.99:/config/template.yaml
curl -sS -H "Authorization: Bearer $TOKEN" -X POST \
  https://home.stromdahl.tech/api/services/template/reload -d '{}'
```

(No HA restart required — `template/reload` is enough.)

### Notes

The dashboard configs (Home + Leonardo Vacuum) are stored inside HA's frontend storage and are managed via the HA UI / lovelace WS API. Card colors that should respect the theme use named colors (`amber`, `teal`) which the theme maps to the brand palette.
