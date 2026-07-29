#!/usr/bin/env python3
"""Publish host metrics to MQTT with Home Assistant discovery (issue 046).

This is the HOST half of the metrics slice: CPU / memory / uptime, filesystem
capacity, board+CPU temperatures and fan speeds, and per-drive SMART
temperature and health. The CONTAINER half is docker2mqtt, which runs as a
compose service and talks to the read-only Docker socket proxy; the two are
separate because reading SMART attributes means issuing SCSI commands to raw
block devices as root, which no container in that stack is allowed to do.

Shape, and why:

* One-shot, driven by a systemd timer, rather than a long-lived daemon. Each
  run is independent, so there is no process to crash or leak, and nothing to
  restart after a broker outage.
* Because a one-shot process disconnects cleanly, an MQTT last-will can never
  fire, so availability is expressed with `expire_after` on every discovery
  payload instead: if the host dies, the timer stops, no state arrives, and HA
  flips the entities to `unavailable` on its own.
* Discovery payloads are published RETAINED on every run (idempotent
  overwrite), so entities survive an HA restart and reappear by themselves even
  if the broker loses its persistence.
* State is published NOT retained, deliberately. A retained state message
  outlives the host: after a three-day outage HA would receive that stale
  payload on reconnect and show it as current for a full expire_after window.
  Losing the value for one poll interval after an HA restart is the better
  trade, because a blank reading is honest and a stale one is not.
* Entity identity is keyed on drive serial / logical unit id, never on
  /dev/sdX. Those letters reshuffle across reboots on this HBA (disk1 is
  currently sdb, disk2 is sda), so device-name-keyed entities would silently
  swap two drives' histories and look like they were working.

All host-specific configuration — mount points, which hwmon readings are worth
publishing, drive labels, broker credentials — lives in the JSON config file
rendered by the Ansible role. This script contains no host specifics.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time

import paho.mqtt.publish as publish

CONFIG_PATH = os.environ.get("MQTT_METRICS_CONFIG", "/etc/mqtt-metrics/config.json")

# smartctl flags: the CHEAPEST combination that still yields a SAS drive's
# temperature. `-x` also works but reads every log page and costs ~7.4 s across
# this box's seven devices, which is far too heavy for a 60 s timer; `-A -H`
# costs ~1 s for the same set and returns both temperature and health. Plain
# `-A`, `-H` alone, `-l temperature` and `-l scttempsts` all return no
# temperature at all for SCSI/SAS devices — verified on-box, don't "simplify".
SMARTCTL_ARGS = ["-j", "-i", "-A", "-H"]

# Seconds between the two /proc/stat samples used for CPU utilisation. Cheap,
# but it does mean every run takes at least this long.
CPU_SAMPLE_SECONDS = 1.0


def run(argv: list[str]) -> str | None:
    """Run a command, returning stdout, or None if it fails.

    Collection is best-effort by design: one unreadable sensor or one drive
    that stopped answering must not cost us every other metric in the run.
    """
    try:
        proc = subprocess.run(
            argv, capture_output=True, text=True, timeout=30, check=False
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        print(f"warning: {argv[0]} failed: {exc}", file=sys.stderr)
        return None
    # smartctl uses a bitmask exit status: low bits are real failures, high bits
    # are advisory ("some SMART attribute is past its threshold"). It still
    # prints valid JSON in the advisory case, so judge it on parseable output
    # rather than on the exit code.
    if not proc.stdout.strip():
        print(f"warning: {argv[0]} produced no output: {proc.stderr.strip()}", file=sys.stderr)
        return None
    return proc.stdout


def run_json(argv: list[str]) -> dict | None:
    out = run(argv)
    if out is None:
        return None
    try:
        return json.loads(out)
    except json.JSONDecodeError as exc:
        print(f"warning: {argv[0]} emitted invalid JSON: {exc}", file=sys.stderr)
        return None


# --------------------------------------------------------------------------
# collectors — each returns {metric_key: value} plus a list of entity specs
# --------------------------------------------------------------------------


def collect_cpu() -> float | None:
    """CPU utilisation percent, from two /proc/stat samples."""

    def snapshot() -> tuple[int, int] | None:
        try:
            with open("/proc/stat", encoding="ascii") as fh:
                fields = fh.readline().split()[1:]
        except OSError:
            return None
        values = [int(v) for v in fields]
        # idle + iowait: a box waiting on these disks is not busy CPU-wise.
        return sum(values), values[3] + values[4]

    first = snapshot()
    time.sleep(CPU_SAMPLE_SECONDS)
    second = snapshot()
    if first is None or second is None:
        return None
    total_delta = second[0] - first[0]
    idle_delta = second[1] - first[1]
    if total_delta <= 0:
        return None
    return round(100.0 * (total_delta - idle_delta) / total_delta, 1)


def collect_memory() -> dict[str, float]:
    """Memory and swap usage from /proc/meminfo (values there are kB)."""
    info: dict[str, int] = {}
    try:
        with open("/proc/meminfo", encoding="ascii") as fh:
            for line in fh:
                key, _, rest = line.partition(":")
                parts = rest.split()
                if parts:
                    info[key] = int(parts[0])
    except OSError as exc:
        print(f"warning: /proc/meminfo unreadable: {exc}", file=sys.stderr)
        return {}

    out: dict[str, float] = {}
    total = info.get("MemTotal", 0)
    available = info.get("MemAvailable")
    if total and available is not None:
        # MemAvailable, not MemFree: page cache is reclaimable, so MemFree
        # reads as "almost no memory left" on any box that has been up a while.
        used_kib = total - available
        out["memory_used"] = round(used_kib / 1024, 1)
        out["memory_used_percent"] = round(100.0 * used_kib / total, 1)
    swap_total = info.get("SwapTotal", 0)
    swap_free = info.get("SwapFree", 0)
    if swap_total:
        out["swap_used_percent"] = round(100.0 * (swap_total - swap_free) / swap_total, 1)
    return out


def collect_boot_time() -> int | None:
    """Boot time as a UNIX timestamp, read from /proc/stat's btime.

    Deliberately not derived from /proc/uptime: that arithmetic lands a second
    or two off on every run, so the timestamp entity would appear to change
    every poll and churn the recorder. btime is a constant.
    """
    try:
        with open("/proc/stat", encoding="ascii") as fh:
            for line in fh:
                if line.startswith("btime "):
                    return int(line.split()[1])
    except (OSError, ValueError) as exc:
        print(f"warning: cannot read btime: {exc}", file=sys.stderr)
    return None


def collect_filesystem(path: str) -> dict[str, float]:
    """Capacity for one filesystem, using df's notion of used/available.

    Note for the SSD tier: /data/ssd is NOT itself a mount point on this host —
    only its btrfs subvolumes are mounted, and they all share one pool. So the
    configured path must be one of the subvolume mounts; it reports the whole
    pool either way.
    """
    try:
        st = os.statvfs(path)
    except OSError as exc:
        print(f"warning: statvfs({path}) failed: {exc}", file=sys.stderr)
        return {}
    gib = 1024**3
    used_bytes = (st.f_blocks - st.f_bfree) * st.f_frsize
    avail_bytes = st.f_bavail * st.f_frsize
    total_bytes = st.f_blocks * st.f_frsize
    denominator = used_bytes + avail_bytes
    return {
        "total": round(total_bytes / gib, 1),
        "used": round(used_bytes / gib, 1),
        "free": round(avail_bytes / gib, 1),
        "used_percent": round(100.0 * used_bytes / denominator, 1) if denominator else 0.0,
    }


def collect_hwmon(specs: list[dict]) -> dict[str, float]:
    """Pull selected readings out of `sensors -j`.

    Curated rather than exhaustive on purpose: this chip exposes voltages, PWM
    duty, intrusion flags and several dead PECI/PCH channels that read 0, and
    publishing all of it would bury the handful of readings that matter.
    """
    if not specs:
        return {}
    data = run_json(["sensors", "-j"])
    if not data:
        return {}
    out: dict[str, float] = {}
    for spec in specs:
        chip = data.get(spec["chip"])
        if not isinstance(chip, dict):
            print(f"warning: hwmon chip {spec['chip']} absent", file=sys.stderr)
            continue
        feature = chip.get(spec["feature"])
        if not isinstance(feature, dict):
            print(
                f"warning: hwmon feature {spec['chip']}/{spec['feature']} absent",
                file=sys.stderr,
            )
            continue
        value = feature.get(spec["sub"])
        if value is None:
            continue
        out[spec["key"]] = round(float(value), 1)
    return out


def drive_identity(report: dict) -> str | None:
    """Stable identity for a drive: SAS logical unit id, else serial number.

    The SAS drives report a logical_unit_id that matches the wwn-* ids the
    storage role pins its mounts on, which is what lets the config map a drive
    to a meaningful label like `disk1`. Drives that report none fall back to
    serial. Either way it is an identity that travels with the physical drive,
    not with a kernel device name.

    The hex validation is load-bearing, not defensive boilerplate: asked about a
    SATA SSD behind this SAS HBA, smartctl can return the literal string
    "error: unexpected NAA" in this field. Two such drives then share an
    "identity", collapse into a single entity, and the second silently
    overwrites the first — which is exactly what happened on the first deploy
    here. Anything that is not a plausible hex id is not an identity.
    """
    lun = report.get("logical_unit_id")
    if isinstance(lun, str):
        candidate = lun.strip().lower()
        if candidate.startswith("0x") and len(candidate) > 2:
            if all(c in "0123456789abcdef" for c in candidate[2:]):
                return candidate
    serial = report.get("serial_number")
    if isinstance(serial, str) and serial.strip():
        return serial.strip()
    return None


def collect_drives(labels: dict[str, str]) -> tuple[dict[str, float | bool], list[dict]]:
    """Per-drive temperature and SMART health for every device smartctl finds.

    Enumerated live via `smartctl --scan` rather than from a configured device
    list, so a drive that moves, or a newly added one, is picked up without a
    config change. Labels are looked up by identity; anything unlabelled still
    gets published, named after its model and serial, because a silently
    skipped drive is the failure mode this is meant to prevent.
    """
    scan = run_json(["smartctl", "--scan", "-j"])
    devices = (scan or {}).get("devices") or []
    values: dict[str, float | bool] = {}
    entities: list[dict] = []

    for dev in devices:
        name = dev.get("name")
        if not name:
            continue
        # Let smartctl auto-detect the device type rather than passing the type
        # from --scan. The scan probes shallowly and calls the SATA SSDs behind
        # this SAS HBA plain "scsi"; asked that way they report no model, no
        # usable identity and a temperature of 0, while auto-detection finds the
        # ATA passthrough and returns all three correctly. The scanned type is
        # kept only as a fallback, for the controllers where it IS required
        # (megaraid and friends) and auto-detection genuinely fails.
        report = run_json(["smartctl", *SMARTCTL_ARGS, name])
        if (not report or (report.get("temperature") or {}).get("current") is None) and dev.get("type"):
            retry = run_json(["smartctl", *SMARTCTL_ARGS, "-d", dev["type"], name])
            if retry and (retry.get("temperature") or {}).get("current") is not None:
                report = retry
        if not report:
            continue

        identity = drive_identity(report)
        if identity is None:
            print(f"warning: {name} reports no usable identity, skipping", file=sys.stderr)
            continue

        model = report.get("model_name") or report.get("scsi_model_name") or "drive"
        serial = report.get("serial_number") or identity
        label = labels.get(identity) or f"{model} {serial}"
        # Key on identity so a relabel in config never mints a duplicate entity.
        slug = "".join(c if c.isalnum() else "_" for c in identity).strip("_").lower()

        # Two drives must never share a key. If they somehow do, say so loudly
        # and drop the second rather than overwriting the first: a silent merge
        # looks like a working entity while hiding a whole drive.
        if f"drive_{slug}_temperature" in values or f"drive_{slug}_smart_ok" in values:
            print(
                f"warning: {name} reports identity {identity!r}, already claimed by "
                f"another drive — skipping to avoid merging two drives into one entity",
                file=sys.stderr,
            )
            continue

        temperature = (report.get("temperature") or {}).get("current")
        if temperature is not None:
            key = f"drive_{slug}_temperature"
            values[key] = round(float(temperature), 1)
            entities.append(
                {
                    "key": key,
                    "name": f"{label} temperature",
                    "unit": "°C",
                    "device_class": "temperature",
                    "state_class": "measurement",
                    "attributes": {"model": model, "serial": serial, "device": name},
                }
            )

        passed = (report.get("smart_status") or {}).get("passed")
        if passed is not None:
            key = f"drive_{slug}_smart_ok"
            values[key] = bool(passed)
            entities.append(
                {
                    "key": key,
                    "name": f"{label} SMART",
                    "component": "binary_sensor",
                    "device_class": "problem",
                    # device_class problem inverts the sense: ON means trouble.
                    "value_template": "{{ 'OFF' if value_json.%s else 'ON' }}" % key,
                    "attributes": {"model": model, "serial": serial, "device": name},
                }
            )

    return values, entities


# --------------------------------------------------------------------------
# discovery + publish
# --------------------------------------------------------------------------

# Static entity specs for the host vitals and per-filesystem metrics. Drive
# entities are built dynamically in collect_drives() since they depend on what
# is actually attached.
VITALS_ENTITIES = [
    {
        "key": "cpu_percent",
        "name": "CPU usage",
        "unit": "%",
        "state_class": "measurement",
        "icon": "mdi:cpu-64-bit",
    },
    {
        "key": "load_1m",
        "name": "Load average 1m",
        "state_class": "measurement",
        "icon": "mdi:chart-line",
    },
    {
        "key": "memory_used_percent",
        "name": "Memory usage",
        "unit": "%",
        "state_class": "measurement",
        "icon": "mdi:memory",
    },
    {
        "key": "memory_used",
        "name": "Memory used",
        "unit": "MiB",
        "device_class": "data_size",
        "state_class": "measurement",
    },
    {
        "key": "swap_used_percent",
        "name": "Swap usage",
        "unit": "%",
        "state_class": "measurement",
        "icon": "mdi:swap-horizontal",
    },
    {
        "key": "boot_time",
        "name": "Last boot",
        "device_class": "timestamp",
        # A UNIX timestamp is not a valid HA timestamp state; convert in the
        # template so the entity gets the ISO 8601 string it expects.
        "value_template": "{{ value_json.boot_time | int | timestamp_utc }}",
        "icon": "mdi:clock-start",
    },
]

FILESYSTEM_METRICS = [
    ("used_percent", "usage", "%", None, "mdi:harddisk"),
    ("free", "free", "GiB", "data_size", None),
    ("used", "used", "GiB", "data_size", None),
    ("total", "size", "GiB", "data_size", None),
]


def build_filesystem_entities(filesystems: list[dict]) -> list[dict]:
    entities = []
    for fs in filesystems:
        for suffix, label, unit, device_class, icon in FILESYSTEM_METRICS:
            spec: dict = {
                "key": f"{fs['key']}_{suffix}",
                "name": f"{fs['name']} {label}",
                "unit": unit,
                "state_class": "measurement",
            }
            if device_class:
                spec["device_class"] = device_class
            if icon:
                spec["icon"] = icon
            entities.append(spec)
    return entities


def discovery_message(entity: dict, cfg: dict, state_topic: str) -> dict:
    """One HA MQTT discovery payload, as a retained message dict."""
    device_id = cfg["device"]["id"]
    component = entity.get("component", "sensor")
    unique_id = f"{device_id}_{entity['key']}"
    payload: dict = {
        "name": entity["name"],
        "unique_id": unique_id,
        "object_id": unique_id,
        "state_topic": state_topic,
        "value_template": entity.get(
            "value_template", "{{ value_json.%s }}" % entity["key"]
        ),
        # Availability without a last-will: no state inside this window and HA
        # marks the entity unavailable by itself.
        "expire_after": cfg["expire_after"],
        "device": {
            "identifiers": [device_id],
            "name": cfg["device"]["name"],
            "manufacturer": cfg["device"].get("manufacturer", ""),
            "model": cfg["device"].get("model", ""),
        },
        "origin": {"name": "mqtt-metrics"},
    }
    for field in ("unit", "device_class", "state_class", "icon"):
        value = entity.get(field)
        if value:
            payload["unit_of_measurement" if field == "unit" else field] = value
    if entity.get("attributes"):
        payload["json_attributes_topic"] = f"{state_topic}/attributes/{entity['key']}"
    return {
        "topic": f"{cfg['discovery_prefix']}/{component}/{device_id}/{unique_id}/config",
        "payload": json.dumps(payload, ensure_ascii=False),
        "qos": 1,
        "retain": True,
    }


def main() -> int:
    try:
        with open(CONFIG_PATH, encoding="utf-8") as fh:
            cfg = json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"error: cannot read {CONFIG_PATH}: {exc}", file=sys.stderr)
        return 1

    device_id = cfg["device"]["id"]
    state_topic = f"{cfg['topic_prefix']}/{device_id}/state"

    # ---- collect ----
    values: dict = {}
    cpu = collect_cpu()
    if cpu is not None:
        values["cpu_percent"] = cpu
    values.update(collect_memory())
    boot_time = collect_boot_time()
    if boot_time is not None:
        values["boot_time"] = boot_time
    try:
        values["load_1m"] = round(os.getloadavg()[0], 2)
    except OSError:
        pass

    for fs in cfg.get("filesystems", []):
        for suffix, value in collect_filesystem(fs["path"]).items():
            values[f"{fs['key']}_{suffix}"] = value

    values.update(collect_hwmon(cfg.get("hwmon", [])))
    drive_values, drive_entities = collect_drives(cfg.get("drives", {}))
    values.update(drive_values)

    if not values:
        print("error: collected nothing, refusing to publish", file=sys.stderr)
        return 1

    # ---- assemble entity list ----
    entities = list(VITALS_ENTITIES)
    entities += build_filesystem_entities(cfg.get("filesystems", []))
    for spec in cfg.get("hwmon", []):
        entities.append(
            {
                "key": spec["key"],
                "name": spec["name"],
                "unit": spec.get("unit"),
                "device_class": spec.get("device_class"),
                "state_class": "measurement",
                "icon": spec.get("icon"),
            }
        )
    entities += drive_entities

    # Only advertise entities we actually have a reading for, so a sensor that
    # vanished does not leave a permanently blank entity behind in HA.
    entities = [e for e in entities if e["key"] in values]

    messages = [discovery_message(e, cfg, state_topic) for e in entities]
    messages.append(
        {
            "topic": state_topic,
            "payload": json.dumps(values, ensure_ascii=False),
            "qos": 1,
            # NOT retained — see the module docstring. A retained state message
            # outlives the host and would be replayed as current after an outage.
            "retain": False,
        }
    )
    for entity in entities:
        if entity.get("attributes"):
            messages.append(
                {
                    "topic": f"{state_topic}/attributes/{entity['key']}",
                    "payload": json.dumps(entity["attributes"], ensure_ascii=False),
                    "qos": 1,
                    "retain": True,
                }
            )

    mqtt_cfg = cfg["mqtt"]
    try:
        publish.multiple(
            messages,
            hostname=mqtt_cfg["host"],
            port=int(mqtt_cfg.get("port", 1883)),
            client_id=mqtt_cfg.get("client_id", f"mqtt-metrics-{device_id}"),
            auth={
                "username": mqtt_cfg["username"],
                "password": mqtt_cfg["password"],
            },
            keepalive=30,
        )
    except Exception as exc:  # noqa: BLE001 - any failure here is just "retry next tick"
        print(f"error: publishing to {mqtt_cfg['host']} failed: {exc}", file=sys.stderr)
        return 1

    print(f"published {len(values)} values across {len(entities)} entities")
    return 0


if __name__ == "__main__":
    sys.exit(main())
