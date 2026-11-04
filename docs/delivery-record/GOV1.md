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
`tools/coordination/demo_cycle.py` builds a throwaway fixture repository and runs the checker through the cycle: handoff awaiting review → review on file with `CHANGES_REQUIRED` → checker refuses the stale handoff status → corrected commit as a new handoff → checker refuses any claim that the old review approves the new commit → re-review approves. Its output is recorded in the handoff. The live part demonstrated on this repository: the workflow validated the records and created the review issue for the GOV 1 handoff. **Not demonstrated**: a ChatGPT review retrieved and published through the system (steps 4–5 of the owner's demonstration list) — that requires the owner's ChatGPT conversation and has not happened; the protocol is therefore not reported as live.

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
