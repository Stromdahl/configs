# shellcheck shell=bash
# Claude Code's clipboard-image detection checks $DISPLAY (X11) before
# $WAYLAND_DISPLAY. On a Wayland session that also has XWayland running
# (both vars set), it queries the empty XWayland clipboard instead of the
# real Wayland one, so Ctrl+V after a screenshot fails with "No image in
# clipboard" even though `wl-paste` sees the image fine. Drop $DISPLAY for
# the claude process only, so it falls back to the Wayland clipboard.
claude() {
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        (unset DISPLAY; command claude "$@")
    else
        command claude "$@"
    fi
}

# Start a new claude session with the clipboard contents as the initial
# prompt. Mirrors the `xco` alias from the wl-clipboard / xclip snippets, but
# has to pick the paste tool itself — aliases don't expand inside a function
# body.
xcoclaude() {
    local text
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-paste >/dev/null 2>&1; then
        text=$(wl-paste --no-newline)
    elif command -v xclip >/dev/null 2>&1; then
        text=$(xclip -out -selection clipboard)
    else
        echo "xcoclaude: neither wl-paste nor xclip available" >&2
        return 1
    fi
    claude "$text"
}
