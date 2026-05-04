# shellcheck shell=bash
# Clipboard aliases (Wayland via wl-clipboard).
# Sourced from ~/.bashrc via ~/.bashrc.d/.

alias xci='wl-copy --trim-newline'
alias xcie='xci <<<' # Works like "echo" but for clipboard
alias xcif='xci <'   # Reads a file to clipboard
alias xco='wl-paste --no-newline'
alias xcpi='wl-copy --primary --trim-newline'
alias xcpo='wl-paste --primary --no-newline'
