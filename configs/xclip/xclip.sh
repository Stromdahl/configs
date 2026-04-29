# shellcheck shell=bash
# xclip aliases.
# Sourced from ~/.bashrc via ~/.bashrc.d/.

alias xci='xclip -rmlastnl -in -selection  clipboard'
alias xcie='xci <<<' # Works line "echo" but for clipboard
alias xcif='xci <' # Reads a file to clipboard
alias xco='xclip -out -selection clipboard'
alias xcpi='xclip -in'
alias xcpo='xclip -out'
