---
name: "spec-doc"
description: >
  The rules for writing or changing any document under docs/, as set in
  AGENTS.md: read every sibling document first, account for every
  component, interface and constraint in components.md and overview.md,
  and cross-check deployment topology, security posture and persistent
  state. Produces a coverage table with no blank rows. Use before you
  create or edit a file under docs/, when asked to "check a spec", "check
  coverage", or "/spec-doc <path>". pr-review uses it on a pull request
  that touches docs/.
---

# Checking a specification document

`AGENTS.md` sets four rules for every document under `docs/`. Read them
there, in the section "Specification document hierarchy". This skill
turns them into a procedure with an output that shows the rules were
applied, not only read.

Two modes:

- `write`, the default. You are about to create or change the document.
  A gap in the table is fixed in the document, then the row is judged
  again.
- `check`. A review. You report and change nothing. `pr-review` runs
  this mode on a pull request that touches `docs/`, and its `MISSING`
  rows become findings.

The argument is the path of the document. Without one, ask.

| Step | Does |
|------|------|
| 1. Read | Every document in the hierarchy, end to end, and every ADR |
| 2. Inventory | Every component, interface, constraint, store, topology and security rule, with its source anchor |
| 3. Cover | One row per inventory item against the document |
| 4. Cross-check | Topology, security posture, persistent state |
| 5. Consistency | Every claim at its source, every link at its target, one name per thing |
| 6. Output | The coverage block |

## 1. Read

The hierarchy, as `AGENTS.md` lists it today:

| File | Holds |
|------|-------|
| `docs/vision.md` | purpose, users, outcomes |
| `docs/architecture.md` | external interfaces, persistent state, environmental constraints |
| `docs/architecture/overview.md` | guiding principles, EARS format, workflow, platform |
| `docs/architecture/components.md` | components, interfaces, cross-cutting concerns |
| `docs/architecture/user-interaction-flow.md` | phases, sequence diagrams, testing strategy |
| `docs/architecture/related-work.md` | projects that inform the design |
| `docs/architecture/open-questions.md` | unresolved questions |
| `docs/decisions/` | architecture decision records |

Open `AGENTS.md` at the head you work on. If it lists a file that is not
in this table, read that file too. The list in `AGENTS.md` wins.

Read every file end to end. Not the headings, not the first screen. In
`check` mode, read them at the pull request head:

```bash
git show "refs/pr/$PR:<path>"
```

While you read, note every named thing and where it is defined. Step 2
is built from these notes, not from memory.

## 2. Inventory

Build one list with a source anchor for every item. Collect by reading,
not by assuming headings.

| Kind | Take from | What counts |
|------|-----------|-------------|
| component | `components.md` | every part that has its own section or its own name in the component list |
| interface | `components.md`, `architecture.md` | every CLI subcommand, API, file format or protocol a component exposes or consumes |
| constraint | `overview.md` guiding principles, `architecture.md` environmental constraints | every rule the design must obey |
| store | `architecture.md` persistent state | every place state lives between runs |
| topology | `overview.md` | every deployment shape it names, such as single-player, multi-player, web |
| security | `architecture.md`, `overview.md` | every rule on credentials, isolation and sandboxes |

The anchor is the GitHub heading anchor: `components.md#ears-manager`.
Check that it exists.

## 3. Cover

One row per inventory item:

| Verdict | Means | Needs |
|---------|-------|-------|
| `covered` | the document addresses it | the `path:line` in the document |
| `not relevant` | the document's scope excludes it | one line that says why |
| `MISSING` | the document's scope includes it and the document is silent | — |

A `not relevant` row without a reason is `MISSING`. Never mark a row
`not relevant` to make the table green. The test is: would a reader of
this document need to know how this item applies? If yes, it is
relevant.

In `write` mode, a `MISSING` row is a change to the document. Make it,
then judge the row again. In `check` mode, a `MISSING` row is a finding
in the caller's format, `issue (blocking)`, with the item, its source
anchor, and the place in the document where it belongs.

If the document introduces a component, interface or store that the
inventory does not have, the same pull request must add it to
`components.md` or `architecture.md`. Say so in the output. A new
thing that lives only in one document is a gap in the hierarchy.

## 4. Cross-check

Three groups of rows, in the same table, from rule 3 in `AGENTS.md`:

- **Topology.** For each deployment shape in the inventory: the
  document says how it applies there, or says why it does not.
- **Security posture.** For each security rule: the document keeps it,
  or says why the rule does not reach its scope.
- **Persistent state.** Every store the document touches is named as
  `architecture.md` names it. No store is introduced here that
  `architecture.md` does not list.

## 5. Consistency

- Every claim the document makes about another document is checked at
  the source. Open the file, find the line, compare.
- Every link resolves: the file exists and the anchor exists.
- One thing, one name. A component called two ways across documents is
  a finding.
- A statement that contradicts an accepted ADR is a `MISSING`-grade
  finding. Either a new ADR supersedes the old one, or the document is
  wrong. Say which.

## 6. Output

The block below, in the chat. In `check` mode, also hand it to the
caller. In `write` mode, fix the document first, so the block shows the
final state.

```markdown
### Coverage: docs/<path>

Read: <n> hierarchy files, <m> decision records.
Inventory: <c> components, <i> interfaces, <k> constraints,
<s> stores, <t> topologies, <r> security rules.

| Item | Kind | Source | In this document | Verdict |
|------|------|--------|------------------|---------|
| ears-manager | component | components.md#ears-manager | docs/x.md:41 | covered |
| web | topology | overview.md#platform | — | not relevant: the document covers the CLI path only |

Cross-checks: topology <ok or gap>, security <ok or gap>,
state <ok or gap>.
Consistency: <n> links checked, <n> claims checked, <n> mismatches.
New things this document introduces: <none, or the list and where
they must be added>.
```

Then, in `write` mode, lint the document the way CI will:

```bash
pre-commit run --files docs/<path>
```

Lines of 80 characters at most, `-` list items, `_emphasis_`,
`**strong**`, `#` headings, `---` rules, backtick fences, no trailing
spaces. Tables and code blocks are exempt from the line limit.

## Rules

- Cite sources, not memory. A row without an anchor is not done.
- Read the whole hierarchy every time. A document changed since the
  last run is the usual cause of a contradiction.
- The document's scope is what its own opening says it is. Do not
  narrow it to pass the table.
- Never edit a sibling document in `check` mode. In `write` mode, edit
  a sibling only to register a new thing, and say so.
