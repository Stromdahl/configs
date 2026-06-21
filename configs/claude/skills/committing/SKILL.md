---
name: committing
description: The shared engine behind /commit and /commit-all — enumerates real changes, groups them into atomic commits, proposes one-line messages in the repo's convention, confirms, commits, and optionally pushes. Invoked by name from the commit / commit-all slash skills with a scope. Do NOT auto-invoke during ordinary work — committing is a deliberate, history-writing action that runs ONLY when the user explicitly asks to commit (via /commit or /commit-all).
---

# Committing

Turn the working tree into clean, atomic commits. The caller passes a **scope**;
everything else — grouping, message style, the confirm gate, optional push — is
identical regardless of scope. This is the engine; `commit` and `commit-all` are
thin wrappers that only choose the scope.

## Scope

- **session** (from `/commit`) — commit what *this session* worked on.
- **worktree** (from `/commit-all`) — commit *everything* dirty in the worktree.

## Procedure

1. **Ground truth first.** Run `git status --porcelain` and `git diff --stat` to
   enumerate what is *actually* changed — modified, staged, and untracked (`??`)
   files alike. `.gitignore` is respected, so scratch like `prompts/` never
   appears. This real list — not memory — is the universe of what can be
   committed. The model cannot commit a file it only imagines editing, nor miss
   one it forgot.

2. **Apply the scope** to that real list:
   - **session** → *attribution filter*: of the actually-dirty paths, keep the
     ones this session edited or created (from this conversation's Edit / Write /
     Bash tool history, including new untracked files it wrote). If dirty paths
     exist that the session has **no** memory of touching, do not silently
     include or exclude them — list *those specific paths* and ask whether they
     belong in this commit. (If the session history isn't in context at all —
     fresh session, post-compaction — say so and offer `/commit-all` or an
     explicit file list instead of guessing.)
   - **worktree** → take all dirty paths.

3. **Group into atomic commits.** Partition the in-scope files into logical
   groups, one commit per coherent change. Granularity is **file-level** — a
   file goes whole into a single commit; no hunk-level `git add -p` splitting.
   For **session** scope this is usually one group (one feature → one commit) but
   split when the session clearly touched unrelated things. For **worktree**
   scope, expect several groups.

4. **Propose, don't surprise.** Print the plan in one shot — for each commit, the
   files it includes and its one-line subject. Then gate on the caller's
   confirmation style:
   - session → a quick one-line confirm ("commit this? / adjust?").
   - worktree → present the full batch for review; let the user merge groups,
     reword, drop a group, or move a file before anything is written.

5. **Execute** each approved group in order: `git add -- <paths>` then
   `git commit -m "<subject>"`. Stage explicitly per group (don't rely on or
   disturb pre-existing staging beyond what each group needs).

6. **Push only if asked.** If the caller's arguments contain the token `push`,
   push **after** all commits succeed: `git push` to the current branch's
   configured upstream. If the branch has **no** upstream, ask which remote
   rather than guessing (repos may have several remotes). With no `push` token,
   stop at the commits — never push.

## Message convention

- **Single subject line only.** Exactly one `-m "subject"`; no body, no
  blank-line-then-explanation, no HEREDOC.
- **Match the current repo's log.** Read recent `git log --oneline` and follow
  its prefix style (e.g. `area: change`). Keep the subject under ~70 chars,
  imperative mood.
- **Never add an AI-attribution / `Co-Authored-By` trailer.** The commit message
  is the subject and nothing else.

## Guardrails

- **No branch gymnastics.** Commit (and push, if asked) on whatever branch is
  checked out. No auto-branching, no special-casing the default branch.
- **Nothing in scope?** Report "nothing to commit" and stop.
- **A pre-commit hook fails?** Surface the failure and stop. Do not retry with
  `--no-verify` unless the user explicitly says to.
