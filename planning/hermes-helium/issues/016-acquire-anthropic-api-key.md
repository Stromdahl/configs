# 016 — Acquire the Anthropic API key

Type: execution
Status: resolved
Parent: [spec 015](015-spec-hermes-on-helium.md)
Blocked by: none — can start immediately
Labels: needs-human

## What to build

The credential every model call in this deployment depends on, held where ansible can
template it.

**This is a human step and cannot be automated.** Ticket `09` established there is **no API
key and no provider profile on krypton**, so this is a **new metered API account** — not the
existing Claude Code subscription, and a real new cost. ⚠️ It is also governed by different
terms than the subscription: the API's no-training and 30-day-retention posture is what
`09` accepted, so the account must be an API account, not a reused login.

The key lands in the same sops-encrypted secrets material that feeds the service's
environment file, alongside the Telegram credentials from `017`. Nothing else in the build
should carry it, and it must never appear in plaintext in this repo — **this repo is public**.

Prove it works before closing: one direct call to the provider from helium, using the key as
ansible will hand it over, returning a real completion. A key that exists but was never
exercised is the shape of failure this map exists to prevent.

## Acceptance criteria

- [x] An Anthropic **API** account exists, distinct from the Claude Code subscription, with
      billing configured. The owner supplied a key in the `sk-ant-api03-…` shape (the API key
      format, not `CLAUDE_CODE_OAUTH_TOKEN`'s shape) — consistent with a real API account, per
      `09`'s D4. Billing configuration itself isn't remotely verifiable; taken on the owner's
      word.
- [x] The key is stored in the repo's sops-encrypted secrets and decrypts on helium. Stored via
      `sops set … --value-file` (never printed the raw key to stdout at any point — see
      Progress). Decryption verified live: ansible rendered it into
      `/data/ssd/appdata/hermes/.env` on helium and the call below used exactly that file.
- [x] The key appears nowhere in plaintext in git. `git status`/`git diff` on
      `secrets.sops.yml` show only the `ENC[...]` ciphertext.
- [x] One live call from helium using that key returns a completion, and the command used is
      recorded in this ticket so a later session can re-run it rather than re-derive it. See
      Progress.
- [x] The monthly ceiling from `09` ($25) is recorded as a **token** count with the price and
      the date it was priced. See Progress — and note `09`'s own pricing table is stale.

## Progress (2026-08-12)

**Secrets landed.** `anthropic_api_key` (and, ahead of `017`, `telegram_bot_token`) added to
`ansible/host_vars/helium/secrets.sops.yml` via:
```
sops set secrets.sops.yml '["anthropic_api_key"]' <jsonfile> --value-file
```
where `<jsonfile>` holds the key JSON-encoded (`sops set` requires the value be valid JSON, and
`--value-file` is what keeps the raw secret out of the process list). Verified round-trip via
`md5sum` before touching the real file — never decrypted to stdout.

Ansible role changes: `roles/compose_stack/templates/hermes.env.j2` (Hermes' **own** `.env`
inside its state volume, `$HERMES_HOME/.env` — confirmed in the image source,
`hermes_cli/env_loader.py:load_hermes_dotenv`, that this is where python-dotenv reads it at
process start; this is deliberately NOT `stack.env.j2`, which feeds compose's own substitution
and would land the key in `docker inspect` output). A new `stack.yml` task renders it
(`no_log: true`) and a new handler restarts `hermes-agent` so the process picks up the value —
mirrors the existing traefik-dynamic-config pattern. `TELEGRAM_BOT_TOKEN` is deliberately
**not** in this file yet — see `017`'s progress for why.

**Live call, from helium, using the deployed key** (2026-08-12):
```
docker exec hermes-agent sh -c 'set -a; . $HERMES_HOME/.env; set +a; curl -s https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" \
  -d "{\"model\":\"claude-haiku-4-5-20251001\",\"max_tokens\":16,\"messages\":[{\"role\":\"user\",\"content\":\"Say only the word: verified\"}]}"'
```
Returned a real completion: `{"content":[{"type":"text","text":"verified"}], "usage":
{"input_tokens":13,"output_tokens":4}, ...}`. `hermes doctor` also independently reports `✓
Anthropic API` under its connectivity checks, but that's a lighter ping — this curl call is the
actual "returns a completion" proof the acceptance criterion asks for.

🔴 **Correction to `09`'s D6 cost table — it's already stale.** Fetched
<https://platform.claude.com/docs/en/about-claude/pricing> on 2026-08-12: **Claude Sonnet 5 is
$2/MTok input, $10/MTok output** — not the $3/$15 `09` recorded on 2026-08-06. The page's own
note explains why: *"The $2/$10 per million input/output token pricing for Claude Sonnet 5,
announced at launch as introductory pricing through August 31, 2026, is now the standard
price. The previously scheduled increase to $3/$15 … will not occur."* `09`'s table needs the
same correction wherever it's read next; not edited here to keep this ticket's diff to its own
scope, but flagged so nobody carries the stale figure forward.

**The $25/month ceiling, converted to tokens (priced 2026-08-12, Claude Sonnet 5, $2/$10 per
MTok):** `09`'s own sizing is ~30k input / ~2k output per run (30 runs/month) — a 15:1
input:output blend. At that blend, blended price = 0.9375 × $2 + 0.0625 × $10 = **$2.50 per
blended MTok**. $25 ÷ $2.50/MTok = **10,000,000 tokens/month** at that blend. Expected actual
usage (30 × 32k ≈ 960k tokens/month) sits at roughly **10% of the ceiling** — a real safety
margin, not a number picked to look tight. `026` is where this actually becomes an alarm
(`09`'s D6(b): a separate `no_agent` post-brief job reading `session_model_usage`); this ticket
only owes the number and its provenance.

## Blocked by

- None — can start immediately.
