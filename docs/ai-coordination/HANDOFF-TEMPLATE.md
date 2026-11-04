# Handoff template

Copy to `handoffs/HO-NNNN.md` (next free number). Fill every section; write `none` where a section has nothing, never delete a section. The checker (`tools/coordination/check_coordination.py`) requires the metadata lines and the fourteen numbered headings exactly as below.

```markdown
# HO-NNNN — <short title>

- Author: Claude Code
- Date: YYYY-MM-DD
- Status: OPEN
- Work package: WP <n> — <name> (or GOV for governance work)
- Branch: `<branch>`
- Commit: `<40-character SHA of the implementation commit this handoff describes>`
- Review: none

## 1. Handoff ID
HO-NNNN. Supersedes: none | HO-MMMM (why).

## 2. Work package and scope
D06 reference, the stage or closure condition delivered, what is explicitly out of scope.

## 3. Branch and commit
Branch, full SHA, parent SHA, and the commit range if more than one commit (`<from>..<to>`).

## 4. Summary of changes
What changed and why, in plain language. Decisions made under assumption, each marked "assumption".

## 5. Files changed
Table or list: path — nature of change. Generated files noted as generated.

## 6. Tests executed and actual results
Commands run, counts (passed / failed / skipped), coverage figure if measured, and anything that did NOT pass or was NOT run. Local results are labelled local.

## 7. CI workflow run IDs and results
| Workflow | Run ID | Conclusion | Commit |
One row per workflow on the handoff commit. "pending" if not finished; never "success" without the run ID.

## 8. Independent review status
none yet | RV-NNNN (status). Re-review requested: yes / no.

## 9. Outstanding findings
Every finding from earlier reviews that touches this work and is not CLOSED: ID, status, what this handoff does about it.

## 10. Technical debt updates
D05 rows added, changed or resolved, with the row IDs. "none" if none.

## 11. Documentation updates
Delivery record, ADRs, D04–D08, README, CHANGELOG touched. "none" if none.

## 12. Decisions required from ChatGPT
Questions the reviewer is asked to answer, or "none".

## 13. Decisions required from the project owner
Each decision with the options and a recommendation, or "none". Never pre-filled with an answer.

## 14. Recommended next action
One line for the reviewer, one line for the owner, one line for Claude Code.
```
