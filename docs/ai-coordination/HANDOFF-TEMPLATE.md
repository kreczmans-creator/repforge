# Handoff template

Copy to `handoffs/HO-NNNN.md` (next free number, never reused). Fill every section; write `none` where a section has nothing; never delete a section. A handoff describes exactly one implementation commit. A later change to that code is a new commit, a new handoff, and this one becomes `SUPERSEDED`.

The checker enforces: the metadata lines below (all required), the fourteen numbered headings exactly as written, a 40-character `Commit` and `Parent` (bare SHA, nothing after it), statuses, and the handoff ↔ review consistency rules in the protocol §4–5. It validates form, not truth.

Mutable lines after creation: `Status`, `Review` (protocol §10). Everything else is fixed once committed.

```markdown
# HO-NNNN — <short title>

- Author: Claude Code
- Date: YYYY-MM-DD
- Status: AWAITING_REVIEW
- Work package: WP <n> — <name>        (or GOV <n> for governance work)
- Branch: `<branch>`
- Commit: `<40-character SHA of the implementation commit>`
- Parent: `<40-character SHA of its parent>`
- Review: none                          (RV-NNNN[, RV-NNNN] once reviews exist)
- Responds to: none                     (RV-NNNN whose findings this handoff corrects)
- Supersedes: none                      (HO-NNNN replaced by this one)

## 1. Handoff ID
HO-NNNN.

## 2. Work package and scope
D06 reference; the stage, correction set or closure condition delivered; what is out of scope. Inherited open conditions on dependencies (for example a conditionally accepted package this work builds on).

## 3. Branch and commit
Branch, commit, parent, and the range `<parent>..<commit>` if more than one commit. Links are generated in the review issue; none needed here.

## 4. Summary of changes
What changed and why. Decisions made under assumption are each marked "assumption".

## 5. Files changed
Path — nature of change. Generated files noted as generated.

## 6. Tests executed and actual results
Commands, counts (passed / failed / skipped), coverage if measured, and anything NOT passing or NOT run. Local results labelled local.

## 7. CI workflow run IDs and results
| Workflow | Run ID | Conclusion | Commit |
One row per workflow on the handoff commit. "pending" if unfinished; "not triggered (path filter)" if not run; never "success" without a run ID.

## 8. Independent review status
none yet | RV-NNNN (outcome). State whether re-review is requested and why.

## 9. Outstanding findings
Every finding from earlier reviews that touches this work and is not CLOSED: ID, status, what this handoff does about it (fixing commit and test, or why it is deferred).

## 10. Technical debt updates
D05 rows added, changed or resolved, with IDs. "none" if none.

## 11. Documentation updates
Delivery record, ADRs, D04–D08, README, CHANGELOG touched. "none" if none.

## 12. Decisions required from ChatGPT
Questions for the reviewer. The reviewer answers and recommends; it does not decide. "none" if none.

## 13. Decisions required from the project owner
Each owner-reserved item (protocol §8) with options and a recommendation, and its DL-NNNN queue row. Never pre-filled with an answer.

## 14. Recommended next action
One line each for the reviewer, the owner and Claude Code.
```
