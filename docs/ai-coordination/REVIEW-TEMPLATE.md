# Review template

Copy to `reviews/RV-NNNN.md` (next free number). The reviewer fills everything except the `Status` and `Resolution` cells of findings, which Claude Code updates later. The checker requires the metadata lines, the ten numbered headings, and the findings table columns exactly as below.

```markdown
# RV-NNNN — review of HO-NNNN: <short title>

- Author: ChatGPT (relayed by the owner)
- Date: YYYY-MM-DD
- Status: OPEN
- Handoff: HO-NNNN
- Commit reviewed: `<40-character SHA actually inspected>`

## 1. Review ID and handoff reference
RV-NNNN reviewing HO-NNNN. Earlier reviews of the same work: none | RV-MMMM.

## 2. Exact commit reviewed
Full SHA and how it was obtained (connector, pasted diff, raw links). If the reviewer could not see the code, say so here; a review of the handoff text alone is labelled "document review only".

## 3. Scope reviewed
What was inspected (files, tests, CI runs, records) and what was not.

## 4. Findings classified by severity
| ID | Severity | Status | Finding | Evidence | Resolution |
|---|---|---|---|---|---|
| RV-NNNN-F1 | High | OPEN | <defect, risk or omission> | `path:line`, run ID, record section | — |
| none | — | — | no findings | — | — |

Severity: Critical (data loss, security, blocks acceptance), High (acceptance criterion unmet or wrong behaviour), Medium (defect with a workaround or a missing test), Low (quality, standards), Info (observation).

## 5. Evidence and file references
Where each finding was verified and how (probe test, re-run, reading). Claims not verified are marked "not verified".

## 6. Required corrections
Findings that must be RESOLVED before the reviewer will recommend acceptance (normally Critical and High).

## 7. Non-blocking recommendations
Improvements that may become D05 debt rows or later work.

## 8. Regression tests required
Named tests that must exist and pass for each required correction.

## 9. Re-review conditions
What Claude Code must deliver for a re-review, and whether a re-review is needed at all.

## 10. Overall recommendation
One of: "Recommend acceptance", "Recommend acceptance subject to the owner's decisions listed", "Corrections required before acceptance", "Reject". This is a recommendation to the owner, not an acceptance.
```
