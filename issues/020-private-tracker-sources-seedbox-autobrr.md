---
title: Add private-tracker sources via seedbox + autobrr, wired into the *arr stack
status: open
priority: medium
created: 2026-07-02
closed: null
labels: [epic:services, needs-human]
---

## Description

Public trackers are an unreliable, poorly-seeded source for the download stack.
Private (invite-only) trackers are the reliable alternative: high-quality,
well-seeded, long-lived general movie/TV releases. This slice brings private
sources into the existing automation so Radarr/Sonarr pull from them. Genuinely
Nordic-origin content is a *bonus*, not the goal — Swedish subtitles on
international releases are already covered by Bazarr's Swedish-first profile, so
a Nordic tracker only earns its keep for Swedish/Nordic-origin films and series.

The way in is a ladder, not a single door. Get a foothold on a reliable general
movie/TV tracker — grabbed during a periodic open-signup window (watch
r/OpenSignups and opentrackers.org for TorrentLeech / FileList / AlphaRatio / a
UNIT3D site like Blutopia or Aither), via an IRC interview, or by paying into
IPTorrents as a guaranteed fallback. A rented seedbox is the ratio engine that
makes the rest work: it seeds 24/7, races new releases to top-seeder, and lets
helium pull completed files home. Whatbox (Netherlands, one-click autobrr, fast
port, full SSH) is the recommended box; a dedicated IP and a Nordic-located box
are both unnecessary. autobrr on the seedbox reads the tracker's announce
channel and auto-grabs freeleech/matching releases; the tracker is added to
Prowlarr to feed the *arr apps. Files land on helium via a copy-off-the-seedbox
(copy-on-import, consistent with issue 014's hardlink trade-off) while the
seedbox keeps seeding them. Ratio discipline — honouring seed-time minimums, no
hit-and-runs — is what keeps the account alive and earns invites upward
(BeyondHD mid-tier; PassThePopcorn for movies via interview and BroadcastTheNet
for TV via invite, long-term).

The access step is inherently manual and gated on external signup windows /
interviews / ratio history, so it cannot be fully automated (hence
`needs-human`). Nordic trackers are optional: Superbits (Swedish, seasonal
Christmas/New-Year application window) is the target if wanted, but
DanishBytes/NordicBytes carries documented Danish law-enforcement exposure and
is best avoided — a further reason to keep all tracker traffic on the seedbox
rather than the home IP.

Depends on `issues/014` (the download stack + Prowlarr/*arr these sources feed).

## Acceptance criteria

- [ ] Membership obtained on at least one reliable general movie/TV private
      tracker (open-signup window, interview, or paid entry).
- [ ] A seedbox is provisioned in an appropriate location and seeding 24/7.
- [ ] autobrr is running and connected to the tracker's announce channel,
      auto-grabbing matching/freeleech releases per defined filters.
- [ ] The tracker is added to Prowlarr and its releases are searchable and
      grabbable from Radarr/Sonarr.
- [ ] Completed downloads are pulled from the seedbox to helium's library
      unattended (copy-on-import), and the seedbox keeps seeding them.
- [ ] Ratio is positive/maintained with no outstanding hit-and-runs (seed-time
      minimums honoured) on the tracker.
