---
name: commit-all
description: Commit the entire working tree — sweep up everything dirty, not just this session's work. Type /commit-all to inspect all modified and untracked files, partition them into logical groups, propose a commit message per group, review the full batch, then make one commit per group. Add the token `push` (/commit-all push) to also push to the current branch's upstream. Defaults to no push.
disable-model-invocation: true
---

Invoke the `committing` skill with **scope = worktree**: commit *every* dirty
path in the working tree (modified + untracked, `.gitignore` respected),
partitioned into logical atomic commits with a proposed message per group.
Present the full batch for review — the user can merge, reword, drop, or move
files — before any commit is written.

If the arguments contain the token `push`, push to the current branch's upstream
after the commits succeed; otherwise commit only.
