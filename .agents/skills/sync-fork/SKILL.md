---
name: "sync-fork"
description: >
  Bring the fork's main up to date with upstream/main and keep the private
  layer healthy. Makes sure the worktree glue is in place, fetches, checks
  that every private commit touches only private paths, rebases,
  force-pushes to the fork with a lease, and says which worktrees are now
  behind. Use when asked to "sync the fork", "catch up with upstream",
  "update main", or "/sync-fork".
disable-model-invocation: true
---

# Syncing the fork

Run it in the main checkout (`claude --no-worktree`), on `main`. In a
worktree, stop and say so. This skill never commits. It rewrites `main`
with a rebase and pushes it with a lease. Nothing else.

Fork `main` is `upstream/main` plus the private layer: `lukas/`, the
eight private skills under `.agents/skills/`, and the Claude Code files
under `.claude/` (`settings.json`, `hooks/`, `rules/`, `CLAUDE.md`).
`.worktreeinclude` and `.git/info/exclude` belong to the layer too, but
stay untracked. The rebase replays that layer on top of the newest
upstream code. It stays
conflict-free as long as no private commit touches an upstream file.
Step 3 checks exactly that, before the rebase starts.

| Step | Does | On failure |
|------|------|------------|
| 0. Glue | Completes `.git/info/exclude` and `.worktreeinclude` | adds the missing lines and reports them |
| 1. Check | Branch, clean tree, remotes | stops and shows the fix |
| 2. Fetch | `upstream` and `origin`, with prune | stops |
| 3. Health | Every private commit touches only private paths | stops, names the commit and the path |
| 4. Rebase | `main` onto `upstream/main` | aborts the rebase and stops |
| 5. Push | `--force-with-lease` to the fork | stops. Never a plain force |
| 6. Report | What arrived, what is private, which worktrees are behind | — |

## 0. Glue

The private paths live in one list, here. `.git/info/exclude` is shared
by every worktree of this repository, so one edit hides these paths on
every branch. On `main` the tracked ones stay tracked. An ignore rule
never affects a tracked file.

Make sure every line below is in `.git/info/exclude`. Append the ones
that are missing, under the marker comment. Never remove a line that is
already there.

```text
# --- private layer, kept complete by /sync-fork ---
/lukas/
/.reviews/
/.worktreeinclude
/.claude/settings.json
/.claude/settings.local.json
/.claude/hooks/
/.claude/rules/
/.claude/CLAUDE.md
/.agents/skills/fullsend
/.agents/skills/pr-create
/.agents/skills/pr-update
/.agents/skills/adr
/.agents/skills/spec-doc
/.agents/skills/pr-review
/.agents/skills/sync-fork
/.agents/skills/prune
```

The skill lines have no trailing slash on purpose. In a worktree the
entry is a symlink, git treats a symlink as a file, and a pattern that
ends with `/` matches only a real directory.

`.worktreeinclude` in the repository root lists what the
`WorktreeCreate` hook puts into a fresh worktree. One path per line. A
file line is copied, shell globs allowed. A line that ends with `/` is a
directory, and the hook links it to the main checkout. The five skills
that run inside a worktree are links, so an edit on `main` is live
everywhere at once. `pr-review`, `sync-fork` and `prune` run only in the
main checkout and are not listed. Make sure every line below is in it.
Create the file if it is missing.

```text
.claude/settings.json
.claude/hooks/*
.claude/rules/*
.claude/CLAUDE.md
.agents/skills/fullsend/
.agents/skills/pr-create/
.agents/skills/pr-update/
.agents/skills/adr/
.agents/skills/spec-doc/
```

A new private skill means one line in the first block, and one in the
second if it runs inside a worktree. Both blocks are in this file, so
edit this file first, then run the skill.

Then check that the create hook has a base to cut from. The hook cuts a
new worktree from `upstream/HEAD`:

```bash
git symbolic-ref -q refs/remotes/upstream/HEAD || git remote set-head upstream -a
```

Report every line and file this step added. If nothing was missing, say
so in one line.

## 1. Check

Stop on the first failure and show the fix.

| Check | How | Fix |
|-------|-----|-----|
| Branch is `main` | `git branch --show-current` | start `claude --no-worktree` in the main checkout |
| Tree is clean | `git status --short` prints nothing | the user commits the notes or stashes. Do not commit for them |
| `upstream` is the original | `git remote get-url upstream` names `redhat-et/protobot` | `git remote add upstream https://github.com/redhat-et/protobot.git` |
| `origin` is the fork | `git remote get-url origin` names `lukaskellerstein/ProtoBot` | stop and ask |

## 2. Fetch

```bash
git fetch upstream --prune
git fetch origin --prune
base_before=$(git merge-base main upstream/main)
```

Keep `base_before`. Step 6 uses it.

## 3. Health

Every path touched by a private commit must match a private rule. This
prints the paths that do not:

```bash
git log --format= --name-only upstream/main..main | sort -u \
  | git check-ignore --no-index --stdin -v -n | grep '^::'
```

It must print nothing. Each printed line is `::<tab><path>`. For each
path, show the commits that touched it:

```bash
git log --oneline upstream/main..main -- <path>
```

Then stop. The fix rewrites `main`, so it is the user's. Say what it
is: move that change onto a feature branch cut from `upstream/main`,
then drop it from the private commit. Do not rebase while the layer is
unhealthy. A private commit that touches an upstream file is the only
thing that can make step 4 conflict.

Also show the size of the layer. It is meant to stay small:

```bash
git log --oneline upstream/main..main
```

## 4. Rebase

```bash
git rebase upstream/main
```

If it stops on a conflict, do not resolve it:

```bash
git rebase --abort
```

Then stop and show the conflicting path. Upstream added a file at a
private path, or step 3 was skipped. Either way the user decides.

After the rebase, `git merge-base --is-ancestor upstream/main main` must
succeed.

## 5. Push

```bash
git push --force-with-lease origin main
```

The fork's `main` is yours alone, so the force is safe. The lease is
what keeps it safe: if something else moved `origin/main`, the push is
refused. Then:

```bash
git fetch origin
git log --oneline main..origin/main
```

Show that and stop. Never fall back to `--force`.

## 6. Report

- Upstream commits that arrived: `git rev-list --count "$base_before..upstream/main"`.
- The private layer after the rebase: `git log --oneline upstream/main..main`.
- Worktrees that are now behind. For each branch in
  `git worktree list --porcelain`, except `main`:

  ```bash
  git rev-list --count "<branch>..upstream/main"
  ```

  List the ones with a count above zero, with the count. Say that
  `/pr-update` rebases a branch that is a day or more behind, and that
  `git rebase upstream/main` inside the worktree does it now.

- What step 0 added, if anything.

Do not commit. Do not touch any worktree.
