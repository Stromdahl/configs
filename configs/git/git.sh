# shellcheck shell=bash
# Git: __git_ps1 + helpers + aliases.
# Sourced from ~/.bashrc via ~/.bashrc.d/.

# Load __git_ps1 (used by the prompt in bashrc)
if [ -z "${__GIT_PROMPT_SOURCED:-}" ]; then
  for f in /usr/share/git/completion/git-prompt.sh \
           /etc/bash_completion.d/git-prompt \
           /usr/local/etc/bash_completion.d/git-prompt; do
    [ -r "$f" ] && . "$f" && __GIT_PROMPT_SOURCED=1 && break
  done
fi

# Git prompt indicators (read by __git_ps1)
GIT_PS1_SHOWDIRTYSTATE=1
GIT_PS1_SHOWSTASHSTATE=1
GIT_PS1_SHOWUNTRACKEDFILES=1

# cd to the top-level of the current git repo
cdgr() {
  local inside_git_repo
  inside_git_repo="$(git rev-parse --is-inside-work-tree 2>/dev/null)"
  if [ "$inside_git_repo" ]; then
    cd "$(git rev-parse --show-toplevel)" || return
  fi
}

wthelp() {
  cat <<'EOF'
Git Worktree Commands
─────────────────────────────────────────────────────
  wtl                    List all worktrees
  wts                    Status (git status --short) for each worktree
  wta  <branch> [path]   Add worktree with new local branch
  wtat <branch> [path]   Add worktree tracking existing remote branch
  wtr  <path>            Remove a worktree
  wtp                    Prune stale worktree refs
  wcd                    cd into a worktree (fzf)
  wto                    Open a worktree in a new terminal (fzf)
EOF
}

# cd into a worktree via fzf
wcd() {
  local wt
  wt=$(git worktree list | fzf --with-nth=1 | awk '{print $1}')
  [ -n "$wt" ] && cd "$wt"
}

# Open a worktree in a new foot terminal
wto() {
  local wt
  wt=$(git worktree list | fzf --with-nth=1 | awk '{print $1}')
  [ -n "$wt" ] && foot --working-directory="$wt" &
}

# Status / log shortcuts
alias gs='git -c color.status=always status --short | sort -r'
alias gsi='git status --short --ignored'
alias glg='git log --graph --oneline --branches --tags --remotes'

# Worktree shortcuts
alias wt='git worktree'
alias wtl='git worktree list'
alias wtp='git worktree prune --expire=now'
alias wts='git wts'
alias wta='git wta'
alias wtat='git wtat'
alias wtr='git wtr'
