# AI coordination protocol

Status: Proposed (owner approval requested; see `DECISION-LOG.md`)
Date: 2026-11-04
Author: Claude Code (drafted); project owner (approves)

## 1. Purpose

Two AI systems work on RepForge. Claude Code implements. ChatGPT reviews independently. The project owner decides. This protocol lets the two systems exchange handoffs, reviews and decisions through files in this repository, so the owner no longer relays reports by hand. GitHub is the shared record. Nothing here changes application functionality or existing governance (`docs/engineering-standards.md`, `docs/adr/`, `docs/wp0/D05`, `docs/wp0/D06`). It adds a message layer on top of them.

## 2. Roles and boundaries

### ChatGPT — independent technical oversight
- Reviews implementation proposals, architecture and delivered work against the handoff evidence.
- Challenges technical decisions and assumptions.
- Identifies defects, risks, omissions and technical debt; classifies findings by severity.
- Checks consistency with D03, the ADRs, the engineering standards and D06.
- Reviews delivery records and states whether acceptance criteria are evidenced.
- Recommends; proposes decisions for the owner; says when owner approval is required.
- Writes reviews in the `REVIEW-TEMPLATE.md` format and messages in `INBOX.md`.
- Does not approve or accept work. A review recommendation is never an acceptance. ChatGPT is never recorded as having approved anything.

### Claude Code — implementation and repository execution
- Implements approved work on the working branch; maintains code, tests and documentation.
- Runs local validation and CI; records run IDs and actual results.
- Produces delivery records, handoffs (`HANDOFF-TEMPLATE.md`) and messages in `OUTBOX.md`.
- Reads `INBOX.md` and the open reviews before starting or continuing work; addresses findings; reports resolution with evidence.
- Maintains `CURRENT-STATE.md`, `DECISION-LOG.md`, D05 and the delivery records accurately.
- Never fabricates test results, CI results, owner decisions, review results or acceptance evidence. Unverified means unverified.
- Does not merge to `main`, does not accept work, does not close a finding that the reviewer or owner has not seen resolved.

### Project owner — final authority
Exclusive authority over: work package acceptance; architecture decisions requiring approval (ADR status Accepted); scope changes; accepted deviations; risk acceptance; technical debt disposition where approval is required; merge to `main`; release approval.

Neither AI may treat silence, a green CI run, a passing test suite or a positive review as owner approval. An owner decision exists only when it is recorded in `DECISION-LOG.md` with the owner named as the decider, or in a delivery record's owner-decisions table, in the owner's words.

## 3. Files

All under `docs/ai-coordination/`.

| File | Purpose | Written by |
|---|---|---|
| `AI-COORDINATION-PROTOCOL.md` | This document | Claude Code drafts; owner approves changes |
| `CURRENT-STATE.md` | Snapshot of where the project is; loaded into every Claude Code session | Claude Code |
| `INBOX.md` | Messages to Claude Code (from ChatGPT or the owner); loaded into every Claude Code session | ChatGPT via the owner; owner; Claude Code updates `Status` and adds responses only |
| `OUTBOX.md` | Messages from Claude Code to ChatGPT and the owner | Claude Code; ChatGPT or owner update `Status` only |
| `handoffs/HO-NNNN.md` | One handoff per meaningful unit of work (`HANDOFF-TEMPLATE.md`) | Claude Code |
| `reviews/RV-NNNN.md` | One independent review per handoff (`REVIEW-TEMPLATE.md`) | ChatGPT via the owner; Claude Code updates finding `Status` and `Resolution` cells only |
| `DECISION-LOG.md` | Every substantive decision, who made it, what it refers to | Claude Code records; owner decisions only in the owner's words |
| `archive/` | Closed messages, moved verbatim when the live files grow | Claude Code |
| `EXAMPLE-WALKTHROUGH.md` | A worked example of one full cycle | Reference only |
| `MCP-INTEGRATION-ASSESSMENT.md` | Future direct model-to-model option | Reference only |

Identifiers: `HO-NNNN` handoffs, `RV-NNNN` reviews, `RV-NNNN-Fn` findings, `MSG-IN-NNNN` and `MSG-OUT-NNNN` messages, `DL-NNNN` decisions. Numbers are sequential and never reused. Every record names its authoring system in an `Author` field.

## 4. Statuses

| Status | Meaning |
|---|---|
| `OPEN` | Created; nobody has started acting on it |
| `IN_PROGRESS` | The responsible party is acting on it |
| `BLOCKED` | Cannot proceed; the blocker is named in the record |
| `RESOLVED` | The responsible party reports it done, with evidence; awaiting re-review or owner decision |
| `ACCEPTED_BY_OWNER` | The owner has recorded a decision on it (`DL-NNNN` cited) |
| `CLOSED` | No further action; the trail is complete |

A handoff is `RESOLVED` when its review has no open required corrections. It is `ACCEPTED_BY_OWNER` only when the owner records acceptance. A finding is `RESOLVED` by Claude Code with evidence, and `CLOSED` only by the reviewer (re-review) or by an owner decision. A finding may be `ACCEPTED_BY_OWNER` when the owner accepts it as tracked debt (then it also gets a D05 `TD-` entry).

## 5. Lifecycle

1. Claude Code completes a meaningful unit of work (a work package stage, a fix set, a closure condition).
2. Claude Code commits the implementation and supporting documentation on the working branch, with CI runs recorded.
3. Claude Code creates `handoffs/HO-NNNN.md` from the template, citing the exact implementation commit SHA, and commits it (the handoff commit follows the implementation commit it describes).
4. Claude Code appends a `MSG-OUT` to `OUTBOX.md` and updates `CURRENT-STATE.md`.
5. The owner points ChatGPT at the handoff (link to the file on the branch, or pasted content; see §7). ChatGPT reviews the evidence independently: it reads the diff, the tests, the CI runs and the records, not the handoff's claims.
6. ChatGPT writes `reviews/RV-NNNN.md` in the template format. The owner commits it to the working branch and, optionally, a `MSG-IN` in `INBOX.md`. If the owner commits only the review file, Claude Code adds the `MSG-IN` entry when it next reads the inbox, marked "indexed by Claude Code".
7. Claude Code reads the review, sets each finding to `IN_PROGRESS`, fixes the required corrections, and sets each to `RESOLVED` with the fixing commit and the test that proves it in the `Resolution` cell. It appends a `MSG-OUT` reporting the resolution and the evidence.
8. ChatGPT re-reviews where the review's "Re-review conditions" say so, and sets findings to `CLOSED` or reopens them in a new review (`RV-NNNN` referencing the earlier one).
9. The owner makes any required decision (acceptance, deviation, debt disposition, merge).
10. Claude Code records the owner's decision verbatim in `DECISION-LOG.md`, updates the delivery record, D05, D06 and `CURRENT-STATE.md`, and sets the affected records to `ACCEPTED_BY_OWNER` or `CLOSED`.

## 6. Rules that keep the trail honest

- **Append, do not overwrite.** Messages and reviews are never deleted or rewritten. Status cells and resolution cells change; everything else stays. Corrections are new entries that reference the old ones.
- **Findings survive commits.** A finding is tied to its review ID, not to a commit. A new commit does not close it; a `RESOLVED` entry with evidence does, after re-review or owner decision.
- **Every record names its author system.** `Author: Claude Code`, `Author: ChatGPT (relayed by the owner)`, `Author: Owner`.
- **Every substantive decision is traceable**: a `DL-NNNN` entry names the decider, the date, and the handoff, review, ADR, WP or TD it affects.
- **No implied approval.** "Recommend accept" from ChatGPT and "ready for acceptance" from Claude Code are recommendations. Only `DL-` entries with `Decided by: Owner` change acceptance state.
- **Evidence distinction** (owner direction, WP 6): CI and emulator results prove automated behaviour only. Device results are entered only when the owner supplies them.
- **No secrets** in any coordination file. Run IDs, SHAs and file paths are the evidence; tokens are never.
- **Lean.** A handoff for a trivial change is not required; a commit message suffices. A handoff is required for: a WP stage or closure, a fix set responding to a review, an architecture change, a scope conflict, or anything that needs an owner decision.

## 7. How ChatGPT reaches the repository today

The repository is private. ChatGPT reads it one of two ways:
1. **GitHub connector** (ChatGPT's built-in connector, read-only), if enabled on the owner's plan, pointed at `kreczmans-creator/repforge` and the working branch.
2. **Owner relay**: the owner pastes the handoff file and any files it names, or shares the raw-file links, into the ChatGPT conversation.

ChatGPT writes back only through the owner: the owner commits the review file ChatGPT produces. One commit per review, through the GitHub web editor or any git client. This is the only manual step on the review path. Direct writes by ChatGPT are a future option; see `MCP-INTEGRATION-ASSESSMENT.md`. Until that is demonstrated and recorded in `DECISION-LOG.md`, this protocol is **not live and not bidirectional**: it is a filing system that both systems can read and that the owner can write to in one action.

## 8. How Claude Code discovers the system

- The root `CLAUDE.md` is loaded by Claude Code at the start of every session (CLI, cloud, GitHub Action) and imports `CURRENT-STATE.md` and `INBOX.md` into context. Keep both short; archive closed messages.
- `CLAUDE.md` states the pre-task checklist (§9) and the handoff rules.
- The skill `.claude/skills/handoff/SKILL.md` (`/handoff`) walks through creating a handoff and the matching outbox and state updates.
- No hooks are installed: SessionStart hooks do not run in every session type and need folder trust, so they would be a false guarantee. `CLAUDE.md` content is advisory; the GitHub Actions check (§10) catches structural omissions after the fact.

## 9. Claude Code pre-task and post-task checklist

Before starting a task:
1. Read `CURRENT-STATE.md` (in context) and compare its commit with `git log -1`. If they differ, the state is stale; update it before relying on it.
2. Read `INBOX.md` (in context). Any message with status `OPEN` or `IN_PROGRESS` addressed to Claude Code is handled, or explicitly deferred with a reason in a `MSG-OUT`, before new work starts.
3. Open every review in `reviews/` with findings not `CLOSED`/`ACCEPTED_BY_OWNER`; list the ones that touch the planned work.
4. Identify dependencies: D06 ordering, open owner decisions in `CURRENT-STATE.md`, open verification items in D05 §C.

After meaningful implementation:
1. Commit implementation; wait for CI run IDs.
2. Create `handoffs/HO-NNNN.md` (`/handoff`), commit it.
3. Append `MSG-OUT`; update `CURRENT-STATE.md`; update D05 and the delivery record if they changed.
4. Run `python3 tools/coordination/check_coordination.py` and fix what it reports before pushing.

After addressing review findings:
1. Update each finding's `Status` and `Resolution` in the review file (cells only).
2. Append `MSG-OUT` listing each finding, the fixing commit, and the test or run that proves it.

## 10. Automation (GitHub Actions)

`.github/workflows/coordination.yml` runs `tools/coordination/check_coordination.py` on every push and pull request that touches `docs/ai-coordination/**`, `CLAUDE.md` or the tool. It fails on: missing required files or sections, invalid statuses or severities, dangling references between handoffs, reviews, messages and decisions, duplicate IDs, malformed commit SHAs, broken relative links. It warns on: open findings, handoffs with no review, open messages, unarchived closed messages. The warnings are written to the run's job summary, which serves as the coordination index. It needs no secrets, creates no issues, merges nothing and accepts nothing. It cannot and does not say whether ChatGPT reviewed anything.

Changes to `main` are governed by branch protection (owner setting on GitHub: require a pull request, require the CI status checks, no force pushes, no direct pushes). The checker cannot enforce that; the owner confirms the setting (see `DECISION-LOG.md` DL-0003).

## 11. Relationship to existing governance

| Existing mechanism | Relationship |
|---|---|
| Delivery records `docs/delivery-record/WP<n>.md` | Remain the acceptance record. A handoff points at the delivery record; it does not replace it. Owner decisions continue to be recorded there and are mirrored in `DECISION-LOG.md`. |
| ADRs | Unchanged. A handoff that proposes an ADR lists it under "Decisions required from the project owner". |
| D05 register | Unchanged. Findings accepted as debt get a `TD-` row; verification items stay in D05 §C. |
| D06 roadmap | Unchanged. `CURRENT-STATE.md` summarises; D06 remains authoritative on sequencing and status. |
| Engineering standards §9 (PR per WP, owner review, squash merge) | Unchanged. The protocol adds the independent-review step before the owner's PR review. |
| "Fresh reviewer" sections inside delivery records | Superseded for new work by `reviews/RV-NNNN.md`; existing sections stay as history. |

## 12. Limitations

- Not live: ChatGPT cannot write to the repository without the owner's action, and reading needs the connector or the owner's paste.
- `CLAUDE.md` is context, not enforcement. Claude Code can fail to follow it; the checker catches structural gaps only after a push.
- The checker validates structure, not truth. It cannot tell a real CI run ID from an invented one. Independent verification of evidence remains ChatGPT's and the owner's job.
- Two live files are loaded into every Claude Code session. If they grow, context cost grows; archiving keeps them small.
