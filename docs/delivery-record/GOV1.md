# Delivery record — GOV 1: AI coordination infrastructure

Date: 2026-11-04
Branch: `claude/ai-coordination-infrastructure-pcf8bb` (based on `ccr-9fda2c32-wr163b` at e45e4f7; `main` untouched)
Status: **delivered for independent review and owner decision; not accepted.** Governance work, not a D06 work package; no application code changed.

## Scope
Establish a GitHub-based coordination system so ChatGPT (independent review) and Claude Code (implementation) exchange handoffs, reviews and decisions through repository files, with the owner as final authority. Explicitly out of scope: application functionality, WP 6/7 implementation, existing owner decisions, roadmap sequencing, merge to `main`, any external service.

## Assessment of existing arrangements (before changes)
- Governance already present and reused: ADRs, delivery records with owner-decision tables and CI run IDs, D05 debt and risk register with owner dispositions, D06 statuses, engineering standards, D05 §C verification items, "fresh reviewer" sections in delivery records.
- Gaps: no `CLAUDE.md` or `.claude/` configuration; no machine-checkable handoff or review format; review findings embedded in delivery records lose status tracking across commits; no message channel; `main` holds only WP 0–1 while all WP 2–7 work is on `ccr-9fda2c32-wr163b`.

## Design (one page)
- **Record layer**: `docs/ai-coordination/` with the protocol, a state snapshot, an inbox and outbox (append-only), one file per handoff (`handoffs/HO-NNNN.md`, 14 sections) and per review (`reviews/RV-NNNN.md`, 10 sections, findings table with per-finding status), a decision log (`DL-NNNN`, decider named), an archive for closed messages, a worked example and the MCP assessment.
- **Discovery**: root `CLAUDE.md` imports `CURRENT-STATE.md` and `INBOX.md` with `@path` so both are in context in every Claude Code session type (CLI, cloud, GitHub Action) without hooks or approvals. A repository skill `/handoff` walks through the post-implementation steps. No hooks: SessionStart hooks do not run in multi-repository or project-thread cloud sessions and need folder trust, so they would be a false guarantee.
- **Automation**: `.github/workflows/coordination.yml` runs a stdlib-only Python checker and its unit tests on changes to the coordination files. Errors fail the run (structure, statuses, cross-references, SHA format, links, imports); warnings (open findings, handoffs without review, open messages) go to the job summary, which is the coordination index. No secrets, no issue creation, no merge, no acceptance, no claim about ChatGPT.
- **Boundaries**: ChatGPT never approves; Claude Code never decides; owner decisions exist only in the owner's words in `DECISION-LOG.md` or a delivery record.
- **Traceability**: handoff → commit SHA → review → findings (`RV-NNNN-Fn`) → resolution commit and test → owner decision (`DL-NNNN`) → delivery record, D05, D06.

## Files created or modified
| Path | Change |
|---|---|
| `CLAUDE.md` | New: session instructions and imports |
| `.claude/skills/handoff/SKILL.md` | New: `/handoff` procedure |
| `docs/ai-coordination/AI-COORDINATION-PROTOCOL.md` | New: roles, files, statuses, lifecycle, rules |
| `docs/ai-coordination/CURRENT-STATE.md`, `INBOX.md`, `OUTBOX.md`, `DECISION-LOG.md` | New: live records |
| `docs/ai-coordination/HANDOFF-TEMPLATE.md`, `REVIEW-TEMPLATE.md` | New: templates |
| `docs/ai-coordination/EXAMPLE-WALKTHROUGH.md` | New: worked example (illustrative, IDs 0042 reserved) |
| `docs/ai-coordination/MCP-INTEGRATION-ASSESSMENT.md` | New: future direct-integration option |
| `docs/ai-coordination/handoffs/`, `reviews/`, `archive/README.md` | New directories |
| `tools/coordination/check_coordination.py`, `test_check_coordination.py`, `README.md` | New: checker, 24 unit tests |
| `.github/workflows/coordination.yml` | New workflow (path-filtered; Flutter workflows untouched) |
| `docs/wp0/D05-technical-debt-and-risk-register.md` | R-13 added (coordination is manual relay; records can drift) |
| `docs/README.md` | Index row added; delivery-record list corrected |
| `docs/delivery-record/GOV1.md` | This record |

## Validation evidence
Recorded in the handoff `docs/ai-coordination/handoffs/HO-0001.md` §6–7 with commands, outputs and run IDs. Application tests and the four Flutter workflows were not run: no file under `app/` changed, and those workflows are path-filtered to `app/**`.

## Independent review
A separate reviewer agent (not the author) assessed the design and the checker before delivery; its findings and their disposition are in HO-0001 §8–9. ChatGPT's independent review is requested through HO-0001 and has not happened.

## Limitations (honest)
- The protocol is not live or bidirectional: ChatGPT reads through its connector or the owner's paste and writes only through the owner's commit.
- `CLAUDE.md` is advisory; the checker catches structural omissions only after a push.
- The checker validates form, not truth; it cannot verify a run ID or a test count.
- Plan facts for ChatGPT MCP support could not be confirmed from official pages inside the build container.

## Decisions requested from the owner
DL-0001 adopt the protocol; DL-0002 choose the ChatGPT read path; DL-0003 confirm branch protection on `main`. No acceptance of GOV 1 is implied by this record.
