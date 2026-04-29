# shellcheck shell=bash
# fzf shell integration (sourcing + helpers).
# Sourced from ~/.bashrc via ~/.bashrc.d/.

[ -f ~/.fzf.bash ] && source ~/.fzf.bash
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
[ -f /usr/share/doc/fzf/examples/completion.bash ] && source /usr/share/doc/fzf/examples/completion.bash

# Checkout a git branch via fzf
gbfzf() {
  local branches branch
  branches=$(git --no-pager branch -vv) &&
  branch=$(echo "$branches" | fzf +m) &&
  git checkout $(echo "$branch" | awk '{print $1}' | sed "s/.* //")
}

# Pick a PID via fzf
p() {
  ps aux | fzf --tiebreak=length | awk '{print($2)}'
}
