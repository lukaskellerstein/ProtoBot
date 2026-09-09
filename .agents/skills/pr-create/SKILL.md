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
| No private files in the diff | the command below prints nothing | the branch was cut from `origin/main`. Run `git rebase --onto upstream/main origin/main` |

```bash
git fetch upstream --prune
git diff --name-only upstream/main...HEAD \
  | grep -E '^(lukas/|\.claude/|\.reviews/|\.worktreeinclude|\.agents/skills/(fullsend|pr-review|pr-create|pr-update)/)'
```

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
- If the diff touches a path the review bot protects (`.github/`,
  `.claude/`, `AGENTS.md`, `agents/`, `skills/`, `scripts/`, and the others
  listed in the Fullsend reference), name the issue that authorizes it in
  the body. The bot never approves such a PR on its own, and the note tells
  the human why.
- Labels: none. `ready-for-review` starts a second review run.
  `fullsend-fix` lets the bot push to your branch, and on a fork PR it is
  refused anyway.

## 5. Wait for CI, then stop

```bash
gh pr checks "$PR" --repo redhat-et/protobot --watch
```

Report the PR URL and the CI result. Say that the bot review lands in 30 to
45 minutes, and that the next step is `/pr-update <N>` once it is there.
Do not wait for the review.
