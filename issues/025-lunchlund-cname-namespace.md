---
title: Bring lunchlund under the stromdahl.io namespace via CNAME to GitHub Pages
status: open
priority: medium
created: 2026-07-02
closed: null
labels: [epic:public-apps, needs-human]
---

## Description

Make lunchlund appear under the one roof **without re-hosting it**. lunchlund is a
static site already built and served by its own GitHub Actions → GitHub Pages
pipeline; the only work is to point a pretty name at it. Add a
`lunchlund.stromdahl.io` record **CNAME'd to the user's GitHub Pages site** and set
the **custom domain** on the lunchlund repo's Pages config so Pages serves a valid
certificate for the name.

lunchlund's build, cron, and content are left untouched — this is purely a
naming/DNS slice that realizes the "one place = the namespace, not one runtime"
decision from the PRD.

Depends on `issues/021` (the `stromdahl.io` zone must exist).

## Acceptance criteria

- [ ] `lunchlund.stromdahl.io` resolves to the GitHub Pages site and serves it over HTTPS with a valid certificate.
- [ ] The lunchlund repo's Pages custom domain is configured for the name.
- [ ] lunchlund's existing build/publish pipeline is unchanged and still produces the site.
