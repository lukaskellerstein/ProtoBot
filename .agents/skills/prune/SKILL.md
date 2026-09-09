---
name: "prune"
description: >
  Clean up after merged pull requests and finished subagents. Finds
  worktrees and branches whose pull request merged or closed, empty
  subagent worktrees, and branches on the fork with nothing left to do.
  Shows the plan, deletes only on your yes, and never touches the main
  checkout, a locked worktree, or a dirty one. Use when asked to "prune",
  "clean up worktrees", "delete merged branches", or "/prune".
disable-model-invocation: true
---

# Pruning worktrees and branches

Run it in the main checkout (`claude --no-worktree`). A worktree cannot
remove itself. This skill never commits and never pushes a commit. Its
one remote action is deleting a branch on the fork.

The Claude Code remove hook keeps the branch on purpose: the branch is
the pull request. Once the pull request is merged or closed, nothing
needs the branch. Subagent worktrees at `.worktrees/agent-<hex>` are
created by the create hook and removed by nobody. Both kinds end here.

| Step | Does | Then |
|------|------|------|
| 1. Inventory | Every worktree and every `lukas/*` and `agent-*` branch, with its pull request state | continues |
| 2. Plan | A table: remove, ask, keep, each with its reason | stops. You read it |
| 3. Apply | Removes and deletes what the plan says | reports |

Your yes on the plan covers the whole `remove` group. Each `ask` row
needs its own yes. `keep` rows are not touched.

## 1. Inventory

```bash
git fetch upstream --prune
git fetch origin --prune
git worktree prune
git worktree list --porcelain
git branch --list 'lukas/*' 'agent-*' --format='%(refname:short)'
git branch -r --list 'origin/lukas/*' 'origin/agent-*' --format='%(refname:short)'
gh pr list --repo redhat-et/protobot --author @me --state all --limit 100 \
  --json number,state,headRefName,mergedAt,url
```

Match pull requests to branches on `headRefName`. One `gh` call, then
local matching. Do not query per branch.

For each worktree except the main checkout, and for each branch:

- path and `locked`, from the porcelain output
- dirty: `git -C <path> status --short` prints something
- unique commits: `git rev-list --count upstream/main..<branch>`
- the pull request: number, state, url, or none
- a matching `.reviews/pr-<N>/` directory, if the branch had a PR

Classify:

| Case | Condition | Group | Action |
|------|-----------|-------|--------|
| locked | porcelain says `locked` | keep | another session is in it |
| open | PR state `OPEN` | keep | — |
| in progress | no PR, unique commits above zero, or dirty | keep | list it |
| merged | PR state `MERGED`, worktree clean | remove | worktree, local branch, fork branch, `.reviews/pr-<N>/` |
| agent leftover | `agent-*`, zero unique commits, clean | remove | worktree, local branch |
| closed | PR state `CLOSED`, not merged | ask | same as merged |
| empty | no PR, zero unique commits, clean | ask | worktree, local branch, fork branch if any |
| dirty but done | merged or closed, but dirty | ask | show `git status --short` first |
| agent with work | `agent-*`, unique commits or dirty | ask | show `git log --oneline upstream/main..<branch>` |
| fork only | `origin/lukas/*` with no local branch | as its PR state says | fork branch only |

Never touch: the main checkout, the branch `main`, a branch checked out
in a locked worktree, any path outside `.worktrees/`.

## 2. Plan

One table, grouped `remove`, then `ask`, then `keep`:

| Worktree | Branch | PR | Unique commits | State | Action | Reason |
|----------|--------|----|----------------|-------|--------|--------|

State is `clean`, `dirty` or `locked`. Action names each thing that
goes: `worktree`, `local branch`, `fork branch`, `.reviews/pr-<N>/`.

Then stop. Nothing is deleted before a yes.

## 3. Apply

For each row with a yes, in this order:

```bash
git worktree remove <path>            # no --force. If refused, the row moves to ask
git branch -D <branch>
git push origin --delete <branch>     # only when origin/<branch> exists
rm -r .reviews/pr-<N>                 # only when the row lists it
```

Then once:

```bash
git worktree prune
find .worktrees -mindepth 1 -type d -empty -delete
```

The `find` removes the empty parent that a nested name like
`lukas/<slug>` leaves behind. It never removes `.worktrees` itself.

Report: what was removed, what was kept and why, and the branches still
on the fork after the run:

```bash
git worktree list
git branch -r --list 'origin/lukas/*'
```
