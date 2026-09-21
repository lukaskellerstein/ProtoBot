---
name: "worktree-update"
description: >
  Bring the worktree you are sitting in up to date, whichever kind it is.
  In a review worktree it resets to the current head of the pull request
  and reports what the author changed since your last round. In your own
  worktree it rebases onto upstream/main and stops before the push. On a
  dirty tree it asks first: commit, stash, or stop. Use when asked to
  "update the worktree", "refresh the PR", "get the latest commits",
  "rebase on upstream", or "/worktree-update".
disable-model-invocation: true
---

# Updating a worktree

Run it inside the worktree you want updated. The branch name decides what
happens. This skill never pushes. It commits or stashes only on a dirty
tree, and only when the user picks that choice.

| Where you are | Does |
|---------------|------|
| `.worktrees/pr/<N>`, branch `pr/<N>` | resets to the head of upstream pull request N |
| `.worktrees/lukas/<slug>`, branch `lukas/<slug>` | rebases onto `upstream/main` |
| the main checkout | stops. `/sync-fork` updates `main` |
| anything else | stops and says the branch name |

`git fetch` needs the sandbox off in this repository. So do `reset`,
`clean`, `rebase` and `stash`, because they write under `.agents/skills`.

Shell variables do not survive from one command to the next. Note every
SHA the steps below set, and use the value.

## 1. Where am I

```bash
pwd
git branch --show-current
git status --short
```

Stop on any of these, with the fix:

| Check | Fix |
|-------|-----|
| The guard line names the main checkout | run `/sync-fork` instead |
| The branch is not `pr/<N>` or `lukas/<slug>` | say the name. The user decides |

A dirty tree is not a stop here. Fetch first. If nothing new arrived, the
tree stays as it is and nobody is asked.

## 2. A dirty tree

When there is something to update and the tree is dirty, ask once, in one
question, before the reset or the rebase. Show the `git status --short`
output and the choices for this kind of worktree:

| Worktree | Choices |
|----------|---------|
| `pr/<N>` | 1. Stash, reset, bring the changes back. 2. Stop. |
| `lukas/<slug>` | 1. Commit, then rebase. 2. Stash, rebase, bring the changes back. 3. Stop. |

Run only the choice the user picks. Never pick for the user.

- Never commit on `pr/<N>`. It is someone else's head, and `/pr-review`
  resets it hard.
- Never push, in either kind. The rebase rewrites a commit you push
  before it, so the push belongs after the rebase. With an open pull
  request every push also starts a bot review round.
- Never `git stash drop`. If the changes cannot come back cleanly, git
  keeps them in `git stash list`. Say so, name the paths, and stop.
- On "stop", say which choice the user can make by hand, and that a
  re-run of `/worktree-update` picks up from a clean tree.

## 3a. A review worktree, `pr/<N>`

`N` is the branch name after `pr/`. Never take it from the user's words:
the worktree you are in is the pull request you are updating.

```bash
old=$(git rev-parse HEAD)
git fetch upstream "pull/<N>/head"
new=$(git rev-parse FETCH_HEAD)
```

If the fetch fails, stop. The pull request may be closed; check with
`gh pr view <N> --repo redhat-et/protobot --json state`.

If `$new` equals `$old`, the head is unchanged. Say so in one line and
stop. Nothing to review. This is the answer that saves a review round.

### Reset

If the tree is dirty, ask (section 2). On "stash":

```bash
git stash push -u -m "worktree-update pr/<N>"
```

`-u` takes the untracked files too, because `git clean -fd` deletes them.
It leaves ignored files alone.

```bash
git reset --hard "$new"
git clean -fd
```

`git clean -fd` leaves ignored files alone, so `.reviews/` and the copied
`.claude/` files survive. Never add `-x`.

After a stash, bring the changes back:

```bash
git stash pop
```

A pop that conflicts or refuses keeps the stash. Stop there (section 2).

### Report

The new commits and the changed files:

```bash
git log --oneline "$old"..HEAD
git diff --stat "$old"..HEAD
```

A force-push can make `$old..HEAD` miss commits that are gone. When
`git merge-base --is-ancestor "$old" HEAD` fails, say the author
rewrote the head, and show `git diff --stat "$old" HEAD` instead.

After a stash, say the changes are back and uncommitted.

### Against your last round

Read `.reviews/pr-<N>/state.json` if it is there. For the last round,
take every comment whose `status` is `open` or `partly` and say whether
the author touched its `path` in the new commits:

```bash
git diff --name-only "$old"..HEAD
```

Report one line per comment: its ID, its `file:line`, and `touched` or
`untouched`. This is a hint, not a verdict. Only `/pr-review <N>` judges
whether a finding is fixed.

Close with: run `/pr-review <N>` for the next round.

## 3b. Your own worktree, `lukas/<slug>`

```bash
git fetch upstream --prune
git rev-list --count HEAD..upstream/main
```

Zero means the branch is current. Say so and stop.

### Dirty or not

```bash
git status --short --untracked-files=no
```

Only tracked changes count. A rebase leaves untracked files alone. If
this prints anything, ask (section 2).

For the commit choice, put the proposed message in the question, in the
style of `git log --oneline upstream/main..HEAD`. The user's pick covers
that message. On "commit":

```bash
git add -A
git commit -m "<message>"
git rebase upstream/main
```

On "stash":

```bash
git rebase --autostash upstream/main
```

Git stashes the tracked changes, rebases, and applies them again. If they
do not apply cleanly, git says so and keeps them in `git stash list`.
Stop there (section 2).

On a clean tree:

```bash
git rebase upstream/main
```

### A conflict

Do not resolve it:

```bash
git rebase --abort
```

The abort also brings back an autostash. Then stop, name every
conflicting path, and say the rebase is the user's to finish. A
specification document that upstream also changed needs a reading, not a
merge tool.

If the rebase does not start because an untracked file is in the way,
stop and name the file.

### After a clean rebase

```bash
git merge-base --is-ancestor upstream/main HEAD
SKIP=skillsaw uvx pre-commit run --all-files
```

The rebase replays your commits onto code they were never tested against,
so the checks run here, not later on the pull request.

Then run the private-path check, the same one `/pr-create` step 1 runs:

```bash
git ls-files -i -c --exclude=/lukas/ \
  --exclude-from="$(git rev-parse --path-format=absolute --git-common-dir)/info/exclude"
```

It must print nothing.

### Stop before the push

Report and stop. Never push.

- The commits replayed, and how many upstream commits arrived.
- What happened to the dirty tree: the new commit and its SHA, or the
  changes back from the stash and still uncommitted.
- The pre-commit result.
- Whether the branch has an open pull request:

  ```bash
  gh pr list --repo redhat-et/protobot --head "<branch>" --state open \
    --json number,reviewDecision
  ```

- With an open pull request: say that the push is
  `git push --force-with-lease`, that it is the user's to run, and that it
  starts a bot review round of 3 to 8 dollars. If a human has an open
  `CHANGES_REQUESTED`, say that a push does not clear it.
- With no pull request: say the next step is `/pr-create`.
