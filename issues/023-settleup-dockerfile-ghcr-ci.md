---
title: Package settleup — Dockerfile + GHCR build/publish pipeline
status: done
priority: high
created: 2026-07-02
closed: 2026-07-03
labels: [epic:public-apps, needs-human]
---

## Description

Make settleup deployable as an image radon can pull, with the build **owned by
settleup's own repo** rather than the public box. settleup is currently a local-only
repo; push it to GitHub under the user's account, add a **multi-stage Dockerfile**
(Rust build stage → small slim/distroless runtime shipping just the binary, listening
on its internal port, with the SQLite path set by env to a mounted location), and a
**GitHub Actions workflow** that runs the test suite as a gate, then builds and
publishes the image to **GHCR as a public package** on each push/tag.

Keeping the build in the app repo means radon holds no Rust toolchain and deploys are
a fast image pull. The image must run under settleup's documented production
environment (bind all interfaces internally, the public base URL, the DB on a mounted
path). This is app-repo work; radon consumes the result in `issues/024`.

Can proceed in parallel with `issues/021` and `issues/022`.

## Acceptance criteria

- [x] settleup is pushed to a GitHub repo under the user's account.
- [x] A multi-stage Dockerfile builds a small runtime image that starts settleup and serves HTTP on its internal port, with the SQLite path configurable via env to a mounted location.
- [x] settleup's `cargo test` suite runs in CI and gates the build.
- [x] On push/tag, CI publishes the image to GHCR as a publicly pullable package.
- [x] Pulling and running the published image serves the app and persists the DB to the mounted volume across restarts.

## Resolution (2026-07-03)

Delivered in the settleup repo (github.com/Stromdahl/settleup, GPL-3.0):

- **Image:** `ghcr.io/stromdahl/settleup` (`:latest` on main, plus `:sha-*` and
  `type=semver` tags on `v*` tags). Multi-stage build — `rust:1-bookworm` builder →
  `debian:bookworm-slim` runtime, ~136 MB, **non-root** (uid 10001).
- **Runtime contract for `issues/024`:** listens on **:3000** internally
  (`SETTLEUP_ADDR=0.0.0.0:3000` baked in); DB at `SETTLEUP_DB=/data/settleup.db`
  with `/data` a `VOLUME` owned by the app user (mount a named volume there);
  `SETTLEUP_BASE_URL` is deliberately **not** baked in — the deployment sets it
  (e.g. `https://settleup.stromdahl.io`) so QR/invite links and Secure cookies are right.
- **CI** (`.github/workflows/ci.yml`): `cargo test --locked` gates a build-and-push
  job; builds on PRs (no push), publishes to GHCR on push to main / `v*` tags.
- **Verified:** CI green; **anonymous** `docker pull` of the published image
  succeeds (package is public — no manual visibility toggle was needed); running the
  pulled image serves the app and a created group survives destroying and recreating
  the container against the same named volume.
