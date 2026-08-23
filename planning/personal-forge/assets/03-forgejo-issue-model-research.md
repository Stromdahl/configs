# Forgejo's issue model — can it carry the tracker *and* wayfinder maps?

Resolves `planning/personal-forge/issues/03-forgejo-issue-model.md`.
Researched 2026-08-23. Primary sources are `forgejo.org/docs`, `forgejo.org/releases`,
the `codeberg.org/forgejo/forgejo` source tree, the live OpenAPI spec at
`codeberg.org/swagger.v1.json`, and **live API calls against codeberg.org** (which
runs Forgejo). Gitea's own CHANGELOG is the primary source for Gitea-origin
version numbers. Claims verified empirically are marked **(verified live)**.

Versions in scope: current stable **v16.0.3** (2026-08-20), current LTS
**v15.0.7** (2026-08-20) — <https://forgejo.org/releases/>. Ticket 01 recommends
pinning the **LTS (`:15`)** line, so the GO rests on **v15** — and evidence
strength differs by item, which is worth naming. The **attachment constants, the
token-scope list and the `[api]` paging constants were read at both the
`v15.0.7` and `v16.0.3` tags** and are byte-identical. The **dependency
endpoints, `internal_tracker`, and the `type=issues` listing behaviour were
verified against codeberg's live `16.0-dev`** and dated by provenance (present
since Forgejo v1.18.0-0 / the API since Gitea 1.20.0) rather than re-read at the
`v15.0.7` tag — near-certainly present in v15 given their age, but **inferred,
not tag-verified**. Codeberg runs
`16.0.0-dev-694-33ae492b+gitea-1.22.0`, i.e. slightly *ahead* of stable, so
live evidence is an upper bound — load-bearing constants were re-verified against
the release tags.

**Reading order.** §1 and §2 decide the verdict. §7 is the adapter mapping the
design question actually asked for. §8 is the verdict for ticket 07.

---

## 1. Blocking dependencies — **native, cross-repo, fully API-driven**

**Verdict: yes, and better than the GitLab free tier.** This is the load-bearing
wayfinder requirement and Forgejo satisfies it natively, with no paid tier and no
fallback needed.

**Provenance.** Inherited from Gitea, where it landed in **Gitea 1.6.0**
(2018-11-22, "Added dependencies for issues (#2196) (#2531)" —
<https://github.com/go-gitea/gitea/blob/main/CHANGELOG-archived.md>). Present in
Forgejo since its **first release, v1.18.0-0** (2022-12-29), verified by the
dependencies block in
<https://codeberg.org/forgejo/forgejo/src/tag/v1.18.0-0/templates/repo/issue/view_content/sidebar.tmpl>.

**The REST API came later than the feature**: Gitea **1.20.0** (2023-07-16, "Add
API to manage issue dependencies (#17935)"), first appearing in Forgejo
**v1.20.1-0** (2023-07-24). *Flagged as inference:* that Forgejo version is
derived from the Gitea CHANGELOG entry plus the Forgejo tag list (v1.19.0-0 and
v1.20.0-0 tags do not exist — the codeberg tags API 404s them, 200s
`v1.20.1-0`); no single Forgejo release-note states it. Irrelevant in practice —
we are deploying v15/v16, three years later.

**Cross-repo dependencies: yes**, since Gitea **1.11.0** (2020-02-10, "Allow
cross-repository dependencies on issues (#7901)"). Two app.ini keys, both in
section **`[service]`** (<https://forgejo.org/docs/latest/admin/config-cheat-sheet/>,
`modules/setting/service.go:244-245`):

- `DEFAULT_ENABLE_DEPENDENCIES` — default `true`. **Only the default for new repos.**
- `ALLOW_CROSS_REPOSITORY_DEPENDENCIES` — default `true`; "allow dependencies on
  issues from any repository where the user is granted access."

There is **no `ENABLE_ISSUE_DEPENDENCIES` key** — that name does not exist.

**Endpoints** (live swagger; `routers/api/v1/api.go:1190-1197`):

```
GET    /repos/{owner}/{repo}/issues/{index}/dependencies   -> Issue[]   # what blocks this
POST   /repos/{owner}/{repo}/issues/{index}/dependencies   body IssueMeta
DELETE /repos/{owner}/{repo}/issues/{index}/dependencies   body IssueMeta
GET    /repos/{owner}/{repo}/issues/{index}/blocks         -> Issue[]   # what this blocks
POST   /repos/{owner}/{repo}/issues/{index}/blocks         body IssueMeta
DELETE /repos/{owner}/{repo}/issues/{index}/blocks         body IssueMeta
```

The payload is **not a bare index** — it is an owner/repo/index object,
`IssueMeta` (`modules/structs/issue.go:272-281`):

```json
{ "owner": "ms", "repo": "lumin", "index": 7 }
```

**The two POSTs are mirror images and are easy to get backwards**
(`routers/api/v1/repo/issue_dependency.go`):

- `POST .../{index}/dependencies` — **path issue is the blocked one, body issue is
  the blocker.** Source comment: *"We want to make `<:index>` depend on `<Form>`,
  i.e. `<:index>` is the target."*
- `POST .../{index}/blocks` — **path issue is the blocker, body issue is the
  blocked one.** Summary: *"Block the issue given in the body by the issue in path."*

An adapter should pick **one** of these and never use the other, to remove the
chance of inverting an edge. `POST .../dependencies` is the right one: it reads
in the same direction as the `Blocked by:` line the other adapters use.

**No blocker summary on the issue object — a real N+1.** The `Issue` struct
carries no dependency field. Live swagger `definitions.Issue.properties` is
exactly: `assets, assignee, assignees, body, closed_at, comments, created_at,
due_date, html_url, id, is_locked, labels, milestone, number, original_author,
original_author_id, pin_order, pull_request, ref, repository, state, title,
updated_at, url, user`. **Nothing analogous to GitHub's
`issue_dependencies_summary`**, no bulk/expand parameter, and no dependency
filter on any issue-list endpoint.

Cost for a frontier: **1 list call + 1 `GET .../dependencies` per open child.**
(Not 2 — `/blocks` is the reverse direction and the frontier never asks it. And
"drop any with an assignee" is free, because `assignees` is on the list payload.)
At wayfinder scale — a map has on the order of ten tickets — that is ~11 requests
per `/wayfinder` invocation. Acceptable. Note `GET .../dependencies` paginates
**in memory after fetching all deps** and filters out issues the caller cannot
read, so a `page`/`limit` window can return fewer items than `limit`; just omit
the params.

**Enablement is per-repo, but it *is* introspectable — no blind pre-flight
needed.** `DEFAULT_ENABLE_DEPENDENCIES` only seeds new repos; live state is the
repo-unit field `EnableDependencies` (`models/repo/repo_unit.go:139`), UI label
"**Enable dependencies for issues and pull requests**"
(`options/locale/locale_en-US.ini:1743`). **(verified live)** it surfaces on the
repo API:

```
$ curl -s https://codeberg.org/api/v1/repos/forgejo/forgejo | jq .internal_tracker
{ "enable_time_tracker": false,
  "allow_only_contributors_to_track_time": true,
  "enable_issue_dependencies": true }
```

`InternalTracker.enable_issue_dependencies` is on both `GET /repos/{owner}/{repo}`
**and** `EditRepoOption`, so an adapter can *check* it and, given `write:repository`,
*turn it on*. An adapter should read it once and, if false, either PATCH it or
fall back to the `Blocked by: #<n>` body line both existing adapters already
document.

**Enforcement is server-side, not cosmetic.** `IssueNoDependenciesLeft` runs at
the end of `CheckPullMergeable` (`services/pull/check.go`), *outside* the
branch-protection skip logic — so neither `ForceMerge` nor repo-admin bypasses
it. Closing an issue with open blockers is likewise refused. **Gotcha for
automation:** the API merge handler (`routers/api/v1/repo/pull.go:947-966`) has no
case for `ErrDependenciesLeft` and falls through to
`ctx.InternalServerError` → **HTTP 500**, not a 405/412. The close-via-PATCH path
does return a clean 412 `"DependenciesLeft"`. Cross-repo attempts with the
setting off return **HTTP 400 `"CrossRepositoryDependencies not enabled"`**; the
web UI shows the *misleading* string "Both issues must be in the same repository"
in that case (`routers/web/repo/issue_dependency.go:47-48`) — that message does
**not** mean cross-repo is impossible.

*Documentation gap, flagged:* there is **no Forgejo user-facing doc page for issue
dependencies** — `/docs/latest/user/issue-pull-request-dependencies/` 404s and the
user-guide index lists no such page. Everything above rests on source,
`locale_en-US.ini`, the config cheat-sheet and live codeberg. The HTTP status
codes are read from source, not observed (no write token on a live instance).

---

## 2. Parent/child sub-issues — **absent, and not even in the dev build**

**Verdict: no.** This is the one hard gap, and it is decisively rather than
marginally absent:

- Tracking issue **forgejo/forgejo#5448 "feat: Sub-issues" is still OPEN** —
  <https://codeberg.org/forgejo/forgejo/issues/5448>.
- All three implementation attempts are **closed unmerged** (`merged: false` via
  the pulls API): **#6267** "WIP: feat(issues): Add sub-issues", **#10601** "WIP:
  subissues implementation", **#10930** "WIP: Sub Issues Implementation".
- **Not in the dev build either.** Codeberg's live swagger (`16.0.0-dev-694`) has
  zero paths matching `sub-issue`/`parent`, `Issue` has no `parent` field, and
  there is no `sub_issue`/`subissue`/`parent_id` string anywhere in
  `options/locale/locale_en-US.ini` on the `forgejo` branch.
- **Live sidebar evidence** (raw HTML of
  <https://codeberg.org/forgejo/forgejo/issues/5448>): the sections present are
  **Labels, Milestone, Projects, Assignees, Notifications, Due date,
  Dependencies ("No dependencies set"), Repository**. No Sub-issues section.
  Matches `templates/repo/issue/view_content/sidebar.tmpl`.

So Forgejo is answer **(b)**: markdown task-list checkboxes, no structural
hierarchy.

**Closest expressible substitutes, ranked by what Forgejo actually does:**

1. **A `wayfinder:map` label + `Part of #<map>` in each child body.** No
   structure, but this is *exactly the GitLab adapter's primary documented shape*
   and GitHub's own documented fallback. Zero novelty, already proven in use.
2. **Dependencies-as-hierarchy** — the only structural, machine-readable,
   API-queryable relation. But its semantics are "blocks", not "contains", and it
   enforces close/merge ordering. Using it for containment would mean the map
   could never be closed before its children *and* would pollute the very
   relation the frontier reads. **Do not do this.**
3. **A markdown task list in the map body** — real, but shallow, and *inert with
   respect to child state*. `GetTasks()`/`GetTasksDone()`
   (`models/issues/issue.go:146-147`) count literal `- [ ]` / `- [x]` characters
   in the parent's body with a regex and render an "N / M tasks" indicator.
   **Closing child #123 does not tick its box** — that is a manual body edit. And
   the task count is **not exposed in the API `Issue` struct at all**. Useful for
   a human-visible index and for *map order*; useless as a state source.
4. **Bare `#123` / `owner/repo#123` references** — these do render a real link and
   post a cross-reference comment on the target
   (<https://forgejo.org/docs/latest/user/linked-references/>), and keywords
   (`closes`, `fixes`) close on merge. But there is no "tracked by"/"parent of"
   semantic.
5. **Labels / milestones** — flat grouping only. Milestones give a % complete but
   are one-level and repo-scoped.

**Recommended shape**: 1 + 3 together — label the map `wayfinder:map`, keep a task
list in its body **for ordering and human legibility only**, and put
`Part of #<map>` at the top of each child. Membership is then queryable two ways
(label the children `wayfinder:effort:<slug>`, or grep the `Part of` line);
ordering comes from the map body; state comes from the children.

---

## 3. Cross-repo views, search, and kanban

**Cross-repo dashboard: yes.** `GET /issues` and `GET /pulls` (plus org-scoped
`/{org}/issues`) — `routers/web/user/home.go`, `buildIssueOverview()`. Params:

| param | values |
|---|---|
| `type` | `created_by`, `assigned`, `mentioned`, `review_requested`, `reviewed_by`, `your_repositories` (default `created_by`; `your_repositories` on org pages) |
| `state` | `closed`, else open — **no "all"** on the dashboard |
| `q` | keyword, through the issue indexer |
| `sort` | indexer sort keys, default `recentupdate` |
| `repos` | `[1,2,3]` repo **IDs** |
| `labels` | comma-separated label **IDs** (negative = exclude, `0` = "no label") |
| `project` | project ID |

Two caveats: the label **picker is only populated in an org context**
(`GetLabelsByOrgID`, home.go:593) — on a *personal* dashboard you can pass label
IDs by URL but there is no selector; and **there is no milestone filter** on the
dashboard (`milestone` is a pager passthrough only, home.go:728). Both matter for
a single-user instance where repos are owned by a *user*, not an org — which
argues for creating a **Forgejo organization** to own the personal repos even
with one member, purely to get org-level labels and a working dashboard filter.

**Full-text search across repos: yes**, and it covers bodies and comments, not
just titles — `IndexerData` indexes `Title`, `Content`, `Comments []string`
(`modules/indexer/issues/internal/model.go`). Default indexer is bleve
(`ISSUE_INDEXER_TYPE` default `"bleve"`).

**REST cross-repo listing: `GET /repos/issues/search`.** Parameters, verbatim
from the spec: `state`, `labels`, `milestones`, `q`, `priority_repo_id`, `type`,
`since`, `before`, `assigned`, `created`, `mentioned`, `review_requested`,
`reviewed`, `owner`, `team`, `page`, `limit`, `sort`. Three asymmetries an
adapter must know:

- `labels=` / `milestones=` take **names**, resolved **globally with OR
  semantics** (`GetLabelIDsByNames`) — a name matches same-named labels in *any*
  repo. This is a **win** for wayfinder: `?labels=wayfinder:map&state=open` is a
  one-call "every open map across every repo".
- **No `created_by`/`assigned_by`/`mentioned_by` username params** — only the
  booleans `assigned`/`created`/`mentioned`, relative to the *authenticated
  user*. "All issues assigned to X" is not expressible unless X owns the token.
  For a single-user forge, irrelevant.
- **No `project` param** (the dashboard UI has one; the API does not).

**Pagination.** **(verified live)** `?limit=100` returned **50** items, with
`x-total-count: 9336` and RFC-5988 `link: …rel="next"/"last"` headers. The cap is
`[api] MAX_RESPONSE_ITEMS` (default 50); `DEFAULT_PAGING_NUM` default is **30**
(`modules/setting/api.go`, confirmed by `GET /api/v1/settings/api` →
`{"max_response_items":50,"default_paging_num":30,…}`). *Doc erratum:* the config
cheat-sheet's `[api] DEFAULT_PAGING_NUM = 10` is wrong — that value belongs to
`[repository.release]`.

**Projects / kanban: they exist, and they are invisible to the API.** This is
stronger than "UI-only".

- Both scopes exist: `models/project/project.go` defines `TypeIndividual`,
  `TypeRepository`, `TypeOrganization`. Repo boards at
  `/{owner}/{repo}/projects`, user/org boards at `/{username}/-/projects`.
  **Owner-level projects landed in Forgejo 1.19.0** (RELEASE-NOTES.md: "Support
  org/user level projects"). *Unverified:* when *repo*-level kanban first landed —
  it predates the fork and no Forgejo source names a version.
- Templates (`models/project/template.go`): none / basic-kanban / bug-triage.
  Default columns (`modules/setting/project.go`): `To do, In progress, Done` and
  `Needs triage, High priority, Low priority, Closed`, plus an always-created
  `Backlog`.
- **Cross-repo cards: yes, within one owner.** `IssueAssignOrRemoveProject` gates
  on `CanBeAccessedByOwnerRepo`; an org/user board accepts issues from any repo of
  that same owner, never across owners. A single user-level board is therefore a
  genuine cross-project kanban — which is the "UI the owner actually opens" that
  the tracker decision rests on.
- **But: zero `/projects` paths in the OpenAPI spec** (326 paths, none matching
  `project`); `grep -in project routers/api/v1/api.go` at v16.0.3 → no hits; the
  `Issue` definition has **no `project` field**; and no issue-list endpoint
  accepts a project filter. All board mutations are UI POST/PUT routes. **An
  agent cannot create, read, set, move, or filter by a board.** Boards are a
  human surface only, and nothing agent-driven may depend on them.
- **Naming trap:** the UI renamed "board" → "column" in 1.21, but the DB and JSON
  still say `project_board` / `board_type` / `project_board_id`.

**Milestones.** API is **per-repo only** (`/repos/{owner}/{repo}/milestones`); no
cross-repo milestone *endpoint*, though there is a cross-repo milestone **UI**
page at `/milestones`, and cross-repo milestone *filtering of issues* works via
`/repos/issues/search?milestones=<names>`.

---

## 4. The API surface an adapter needs

Base path `/api/v1`. All paths from <https://codeberg.org/swagger.v1.json>,
re-checked at the v16.0.3 and v15.0.7 tags.

**Issues**

- create `POST /repos/{owner}/{repo}/issues` — `CreateIssueOption`:
  `{title*, body, assignees[], labels[], milestone, due_date, closed, ref}`.
  **`labels` here is label *IDs only*** — an adapter must resolve names first.
- get `GET /repos/{owner}/{repo}/issues/{index}`
- edit `PATCH /repos/{owner}/{repo}/issues/{index}` — `EditIssueOption`:
  `{title, body, assignees[], milestone, state, ref, due_date, unset_due_date,
  updated_at}`. **Close = `PATCH {"state":"closed"}`**; there is no dedicated
  close endpoint, and **`EditIssueOption` has no `labels` field** — labels move
  only through the sub-resource.
- list in repo `GET /repos/{owner}/{repo}/issues` — `state` (`open`/`closed`/`all`),
  `labels` (names), `q`, `type`, `milestones` (names *or* ids), `since`, `before`,
  `created_by`, `assigned_by`, `mentioned_by`, `page`, `limit`, `sort`.
- also available: `/issues/{index}/timeline`, `/deadline`, `/pin`, `/reactions`,
  `/times`, `/issues/pinned`.

**Comments** — list/create `GET|POST /repos/{owner}/{repo}/issues/{index}/comments`;
repo-wide list `GET /repos/{owner}/{repo}/issues/comments`; edit/delete
`PATCH|DELETE /repos/{owner}/{repo}/issues/comments/{id}` (also available under
`/issues/{index}/comments/{id}`). *Gotcha:* `GET` of a **single** comment exists
only on the `/issues/comments/{id}` form.

**Labels** — repo `GET|POST /repos/{owner}/{repo}/labels`, `…/labels/{id}`;
**org-level `GET|POST /orgs/{org}/labels`** (needs the *organization* scope, not
issue). On an issue: `GET|POST|PUT|DELETE
/repos/{owner}/{repo}/issues/{index}/labels` (POST=add, PUT=replace, DELETE=clear)
and `DELETE …/labels/{identifier}` where identifier is **name or id**.
`IssueLabelsOption.labels` accepts ids **or** names — unlike `CreateIssueOption`.
Also `GET /label/templates` for the built-in sets. Label objects carry
`exclusive` and `is_archived`; `exclusive` (scoped `foo/bar` labels) is a good fit
for `wayfinder:<type>` if mutual exclusion is wanted.

**Assignees** — **no dedicated issue-assignee endpoint** (unlike PR reviewers).
Set via `PATCH …/issues/{index}` with `assignees: ["login"]`, which **replaces**
the set. **No `@me` sentinel anywhere in `routers/api/v1`.** Resolve the token
owner with **`GET /user`** and pass the login; or cross-repo, use the booleans
`assigned=true` on `/repos/issues/search`.

**Issue index vs global id.** Issues are addressed by **per-repo `index`** in
paths; the global `id` appears only in the response (`Issue.id` global,
`Issue.number` = index). **Comments, labels, milestones and attachments are
addressed by global `id`.** This is a meaningful contrast with the GitHub adapter,
which needs the *database id* for dependency edges — Forgejo does not: dependency
edges take `IssueMeta{owner, repo, index}`, i.e. the human-visible number. **The
GitHub adapter's most error-prone instruction disappears.**

**Auth.** `Authorization: token <token>` (spec `AuthorizationHeaderToken`: "API
tokens must be prepended with \"token\" followed by a space" —
<https://forgejo.org/docs/latest/user/api-usage/>). OAuth2 access tokens use
`Bearer`. BasicAuth is supported, plus `X-FORGEJO-OTP` under 2FA.

**Token scopes.** Scoped tokens arrived in **Forgejo v1.19**, and the scope
*strings* were **refactored in v1.20.1-0** into `read:`/`write:` categories
(RELEASE-NOTES.md). Full set (`models/auth/access_token_scope.go`, and
<https://forgejo.org/docs/latest/user/token-scope/>): `all`, `public-only`
(modifier), and `read:`/`write:` × `activitypub, admin, misc, notification,
organization, package, issue, repository, user`. Write implies read.

What an issue-tracker adapter needs:

- **`write:issue`** — buys the *entire* tracker surface. The route group at
  `api.go:1095` covers `/repos/issues/search`, all of
  `/repos/{o}/{r}/issues/**` (comments, labels-on-issue, `/assets`,
  **dependencies and blocks**), *and* repo-level `/labels` and `/milestones`.
- **`read:user`** — for `GET /user`, to resolve the login for claim/assignment.
- **`write:repository`** — only to flip `internal_tracker.enable_issue_dependencies`
  via `PATCH /repos/{owner}/{repo}`. Not needed for the issue endpoints.
- **`write:organization`** — only for org-level labels.

Scope checks layer *on top of* normal repo permissions
(`reqRepoReader/Writer(unit.TypeIssues)`); a v1.21 note records that issue-scoped
tokens no longer bypass team-level issue-vs-PR restrictions, which can surface as
404s.

**Rate limits: none built in.** No rate-limiting keys anywhere in
`custom/conf/app.example.ini` (2902 lines; grep for `rate`, `throttl`, `limiter`),
none in the config cheat-sheet, nothing in the api-usage doc, and **(verified
live)** no `X-RateLimit-*` headers on codeberg responses. Limiting is a
reverse-proxy concern — for helium, Traefik's middleware if ever needed. *Flagged
as negative evidence*: absence in primary sources, not an affirmative upstream
statement. The only response-shaping knob is `[api] MAX_RESPONSE_ITEMS = 50`.

**CLI tooling — there is no `gh`-grade client, and the adapter should not depend
on one.**

- **No official Forgejo client CLI.** `forgejo-cli` is a *server-side admin*
  subcommand whose command list is just `CmdActions`; the docs say explicitly it
  is "not to be confused with user CLIs"
  (<https://forgejo.org/docs/latest/admin/command-line/>).
- **`tea`** (gitea.com/gitea/tea) — v0.15.1, 2026-08-02, actively maintained.
  Works against Forgejo because Forgejo implements the Gitea `/api/v1` surface,
  but a grep of the whole v0.15.1 tree for "forgejo" returns **zero hits** — no
  support statement either way. Has issues, **comment CRUD**, labels, milestones.
  **No issue dependencies. No issue attachments.** `tea api` is the escape hatch.
  **Not in Debian** — and `apt install tea` gets the *TEA text editor*
  (<https://packages.debian.org/trixie/tea>). Install via release binary or
  `go install`.
- **`fj`** (codeberg.org/forgejo-contrib/forgejo-cli) — the de-facto Forgejo
  client, **community, not official** (separate org, MIT/Apache vs core's GPL-3,
  no Forgejo docs page names it). Rust, v0.6.0 (2026-07-19), 471 stars. Covers
  `issue create|view|search|close`, `comment`, `edit … labels --add/--rm`,
  `assign`/`unassign`, and — unlike tea — **`issue depend add|remove|list` and
  `issue block add|remove|list`**, with `owner/repo#123` cross-repo refs. **No
  milestones, no attachments.** Debian **sid only, at 0.3.0-9** — *not in trixie*,
  so `apt install forgejo-cli` fails on Debian 13, and 0.3.0 predates the
  depend/block work. 0.6.0 via `cargo install`, Arch, nix, brew, or tarball.

**Recommendation: the adapter should drive `/api/v1` directly** with
`curl`+`jq`, and treat both CLIs as human conveniences. `fj` covers dependencies
but not attachments; `tea` covers milestones but not dependencies; **neither
covers attachments, and neither can touch projects** (no API to touch). Depending
on either means a partial adapter plus a raw-API escape hatch anyway, and it adds
a non-Debian-packaged install to the dotfiles. A `bin/forge` wrapper in this repo
(the `bin/ha` pattern, per `feedback_extend_wrapper_first`) is the better shape:
one place for the base URL, the token, and the `type=issues` and `IssueMeta`
footguns.

---

## 5. Attachments — capable, but the recommendation is **link, don't attach**

**Mechanics.** `GET|POST /repos/{owner}/{repo}/issues/{index}/assets` and
`GET|PATCH|DELETE …/assets/{attachment_id}`; the same under
`/repos/{owner}/{repo}/issues/comments/{id}/assets`. POST is
`multipart/form-data`, **form field name `attachment`**, optional `name` and
`updated_at` query params. `Issue.assets` is on the issue payload, so attachments
are visible without an extra call.

**app.ini `[attachment]`** (`modules/setting/attachment.go`, identical at v16.0.3
and v15.0.7): `ENABLED` (`true`), `ALLOWED_TYPES`, `MAX_SIZE` (**2048**,
megabytes), `MAX_FILES` (**5**), `STORAGE_TYPE` (`local`), `PATH`
(`data/attachments`).

**Default `ALLOWED_TYPES`, verbatim at v16.0.3:**

```
.avif,.cpuprofile,.csv,.dmp,.docx,.fodg,.fodp,.fods,.fodt,.gif,.gz,.jpeg,.jpg,
.json,.jsonc,.log,.md,.mov,.mp4,.odf,.odg,.odp,.ods,.odt,.patch,.pdf,.png,.pptx,
.svg,.tgz,.txt,.webm,.webp,.xls,.xlsx,.zip
```

**`.md` is allowed by default** (as are `.json`, `.txt`, `.log`, `.patch`,
`.csv`; **not** `.yaml`/`.yml`, `.tar`, `.sh`). Empty or `*/*` allows everything.
An adapter should read `GET /api/v1/settings/attachment` rather than assume —
codeberg returns `{"allowed_types":"*/*","max_size":100,"max_files":20}`, proving
instances override the defaults.

**Recommendation: wayfinder assets stay in-repo and get linked.** Attaching is
*possible* and the `.md` default makes it frictionless, but an attached `.md` is
opaque: not greppable from a clone, not diffable, no `git blame`, no revision
history — and revising an asset means DELETE+POST, losing the old version. A
research asset is exactly the kind of artifact whose *evolution* matters. This
effort is already living proof of the in-repo shape working
(`planning/personal-forge/assets/01-…md`, and this file).

**The tension, stated honestly:** an effort that produces only *decisions* has no
natural repo for its assets. Two answers, both fine, and the choice belongs to
ticket 07 / the new-project convention fog:

- **Preferred:** a plan-only effort still gets a repo (or a `planning/` directory
  in an existing one), and the map issue links out to it by URL. Keeps everything
  greppable; costs one repo.
- **Fallback:** attach the `.md` to the map issue. Use this only when there is
  genuinely no repo, and accept the loss of history.

Either way, **an asset should never be the only copy of a decision** — the map's
Decisions-so-far line is the durable record, per the wayfinder resolve step.

---

## 6. One more thing the adapter must get right: **issues and PRs share a number space**

Both existing adapters end their PR/MR section with a number-space note, and
Forgejo lands on the **GitHub** side of that split — it inherits Gitea's single
`issue` table. **(verified live)** against codeberg:

- `GET /repos/forgejo/forgejo/issues/6267` — where 6267 is a *pull request* —
  returns **200**, `number: 6267`, with a populated
  `pull_request: {merged, merged_at, draft, html_url}` object. `…/issues/5448` (a
  real issue) returns `pull_request: null`. So **the issue endpoint resolves PR
  indices**, and `pull_request != null` is the discriminator.
- **The per-repo issue list includes PRs by default.** `type` has no default
  (swagger: enum `[issues, pulls]`, no `default`). Live:
  `GET …/issues?state=open&limit=50` → 50 items, **28 of them with a
  `pull_request` object**. The same call with `&type=issues` → 50 items, **0**
  with `pull_request`.

**This is load-bearing for the frontier.** Every listing call in the adapter —
per-repo *and* `/repos/issues/search` — must pass **`type=issues`**, or
`/wayfinder` will pick up pull requests as candidate tickets. The GitHub adapter
gets away with a prose warning about `#42` ambiguity; the Forgejo adapter needs
`type=issues` baked into every documented command.

For the **"PRs as a triage surface"** section: Forgejo has the full PR API
(`/repos/{o}/{r}/pulls`, `…/pulls/{index}`, `…/pulls/{index}.diff`) so the
section is expressible, but note there is **no `authorAssociation` field** on the
Forgejo PR payload — the GitHub adapter's triage filter ("keep only
`CONTRIBUTOR`/`FIRST_TIME_CONTRIBUTOR`/`NONE`") has **no direct equivalent**. The
GitLab adapter's looser wording ("keep only PRs whose author is not a project
member") is the shape to copy, resolved via
`GET /repos/{owner}/{repo}/collaborators`. Moot for this instance — a private
single-user forge takes no external PRs, so the flag ships as **`no`**.

---

## 7. What `issue-tracker-forgejo.md` would have to say

Section by section against the three existing adapters. The honest summary: it is
**closest to the GitLab adapter in shape** (labelled map, `Part of #<map>`) and
**closest to the GitHub adapter in capability** (native, API-driven dependencies).

### Header / preamble — **maps cleanly, with one addition**

"Issues and PRDs for this repo live as Forgejo issues." But unlike `gh`/`glab`,
**there is no CLI to name**, so the preamble must instead establish the
transport: base URL, `Authorization: token`, and where the token lives. Both
existing adapters get repo inference for free from `git remote -v`; the Forgejo
adapter has to say how owner/repo is derived from the remote itself (or defer to
a `bin/forge` wrapper that does it). **This is the single biggest structural
difference between this adapter and the other two.**

### Conventions — **maps cleanly, six footguns to document**

Every operation exists. What the doc must spell out:

1. **`type=issues` on every list call** (§6). Non-optional.
2. **Close is `PATCH {"state":"closed"}`** — no close endpoint, and no
   closing-comment parameter, so (as in the GitLab adapter) post the comment
   *first*, then close.
3. **`labels` on create is IDs; on `/issues/{index}/labels` it is names or IDs.**
   Prefer creating the issue bare and adding labels by name in a second call — one
   fewer name→ID resolution.
4. **`PATCH` has no `labels` field.** Label edits go only through the
   sub-resource; `POST` adds, `PUT` replaces, `DELETE …/labels/{name}` removes one.
5. **Assignees replace, not append** — `PATCH assignees: [...]` overwrites.
6. **No `@me`** — `GET /user` first, use `.login`.
7. **`labels=` is OR, not AND.** The spec says it verbatim on both endpoints:
   *"Fetch only issues that have **any** of this labels. Non existent labels are
   discarded."* (`/repos/{owner}/{repo}/issues` and `/repos/issues/search`, both
   confirmed in the live spec.) `gh issue list --label a --label b` is **AND** —
   so any command translated from the GitHub adapter that narrows by two labels
   silently becomes a union here, and the second filter must be applied
   client-side with `jq`. Also note "non existent labels are discarded" means a
   typo'd label does not error — it just widens the result set.

**One capability the other two adapters lack: `exclusive` labels.** Forgejo's
`Label` object carries an `exclusive` flag for scoped `scope/value` labels —
setting one automatically clears any sibling in the same scope. The five
canonical triage roles in
`~/.claude/skills/setup-matt-pocock-skills/triage-labels.md` (`needs-triage`,
`needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`) are mutually
exclusive *states*, and today nothing enforces that on GitHub or GitLab. Naming
them `triage/needs-triage` … `triage/wontfix` with `exclusive: true` makes the
state machine structural rather than conventional, and removes the
remove-then-add dance from every `/triage` transition. The same applies to
`wayfinder/<type>`. This is worth a Conventions paragraph — it is a genuine
*improvement* over both existing adapters, and the only one in this document.

Plus two clarifications with no analogue in the other adapters: the
index-vs-global-id split (issues by index; comments/labels/attachments by id),
and the 50-item page cap with `x-total-count` / `link` pagination.

### "PRs as a triage surface" — **expressible, degraded, and ships off**

Section is writable; `authorAssociation` has no equivalent (§6). Flag ships as
**`no`**. The number-space note is the GitHub one, *plus* the `type=issues`
consequence.

### "Publish to the issue tracker" / "Fetch the relevant ticket" — **map cleanly**

`POST …/issues` and `GET …/issues/{index}` + `GET …/issues/{index}/comments`.
Trivial.

### "Wayfinding operations" — the section that actually matters

| Operation | Forgejo | Notes |
|---|---|---|
| **Map** | ✅ clean | An issue labelled `wayfinder:map`. Identical to GitLab's. Plus a bonus the other two lack: `GET /repos/issues/search?labels=wayfinder:map&state=open&type=issues` is a **one-call, cross-repo list of every open map** — global label resolution by name makes this free. Neither `gh` nor `glab` gets that in one call. |
| **Child ticket** | ⚠️ **workaround** | No sub-issues (§2). Falls back to `Part of #<map>` at the top of the body + `wayfinder:<type>` labels — i.e. **GitLab's primary shape, and GitHub's documented fallback**. Add `wayfinder:effort:<slug>` so membership is a label query rather than a body grep — and note the label query must be **single-label**, since `labels=` is OR (§4), so narrowing by effort *and* type needs client-side filtering. A task list in the map body carries *order* only. **`Part of #<map>` only resolves within one repo** — if a map's children ever live in a different repo from the map issue, the convention must use `owner/repo#123`, the same form the dependency refs take. |
| **Blocking** | ✅ **clean and native** | `POST /repos/{o}/{r}/issues/{child}/dependencies` with `{"owner","repo","index"}`. **Better than the GitHub adapter's instruction** — no database-id lookup, the human-visible index works. **Better than GitLab free** — no Premium gate. Cross-repo works when `ALLOW_CROSS_REPOSITORY_DEPENDENCIES` is on (default). Must document: the `dependencies`-vs-`blocks` direction inversion, the per-repo `internal_tracker.enable_issue_dependencies` pre-flight (readable *and* settable via the repo API), and the `Blocked by: #<n>` body-line fallback if it is off. |
| **Frontier query** | ⚠️ **N+1, but cheap** | No `issue_dependencies_summary` equivalent. List the map's children (label query, `state=open`, `type=issues`), drop any with a non-empty `assignees`, then **one `GET …/issues/{index}/dependencies` per remaining child** and drop any whose result contains an issue with `state != "closed"`. ~11 calls for a ten-ticket map, and no rate limit to worry about. Order comes from the map body's task list. |
| **Claim** | ✅ clean | `PATCH …/issues/{n}` with `assignees: ["<login>"]`, login from `GET /user`. Same "first write of the session" semantics. |
| **Resolve** | ✅ clean | `POST …/issues/{n}/comments` with the answer, then `PATCH {"state":"closed"}`, then `PATCH` the map body to append the Decisions-so-far pointer. **Watch out:** closing is *refused* if the ticket still has open blockers (HTTP 412 `DependenciesLeft`) — a real behavioural difference from GitHub/GitLab, and arguably a feature. |

### Cannot be expressed at all

1. **Parent/child hierarchy.** No native containment, not even in dev.
2. **Anything project/kanban-driven.** Zero `/projects` API paths, no `project`
   field on `Issue`, no project filter on issue search. A user-level board is a
   fine *human* cross-project view — and probably the "UI the owner actually
   opens" that justified the tracker decision — but **no agent skill may read or
   write it**. Any adapter sentence about boards must be marked human-only.
3. **`authorAssociation`-based external-PR triage** (degradable, and moot here).
4. **A CLI-shaped adapter.** Both existing adapters are essentially CLI
   cookbooks. This one is an HTTP cookbook, or a cookbook for a wrapper this repo
   has to write.

---

## 8. Verdict: **GO-WITH-WORKAROUND**

**Can Forgejo carry wayfinder maps natively?** *Natively*, no — one thing is
missing, and it is the hierarchy. **In practice, yes**, via a workaround that is
not novel: it is the GitLab adapter's *primary documented shape* and the GitHub
adapter's own documented fallback.

The useful framing for ticket 07 is **placement**:

> **Forgejo sits strictly between GitHub and GitLab-free.** It is *better than
> GitLab-free* on the load-bearing capability — blocking dependencies are native,
> cross-repo, API-driven, and behind no paid tier — and *worse than GitHub* on
> hierarchy, having no sub-issues at all. On everything else (cross-repo search,
> labels, comments, assignees, attachments, no rate limits) it is at parity or
> better.

That reframes 07 from "does this work?" to **"is the labelled-map +
`Part of #<map>` convention acceptable?"** — a convention question, not a
capability question. And it is a convention already running in production on
GitLab-hosted efforts.

**The two caveats that belong in the verdict, not a footnote:**

- **Dependencies are per-repo-enabled.** The default is on
  (`DEFAULT_ENABLE_DEPENDENCIES = true`) and the flag is both readable and
  settable through `internal_tracker.enable_issue_dependencies` on
  `GET`/`PATCH /repos/{owner}/{repo}` **(verified live)** — so an adapter can
  pre-flight rather than discover it through a failed POST. But the GO rests on
  this flag, so the adapter must check it and must document the `Blocked by:
  #<n>` fallback.
- **Boards are unautomatable.** If any part of the intended workflow is
  board-driven, that part is human-only, permanently. Design accordingly.

**An option ticket 07 should consider and this document deliberately does not
decide:** this repo's own convention already keeps maps as *markdown*
(`planning/personal-forge/`) and graduates execution into `issues/NNN`. A
**hybrid** — the `local` adapter for maps, a Forgejo adapter for execution
tickets — is already live, dodges the hierarchy gap entirely, and keeps assets
in-repo and greppable (§5). It also matches the map's own "Plan, don't do"
premise: maps produce decisions, and decisions belong in git. Worth naming as a
live option rather than assuming every skill moves to the forge — which the map
already lists as open fog ("How far the agent toolchain moves").

---

## Explicitly unverified — do not read these as assertions

- **Forgejo v1.20.1-0 as the dependency-API landing** is an inference from two
  primary sources (Gitea 1.20.0 CHANGELOG + the Forgejo tag list), not a single
  Forgejo statement.
- **No Forgejo prose doc for issue dependencies exists** — the whole of §1 rests
  on source, locale strings, the config cheat-sheet and live codeberg.
- **HTTP status codes in §1** are read from source, not observed; no write token
  was used against a live instance.
- **Rate limits** are established by *absence* in primary sources (app.example.ini,
  cheat-sheet, api-usage doc, live response headers), not by an upstream
  statement. Forgejo's docs assert nothing either way.
- **When repo-level kanban first shipped** — predates the fork; no Forgejo source
  names a version. Only *owner-level* projects are pinned (1.19.0).
- **When `/repos/issues/search` and the `/assets` endpoints were introduced** —
  both confirmed present in v16.0.3 and v15.0.7; first release not traced.
- Codeberg's `allowed_types: "*/*"`, `max_size: 100` are **Codeberg's config**,
  not Forgejo defaults.
