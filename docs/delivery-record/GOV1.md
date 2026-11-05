# Delivery record — GOV 1: AI coordination infrastructure (human-supervised autonomous pipeline)

Date: 2026-11-04
Branch: `claude/ai-coordination-infrastructure-pcf8bb` (based on `ccr-9fda2c32-wr163b` at e45e4f7; `main` untouched)
Status: **delivered for independent review and owner decision; not accepted.** Governance work, not a D06 work package; no application code changed. Version 2 of the system (the owner's revised brief of 2026-11-04 superseded the first brief the same day; the version-1 files were extended in place).

## Scope
Owner briefs of 2026-11-04 (original and revised): a GitHub-based coordination protocol between ChatGPT (independent review) and Claude Code (implementation) with the owner as final authority; autonomous work package progression under D06 with an owner-decision queue; GitHub Actions automation without secrets or API cost; a future MCP assessment; a demonstration. Out of scope and untouched: application code, WP 6/7 implementation, existing owner decisions, D06 sequencing, merge to `main`, any external or paid service.

## Assessment of existing arrangements (before changes)
- Reused: ADRs, delivery records with owner-decision tables and CI run IDs, D05 register, D06 statuses, engineering standards, D05 §C verification items, "fresh reviewer" sections in delivery records (now `LEGACY` in `PROGRAMME.md`).
- Gaps closed: no `CLAUDE.md` or `.claude/`; no machine-checkable handoff or review format; findings embedded in delivery records lost their status across commits; no message channel; no programme-level state; `main` holds WP 0–1 while all WP 2–7 work is on `ccr-9fda2c32-wr163b`.

## Design
- **Records** (`docs/ai-coordination/`): protocol v2; `CURRENT-STATE.md` (authoritative concise status); `PROGRAMME.md` (D06 dependency graph with three independent axes: implementation, review, acceptance); generated `DASHBOARD.md`; `INBOX.md`/`OUTBOX.md`; `handoffs/HO-NNNN.md` (one per submitted commit, 14 sections, `Responds to`/`Supersedes` links); `reviews/RV-NNNN.md` (one per commit reviewed, 10 sections, outcome, findings with per-finding status); `DECISION-LOG.md` (owner decisions in the owner's words plus the pending owner-decision queue); templates, worked example, MCP assessment.
- **Lifecycle** A–F: implement → submit (two-commit: implementation, then handoff) → review requested (issue) → review response (outcome) → correction (new commit, new handoff, old one superseded) → re-review. Approval never carries across commits; the checker enforces it.
- **Discovery**: `CLAUDE.md` imports `CURRENT-STATE.md` and `INBOX.md` into every session; session-start procedure; `/handoff` and `/resolve-findings` skills. No hooks.
- **Automation** (`.github/workflows/coordination.yml`): job 1 validates (54-test checker: structure, statuses, outcome ↔ status, commit consistency, programme table and eligibility, decision log, links, imports, dashboard freshness, cited commits exist in history, append-only history since the previous push); job 2 mirrors each handoff into one `ai-review` issue with every evidence link and the sentence the owner pastes into ChatGPT, comments on status changes, closes on supersede or acceptance. Actions token only; no secrets; never records a review; never merges or accepts.
- **Evidence pack**: `check_coordination.py --evidence HO-NNNN` bundles handoff, links, diff stat and open findings for the no-connector case.

## Files created or modified
| Path | Change |
|---|---|
| `CLAUDE.md` | New: operating model, imports, session procedure, never-rules |
| `.claude/skills/handoff/SKILL.md`, `.claude/skills/resolve-findings/SKILL.md` | New skills |
| `docs/ai-coordination/AI-COORDINATION-PROTOCOL.md` | New (v2) |
| `docs/ai-coordination/CURRENT-STATE.md`, `PROGRAMME.md`, `DASHBOARD.md` (generated), `INBOX.md`, `OUTBOX.md`, `DECISION-LOG.md` | New live records |
| `docs/ai-coordination/HANDOFF-TEMPLATE.md`, `REVIEW-TEMPLATE.md`, `EXAMPLE-WALKTHROUGH.md`, `MCP-INTEGRATION-ASSESSMENT.md` | New |
| `docs/ai-coordination/handoffs/`, `reviews/`, `archive/` | New directories |
| `tools/coordination/check_coordination.py` (+ tests), `sync_review_issues.py` (+ tests), `demo_cycle.py`, `README.md`, `.gitignore` | New tooling |
| `.github/workflows/coordination.yml` | New workflow (path-filtered; Flutter workflows untouched) |
| `docs/wp0/D05-technical-debt-and-risk-register.md` | R-13 added |
| `docs/README.md` | Index rows; delivery-record list corrected |
| `docs/delivery-record/GOV1.md` | This record |

## Validation evidence
Recorded in the GOV 1 handoff (`docs/ai-coordination/handoffs/`, §6–7) with commands, outputs and run IDs. Application tests and the four Flutter workflows were not run: no file under `app/` changed and those workflows are path-filtered to `app/**`.

## Demonstration
`tools/coordination/demo_cycle.py` builds a throwaway fixture repository and runs the checker through the cycle: handoff awaiting review → review on file with `CHANGES_REQUIRED` → checker refuses the stale handoff status → corrected commit as a new handoff → checker refuses any claim that the old review approves the new commit → re-review approves. Its output (2026-11-04, tree 04d44a7):

```
=== 1. Handoff submitted: awaiting review
--- checker exit 0 (as expected)
WARN docs/ai-coordination/handoffs/HO-0101.md: HO-0101 is AWAITING_REVIEW (in the review queue)
0 error(s), 1 warning(s)

=== 2a. Review on file but handoff not updated: checker refuses the stale status
--- checker exit 1 (as expected)
ERROR docs/ai-coordination/reviews/RV-0101.md: RV-0101 is not listed in HO-0101's Review field
WARN docs/ai-coordination/reviews/RV-0101.md: open finding RV-0101-F1 (High, OPEN)
WARN docs/ai-coordination/handoffs/HO-0101.md: HO-0101 is AWAITING_REVIEW (in the review queue)
1 error(s), 2 warning(s)

=== 2b. Handoff reflects CHANGES_REQUIRED; open finding is listed
--- checker exit 0 (as expected)
WARN docs/ai-coordination/reviews/RV-0101.md: open finding RV-0101-F1 (High, OPEN)
0 error(s), 1 warning(s)

=== 3. Corrected commit submitted as HO-0102 (supersedes HO-0101, responds to RV-0101)
--- checker exit 0 (as expected)
WARN docs/ai-coordination/handoffs/HO-0102.md: HO-0102 is AWAITING_REVIEW (in the review queue)
0 error(s), 1 warning(s)

=== 4. Attempt to carry RV-0101 over to the new commit: refused
--- checker exit 1 (as expected)
ERROR docs/ai-coordination/handoffs/HO-0102.md: RV-0101 says Handoff: HO-0101
ERROR docs/ai-coordination/handoffs/HO-0102.md: review RV-0101 reviewed aaaaaaa but handoff commit is bbbbbbb; approval or findings do not carry across commits
ERROR docs/ai-coordination/handoffs/HO-0102.md: Status APPROVED_FOR_OWNER_ACCEPTANCE does not match RV-0101 Outcome CHANGES_REQUIRED
3 error(s), 0 warning(s)

=== 5. Re-review RV-0102 of the corrected commit approves; owner decision now owed
--- checker exit 0 (as expected)
0 error(s), 0 warning(s)

--- dashboard excerpt: HO-0102 listed under 'Approved, awaiting owner acceptance'

DEMO RESULT: all stages behaved as the protocol specifies
```

The live part demonstrated on this repository (2026-11-04/05):

| Step | Evidence |
|---|---|
| Automation detects the handoff | Run 41916119691 on 8ac106d: validate success; notify created issue #2 `[AI review] HO-0001` with commit, compare, raw-diff, checks, handoff and record links |
| Idempotence | Run 41916214670 on 901c728: validate success; notify printed `unchanged #2`, no duplicate issue, no comment |
| Owner sees the review is required | Issue #2 and `DASHBOARD.md` "Awaiting independent review" |
| ChatGPT retrieves the evidence | RV-0001 §2: records and selected source retrieved through the GitHub connector |
| ChatGPT publishes an outcome | RV-0001 (REVIEW_INCOMPLETE) relayed by the owner and committed verbatim to `reviews/` |
| Claude Code retrieves and processes the findings | This session: HO-0001 set to REVIEW_INCOMPLETE, MSG-IN-0001 indexed, records reconciled, correction handoff HO-0002 submitted |
| Corrected commit requires re-review | HO-0002 supersedes HO-0001 with a new commit; the checker and the issue mirror treat it as a new review item |

**Not yet demonstrated**: the re-review being published and processed, which completes a full round-trip; the protocol is not reported as live until then. ChatGPT did not execute the test suite or reproduce the workflow runs (RV-0001 §2), so technical approval is outstanding.

## Author-side pre-review (not independent review)
Before delivery, a separate Claude subagent (not the author) reviewed the version-1 design and checker: 3 High, 8 Medium, 9 Low findings. Disposition is in the GOV 1 handoff §4. This is author-side quality control; the independent review is ChatGPT's and has not happened.

## Limitations (honest)
- Review initiation and the commit of the review file are owner actions; GitHub cannot trigger ChatGPT.
- Whether the owner's ChatGPT plan reads a private repository through the connector is unconfirmed (DL-0002); the evidence pack is the fallback.
- `CLAUDE.md` is advisory; the checker catches structural omissions after a push.
- The checker validates form and consistency, not truth; `--verify-commits` proves a SHA exists, not that the run IDs or counts are real.
- Issue mirroring uses the Actions token: it works for pushes to this repository, not for pull requests from forks.

## Decisions requested from the owner
DL-0001 adopt protocol v2; DL-0002 ChatGPT read path; DL-0003 branch protection on `main`; DL-0005 WP 15 wording; DL-0006 authorise WP 8 start. No acceptance of GOV 1 is implied by this record.
