# hermes-helium ticket 019 — derived Hermes image.
#
# Per ticket 03's design, this derived image's job is exactly three things: the
# digest pin below, himalaya (deferred — see note), and the healthcheck script.
# Never use :latest — CI tags that on every main-branch commit, so it is main HEAD,
# not the newest release; upstream shipped six named releases in ~2 months.
#
# himalaya (needed by ticket 07's email triage) is deliberately NOT added here yet:
# its documented install is an unpinned `curl .../master/install.sh | sh`, and an
# unpinned layer on a digest-pinned image means a rebuild silently moves one thing
# while a rollback only restores the other. 025 owns pinning it properly. Until
# then this tag has no business claiming a binary it doesn't carry — hence
# `helium/hermes-agent:v2026.7.30`, not `...-himalaya`.
FROM nousresearch/hermes-agent:v2026.7.30@sha256:b869e64d6496d4763d5e4fb675b5f504cb23b0e35ec9b790481a56118602b10f

COPY --chmod=755 hermes-healthcheck /usr/local/bin/hermes-healthcheck

# start-period=120s: a cold boot on helium took ~40s before the gateway reported
# ready in ticket 03's own verification; double it for margin. interval/retries
# mirror ticket 03's design.
HEALTHCHECK --interval=60s --timeout=15s --start-period=120s --retries=3 \
	CMD ["/usr/local/bin/hermes-healthcheck"]
