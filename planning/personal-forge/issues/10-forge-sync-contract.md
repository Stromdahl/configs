# The `forge sync` contract

Type: grilling
Status: open
Blocked by: 01

## Question

A restore command is in scope: the half that makes "helium has my code" a tested
fact rather than a belief. It reads the forge's repo list and reconciles it with
`~/projects`.

Settle its contract with the owner (`/grilling`), using ticket 01's findings on
the Forgejo API and auth model:

1. **Directions.** Which of these does it do?
   - **Clone missing** — repos on the forge that are not on this machine (the
     fresh-laptop restore case).
   - **Fetch existing** — pull down what was pushed from elsewhere.
   - **Report drift** — local repos **not** on the forge. This is the one that
     catches the real failure mode: a repo created six months from now and never
     pushed. It is also the only direction that needs no network write.
   - **Push** — actually create and push the missing ones, or just name them?
2. **Read-only by default?** Recommendation: yes — report and clone, never push or
   delete without an explicit flag. A sync tool that force-pushes is a foot-gun,
   and this one runs on a machine holding the only other copy.
3. **Where it lives.** `~/.dotfiles/bin/` alongside the other wrappers, per
   `feedback_extend_wrapper_first`. Name, language (bash + `curl`/`jq` vs
   something typed), and whether it needs a config file or reads everything from
   the forge.
4. **Auth.** A Forgejo API token on krypton — where does it live? (sops-encrypted
   in the repo, `pass`, or a plain file in `~/.config`?) Note the house rule:
   `feedback_sops_no_stdout`.
5. **What it does about the exclusions.** Ticket 06 rules some directories out
   (upstream Marlin clones, non-git dirs). Does `sync` know about them, or does it
   report them as drift forever? An ignore list of some kind is probably needed.
6. **Archived repos.** A repo archived on the forge (ticket 06) — does `sync`
   clone it onto a fresh machine, or skip it?

Output: a precise enough contract that building it is execution, not design.
