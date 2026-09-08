---
name: "review-pr"
description: >
  Provides a structured process and a comment format for reviewing pull
  requests. Runs in three stages, each one gated by the user: a local review
  document, then the review posted to GitHub, then the fullsend fix agent
  triggered. Use when asked to "review a PR", "review PR #N", or "give me a
  review".
---

# Reviewing a Pull Request

A review runs in three stages. Each stage ends with a stop. Never start the
next stage before the user answers.

| Stage | Produces | Then |
|-------|----------|------|
| 1. Draft | `review-<PR number>.md` in the repository root | Ask the user to read it |
| 2. Post | One GitHub review: a summary plus the inline comments | Ask if the fix agent should run |
| 3. Trigger | One PR comment that starts with `/fs-fix` | Report what ran |

Stage 1 always runs. Stage 2 runs only after the user agrees. Stage 3 runs
only after the user agrees a second time.

"Review a PR" means stage 1. It does not mean all three. A user who wants
everything in one go says so.

## Stage 1 — the local review

- Fetch the PR with `gh pr view` and `gh pr diff`. Record the head SHA, the
  base branch, and the merge base. Every line number in the review refers to
  the head SHA.
- Read the full diff. Then read every file the diff cites or depends on. For
  design documents, read the sibling documents end to end. Contradictions
  live in the parts that nobody cites.
- Check every claim against its source and every link against its target.
  Record what you checked and what you did not.
- Write the review to `review-<PR number>.md` in the repository root. Do not
  commit it, do not post it, do not push.

Then stop. Name the file and ask the user to read it.

The user agrees in a plain sentence: "I agree", "looks good", "go ahead".
Anything else is a change request. Edit the document, then stop again.
Silence is not agreement.

### Review document

1. Header: PR link, head and base SHAs, author, review date, files touched.
2. Verdict: approve or request changes, then the blocking comments as a
   list, one line each: ID and title. Then any `chore`, then praise, then
   any `thought`. Nothing else.
3. Comments, grouped in this order: blocking; non-blocking issues and
   suggestions; todos, nitpicks, and questions; other files. Inside a group,
   keep file order.
4. What was checked, and what was not.

### Comment format

Each comment is a heading, a location, and a
[Conventional Comment](https://conventionalcomments.org):

```markdown
### B5 · Request tools missing

`docs/architecture/architecture.md:505-519`

**issue (non-blocking):** The tool inventory has no request tools.

The Drafting Table agent creates and refines backlog requests
(`docs/architecture/user-interaction-flow.md:842-866`). The table has only
"WMS query" and "WMS resolve".

**suggestion:** Add `WMS request create/refine/link`.
```

- **Heading:** an ID and a title. The ID is a group letter plus a number.
  The title is how a reader remembers the comment: 3 to 7 words that name
  the problem, not the location and not the fix. Titles are unique inside
  one review.
- **Location:** `path:line` or `path:start-end` at the head SHA, on its own
  line. Separate several ranges with commas. The first range is the anchor;
  the rest are repeated in the posted body as `Also lines X-Y.`
- **Subject line:** `**label (decoration):** subject`. The subject is one
  sentence that states the claim.
- **Discussion:** evidence with `path:line` citations, two to five lines,
  then the fix. An `issue` is always paired with a `**suggestion:**` line.
- **Labels:** `issue` for a concrete defect, `suggestion` for an improvement
  with its reason, `todo` for a small required change, `question` for a
  concern you cannot settle, `nitpick` for a preference, `praise` for what
  is right, `chore` for a task that must happen before merge and has no
  line to anchor to (it blocks, like an `issue (blocking)`), `thought` and
  `note` for non-blocking context.
- **Decorations:** always decorate `issue` with `(blocking)` or
  `(non-blocking)`. `(blocking)` means the PR must not merge until the
  comment is resolved. A `suggestion` without a decoration is non-blocking.

### Rules for the content

- Post only what the author can act on. A check that found nothing (the
  branch is behind `main`, the merge is clean, no stale wording is left)
  goes in the "What was checked" section of the local document, never in
  the posted review or its comments.
- Problem first, then evidence, then fix. Say what is wrong before why.
- Every fix must make the design or the code simpler or more complete. Drop
  a proposal that adds more than it removes.
- Cite sources, not memory. A claim about another file carries its
  `path:line`.
- Short sentences, one idea each. If a comment needs more than about ten
  lines, split it or cut it.
- Mark uncertainty. "As far as I know" is allowed. A guess presented as a
  fact is not.

## Stage 2 — post to GitHub

Post the whole review as **one** GitHub review, never as a stream of
separate comments. One review is one notification and one review state.

Build a JSON payload and send it in a single call:

```bash
gh api --method POST "repos/$REPO/pulls/$PR/reviews" --input review.json
```

```json
{
  "commit_id": "<head SHA from stage 1>",
  "event": "REQUEST_CHANGES",
  "body": "<the verdict section>",
  "comments": [
    {
      "path": "docs/architecture/architecture.md",
      "start_line": 505,
      "line": 519,
      "side": "RIGHT",
      "body": "**B5 · Request tools missing**\n\n**issue (non-blocking):** ..."
    }
  ]
}
```

- `event` is `REQUEST_CHANGES` when the review has a blocking comment,
  `APPROVE` when it has none and you approve, `COMMENT` otherwise.
- Drop `start_line` for a single-line anchor. Keep `side` as `RIGHT` unless
  the comment is about a deleted line.
- Each inline body starts with the **bold heading**, then any extra ranges
  as `Also lines X-Y.`, then the subject line and the discussion. The
  heading is posted. Stage 3 refers to comments by their ID, so the ID has
  to survive into GitHub.
- The `body` ends with the head SHA the line numbers refer to, and a link
  to Conventional Comments.

Then stop. Report the review URL and ask whether the fix agent should run.

## Stage 3 — trigger the fix agent

Only in a repository that has `.fullsend/config.yaml` with `fix` in its
`roles`. Skip this stage everywhere else and say why.

The trigger is a **new top-level PR comment** whose **first word** is
`/fs-fix`. It cannot go anywhere else:

| Where | Fires? |
|-------|--------|
| New PR comment, `/fs-fix` first word | yes |
| Appended to the review body | no — a human review is not routed |
| Inside an inline comment | no — that event is not subscribed to |
| Added by editing an existing comment | no — only `created` is routed |

The fix agent does not read inline comments. It reads the review body of a
**bot** review and the text of the `/fs-fix` comment. So the comment has to
tell it how to fetch the review:

````markdown
/fs-fix Address my N blocking review comments (A1-AN) on this PR.

They are inline review comments, so they are not in your `review-body.txt`.
Fetch them:

```
gh api "repos/${REPO_FULL_NAME}/pulls/${PR_NUMBER}/comments" --paginate \
  --jq '.[] | select(.user.login == "<reviewer login>") |
        "=== \(.path) lines \(.start_line // .line)-\(.line) ===\n\(.body)\n"'
```

Handle only the comments whose title starts with "A" in this run. Each is
marked `issue (blocking)` and names its own file and line range.

Leave the other groups alone — I will send those in a separate run.
````

- `REPO_FULL_NAME` and `PR_NUMBER` are set inside the agent sandbox. Leave
  them as written; do not expand them.
- The `select` on the reviewer login is what keeps other bots' inline
  comments out of the run.
- Send the blocking group first. A run has a 25 minute timeout, and a large
  review does not finish in one pass.
- A new `/fs-fix` cancels the run still going on the same PR. Wait for one
  to finish before sending the next group.
- Check the remaining budget first. The cap is 10 human-triggered runs per
  PR, shared with the bot's own runs:

  ```bash
  gh api "repos/$REPO/pulls/$PR/commits" --paginate \
    | jq -s 'add | [.[] | select(.commit.author.name == "fullsend-fix")] | length'
  ```

Then report: the comment URL, the workflow run, and which groups are still
unsent.
