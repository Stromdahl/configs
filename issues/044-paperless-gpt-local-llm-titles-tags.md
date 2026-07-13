---
title: Local-LLM title / tag / correspondent suggestions for Paperless via paperless-gpt + Ollama
status: in-progress
priority: low
created: 2026-07-13
labels: [epic:services, needs-human]
---

## Description

Give Paperless AI-generated **titles, tags, and correspondents** without sending any
document to a cloud provider. The constraint that shapes the whole design: helium is
**CPU-only** (the RTX 2060 was pulled — no CUDA path; iGPU only, used by Jellyfin
QuickSync). So:

- **Titles / tags / correspondents → local LLM.** Run **Ollama** (CPU) on helium with a
  small multilingual text model, and the **paperless-gpt** add-on (icereed) drives it: it
  reads a document's OCR text over the Paperless REST API, asks Ollama for a title/tags/
  correspondent, and writes the result back. Async and tag-triggered, so CPU latency
  (tens of seconds/doc) is fine.
- **OCR stays on Tesseract.** Paperless already OCRs locally with Tesseract (`eng+swe`).
  paperless-gpt *can* do LLM-vision OCR, but a vision model on this CPU is minutes/page —
  not worth it. OCR is left entirely on Tesseract; the LLM-OCR path is **not** enabled
  (no `OCR_PROVIDER=llm`, no vision model pulled). LLM-OCR in paperless-gpt is strictly
  opt-in (per-doc `paperless-gpt-ocr-auto` tag), so leaving it unconfigured is safe.

Nothing leaves the box: Ollama is on the internal `paperless` bridge, no published ports,
no Traefik. paperless-gpt has a review web UI exposed like the rest of the stack
(`paperless-gpt.home.stromdahl.tech`, LAN + mesh, never public).

### Why the add-on and not native Paperless AI

Paperless-ngx **v3.0.0** ships native AI suggestions (`PAPERLESS_AI_*`, Ollama/OpenAI
backends — PR #10319, milestone v3.0.0). Confirmed **absent from the pinned v2.20.15**
(`PAPERLESS_AI` = 0 hits in the v2.20.15 tag, 9 hits in v3.0.0-beta.rc1). Adopting native
AI would mean upgrading the document store to a **beta** release — a separate, bigger
decision for a system holding irreplaceable records, deliberately avoided by the v2-stable
pin in `host_vars/helium/vars.yml`. paperless-gpt gets the same result on the stable line
and is cleanly removable if/when v3 goes stable and native AI is adopted.

### Workflow (starts manual, review-first)

- Tag a document `paperless-gpt` → paperless-gpt generates a suggestion you review/apply in
  its web UI. Tag `paperless-gpt-auto` → it applies automatically. Nothing is automatic
  until a doc is tagged, so the rollout is opt-in per document.
- `CREATE_NEW_TAGS=false` initially — it only applies tags that already exist, so it can't
  pollute the tag list while you evaluate quality. Flip to `true` later if wanted.

## Acceptance criteria

- [x] **RAM gate:** `free -h` on helium = 15 GiB total, ~10 GiB available — `qwen2.5:3b`
      (1.9 GB) fits comfortably alongside CPU-only Immich ML + the full stack. Headroom for
      `qwen2.5:7b` later if wanted.
- [x] Ollama runs on helium (internal `paperless` bridge, no published ports) and the model
      is pulled (`qwen2.5:3b`, automated by the compose-stack role's idempotent pull task).
- [x] paperless-gpt runs, reaches Paperless (`paperless:8000`) and Ollama (`ollama:11434`),
      and its UI is reachable at `paperless-gpt.home.stromdahl.tech` (valid LE cert) over
      LAN + mesh, never public.
- [x] **Token write-scope:** the reused `paperless_api_key` belongs to user `ms`
      (`is_superuser=true`, `change_document` granted) — full write access, no dedicated
      token needed.
- [ ] Tagging a real document `paperless-gpt` produces a sensible title + tags in Swedish
      *and* English documents; applying the suggestion updates the document. **(needs-human:
      quality check on real docs in the UI.)**
- [x] Container + Ollama + all non-secret config live in the Ansible compose-stack role;
      no document data leaves helium.

## Outcome (2026-07-13)

Deployed via `ansible-playbook site.yml --limit helium --tags compose`. ollama + paperless-gpt
up; `qwen2.5:3b` pulled; paperless-gpt authenticated to the Paperless API and OCR gracefully
self-disabled ("OCR provider is set to LLM, but no VISION_LLM_PROVIDER is set. Disabling OCR.").
Two fixes were needed during bring-up:

1. **paperless-gpt caps.** Its entrypoint starts root, `chown`s `/app` + `/home/paperless-gpt`
   and drops to a non-root user, so a blanket `cap_drop:[ALL]` crash-looped it
   ("chown: Operation not permitted"). Fixed by adding the curated `*caps-privdrop` set (same
   as the paperless webserver) — the issue-010 pattern for root-entrypoint-then-drop images.
2. **DNS-01 cert for the new subdomain.** Issuance failed repeatedly ("dns01: time limit
   exceeded ... NS 127.0.0.11 did not return the expected TXT record"): lego's propagation
   self-check queried the container's split-horizon resolver, which never returns the public
   `_acme-challenge` TXT. This was NOT the transient "restart traefik" gotcha — two restarts
   reproduced it. Fixed durably by pinning the check to public resolvers
   (`dnschallenge.resolvers=1.1.1.1:53,8.8.8.8:53`); cert then issued (LE). This also fixes
   every future new subdomain on this split-horizon domain.

Remaining: judge suggestion quality on real Swedish + English docs (tag one `paperless-gpt`,
review in the UI, apply). Then optionally flip `CREATE_NEW_TAGS=true` / add the
`paperless-gpt-auto` tag for hands-off processing.

## Notes

- Images pinned: `ollama/ollama:0.31.2`, `icereed/paperless-gpt:v0.26.1`.
- Deploy scoped to `--tags compose` only (never the full play — ufw/iptables-persistent
  eviction, see issue 028 / `project_ufw_breaks_iptables_persistent`).
- Model is a var (`paperless_gpt_llm_model`); bump to `qwen2.5:7b` for better quality once
  RAM is confirmed (≈2× resident, slower on CPU).
