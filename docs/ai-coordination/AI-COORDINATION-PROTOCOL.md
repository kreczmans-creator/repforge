# AI coordination protocol — human-supervised autonomous engineering pipeline

Status: Proposed (owner approval requested: `DECISION-LOG.md` DL-0001)
Version: 2 (2026-11-04; version 1 was the file-exchange protocol, superseded the same day by the owner's revised brief)
Author: Claude Code (drafted); project owner (approves)

## 1. Purpose and operating model

RepForge is built by a pipeline with one human gate:

| Party | Role |
|---|---|
| Claude Code | Primary implementation and execution agent. Works autonomously inside approved scope. |
| ChatGPT | Independent technical reviewer and engineering oversight. Initiated by the owner in the existing ChatGPT conversation. |
| GitHub | Source of truth, communication channel and evidence store. |
| Project owner | Final authority for owner-reserved decisions, formal acceptance and release control. |

The owner makes engineering decisions. The owner does not relay reports, diffs, test results or findings between systems: every one of those is a file or a link in this repository.

No OpenAI API, Anthropic API orchestration, paid orchestration service, always-on model-to-model server or automated merge or acceptance is used (owner brief 2026-11-04 §2). Everything runs on Claude Code, GitHub, GitHub Actions and the owner's existing ChatGPT with its GitHub connection.

## 2. Roles and boundaries

### Claude Code — autonomous implementation inside approved scope
May, without asking: implement approved work packages in D06 order; start the next eligible package (§7); run format, analysis, tests and CI; fix defects; address review findings; update documentation, ADRs (as Proposed), D05, D06 statuses and delivery records; produce handoffs; resubmit corrected work; keep `CURRENT-STATE.md` and `PROGRAMME.md` accurate.

Must stop and queue an owner decision (§8) for anything owner-reserved. Must never: fabricate test, CI, device or review evidence; record a decision the owner did not state; merge to `main`; accept work; close a finding without evidence; change scope to make a package look complete; proceed through a known blocker; bypass a D06 dependency.

### ChatGPT — independent technical review
Reviews a specific commit against the twelve dimensions in §5 and returns exactly one outcome: `APPROVED_FOR_OWNER_ACCEPTANCE`, `CHANGES_REQUIRED`, `BLOCKED` or `REVIEW_INCOMPLETE`. Identifies defects, risks, omissions, debt; checks consistency with D03, ADRs, standards, D04 and D06; says what it could and could not verify. Recommends to the owner; never approves on the owner's behalf. Must not claim to have read code, run tests or checked CI unless it did; `REVIEW_INCOMPLETE` exists for that case.

### Project owner — final authority
Exclusive over: work package acceptance; architecture decisions (ADR Accepted); scope changes; material requirement changes; accepted deviations; risk acceptance, including residual high-severity risk; technical debt disposition where approval is required; physical-device verification needing owner hardware; merge to `main`; release approval.

Neither AI may treat silence, green CI, a passing test suite or a positive review as owner approval. An owner decision exists only when recorded in `DECISION-LOG.md` with `Decided by: Owner`, or in a delivery record's owner-decisions table, in the owner's words. Technical approval (`APPROVED_FOR_OWNER_ACCEPTANCE`) is not acceptance.

## 3. Files and identifiers

All under `docs/ai-coordination/` unless stated.

| File | Purpose | Written by |
|---|---|---|
| `AI-COORDINATION-PROTOCOL.md` | This document | Claude Code drafts; owner approves |
| `CURRENT-STATE.md` | Authoritative concise status; imported into every Claude Code session | Claude Code |
| `PROGRAMME.md` | Work package table: dependencies (from D06), implementation, review and acceptance state per package | Claude Code; D06 stays authoritative on scope and sequencing |
| `DASHBOARD.md` | Owner dashboard, **generated** from the records by the checker; never hand-edited | Checker (`--write-dashboard`) |
| `INBOX.md` | Messages to Claude Code; imported into every session | ChatGPT via the owner; owner; Claude Code updates status and responds |
| `OUTBOX.md` | Messages from Claude Code | Claude Code |
| `handoffs/HO-NNNN.md` | One handoff per submitted commit (`HANDOFF-TEMPLATE.md`) | Claude Code |
| `reviews/RV-NNNN.md` | One independent review per handoff (`REVIEW-TEMPLATE.md`) | ChatGPT, committed by the owner; Claude Code updates finding `Status`/`Resolution` cells only |
| `DECISION-LOG.md` | Every substantive decision and the owner-decision queue | Claude Code records; owner decisions in the owner's words |
| `archive/` | Closed messages, moved verbatim | Claude Code |
| `EXAMPLE-WALKTHROUGH.md`, `MCP-INTEGRATION-ASSESSMENT.md` | Reference | — |
| `.github/workflows/coordination.yml`, `tools/coordination/` | Automation (§6) | Claude Code |
| `CLAUDE.md`, `.claude/skills/` | Claude Code discovery and procedures (§9) | Claude Code |

Identifiers: `HO-NNNN`, `RV-NNNN`, `RV-NNNN-Fn` (findings), `MSG-IN-NNNN`, `MSG-OUT-NNNN`, `DL-NNNN`. Sequential, never reused. Every record names its authoring system (`Author:`).

## 4. States

**Handoff status** (the coordination state of a submitted commit):

| Status | Meaning |
|---|---|
| `AWAITING_REVIEW` | Submitted; no review on file for this commit |
| `CHANGES_REQUIRED` | Latest review outcome; corrections owed by Claude Code |
| `APPROVED_FOR_OWNER_ACCEPTANCE` | Latest review outcome; technically approved at this exact commit; owner decision owed |
| `BLOCKED` | Review or implementation cannot proceed; blocker named in the record |
| `REVIEW_INCOMPLETE` | Reviewer could not obtain the evidence; owner action or a new handoff needed |
| `ACCEPTED_BY_OWNER` | Owner recorded acceptance (`DL-NNNN` cited in the handoff) |
| `SUPERSEDED` | A later handoff replaced it (new commit); its review results do not carry forward |

**Review outcome**: `APPROVED_FOR_OWNER_ACCEPTANCE`, `CHANGES_REQUIRED`, `BLOCKED`, `REVIEW_INCOMPLETE`. A review names exactly one commit; it applies to no other.

**Finding, message and review-record status**: `OPEN`, `IN_PROGRESS`, `BLOCKED`, `RESOLVED` (Claude Code reports done, with evidence), `ACCEPTED_BY_OWNER` (owner accepted as debt or deviation; `DL-` and `TD-` cited), `CLOSED` (reviewer confirmed in re-review, or owner decision).

**Programme states** (`PROGRAMME.md`): Implementation `NOT_STARTED | IN_PROGRESS | DELIVERED`; Review `NONE | LEGACY | <handoff status>`; Acceptance `NOT_ACCEPTED | CONDITIONALLY_ACCEPTED | ACCEPTED | CLOSED`. `LEGACY` marks packages reviewed inside their delivery record before this protocol existed.

The three axes are never merged: delivered ≠ approved ≠ accepted.

## 5. Lifecycle (Stages A–F)

**A — Implementation.** Claude Code implements an approved package or correction on its working branch, following D03, the standards and the D04 acceptance criteria. Local checks: `dart format`, `flutter analyze --fatal-infos`, `flutter test`, coverage gate.

**B — Delivery submission.** Claude Code commits implementation, tests, delivery record and supporting documentation; waits for CI run IDs; then commits `handoffs/HO-NNNN.md` citing the exact implementation commit and its parent. Any later change to the submitted code is a new commit and therefore a new handoff; the earlier handoff becomes `SUPERSEDED`.

**C — Review requested.** The handoff is created with `Status: AWAITING_REVIEW`. Claude Code appends `MSG-OUT`, updates `CURRENT-STATE.md` and `PROGRAMME.md`, regenerates `DASHBOARD.md`, runs the checker and pushes. The workflow validates the records and opens or updates one GitHub issue per handoff, labelled `ai-review`, holding every evidence link (§6). GitHub does not notify ChatGPT; the owner starts the review by asking ChatGPT, in the existing conversation, to inspect the latest delivery.

**D — Review response.** ChatGPT retrieves the evidence through its GitHub connection (commit, compare view, files, tests, CI checks, D04, ADRs, D05, delivery record, all linked from the issue and the handoff), assesses the twelve dimensions below, and returns the complete `reviews/RV-NNNN.md`. The owner commits the file to the working branch. The review's `Outcome` becomes the handoff's status (Claude Code sets the `Review:` and `Status:` lines on its next session if the owner did not; the checker refuses any mismatch).

Review dimensions: 1 functional correctness; 2 architectural consistency; 3 domain model integrity; 4 data persistence and migration safety; 5 error handling; 6 security and privacy; 7 test coverage and quality; 8 regression risk; 9 requirements compliance; 10 documentation and governance accuracy; 11 technical debt; 12 acceptance evidence.

**E — Correction.** On `CHANGES_REQUIRED`, Claude Code reads every finding, investigates the cause, implements corrections, adds regression tests, runs all relevant validation, updates the delivery evidence, commits, and submits a new handoff with `Responds to: RV-NNNN` and `Supersedes: HO-<previous>`. It sets each finding to `RESOLVED` with the fixing commit and the proving test in the `Resolution` cell. A finding is never marked resolved without that evidence.

**F — Re-review.** The corrected commit is reviewed again as a new review (`RV-<next>`), which closes or reopens the earlier findings. Approval of an earlier commit never carries forward: the checker rejects a handoff that claims an outcome from a review of a different commit.

**Acceptance.** When the handoff is `APPROVED_FOR_OWNER_ACCEPTANCE` and the package's acceptance conditions (D06, delivery record) are evidenced, the owner decides. Claude Code records the decision (`DL-NNNN`), sets the handoff to `ACCEPTED_BY_OWNER`, updates the delivery record, D05, D06, `PROGRAMME.md` and `CURRENT-STATE.md`.

## 6. Automation (no API cost, no secrets)

`.github/workflows/coordination.yml` runs on every push and pull request touching the coordination files, `CLAUDE.md`, the skills or the tools:

1. **Validate** (`tools/coordination/check_coordination.py`): required files and sections; statuses, outcomes and severities; handoff ↔ review ↔ commit consistency (approval cannot carry across commits; a correction must be a new commit; a superseded handoff is marked so); findings table; programme table consistency and eligibility; decision log; message metadata and references; relative links; `CLAUDE.md` imports; `DASHBOARD.md` freshness. Errors fail the run. Warnings and the queues (review queue, open findings, owner-decision queue, next eligible packages) go to the job summary.
2. **Notify** (`tools/coordination/sync_review_issues.py`, push events only, `issues: write` with the Actions token): one issue per handoff titled `[AI review] HO-NNNN — …`, body generated from the handoff: commit, compare-with-parent, raw diff and checks links, handoff and review links, delivery record, D05/D06, and the exact sentence the owner can paste into ChatGPT. On status change it comments and updates the body; when a handoff is superseded or owner-accepted it closes the issue (bookkeeping, not acceptance). It never writes "reviewed"; it reports "review on file" only when a review file exists in the repository.
3. **Evidence pack** (`check_coordination.py --evidence HO-NNNN`, run locally by Claude Code or the owner): one Markdown bundle (handoff, links, diff stat, open findings) for the case where the ChatGPT connector cannot reach the repository and the owner pastes once.

Not automated, by design: review itself, acceptance, merge, closing findings, anything requiring a secret or a paid service.

## 7. Autonomous work package progression

D06 is the authoritative roadmap. `PROGRAMME.md` mirrors its dependency graph and the current state of each package. Claude Code maintains both.

Eligibility: a package is eligible when its implementation is `NOT_STARTED` and every hard D06 dependency is owner-accepted (conditionally or fully) or technically approved (`APPROVED_FOR_OWNER_ACCEPTANCE`). Soft dependencies do not block. The checker lists eligible packages; `DASHBOARD.md` shows them.

Order of work in a session:
1. Corrections owed (`CHANGES_REQUIRED` handoffs, open findings touching current work).
2. Closure conditions of conditionally accepted packages that are Claude Code's to do (for example the WP 7 portion-precision condition).
3. The lowest-numbered eligible package.

Rules: never bypass a dependency; never close a package without its acceptance conditions; never treat technical approval as acceptance; never proceed through a known blocker (a `BLOCKED` handoff, a failing required workflow, an unresolved Critical finding on the code being built on); never alter scope silently. Where a dependency is conditionally accepted with outstanding owner conditions (WP 6 device verification, WP 7 precision), the dependent handoff lists that inherited condition under "Outstanding findings" so the reviewer and owner see it.

Preserved position (owner brief 2026-11-04): WP 0–5 accepted and closed; WP 6 delivered, physical-device verification and D05 V-01 outstanding; WP 7 delivered, NUT-017 revision 1.3 precision correction outstanding; WP 8 onwards is the pipeline; WP 15 is "Nutrition entry units and serving sizes", including recognised serving quantities such as biscuits, slices, eggs and millilitres (owner wording; D06 WP 15 text remains as approved until the owner confirms the wording change, DL-0005).

## 8. Owner escalation and the decision queue

Always owner-reserved: new features outside approved scope; material requirement changes; new architectural decisions (ADR acceptance); significant deviations; residual high-severity risks; physical-device verification needing owner hardware; formal package acceptance; production release; merge to `main`.

Claude Code does not interrupt implementation for each item. It appends a `DL-NNNN` row with `Decided by: Pending owner decision`, states options and a recommendation in the relevant handoff §13, and continues unrelated eligible work. The pending rows are the owner-decision queue; `DASHBOARD.md` lists them. The owner answers by editing the row (or by a message in `INBOX.md`), and Claude Code records the answer in the owner's words.

## 9. Claude Code discovery and session procedure

`CLAUDE.md` (repository root) is loaded at the start of every Claude Code session and imports `CURRENT-STATE.md` and `INBOX.md` with `@path`, so both are in context in the CLI, cloud sessions and the GitHub Action without hooks or approvals. Hooks are deliberately not used: SessionStart hooks do not run in multi-repository or project-thread cloud sessions and require folder trust, so they would be a false guarantee. Skills: `/handoff` (Stage B–C), `/resolve-findings` (Stage E). The checker is the backstop that catches omissions after a push.

Session start: compare the state commit with `git log -1`; process `INBOX.md`; open every review with non-closed findings; read `PROGRAMME.md`; pick work by §7. Session end: handoff if a unit of work was delivered; otherwise update `CURRENT-STATE.md` with where the work stands and push.

## 10. Rules that keep the trail honest

- Append, never overwrite. Status and resolution cells change; nothing else is rewritten. Corrections are new entries referencing old ones.
- Findings belong to a review ID, not to a commit; they survive until closed by evidence and re-review or by an owner decision.
- Every record names its author system. Every decision names its decider.
- Evidence distinction (owner direction, WP 6): CI and emulator results prove automated behaviour only. Device results are entered only when the owner supplies them.
- No credentials in any file. Run IDs, SHAs and paths are the evidence.
- The protocol is not reported as bidirectional until a ChatGPT review has actually been committed and processed through it and the fact recorded in `DECISION-LOG.md`.

## 11. Relationship to existing governance

| Existing mechanism | Relationship |
|---|---|
| Delivery records `docs/delivery-record/WP<n>.md` | Remain the acceptance record; a handoff points at them. Owner decisions continue to be recorded there and mirrored in `DECISION-LOG.md`. |
| ADRs | Unchanged. A handoff proposing an ADR lists it in §13. |
| D05 | Unchanged. Findings accepted as debt get a `TD-` row; verification items stay in §C. |
| D06 | Authoritative on scope and sequencing; `PROGRAMME.md` mirrors state and must not contradict it. |
| Engineering standards §9 | Unchanged. Independent review precedes the owner's PR review; squash merge by the owner only. |
| "Fresh reviewer" sections in old delivery records | History; new work uses `reviews/`. `PROGRAMME.md` marks them `LEGACY`. |

## 12. Limitations

- The review is initiated by the owner in the ChatGPT conversation; GitHub cannot trigger ChatGPT. The owner also commits the review file (one action).
- Whether the owner's ChatGPT plan can read a private repository through the connector is an owner-side fact (DL-0002). Without it, the evidence pack is pasted once.
- `CLAUDE.md` is context, not enforcement. The checker catches structural omissions after a push, not behavioural ones.
- The checker validates form and internal consistency, not truth. ChatGPT and the owner verify evidence.
- Issue creation uses the Actions token; it works for pushes to this repository, not for pull requests from forks.
