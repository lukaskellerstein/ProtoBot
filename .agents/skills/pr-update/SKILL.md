---
name: "pr-update"
description: >
  Take care of your own pull request on redhat-et/ProtoBot after a review.
  Reads every open comment, judges it, writes an HTML report, and on your
  yes fixes what is valid, replies in every thread, resolves every thread,
  and pushes once. Use when asked to "update PR N", "address the review on
  PR N", "handle the comments on PR N", or "/pr-update N".
---

# Updating your pull request

Read `.agents/skills/fullsend/SKILL.md` first.

Run it inside the worktree of the PR branch. If no worktree has the branch
(`git worktree list`), stop and ask for `claude -w lukas/<slug>`.

This skill never sends a `/fs-` command. On a fork PR the fix agent is
refused, and on your own PR this session is the fixer. The one Fullsend
effect is the review run that every push starts. So there is one push per
round.

| Step | Does | Then |
|------|------|------|
| 1. Collect | Reads the PR, CI, threads and bot findings | continues |
| 2. Judge | Writes `.reviews/pr-<N>/update-<k>.html` | stops. You read it |
| 3. Apply | Fixes, tests, commits, replies, resolves, pushes once | reports |

Your yes on the report covers all of step 3, the commit and the push
included. Anything else is a change request: edit the report and stop again.

## 1. Collect

- The PR: head SHA, base, `isCrossRepository`, `reviewDecision`, labels,
  `mergeable`, and how far the branch is behind `upstream/main`.
- CI: `gh pr checks`.
- Every unresolved thread: thread id, path, line, outdated flag, the author
  of the first comment, its database id, its body, and any replies. The
  GraphQL query is in the Fullsend reference.
- Bot findings that have no thread: the sticky review comment and the
  overflow `COMMENTED` review. Match them against the threads so nothing is
  counted twice.
- Human findings that have no thread: the bodies of human
  `CHANGES_REQUESTED` and `COMMENTED` reviews.
- The round number from `.reviews/pr-<N>/state.json`, or 1.

## 2. Judge

Give every finding an ID `T<n>` in file order and decide:

| Verdict | Meaning | Reply in step 3 |
|---------|---------|-----------------|
| `valid` | the finding is right and worth a change | `Fixed in <sha>: <one line>` |
| `done` | the head already has it | `Already in <sha>: <where>` |
| `not-valid` | the finding is wrong, or the change costs more than it gives | `Not changed: <reason in one or two sentences>` |
| `question` | a human asked something | the answer. Change the code only if the answer needs it |

Importance: `high` for a defect or a contradiction with another document,
`medium` for a missing piece, `low` for wording and style.

Round policy. Rounds 1 and 2: every `valid` finding is fixed. From round 3:
`valid` findings from humans are fixed, and bot findings of severity `high`
or `critical`. Every other bot finding becomes `not-valid` with the reason
`Round <k>: style only, not worth another review run.` Say in the report
when this policy is in force.

Write `.reviews/pr-<N>/update-<k>.html`. One file, inline CSS, no external
assets. Sections: header (PR, head, round, CI), a table (ID, source,
`file:line`, the claim in one line, verdict, importance, action), then each
finding in full with the planned reply. Then stop and name the file.

## 3. Apply

1. Make the changes in the worktree. Keep to what the report says.
2. If the branch is a day or more behind `upstream/main`, or has a
   conflict: `git fetch upstream && git rebase upstream/main`.
3. `pre-commit run --all-files`, and the tests if there are any. Nothing
   goes out red.
4. One commit: `<type>(#<issue>): address review round <k>`, with the IDs
   in the body.
5. Reply in every thread with the words from the report, then resolve it.
   All of them, `not-valid` included. No thanks, no filler. For a bot
   finding with no thread, post one top-level comment that lists the IDs
   and verdicts. It must not start with `/`.
6. Push once. `git push --force-with-lease` after a rebase, plain `git push`
   otherwise.
7. If a human has an open `CHANGES_REQUESTED`, ask that person for a
   re-review. A push never clears a request for changes. Only they can.

   ```bash
   gh api -X POST "repos/redhat-et/ProtoBot/pulls/$PR/requested_reviewers" -f 'reviewers[]=<login>'
   ```

8. Write the round into `state.json`.

Report: the commit, what was fixed, what was not and why, the threads
resolved, and that the bot review follows in 30 to 45 minutes.

## When to stop running this skill

- The bot approved (`ready-for-merge`) and no human thread is open. Ask a
  maintainer for the approval. Done.
- Round 3 or later, and only bot style findings came back. Do not run
  again. Ask a maintainer for the approval and say that the bot's remaining
  findings are answered in the threads.
- A human requested changes. Run again after you read their comments.

## State file

`.reviews/pr-<N>/state.json`:

```json
{
  "repo": "redhat-et/ProtoBot",
  "pr": 70,
  "rounds": [
    {
      "round": 1,
      "head": "abc1234",
      "commit": "def5678",
      "findings": [
        {
          "id": "T1",
          "source": "bot medium cross-document consistency",
          "path": "docs/x.md",
          "line": 12,
          "thread_id": "PRRT_...",
          "verdict": "valid"
        }
      ]
    }
  ]
}
```
