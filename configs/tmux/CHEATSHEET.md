# tmux cheat sheet

Tailored to *this* config (`~/.config/tmux/tmux.conf`). View it anytime with
`less ~/.config/tmux/CHEATSHEET.md`.

**The prefix is `C-b`** (Ctrl+b). Notation: `C-b c` = press Ctrl+b, release,
then press `c`. `C-b C-s` = press Ctrl+b, release, then press Ctrl+s.

`★` = a custom binding from this config. Everything else is a tmux default.

---

## From the shell (no prefix — you type these as commands)

| Command | Does |
|---|---|
| `tmux` | Start a new session |
| `tmux new -s work` | Start a session named `work` |
| `tmux ls` | List sessions |
| `tmux attach` / `tmux a` | Reattach to the last session |
| `tmux a -t work` | Reattach to session `work` |
| `tmux kill-session -t work` | Kill session `work` |
| `tmux kill-server` | Kill **all** sessions |

The core trick: `C-b d` to detach (tmux keeps running in the background),
`tmux a` to come back exactly where you left off — survives closed terminals,
dropped SSH, and (thanks to the plugins) reboots.

---

## Sessions

| Keys | Does |
|---|---|
| `C-b d` | Detach (leave tmux running) |
| `C-b s` | Interactive session list — pick one to switch |
| `C-b $` | Rename the current session |
| `C-b (` / `C-b )` | Previous / next session |

## Windows (like tabs)

| Keys | Does |
|---|---|
| `C-b c` | ★ New window (opens in current pane's directory) |
| `C-b ,` | Rename current window |
| `C-b &` | Kill current window (asks first) |
| `C-b n` / `C-b p` | Next / previous window |
| `C-b 1` … `C-b 9` | Jump to window by number (windows start at 1) |
| `C-b w` | Interactive window/session tree — pick one |
| `C-b f` | Find a window by name |

> Note: `C-b l` is normally "last window" but this config repurposes `l` for
> pane navigation (below). Use `C-b n`/`C-b p` or a number instead.

## Panes (splits)

| Keys | Does |
|---|---|
| `C-b \|` | ★ Split left/right (keeps current directory) |
| `C-b -` | ★ Split top/bottom (keeps current directory) |
| `C-b %` / `C-b "` | Default split bindings (still work) |
| `C-b h` `j` `k` `l` | ★ Move to pane left / down / up / right (vim-style) |
| `C-b ←↓↑→` | Move between panes (arrow-key default, still works) |
| `C-b H` `J` `K` `L` | ★ Resize pane (hold prefix; repeatable for ~0.5s) |
| `C-b z` | Zoom current pane to fullscreen (toggle) |
| `C-b o` | Cycle to the next pane |
| `C-b ;` | Jump to the last-used pane |
| `C-b q` | Show pane numbers (press the number to jump) |
| `C-b {` / `C-b }` | Swap pane with previous / next |
| `C-b space` | Cycle through preset layouts |
| `C-b x` | Kill current pane (asks first) |
| `C-b !` | Break the current pane out into its own window |

## Copy / scrollback mode (vim keys)

| Keys | Does |
|---|---|
| `C-b [` | Enter copy mode (scroll back through history) |
| `q` | Quit copy mode |
| `h j k l` / arrows | Move the cursor |
| `C-u` / `C-d` | Half-page up / down |
| `g` / `G` | Jump to top / bottom of history |
| `/` then text | Search forward (`?` searches backward) |
| `n` / `N` | Next / previous search match |
| `v` | ★ Start a selection |
| `C-v` | ★ Toggle block (column) selection |
| `y` or `Enter` | ★ Yank selection to the system clipboard (`wl-copy`) |
| `C-b ]` | Paste the last yank back into the terminal |

You can also just **scroll with the mouse** to enter copy mode, and
**drag to select** — releasing the drag copies to the clipboard.

## Plugins — session persistence

| Keys | Does |
|---|---|
| `C-b C-s` | Save all sessions/windows/panes to disk (tmux-resurrect) |
| `C-b C-r` | Restore the last save |
| `C-b I` | Install plugins declared in the config (TPM) |
| `C-b U` | Update installed plugins |
| `C-b M-u` | Remove plugins no longer declared |

Auto-save runs every 15 min, and the last save auto-restores the first time
you start tmux after a reboot (tmux-continuum).

## Handy / meta

| Keys | Does |
|---|---|
| `C-b C-h` | ★ Open this cheat sheet in a popup (press `q` to close) |
| `C-b ?` | **List every key binding** (your built-in reference) |
| `C-b :` | Command prompt (type tmux commands directly) |
| `C-b /` | Describe-key: press a key to see what it does |
| `C-b t` | Big clock |
| `C-b r` | ★ Reload `~/.config/tmux/tmux.conf` after editing |

---

### Mental model
- **Server** holds everything and runs in the background.
- A **session** is a workspace (e.g. one project). You attach/detach from it.
- A session has **windows** (tabs); each window has **panes** (splits).
- Detaching never stops your programs — they keep running until you kill the
  session or the machine reboots (and even then, the plugins bring the layout
  back).
