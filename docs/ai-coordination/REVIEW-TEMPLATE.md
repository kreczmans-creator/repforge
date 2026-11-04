# Review template

Copy to `reviews/RV-NNNN.md` (next free number, never reused). The reviewer fills everything except the `Status` and `Resolution` cells of findings, which Claude Code updates later with evidence. One review covers exactly one commit; a later commit needs a new review.

The checker enforces: the metadata lines (all required), the ten numbered headings exactly as written, the findings table columns, outcome ↔ findings consistency (CHANGES_REQUIRED needs at least one Critical/High/Medium finding; APPROVED_FOR_OWNER_ACCEPTANCE needs no open Critical/High finding), and `Commit reviewed` equal to the handoff's commit.

Review `Status` meaning: `OPEN` while any finding is not CLOSED/ACCEPTED_BY_OWNER; `CLOSED` when all findings are closed or the review is superseded by a later review of a newer commit.

```markdown
# RV-NNNN — review of HO-NNNN: <short title>

- Author: ChatGPT (relayed by the owner)
- Date: YYYY-MM-DD
- Status: OPEN
- Outcome: APPROVED_FOR_OWNER_ACCEPTANCE | CHANGES_REQUIRED | BLOCKED | REVIEW_INCOMPLETE
- Handoff: HO-NNNN
- Commit reviewed: `<40-character SHA actually inspected>`

## 1. Review ID and handoff reference
RV-NNNN reviewing HO-NNNN. Earlier reviews of the same work: none | RV-MMMM.

## 2. Exact commit reviewed
Full SHA and how the evidence was obtained (GitHub connector: compare view, files, checks; or the evidence pack pasted by the owner). List what could NOT be retrieved. If the code or tests could not be read, the outcome is REVIEW_INCOMPLETE, not an approval.

## 3. Scope reviewed
Assessment against the twelve dimensions (protocol §5): functional correctness; architectural consistency; domain model integrity; data persistence and migration safety; error handling; security and privacy; test coverage and quality; regression risk; requirements compliance; documentation and governance accuracy; technical debt; acceptance evidence. One line each: what was checked and the result, or "not assessed" with the reason.

## 4. Findings classified by severity
| ID | Severity | Status | Finding | Evidence | Resolution |
|---|---|---|---|---|---|
| RV-NNNN-F1 | High | OPEN | <defect, risk or omission> | `path:line`, run ID, record section | — |
| none | — | — | no findings | — | — |

Severity: Critical (data loss, security, blocks acceptance), High (acceptance criterion unmet or wrong behaviour), Medium (defect with a workaround, missing test, migration risk), Low (quality, standards), Info (observation).

## 5. Evidence and file references
How each finding was verified (probe, re-run, reading). Claims not verified are marked "not verified".

## 6. Required corrections
Findings that must be RESOLVED before the outcome can become APPROVED_FOR_OWNER_ACCEPTANCE (normally Critical, High and Medium).

## 7. Non-blocking recommendations
Improvements that may become D05 debt rows or later work.

## 8. Regression tests required
Named tests that must exist and pass for each required correction.

## 9. Re-review conditions
What the corrected handoff must contain. A corrected commit is always re-reviewed; say which findings need a full re-check and which need only evidence inspection.

## 10. Overall recommendation
Restate the Outcome and, for APPROVED_FOR_OWNER_ACCEPTANCE, the owner decisions still required (acceptance, deviations, debt). This is a recommendation to the owner, not an acceptance.
```
