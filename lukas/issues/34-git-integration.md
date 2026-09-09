# Issue #34 — Define the Single-Player Git Integration

Brief for the worktree agent. Written 2026-09-10 from the issue, the
specification hierarchy at `upstream/main`, and the pending PR 81.
Assigned to lukaskellerstein. Branch `lukas/34-git-integration`.

## The question (from the issue)

How does the Drafting Table turn governed specification changes into
reviewable Git history in single-player and multi-player modes?

Scope: project identification, artifact-path selection,
`.protobot/project.yaml`, branch and commit behavior, PR preparation,
approved specification state, the permitted Git operations, which writes
go through `ears-manager`, and how IdeaBot material seeds a session
without becoming a hard dependency.

Completion criteria:

1. A local bare-repository fixture covers project initialization, branch
   creation, commit, and reviewable PR preparation.
2. Direct edits to registered specification artifacts are rejected or
   caught by validation.
3. Single-player and multi-player behavior differ only in review
   ceremony, not artifact ownership.
4. Merge and failure behavior is explicit.

## Where the document goes

New file `docs/architecture/git-integration.md`. Precedent: PR 81 added
`docs/architecture/drafting-table-ux.md` for #28 with this shape:
Purpose and scope → Relationship to sibling contracts (#28, #30, #33) →
the contract sections → Out-of-scope decisions (a table) → Related
Documents. Follow it. Markdown rules: 80 columns, `-` lists,
`_emphasis_`, `**strong**`, `---` between major sections.

Downstream: #75 implements this contract (fixture, `project.yaml`,
branch, commit, PR). #66 is the vertical slice. Write the fixture as a
test plan #75 can execute, not as prose.

## Already decided elsewhere. Do not contradict, link instead

- Modes differ in ceremony only: `overview.md#single-player-mode`,
  `overview.md#multi-player-mode`.
- Project Repository contract, branch conventions (`wi/` for work
  items, contributor branches for drafts, `main` approved), write gates,
  merge commits: `architecture.md#project-repository`.
- Stores and schema owners: `architecture.md#specification-store-git`,
  `architecture.md#project-configuration-protobot`.
- `.protobot/` table with owners, "How it works", "Why this split",
  merge strategy (decided), open question "Branch naming and lifecycle":
  `components.md#content-storage-model`.
- Drafting Table "To project repo: creates branches/commits and opens
  PRs containing artifacts produced through ears-manager":
  `components.md#drafting-table` → Interfaces.
- Governed tools, enforcement layers, "Git operations are explicit",
  tool inventory row "Git branch/commit/PR":
  `architecture.md#governed-tool-integrations`.
- Multi-player PR → merge → materialize, and the single-player
  `register-approved-change-set` command ("direct push is not
  sufficient by itself"): `components.md#multi-player-workflow`.
- Manifest fields, `base_commit` is a full SHA, artifact registry with
  `path` and `digest` in `.protobot/project.yaml`, schema versions per
  store: `docs/decisions/0002-ears-specification-record-schema.md`.
- Manifests live in `.protobot/change-sets/`, one file per record, the
  compare/impact summary for PRs: ADR-0001 "PR reviewability plan" and
  "Change-Set History Representation".
- IdeaBot handoff is manual: `open-questions.md#q4-ideabot-handoff-format`
  and Vision non-goal 3.
- Credentials never in `.protobot/`; Bridge/Gate for hosted modes:
  `architecture.md#environmental-constraints`,
  `components.md#authentication-and-credential-isolation`.
- PR 81 (pending, cite as pending): session start initializes
  `.protobot/` through `ears-manager`, then creates a contributor branch;
  no auto-commit; commit and PR only on explicit user request; the
  mutation-ownership table names "#34" for commit and PR mechanics.

## Decisions this document must make

Suggested answers. The worktree agent proposes, you decide.

| Topic | Suggested answer |
|:--|:--|
| Project identification | `.protobot/project.yaml` at the repository root of the working tree. Identity fields plus the canonical remote and default branch. Caller-supplied project claims are not trusted. |
| Artifact paths | Registered in `project.yaml` (ADR-0002 registry). `protobot new` proposes defaults, the user confirms. Layout inside the requirement store stays with `ears-manager` (its open question). |
| Branch | One branch per change set, `cs/<nnn>-<slug>`, cut from the default branch when `change-set create` runs. The initial Sketch is a change set too. |
| Commit | Only registered paths plus the manifest. Only on explicit user request. Message `spec(CS-nnn): <intent>` with a `Change-Set:` trailer. Never amend or force-push pushed history. Refresh = merge the default branch in, then `change-set update` records the new base. |
| PR | Title from intent, body from `ears-manager compare` and `impact`. CI runs `ears-manager check`. No labels. |
| Modes | Same branch and commit rules. Multi-player: reviewer merges, merge hook registers. Single-player: user merges or pushes, then the Drafting Table runs `register-approved-change-set`. Where the choice lives (`project.yaml` vs branch protection) is a decision to record. |
| Ungoverned edits | Before staging, compare working-tree digests with the registry digests. Mismatch = refuse. CI `ears-manager check` repeats it. Path ownership in CI is the last layer. |
| Permitted operations | An allowlist table: init, branch, stage registered paths, commit, push branch, open/update PR, merge own PR (single-player), delete merged branch, merge default branch in. Everything else forbidden, `wi/` branches included. |
| IdeaBot | Input content, never a registered artifact and never a dependency. It enters only through `ears-manager artifact put`. |
| Failures | A table: missing `project.yaml`, version mismatch, dirty registered paths, branch exists, push rejected, PR creation failed, `check` failed, merge conflict, registration failed. Each with a deterministic diagnostic and the safe retry. |
| Fixture | Bare repository, steps 1 to 8 with expected results, for #75. |

## Cross-document edits in the same PR

- `components.md` Content Storage Model, open question "Branch naming
  and lifecycle": mark the change-set part resolved with a link, keep
  the `wi/` part open.
- `components.md` Drafting Table → Interfaces → "To project repo": link
  to the new document.
- `architecture.md` Project Repository: link to the new document.
- Related Documents lists where the new document belongs.
- `AGENTS.md` lists the hierarchy and is a protected path. Do not edit
  it. Ask in the PR body whether the contract documents belong there.

## Process

1. Main checkout: `/sync-fork` (fork `main` is behind, PR 61 merged).
2. `claude -w lukas/34-git-integration`. The worktree is cut from
   `upstream/main` and has the five skills linked.
3. Worktree agent: read this brief, then write the document.
4. `/spec-doc docs/architecture/git-integration.md` in write mode until
   no row is `MISSING`.
5. You read the document. `pre-commit run --all-files`. You commit.
6. `/pr-create`. Stops when CI is green.
7. Bot review in 30 to 45 minutes. `/pr-update <N>`. Repeat.
8. Maintainer approval. Merge queue. Then `/sync-fork` and `/prune`.
