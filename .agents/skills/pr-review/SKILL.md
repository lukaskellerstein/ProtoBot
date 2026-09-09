---
name: "pr-review"
description: >
  Review someone else's pull request on redhat-et/ProtoBot, usually one a
  Fullsend bot opened. Writes an HTML report first, posts one GitHub review
  after you approve the report, hands the fixes to the fix agent, and on a
  re-run reports what is fixed, what is still open, and what is new. Use
  when asked to "review PR N", "re-review PR N", or "/pr-review N".
---

# Reviewing a pull request

Read `.agents/skills/fullsend/SKILL.md` first. Every rule below follows
from it.

Run every round of one PR from the same checkout, because the state lives
in `.reviews/pr-<N>/` there. The main checkout (`claude --no-worktree`) is
the natural place. This skill changes no code.

| Phase | Does | Then |
|-------|------|------|
| 0. Freeze | Stops the bot fix loop on a bot PR | continues |
| 1. Report | Writes `.reviews/pr-<N>/round-<k>.html` | stops. You read it |
| 2. Post | One GitHub review. On a re-run, first replies to and resolves the fixed threads | stops. You decide about the fix agent |
| 3. Fix | One `/fs-fix` comment, then waits for the run | stops. The next round starts with `/pr-review N` again |
| 4. Approve | Replaces the review with an approval, resolves the rest, reports | ends |

"Review PR N" means phases 0 and 1. Each later phase needs a yes. A plain
yes is "go ahead", "post it", "agree". Anything else is a change request:
edit the report and stop again. Silence is not a yes.

## Phase 0 — freeze

Collect: author, title, head SHA, base, `isCrossRepository`, labels.

- If the author is a bot, or the PR carries `fullsend-fix`: comment
  `/fs-fix-stop` as the whole body. Within a minute `fullsend-no-fix` must
  show on the PR. If it does not, stop and say so. The command was refused
  silently.
- Wait until no `Fix` job for this PR is still running. A fix in flight
  moves the head. A review in flight does not, and with the label on its
  verdict starts nothing.
- List other humans with an open `CHANGES_REQUESTED`: the latest
  state-setting review per login, bots excluded. Tell the user. Their
  comments join the same `/fs-fix` batch in phase 3.
- On a human PR without `fullsend-fix` there is no loop. Skip the freeze.

Never remove `fullsend-no-fix` in this skill. Phase 4 says why.

## Phase 1 — report

### First round

1. Get the diff and the files at the head, without a checkout:

   ```bash
   git fetch upstream "pull/$PR/head:refs/pr/$PR"
   git show "refs/pr/$PR:<path>"
   ```

2. Read the full diff. Then read every file the diff cites or depends on.
   For design documents, read the sibling documents end to end. Check every
   claim against its source and every link against its target. If the diff
   touches `docs/`, run `/spec-doc <path>` in `check` mode for each changed
   document. Its `MISSING` rows become `issue (blocking)` comments.
3. Read the bot's sticky review comment. Where a bot finding matches one of
   yours, end your comment with `Same as the Fullsend finding on this
   line.` Then one instruction reaches the fix agent instead of two. If the
   sticky comment names an older head than the PR's, its findings are stale.
   Say so in the report.
4. Write the comments in the format below. Group them: blocking, then
   non-blocking issues and suggestions, then todos, nitpicks and questions.
   File order inside a group. IDs start at `A1`.
5. Write `.reviews/pr-<N>/round-1.html` and `.reviews/pr-<N>/state.json`.

### Re-run

`state.json` exists. Then:

1. Get the new head. If it equals the head in state, say so and stop.
   Nothing changed.
2. For each open ID in state, judge it against the new head. Read the fix
   bot's latest **Fixed** and **Disagreed** lists, read the changed text at
   the cited location, and decide: `fixed`, `partly`, `disagreed` or `open`.
   Trust the diff, not the bot's list.
3. Review the new head for new findings. Continue the IDs with the next
   unused letter.
4. Write `round-<k>.html` with three parts in this order: fixed, still open
   with what is still missing, new. Update state with the verdicts and the
   new head.

Then stop. Name the file. Do not post, commit or push.

### The HTML report

One file, inline CSS, no external assets, readable in light and dark.
Sections, in order:

1. Header: PR link and title, author, head SHA, base, round, date, files
   touched.
2. Verdict: approve or request changes. Then the table of comments: ID,
   label, `file:line`, status. Status is one of `new`, `fixed`, `partly`,
   `disagreed`, `open`.
3. The comments in full, grouped as above, each with its ID as an anchor.
4. What was checked, and what was not. A check that found nothing belongs
   here and nowhere else.

### Comment format

Each comment is a heading, a location, and a
[Conventional Comment](https://conventionalcomments.org):

```markdown
#### B5 · Request tools missing

`docs/architecture/architecture.md:505-519`

**issue (non-blocking):** The tool inventory has no request tools.

The Drafting Table agent creates and refines backlog requests
(`docs/architecture/user-interaction-flow.md:842-866`). The table has only
"WMS query" and "WMS resolve".

**suggestion:** Add `WMS request create/refine/link`.
```

- Heading: ID and title. The title names the problem in 3 to 7 words, not
  the location and not the fix. Titles are unique inside one PR.
- Location: `path:line` or `path:start-end` at the head SHA. The first
  range is the anchor on GitHub, and it must be a line the PR changed. Extra
  ranges are repeated in the posted body as `Also lines X-Y.`
- Subject line: `**label (decoration):** claim`, one sentence.
- Discussion: evidence with `path:line` citations, two to five lines, then
  the fix. An `issue` always has a `**suggestion:**` line.
- Labels: `issue` with `(blocking)` or `(non-blocking)`, always;
  `suggestion`; `todo`; `question`; `nitpick`; `praise`; `chore` for a task
  that blocks and has no line; `thought`; `note`.

Rules: post only what the author can act on. Problem, then evidence, then
fix. Cite sources, not memory. Short sentences. Mark a guess as a guess.

## Phase 2 — post

On a re-run, first close what is fixed. For each ID with status `fixed`:
reply in its thread with `Fixed in <short sha>.` and resolve the thread.
`partly` and `open` stay open. A `disagreed` thread needs your words: ask
the user, reply, and leave it open until they decide.

Then post the round as **one** review:

```bash
gh api --method POST "repos/$REPO/pulls/$PR/reviews" --input review.json
```

- `commit_id` is the head SHA. `event` is `REQUEST_CHANGES` when a comment
  blocks, else `COMMENT`. Never `APPROVE` here.
- `body`: the verdict, the table of IDs and titles, every comment that has
  no anchor in the diff, and one line that names the head SHA.
- `comments[]`: one per anchored comment. `path`, `line`, `side: RIGHT`,
  and `start_line` for a range. The body is the heading, then `Also lines
  X-Y.`, then the subject line and the discussion. GitHub rejects the whole
  review with 422 if one anchor is outside the diff.
- Record in state: the review id, and for each ID its thread id and first
  comment id. Query the threads after the post.

Then stop. Report the review URL and ask if the fix agent runs.

## Phase 3 — fix

Only on a same-repo PR. On a fork PR the fix agent is refused. Hand the
review to the author and stop.

Check the budget first: fix commits so far, against the cap of 10 for
human-triggered runs. Never send a second `/fs-fix` while one runs.

Send **one** batch for the whole round, and for every reviewer from phase 0.
Select by label: `issue`, `todo` and `chore` always; `suggestion` only for
the IDs the user names; never `question`, `nitpick`, `praise`, `thought` or
`note`. A question needs the user's answer, not a patch.

The comment is one file whose first line starts with `/fs-fix`:

````markdown
/fs-fix Address N review comments on this PR, round <k>.

They are inline review comments, so they are not in your `review-body.txt`.
Fetch them:

```
gh api "repos/${REPO_FULL_NAME}/pulls/${PR_NUMBER}/comments" --paginate \
  --jq '.[] | select(.pull_request_review_id == <review id>) |
        "=== \(.path) lines \(.start_line // .line)-\(.line) ===\n\(.body)\n"'
```

<For comments without an anchor: they are in the body of review <review id>.
Read them there.>

Handle exactly these, matched by the ID in the heading of each comment:

- `issue`: B1, B2, B5
- `todo`: C1, C2

Skip everything else. Leave <the other IDs> alone.

Check the cited `file:line` references yourself. `issue` and `todo` mean
change it. `chore` and `suggestion` mean act on it. Where you disagree,
record the disagreement in your summary instead of forcing a change.
````

Leave `${REPO_FULL_NAME}` and `${PR_NUMBER}` as written. The agent's
sandbox sets them. For several reviewers, select on
`.user.login == "a" or .user.login == "b"` and print the login in the
header, because an ID like `A1` can repeat across reviewers.

Poll every two minutes for the status comment that says `Finished Fix`.
Read the fix summary. Then stop and say: run `/pr-review N` again for the
next round.

## Phase 4 — approve

Only when the user asks for an approval by name. It carries their identity.

1. Check that the head the user read is still the head.
2. Post `APPROVE` with a body that names the SHA and lists what changed
   since the last round.
3. Reply and resolve every remaining thread of yours that is fixed. Leave
   the rest open and say which.
4. Leave `fullsend-no-fix` on. The merge rules need a maintainer's approval,
   not the bot's, and an approval survives later pushes. With the label on,
   no bot commit lands under it. Say this in the report. The user removes
   the label by hand if they want the loop back.
5. Report: commits, review state and its SHA, threads resolved, comments not
   sent.

## State file

`.reviews/pr-<N>/state.json`:

```json
{
  "repo": "redhat-et/ProtoBot",
  "pr": 61,
  "reviewer": "lukaskellerstein",
  "rounds": [
    {
      "round": 1,
      "head": "1446176",
      "review_id": 5155779823,
      "comments": [
        {
          "id": "A1",
          "label": "issue (blocking)",
          "path": "docs/x.md",
          "line": 201,
          "thread_id": "PRRT_...",
          "comment_id": 3969193865,
          "status": "open"
        }
      ]
    }
  ]
}
```

`status` is one of `open`, `fixed`, `partly`, `disagreed`, `dropped`.
