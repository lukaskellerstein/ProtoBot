# ProtoBot — Claude Code

`AGENTS.md` in the repository root is the contribution guidance, and the root
`CLAUDE.md` is a symlink to it. This file adds only what is true of this
machine, so nothing here has to change an upstream file.

Reference file: [`rules/worktree.md`](rules/worktree.md) (where you may change
files: your worktree under `.worktrees/<name>`, never the main checkout).

- Know where you stand before you read or edit: `pwd` and
  `git branch --show-current`. In the main checkout you may read and answer,
  not edit — [`rules/worktree.md`](rules/worktree.md).
- Every edit lands in your own worktree (`.worktrees/<name>`, branch
  `<name>`), never in the main checkout or another worktree.
- This file, `rules/`, `hooks/` and `settings.json` are tracked on the fork's
  `main` only, as part of the private layer. The upstream repository is
  `redhat-et/protobot`, and they never go into a pull request: a worktree gets
  untracked copies, hidden by `.git/info/exclude`. Edit them in the main
  checkout only.
