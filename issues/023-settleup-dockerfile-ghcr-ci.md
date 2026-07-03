---
title: Package settleup — Dockerfile + GHCR build/publish pipeline
status: in-progress
priority: high
created: 2026-07-02
closed: null
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

- [ ] settleup is pushed to a GitHub repo under the user's account.
- [ ] A multi-stage Dockerfile builds a small runtime image that starts settleup and serves HTTP on its internal port, with the SQLite path configurable via env to a mounted location.
- [ ] settleup's `cargo test` suite runs in CI and gates the build.
- [ ] On push/tag, CI publishes the image to GHCR as a publicly pullable package.
- [ ] Pulling and running the published image serves the app and persists the DB to the mounted volume across restarts.
