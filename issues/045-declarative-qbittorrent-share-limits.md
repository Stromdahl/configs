---
title: Make qBittorrent's share limits declarative instead of appdata-only runtime state
status: open
priority: medium
created: 2026-07-25
closed: null
labels: [epic:services]
---

## Description

qBittorrent's seeding policy lives only in its own config file inside the appdata
tier, written by the app itself. Nothing in the repo describes it, so a fresh
build or an appdata restore silently comes back with defaults and the stack
quietly seeds far less than intended — a regression with no deploy, no diff, and
no alert.

The policy was retuned by hand on 2026-07-25 (applied live over the WebUI API,
currently running):

- max ratio 2.0 (was 1.0)
- max seeding time 4320 min / 3 days (was 1440 / 24 h)
- max inactive seeding time enabled at 2880 min / 2 days (was disabled)
- share-limit action: pause (unchanged) — Radarr/Sonarr's "remove completed
  downloads" then deletes the paused torrent and its data
- max active uploads 8 (was 3), max active torrents 12 (was 5) — the queue caps
  have to rise with the seed window or the extra torrents just park in the queue
  and upload nothing

Rationale for the values, so a future reader does not "tidy" them back: the old
"ratio 1.0 **or** 24 h, whichever first" cut short exactly the swarms where our
seed matters most — popular releases hit ratio 1.0 in hours, while thin swarms
expired at 24 h having uploaded almost nothing. The inactive-seeding limit is the
release valve that makes a long absolute window safe. Values are tuned for public
trackers only (currently TPB + YTS); they are *not* private-tracker safe, and
private-tracker support is a separate, larger slice gated on the copy-on-import /
hardlink storage question.

The non-obvious constraint: qBittorrent rewrites its config on shutdown, so
naively templating the file races the running container and gets clobbered. The
slice has to pick an approach that survives a normal deploy and a container
restart — e.g. writing the config only while the service is down, or driving the
WebUI API as a post-deploy convergence step. Whichever is chosen must be
idempotent and must not fight the existing gluetun port-forward sync, which
already writes the listen port into the same running instance.

Depends on `issues/014` (the qBittorrent instance this configures).

## Acceptance criteria

- [ ] The seeding policy above is expressed in the repo, not only in appdata, and
      a deploy converges a drifted instance back to it.
- [ ] Re-running the deploy with the policy already in effect changes nothing
      (idempotent, no container restart churn).
- [ ] Wiping or restoring qBittorrent's appdata and redeploying restores the
      documented values without hand-editing the WebUI.
- [ ] The gluetun forwarded port still matches qBittorrent's listen port after a
      deploy and after a gluetun reconnect (the port-forward sync is not
      clobbered by the new mechanism).
- [ ] A comment or note records that these values are public-tracker-only, so
      adding a private tracker is understood to need its own per-category policy.
