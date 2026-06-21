---
name: commit
description: Commit what the current Claude Code session worked on — wrap up a feature at the end of a session. Type /commit to stage and commit only the files this session edited or created (grouped into atomic commits when they span unrelated changes), then report the result — no confirmation. Add the token `push` (/commit push) to also push to the current branch's upstream. Defaults to no push.
disable-model-invocation: true
---

Invoke the `committing` skill with **scope = session**: commit the files *this
session* edited or created, grounded against the actual working tree, grouped
into atomic commits (default one, split when the session touched unrelated
things), then report the result. No confirmation before committing.

If the arguments contain the token `push`, push to the current branch's upstream
after the commits succeed; otherwise commit only.
