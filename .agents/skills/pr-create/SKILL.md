---
name: "pr-create"
description: >
  Open a pull request against redhat-et/ProtoBot from a worktree branch on
  the fork. Checks the base and the diff, rebases, runs pre-commit, pushes
  once, opens the PR, waits for CI, and stops. Use when asked to "create a
  PR", "open a PR", "make a PR", or "/pr-create".
---

# Creating a pull request

Read `.agents/skills/fullsend/SKILL.md` first. The Fullsend review bot
reviews the PR on every push, so this skill pushes exactly once.

Run it inside the worktree of the branch: `.worktrees/lukas/<slug>` on
branch `lukas/<slug>`.

## 1. Check the branch

Stop on the first failure and show the fix.

| Check | How | Fix |
|-------|-----|-----|
| Branch is `lukas/<slug>`, not `main` | `git branch --show-current` | start `claude -w lukas/<slug>` |
| Tree is clean | `git status --short` prints nothing | the user commits or stashes. Do not commit for them |
| No private files in the diff | the command below prints nothing | the branch was cut from fork `main`. See below |

```bash
git fetch upstream --prune
git ls-files -i -c --exclude=/lukas/ \
  --exclude-from="$(git rev-parse --path-format=absolute --git-common-dir)/info/exclude"
```

The private paths are the rules in `.git/info/exclude` plus `lukas/`, which
is private but not in that file, and the command lists every tracked file on
this branch that matches one. Upstream has none of these
paths, so a printed path means the branch carries the private layer in its
history. That file is the one list, and `/sync-fork` keeps it complete. Do not
pipe the diff into `git check-ignore` here: it aborts on a path behind one of
the skill symlinks. Find where the feature commits start and move only those:

```bash
git log --oneline upstream/main..HEAD   # the private commits come first, then yours
git rebase --onto upstream/main <sha of the last private commit>
```

Do not use `git rebase --onto upstream/main origin/main`. `origin/main` moves
with every `/sync-fork`, and after one the merge base falls back to an old
upstream commit, so the private commits ride along.

## 2. Rebase and test

```bash
git rebase upstream/main
pre-commit run --all-files
```

Resolve conflicts, then run pre-commit again. Run the project's tests if the
change has any. Nothing goes out red. After the rebase,
`git merge-base --is-ancestor upstream/main HEAD` must succeed.

## 3. Push once

```bash
git push -u origin "lukas/<slug>"
```

The branch goes to the fork, never to upstream. A rule there blocks new
branches. If the branch already exists on the fork, push with
`--force-with-lease`.

## 4. Open the PR

```bash
gh pr create --repo redhat-et/protobot --base main \
  --head "lukaskellerstein:lukas/<slug>" \
  --title "<type>(#<issue>): <summary>" --body-file body.md
```

- Not a draft. The bot reviews drafts too, so a draft only delays the human.
- Title in the repository's commit style, for example
  `docs(#46): define logical schema for EARS specification records`.
- Body: what changed, why, how it was tested, then `Closes #<issue>` when
  there is one.
- If the diff touches a protected path, name the issue that authorizes it in
  the body. The list is in the Fullsend reference, section "Protected
  paths". `.github/`, `.pre-commit-config.yaml` and `AGENTS.md` are the ones
  this repository hits. The bot never approves such a PR on its own, and the
  note tells the human why.
- Labels: none. `ready-for-review` starts a second review run.
  `fullsend-fix` lets the bot push to your branch, and on a fork PR it is
  refused anyway.

## 5. Wait for CI, then stop

`$PR` is the number at the end of the URL that `gh pr create` printed.

```bash
gh pr checks "$PR" --repo redhat-et/protobot --watch
```

Report the PR URL and the CI result. Say that the bot review lands in 30 to
45 minutes, and that the next step is `/pr-update <N>` once it is there.
Do not wait for the review.
