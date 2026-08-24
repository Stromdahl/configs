# Issue 067 — secret audit of the public history of `planning/` and `issues/`

Swept 2026-08-24 on krypton, at `7d3643f`. Read-only: nothing was rotated,
nothing was rewritten, and no encrypted file was decrypted. Every command below
is re-runnable verbatim; the redaction wrapper is part of the method, not
decoration — it is what keeps a hit out of the transcript.

**Result: 6 hits, 0 live, 6 dead.** No rotation is required.

---

## Method

`$S` is any scratch directory.

### 1. Enumerate the commits

```
$ git log --oneline -- planning issues | wc -l
232
$ git log --merges --oneline -- planning issues | wc -l
0
$ git log --diff-filter=R --name-status --oneline -- planning issues   # (no output)
$ git log --pretty=format: --name-only -- planning issues | sort -u | grep -vE '\.(md|sh)$'   # (no output)
```

**232 commits**, **no merge commits**, **no renames**, **136 distinct paths**, all
`.md` or `.sh`. The three negatives matter for coverage: `git log -p` silently
omits merge diffs, a rename can carry content in with an empty diff, and a binary
would defeat a `grep` sweep. None of those apply here.

The ticket said "eighty-seven commits". Nothing reproduces that figure — `planning
+ issues` is 232, `issues` alone 129, `planning/personal-forge + issues` 176,
`planning/personal-forge` alone 49 — so it counted some narrower path set that is
not recoverable from the ticket text. The sweep below is a strict superset either
way, which is the safe direction to be wrong in.

### 2. Two sweeps, deliberately redundant

**Sweep A — every added line, via the patch stream:**

```
$ git log -p --no-color --unified=0 -- planning issues > $S/history.patch
$ wc -l < $S/history.patch
29429
```

**Sweep B — every version of every file, via the object store.** This is the
completeness check: it does not depend on diff semantics at all.

```
$ git rev-list --all -- planning issues | while read c; do
    git ls-tree -r "$c" --format='%(objectname)' -- planning issues
  done | sort -u > $S/blobs.txt
$ wc -l < $S/blobs.txt
495
$ git cat-file --batch < $S/blobs.txt > $S/allblobs.txt
$ wc -l < $S/allblobs.txt
81810
```

495 distinct blobs — every historical revision of all 136 paths.

**Sweep C — the commit messages of those same commits.** They are just as public
and just as permanent as the file content, and neither sweep above touches them:

```
$ git log --all --format='%B' -- planning issues > $S/msgs.txt
$ wc -l < $S/msgs.txt
468
```

All three pattern sets below were run against `$S/msgs.txt` as well. **Zero hits
across P1–P12 and R1–R9.** Two Q-set hits, both benign: one message names
`settleup.stromdahl.io` (a hostname, already-public DNS) and one names the
*variable* `TELEGRAM_ALLOWED_CHATS in .env` with no value.

### 3. The pattern set

Written to `$S/patterns.txt`, one PCRE per line, and run as
`while IFS= read -r p; do grep -cPa -- "$p" <corpus>; done < $S/patterns.txt`:

```
ghp_[A-Za-z0-9]{20,}
github_pat_[A-Za-z0-9_]{20,}
gh[pousr]_[A-Za-z0-9]{20,}
AGE-SECRET-KEY-1[A-Z0-9]{10,}
-----BEGIN [A-Z ]*PRIVATE KEY-----
xox[baprs]-[A-Za-z0-9-]{10,}
AKIA[0-9A-Z]{16}
sk-[A-Za-z0-9]{20,}
eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.
[Aa]uthorization: *[Bb]earer +[A-Za-z0-9._~+/=-]{8,}
[Xx]-[Aa]pi-[Kk]ey: *[A-Za-z0-9._~+/=-]{8,}
(?i)(password|passwd|secret|token|api[_-]?key|apikey|private[_-]?key|credential)["']? *[:=] *["']?[^\s"'<>{}$,)\]]{6,}
```

Second set (`patterns2.txt`) — hashes, blobs, and the ticket's "hostnames and
internal addresses" clause:

```
\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{20,}
\$[156]\$[./A-Za-z0-9]{8,}
(?i)passphrase
(?i)htpasswd
age1[a-z0-9]{30,}
[A-Za-z0-9+/]{40,}={0,2}
\b100\.(6[4-9]|[7-9][0-9]|1[0-1][0-9]|12[0-7])\.[0-9]{1,3}\.[0-9]{1,3}\b
\b(192\.168|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)[0-9.]+
\b([0-9]{1,3}\.){3}[0-9]{1,3}\b
[a-z0-9-]+\.(home\.)?stromdahl\.(tech|io|se|com)
```

Third set (`patterns3.txt`) — the ticket's "credential quoted inline in a
resolution or a measurement transcript" clause, which is the shape a regex for
`ghp_` will never catch:

```
curl [^\n]*(-u |--user )
Basic [A-Za-z0-9+/=]{12,}
(?i)\b(admin|root|user)(name)?[ ]*[:=][ ]*\S+[ ]*[/:][ ]*\S+
(?i)FORGEJO_[A-Z_]*(TOKEN|PASSWORD|SECRET)[ ]*=[ ]*\S+
(?i)(ADMIN|DB|POSTGRES|MYSQL|REDIS)_PASSWORD[ ]*=[ ]*\S+
(?i)LOCK_?(SECRET|KEY)|JWT_SECRET|SECRET_KEY[ ]*=[ ]*\S+
(?i)sops +-d
ssh-(rsa|ed25519) AAAA[A-Za-z0-9+/]{20,}
(?i)mfa|totp|otpauth://
(?i)\.env\b
```

**Bare unlabelled 32-hex values** deserve their own pass: the `*arr` / Jellyfin API
keys that dominate this homelab are exactly that shape, and they slip past both
P11/P12 (which need a label) and Q6 (which needs 40+ characters).

```
$ grep -oPa '\b[0-9a-f]{32}\b' $S/allblobs.txt | sort -u | wc -l
0
```

**Zero** — not one 32-hex string in 82k lines, so there is not even md5sum noise to
triage despite `| md5sum` being the house verification idiom.

No scanner was installed. `command -v gitleaks trufflehog` found neither, and
installing a tool to scan 82k lines of markdown was not worth the ask — the
pipeline above is the method of record and re-runs with no dependencies.

### 4. Redaction wrapper (used on every listing)

Hits were never printed raw. The assignment's value is truncated to four
characters and its length reported:

```
$ grep -Pa -- "<P12>" $S/allblobs.txt | perl -pe 's/((?i:password|passwd|secret|token|api[_-]?key|apikey|private[_-]?key|credential)["\x27]? *[:=] *["\x27]?)([^\s"\x27<>{}\$,)\]]{6,})/$1 . substr($2,0,4) . "***" . length($2)/ge' | sort | uniq -c
```

---

## Raw counts

| Set | Pattern | Patch stream | Blob store |
|---|---|---|---|
| P1–P11 | `ghp_`, `github_pat_`, `gh[pousr]_`, `AGE-SECRET-KEY-`, `BEGIN … PRIVATE KEY`, `xox*`, `AKIA`, `sk-`, JWT, bearer header, api-key header | **0 each** | **0 each** |
| P12 | generic `secret/token/password/api_key` assignment | 5 unique | 8 (5 unique) |
| Q1–Q2, Q4–Q5 | bcrypt/crypt hashes, `htpasswd`, `age1` recipient | 0 | — |
| Q3 | `passphrase` | 2 | — |
| Q6 | 40+ char base64-ish run | 275 | — |
| Q7–Q10 | mesh IPs, RFC1918, all IPv4, `*.stromdahl.*` | 16 / 30 / 53 / 105 | — |
| — | bare `\b[0-9a-f]{32}\b` (unlabelled arr/Jellyfin key shape) | — | **0** |
| R1–R2, R4–R6, R8 | `curl -u`, `Basic`, service-password env assignments, SSH pubkeys | **0 each** | — |
| R3 | `admin:`/`user:` pair | 8 | — |
| R7 | `sops -d` | 2 | — |
| R9 | MFA/TOTP | 1 | — |

Both sweeps agree: the only credential-*shaped* material in the entire history of
these two directories is the P12 set, and only one of its five members is
actually credential-shaped rather than a prose false positive.

---

## Hit table

| # | Where | Redacted shape | Live/dead | Justification |
|---|---|---|---|---|
| 1 | `planning/personal-forge/assets/04-runner-topology-research.md`, commit `39a0959`, in the `server:` YAML block (`token: d4fe***`, 40 chars, plus `uuid: 33834eef-…`) | 40-char hex runner registration token | **DEAD** | Verbatim Forgejo documentation example. `curl -sL https://forgejo.org/docs/latest/admin/actions/registration/` and `grep -qF` on both values matches the live docs page exactly — the token and the uuid are upstream's sample values; only the `url:` line was adapted to `git.home.stromdahl.tech`. The byte-match is decisive on its own: the value never belonged to us, so there is nothing it could authenticate against. |
| 2 | `04-runner-topology-research.md` (×2 lines, ×3 blob revisions) | `permissions: id-token: writ***` | **DEAD** | Not an assignment — a quoted GitHub Actions workflow permission literal (`id-token: write`). The regex matched the word `write`. |
| 3 | `planning/personal-forge/assets/05-prototype-notes.md` (×2 revisions) | `--must-change-password=fals***` | **DEAD** | A CLI flag value (`false`), not a credential. The prototype's actual admin password is not in the corpus (R4/R5 = 0). |
| 4 | `planning/hermes-helium/assets/10-telegram-authz-probe.md` (×3 revisions; commits `452d2c6`, `35b8e06`, `f3419a2`) | `printf 'TELEGRAM_BOT_TOKEN=…\n…\nANTHROPIC_API_KEY=…\n' > $D/.env` | **DEAD** | Both token values are written as a literal ellipsis `…` in the transcript — the author elided them at capture time. The line also carries `TELEGRAM_ALLOWED_USERS=8468278488`, which is a Telegram numeric user id (an identifier, not a bearer credential). |
| 5 | `planning/personal-forge/assets/04-runner-topology-research.md` | `EB114F5E6C0DC2BCDD183550A4B61A2DC5923710` | **DEAD** | Forgejo's **public** release-signing GPG fingerprint, quoted next to "Good signature from Forgejo". Public by construction. |
| 6 | `issues/024-radon-stack-traefik-settleup.md:79` | `ClientHost=90.***.***.**` — a residential IPv4 | **DEAD as a credential; live as a disclosure** | Krypton's home public IP, quoted from a Traefik access log to prove Traefik records the real client IP rather than a Cloudflare edge address. Not a secret and not rotatable in the credential sense (dynamic ISP assignment; every service the user connects to already sees it). Flagged for the owner's awareness only — see below. |

### Not hits, but checked and cleared

- **Q6's 275 base64-ish runs**: 237 are unique 40-hex digests (image/commit
  digests) and the rest are URL path fragments split at a `/` (`org/docs/latest/…`).
  Nothing decodable, nothing credential-shaped.
- **Q3 `passphrase` (2)**: both are prose about *where a passphrase should come
  from* ("sourced from sops (never landing in git or world-readable)"), not a value.
- **Q7–Q10 hostnames and internal addresses**: `100.65.22.72` (helium's mesh IP,
  16×), `192.168.1.{99,153,165,191}`, `192.168.124.60`, `2.24.160.184` (radon,
  already public DNS), and 105 mentions of `*.stromdahl.tech` /
  `*.stromdahl.io`. All are RFC1918/CGNAT-range addresses reachable only from the
  LAN or the NetBird mesh, or names a public wildcard DNS record already
  publishes. Disclosure, not credential — and the design already assumes the
  names are public (that is what the Cloudflare wildcard does). No rotation
  applies.
- **R3's 8 `admin:`/`user:` pairs**: every one is a `user: "1001:1003"` uid:gid
  compose directive.
- **R7's 2 `sops -d`**: both are prose describing verification-without-stdout
  (`sops -d --extract … | md5sum`). No decryption happened during this audit.
- **R9's 1 MFA hit**: prose noting the Proton Bridge login needs interactive 2FA.

---

## Conclusion

**No live secret is present in the public history of `planning/` or `issues/`.**
Nothing to rotate, so acceptance criterion 3 has no work to do — it is ticked as
vacuous, *not* on the strength of an owner acceptance, which nobody gave. The one
credential-shaped 40-character token is upstream documentation's own example
value, verified against the live docs page rather than assumed.

Two standing notes for the owner, neither blocking:

1. **`issues/024` publishes the home public IP.** Dead as a credential, but it is
   a permanent, unremovable disclosure of a residential address-adjacent
   datapoint. If that is unwanted the mitigation is *not* a history rewrite
   (which the ticket rules out and which would not unpublish it anyway) — it is
   simply to stop quoting client IPs in future access-log excerpts.
2. **The corpus is clean because the house habit already works** — measurement
   transcripts in this repo elide token values at capture time (hit 4) and prefer
   `| md5sum` over `sops -d` to stdout (R7). This audit is a re-runnable check on
   that habit, not a one-off: re-run §2–§3 after any large planning push.
