---
name: "adr"
description: >
  Write an architecture decision record in docs/decisions/ in the house
  format: the next free number, the section layout of ADR-0001, the status
  line, relative links to the architecture documents, and the markdownlint
  rules. Reads the open question or issue it resolves first, and runs
  spec-doc on the result. Use when asked to "write an ADR", "record a
  decision", "add a decision record", or "/adr".
disable-model-invocation: true
---

# Writing a decision record

Run it in a worktree on a `lukas/<slug>` branch. An ADR is a
contribution, so it never starts on `main`. This skill writes files and
stops. It does not commit.

`docs/decisions/` is part of the specification hierarchy in `AGENTS.md`,
so an ADR must pass the same coverage check as every other document
under `docs/`. Step 4 runs it.

| Step | Does | Then |
|------|------|------|
| 1. Frame | Reads what the decision resolves, and every existing ADR | continues |
| 2. Number | Picks the next free number, checks open PRs for a clash | continues |
| 3. Write | The record, in the house format | continues |
| 4. Check | `/spec-doc` in write mode, until no row is `MISSING` | continues |
| 5. Link | Updates the open question or document that pointed at the gap | continues |
| 6. Lint | `pre-commit` on the touched files | stops and reports |

## 1. Frame

An ADR resolves one thing. Find it and read it at the source:

- an open question `Qn` in `docs/architecture/open-questions.md`
- an issue `#N`: `gh issue view N --repo redhat-et/protobot`
- the user's words, when neither exists. Then ask which document the
  gap lives in, and read that section.

Then read every file in `docs/decisions/` end to end. The new record
must not contradict an accepted one. If it must, it supersedes that
record: say so in the new Context section, and change the old status
line to `Superseded by ADR-NNNN`.

Write down, before you write the record: the question in one sentence,
the evaluation criteria if the source lists any, and the decision in one
sentence. If the decision is not clear yet, stop and ask. An ADR records
a decision. It does not make one.

## 2. Number

```bash
ls docs/decisions/ | grep -E '^[0-9]{4}-' | sort | tail -1
gh pr list --repo redhat-et/protobot --state open --json number,files \
  --jq '.[] | .number as $n | .files[].path
        | select(startswith("docs/decisions/")) | "\($n) \(.)"'
```

The number is the highest on disk plus one, unless an open pull request
already uses it. Then take the next one and say so in the report, so the
PR body can name the clash.

The filename is `docs/decisions/NNNN-<slug>.md`. The slug is three to
six words from the title, lowercase, joined with dashes.

## 3. Write

Copy the shape of `docs/decisions/0001-requirements-storage-format.md`.
It looks like this:

```markdown
# ADR-NNNN: <Title In Title Case>

> Status: **Accepted** — <Month YYYY>

**Contents:**

- [Context](#context)
- [Decision](#decision)
- [Rationale](#rationale)
- [Alternatives Considered](#alternatives-considered)
- [Consequences](#consequences)
- [Related Documents](#related-documents)

## Context

...

---

## Decision

...
```

Rules of the form:

- Status is `Accepted` with the month, as ADR-0001 was merged. If the
  user says the decision is still open, write `Proposed`.
- Major sections are separated by a line with `---`.
- Context: what the gap is, where the hierarchy says it is unresolved,
  with a link to that place. The evaluation criteria as a numbered list
  under `### Evaluation criteria`, when the source has them.
- Decision: the decision in one paragraph, in bold where the sentence
  carries it. Then what is out of scope, and which issue or ADR owns
  each out-of-scope item.
- Rationale: one `### n. <criterion>` per criterion, in the source's
  order. Under each, the argument with evidence.
- Alternatives Considered: one `### <Alternative>` each, with what it
  gives and why it lost.
- Consequences: a dash list. Each item starts with a bold lead of two
  to four words, then the sentence.
- Related Documents: a dash list. Each item is a reference-style link
  or an issue number, then a dash, then what the link is to this ADR.
  The link targets sit at the bottom of the file:
  `[id]: ../architecture/<file>.md#<anchor>`.
- Every claim about a component, interface or store links to its anchor
  in `components.md`, `overview.md` or `architecture.md`. Check that the
  anchor exists: a heading `## Content Storage Model` gives
  `#content-storage-model`.
- Name things the way the sibling documents name them. One component,
  one name.

Markdownlint rules the CI applies to `docs/`:

- lines of 80 characters at most. Tables and code blocks are exempt
- `-` for list items, `_text_` for emphasis, `**text**` for strong
- `#` headings, no two sibling headings with the same text
- `---` for a horizontal rule, three backticks for a code block
- no trailing spaces

## 4. Check

Run `/spec-doc docs/decisions/NNNN-<slug>.md` in write mode. Fix the
record until the coverage table has no `MISSING` row. A `not relevant`
row needs its one-line reason. The coverage block goes into the report.

## 5. Link

The document that named the gap now points at the answer, in the same
pull request:

- An open question `Qn`: mark it resolved the way
  `open-questions.md` marks other resolved questions. Read the file and
  follow it. Link to the new ADR.
- A document that says a matter is unresolved or tentative: change
  that sentence to state the decision and link to the ADR.
- A superseded ADR: its status line, as in step 1.

Change nothing else in those files.

## 6. Lint

```bash
pre-commit run --files docs/decisions/NNNN-<slug>.md <every file step 5 touched>
```

Fix what it reports and run it again. Then stop.

Report: the file and its number, what it resolves, the files step 5
touched, the coverage block from step 4, and the pre-commit result. Say
that the next step is a commit by the user, then `/pr-create`.
