---
name: "fullsend"
description: >
  Reference for how Fullsend behaves on redhat-et/ProtoBot: what wakes each
  agent, the slash commands, the labels, the caps, the comment markers, the
  merge rules, and the gh commands that read or drive it. Read it before you
  send a /fs- command or change a Fullsend label. The skills pr-review,
  pr-create and pr-update depend on it.
---

# Fullsend on redhat-et/ProtoBot

Checked against the Fullsend source at v0.40.0 and the shim in
`.github/workflows/fullsend.yaml`. Fullsend runs only in the upstream
repository. It never sees the fork.

## Who wakes up when

| Event | Agent | Condition |
|-------|-------|-----------|
| PR opened, commit pushed, PR taken out of draft | review | the PR author is a bot, or has triage access or more |
| Label `ready-for-review` added to a PR | review | none |
| Comment `/fs-review` | review | triage access or more |
| The review bot submits `CHANGES_REQUESTED` | fix | same-repo PR, no `fullsend-no-fix`, and the author is a bot or the PR carries `fullsend-fix` |
| Comment `/fs-fix <text>` | fix | write access. A fork PR is refused |
| Comment `/fs-fix-stop` | none. Adds `fullsend-no-fix` | write access, or the PR author |
| PR closed or merged | retro | none |

What follows from the table:

- A human review never starts the fix agent. Only the bot's own verdict does.
- Draft PRs are reviewed. A draft saves nothing.
- Every push costs one review run: 3 to 8 dollars and 30 to 45 minutes on
  this repository. Push once per round.
- A new push cancels the review still running on the old commit. Three quick
  pushes cost one run.
- A PR from the fork is reviewed, because its author has write access. The
  bot never fixes it.
- A human PR without `fullsend-fix` has no loop. A bot PR without
  `fullsend-no-fix` loops until the cap.

## Slash commands

The command is the first word of the first line of a **new top-level PR
comment**. Nothing else is read.

| Where the text is | Works? |
|-------------------|--------|
| `gh pr comment N --body '/fs-...'` | yes |
| A reply in an inline thread | no |
| The body of a review (`gh pr review`) | no |
| An edited comment | no |
| A comment from a bot or an app token | no |
| Text before the command on the first line | no |

- `/fs-fix-stop` must be the whole comment. Nothing after it.
- `/fs-fix` takes free text after it, up to 10,000 bytes. That text outranks
  the bot's review body. A second `/fs-fix` cancels the one in flight.
- A command you are not allowed to send fails silently. Check the effect,
  not the exit code.

## Labels

| Label | Set by | Removed by | Effect |
|-------|--------|------------|--------|
| `ready-for-review` | the code bot when it opens a PR, or a human | nobody | one review run when added |
| `fullsend-no-fix` | `/fs-fix-stop` | a human only | blocks bot-triggered fix runs. `/fs-fix` by hand still works |
| `fullsend-fix` | a human | a human | opts a human PR into bot fix runs. The label does not exist in this repository yet |
| `ready-for-merge` | the review bot on approve | the review bot on the next round | a light, not a gate. The merge rules ignore it |
| `requires-manual-review` | the review bot | the review bot | the bot could not decide |
| `risk/low` to `risk/critical` | the review bot | the review bot | information |
| `needs-human` | the fix bot, one round before its cap | nobody | information. It stops nothing |
| `do-not-merge` | a human | a human | not read by Fullsend |

## Caps

- Fix runs are counted as commits by the author `fullsend-fix` on the PR.
  Bot-triggered runs stop at 5, human-triggered at 10. Both count the same
  commits.
- The fix agent reads two things: the body of the bot's latest
  `CHANGES_REQUESTED` review, and the text after `/fs-fix`. It never reads
  inline comments, thread replies, other comments, CI logs or the issue. It
  never replies in a thread and never resolves one.
- The retro agent runs on every close. Only the kill switch stops it.

## Merge rules on upstream `main`

- One approval from the team `redhat-et/sdlc-maintainers`, who are also the
  code owners. A self-approval does not count.
- The check `CI Workflow - Success` must pass. The merge goes through the
  merge queue.
- An approval is not dismissed by a later push. Commits pushed after an
  approval merge under it. So freeze a bot PR once a human approves it.

## What the bots post

| Post | Author | How to find it |
|------|--------|----------------|
| Sticky review comment, edited in place each round. Older rounds sit under `Previous run` | `fullsend-ai-review[bot]` | `<!-- fullsend:review-agent -->`, then `<!-- **Head SHA:** <sha> -->` |
| Formal review with inline comments `**[severity]** category`. Its body is one link to the sticky comment | same | state `CHANGES_REQUESTED` or `APPROVED` |
| Overflow review for findings GitHub refused with 422 | same | state `COMMENTED`, body starts `**Note:** The following review comments could not be posted` |
| Risk sticky | same | `<!-- fullsend:risk-assessment -->` |
| Run status, one per run | each bot | `<!-- fullsend:agent-status:<run id> -->`, plus `<!-- fullsend:status:terminal -->` when the run is over |
| Fix summary with a **Fixed** list and a **Disagreed** list | `fullsend-ai-coder[bot]` | heading `### 🔧 Fix agent — iteration N` |

Logins: REST returns `fullsend-ai-review[bot]`. GraphQL and
`gh pr view --json` return `fullsend-ai-review`.

## Commands

`REPO=redhat-et/ProtoBot`, `PR=<number>`.

The bot's current review body and the SHA it reviewed:

```bash
gh api "repos/$REPO/issues/$PR/comments" --paginate \
  --jq '.[] | select(.body | contains("<!-- fullsend:review-agent -->")) | .body' \
  | sed '/<!-- sticky:history-start -->/,$d'
```

The last finished run:

```bash
gh api "repos/$REPO/issues/$PR/comments" --paginate \
  --jq '[.[] | select(.body | contains("<!-- fullsend:status:terminal -->"))] | last | .body'
```

Runs still going, and which stage each one is. Runs are listed by PR title,
not by number:

```bash
gh run list --repo "$REPO" --workflow fullsend --limit 30 \
  --json databaseId,status,displayTitle \
  --jq '.[] | select(.status != "completed") | select(.displayTitle == "<PR title>") | .databaseId' \
  | xargs -I{} gh run view {} --repo "$REPO" --json jobs --jq '[.jobs[].name] | join(", ")'
```

Fix commits used so far:

```bash
gh api "repos/$REPO/pulls/$PR/commits" --paginate \
  --jq '[.[] | select(.commit.author.name == "fullsend-fix")] | length'
```

Unresolved threads, with the id to resolve and the comment id to reply to:

```bash
gh api graphql -F owner=redhat-et -F repo=ProtoBot -F pr="$PR" -f query='
query($owner:String!,$repo:String!,$pr:Int!){
  repository(owner:$owner,name:$repo){ pullRequest(number:$pr){
    reviewThreads(first:100){ nodes{
      id isResolved isOutdated path line startLine
      comments(first:20){ nodes{ databaseId author{login} body url }}}}}}}' \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)'
```

Reply in a thread, then resolve it. The reply goes to the first comment of
the thread:

```bash
gh api -X POST "repos/$REPO/pulls/$PR/comments/$FIRST_COMMENT_ID/replies" -f body="$TEXT"
gh api graphql -F id="$THREAD_ID" -f query='
mutation($id:ID!){ resolveReviewThread(input:{threadId:$id}){ thread{ isResolved }}}'
```

Send a command:

```bash
gh pr comment "$PR" --repo "$REPO" --body '/fs-fix-stop'
gh pr comment "$PR" --repo "$REPO" --body-file fs-fix.md   # first line starts with /fs-fix
```
