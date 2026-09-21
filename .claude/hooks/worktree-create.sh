#!/bin/bash
# WorktreeCreate hook — `claude -w <name>` works in <repo>/.worktrees/<name>.
#
# Claude Code's own logic puts a worktree under .claude/worktrees/<name> on a
# branch called worktree-<name>, and `-w` takes a name only — there is no
# location setting (checked 2026-09-08, Claude Code 2.1.263). A WorktreeCreate
# hook replaces that logic entirely, which is the documented way to choose the
# directory. This one gives the convention every repo on this machine follows:
#
#   - the worktree lives at <repo>/.worktrees/<name>
#   - the branch is called <name>          (`lukas/44-resolve` is a valid name)
#   - a worktree that already exists there is adopted, never recreated — that
#     is how two sessions share one, and how a hand-made worktree is used.
#     An adopted worktree is populated too, so it gets the same files
#   - a new worktree branches from upstream/<default branch> when the repo has
#     an `upstream` remote, else from origin/<default branch>, after a fetch
#   - an existing branch called <name> is checked out instead of created,
#     including one that exists only on origin — an open pull request's
#     branch, or one pushed from another machine (ProtoBot-only)
#   - a name pr/<N> is a review worktree: branch pr/<N> is set to the head of
#     upstream pull request N and checked out (ProtoBot-only)
#
# ProtoBot-only (2026-09-11): the blocks marked "ProtoBot-only" below are
# not in the mac-setup template, and mac-setup's /claude-setup overwrites this
# file on a re-run. This copy is tracked on the fork's main, so after such a
# run `git diff` shows the loss and `git checkout -- <this file>` restores it.
#
# Isolation is unchanged: the native checks, the sandbox and worktree-guard.py
# all key on the session's cwd, wherever that is. Measured in a probe repo.
# Contract: mac-setup projects/claude-code.md § Worktrees.
#
# stdin:  JSON — session_id, cwd, hook_event_name, name (the -w argument, or
#         agent-<hex> for a subagent with isolation: worktree)
# stdout: the worktree directory, one line; Claude Code starts the session there
# stderr: shown to the user
# exit:   non-zero aborts the session start
#
# bash 3.2 (a fresh Mac). Runs outside the sandbox, from the launch directory.

set -eu

input=$(cat)
name=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin)["name"])')
[ -n "$name" ] || { echo "worktree-create: empty worktree name" >&2; exit 1; }

# The main checkout — even when launched from inside a linked worktree, the
# common git dir is always <main>/.git.
root=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
dir="$root/.worktrees/$name"

# .worktreeinclude — gitignored files a fresh worktree needs (Claude Code skips
# its own copy step when a hook creates the worktree). One path per line,
# relative to the repo root, shell globs allowed, `#` comments. Only files that
# exist in the main checkout are copied, and nothing already present is touched.
#
# ProtoBot-only: a line that ends with `/` names a directory, and it is linked
# to the main checkout instead of copied. The private skills use this: an edit
# on main is live in every worktree at once, and a worktree session cannot edit
# the link target, because worktree-guard.py denies a write into the main
# checkout. .git/info/exclude hides the links from git.
populate() {
  [ -f "$root/.worktreeinclude" ] || return 0
  while IFS= read -r pat || [ -n "$pat" ]; do
    case "$pat" in ''|'#'*) continue ;; esac
    (
      cd "$root"
      case "$pat" in
        */)
          d=${pat%/}
          [ -d "$d" ] && [ ! -e "$dir/$d" ] && [ ! -L "$dir/$d" ] || exit 0
          mkdir -p "$dir/$(dirname "$d")" && ln -s "$root/$d" "$dir/$d" \
            && echo "worktree-create: linked $d -> $root/$d" >&2
          ;;
        *)
          # shellcheck disable=SC2086  # the line is a glob on purpose
          for f in $pat; do
            [ -f "$f" ] && [ ! -e "$dir/$f" ] || continue
            mkdir -p "$dir/$(dirname "$f")" && cp -p "$f" "$dir/$f" \
              && echo "worktree-create: copied $f" >&2
          done
          ;;
      esac
    )
  done < "$root/.worktreeinclude"
}

if [ -d "$dir" ]; then
  echo "worktree-create: adopting $dir" >&2
  # ProtoBot-only: populate an adopted worktree too. A hand-made worktree, or
  # one whose skill set grew since it was created, gets the missing files.
  # Nothing that already exists is touched, so a second session is unaffected.
  populate
  printf '%s\n' "$dir"
  exit 0
fi

# Base: the remote default branch, fetched first so "fresh" means fresh.
#
# ProtoBot-only: this repository is a fork. A feature branch must start at
# upstream/main, never at origin/main — the fork's main carries the private
# layer (lukas/, the private skills, the .claude/ files) as commits, and a
# branch cut there would carry them into the pull request. So the `upstream`
# remote wins when it exists. Without one, origin/<default> as everywhere
# else. No remote at all: the main checkout's HEAD.
base=$(git -C "$root" symbolic-ref -q --short refs/remotes/upstream/HEAD 2>/dev/null || true)
if [ -z "$base" ] && git -C "$root" rev-parse -q --verify refs/remotes/upstream/main >/dev/null 2>&1; then
  base=upstream/main
fi
if [ -z "$base" ]; then
  base=$(git -C "$root" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)
fi
if [ -z "$base" ] && git -C "$root" rev-parse -q --verify refs/remotes/origin/main >/dev/null 2>&1; then
  base=origin/main
fi
if [ -n "$base" ]; then
  git -C "$root" fetch -q "${base%%/*}" "${base#*/}" 2>/dev/null \
    || echo "worktree-create: fetch failed, branching from the cached $base" >&2
else
  base=HEAD
fi

# ProtoBot-only: a name pr/<N> is a review worktree for upstream pull request
# N. The branch pr/<N> is set to the pull request head here, so the check
# below finds it and checks it out. The `+` allows a moved head: the branch is
# never ours, nothing on it is lost. Re-entry adopts the directory above and
# does not fetch; pr-review refreshes the head at the start of every round.
case "$name" in
  pr/[0-9]*)
    pr=${name#pr/}
    if ! git -C "$root" fetch -q upstream "+pull/$pr/head:refs/heads/$name"; then
      echo "worktree-create: cannot fetch upstream pull request $pr into $name" >&2
      exit 1
    fi
    echo "worktree-create: $name is at the head of upstream pull request $pr" >&2
    ;;
esac

# ProtoBot-only: a branch that exists on a remote but not here — the branch of
# an open pull request, or one pushed from another machine. Create it locally
# at the remote's tip and track it. Without this the next block would make a
# fresh branch of the same name at $base, and the pull request's commits would
# be silently absent. Own branches live on origin; upstream is tried second.
# A pr/<N> branch was just created above, so this is skipped for it.
if ! git -C "$root" show-ref -q --verify "refs/heads/$name"; then
  for remote in origin upstream; do
    git -C "$root" rev-parse -q --verify "refs/remotes/$remote" >/dev/null 2>&1 || true
    git -C "$root" fetch -q "$remote" "+refs/heads/$name:refs/remotes/$remote/$name" 2>/dev/null || continue
    git -C "$root" branch -q --track "$name" "$remote/$name" 2>/dev/null || continue
    echo "worktree-create: $name taken from $remote/$name, not created from $base" >&2
    break
  done
fi

if git -C "$root" show-ref -q --verify "refs/heads/$name"; then
  git -C "$root" worktree add "$dir" "$name" >&2
  echo "worktree-create: created $dir on the existing branch $name" >&2
else
  git -C "$root" worktree add -b "$name" "$dir" "$base" >&2
  echo "worktree-create: created $dir on new branch $name from $base" >&2
fi

populate

printf '%s\n' "$dir"
