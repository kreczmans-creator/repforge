# Example walkthrough — one full cycle

**Illustrative only.** Every record below is an example, not a real handoff, review or decision. The IDs `HO-0042`, `HO-0043`, `RV-0042` and `RV-0043` are reserved for this walkthrough by convention (not enforced by the checker) and are never used for real records. The scenario is the WP 7 closure condition (portion precision 0.01, `docs/delivery-record/WP7.md`), chosen because it is real pending work; the commits, run IDs and findings shown are invented.

## Step 1 — Claude Code delivers and hands off

Claude Code implements the closure condition on the working branch, runs the local checks, waits for the four workflows, then commits the handoff:

```markdown
# HO-0042 — WP 7 closure: portion precision 0.01

- Author: Claude Code
- Date: 2026-11-10
- Status: AWAITING_REVIEW
- Work package: WP 7 — Recipe management and meal planning (closure condition)
- Branch: `ccr-9fda2c32-wr163b`
- Commit: `0123456789abcdef0123456789abcdef01234567`
- Parent: `e45e4f7a10b66ea78764551b580076b5e70e1aec`
- Review: none
- Responds to: none
- Supersedes: none

## 1. Handoff ID
HO-0042. Supersedes: none.

## 2. Work package and scope
D06 WP 7 closure condition (owner decision 2026-11-04): portion counts stored and calculated at 0.01 everywhere; inputs accept two decimals; g/ml stay at 0.1; spec rev 1.3 examples E39–E41. Out of scope: NUT-022 (WP 15), TD-37/38/39.

## 3. Branch and commit
`ccr-9fda2c32-wr163b`, 0123456789abcdef0123456789abcdef01234567, parent e45e4f7…; range e45e4f7..0123456.

## 4. Summary of changes
Portion quantities use a shared `Portions` value type rounded to 0.01 … (assumption: saved-meal multipliers are portions and follow the same rule).

## 5. Files changed
`app/lib/domain/nutrition/portions.dart` — new; `app/lib/features/recipes/...` — inputs; `docs/nutrition-calculation-spec.md` — rev 1.3; `app/test/...` — 14 tests.

## 6. Tests executed and actual results
`flutter test` local: 723 passed, 0 failed, 0 skipped. Coverage 89.3 % hand-written (gate 80 %).

## 7. CI workflow run IDs and results
| Workflow | Run ID | Conclusion | Commit |
|---|---|---|---|
| CI | 42000000001 | success | 0123456 |
| Android build | 42000000002 | success | 0123456 |
| iOS build | 42000000003 | success | 0123456 |
| Integration tests | 42000000004 | success | 0123456 |

## 8. Independent review status
none yet. Re-review requested: yes (closure condition requires a fresh review).

## 9. Outstanding findings
none in `reviews/`. From WP 7 record: N3 → TD-38, N4 → TD-39 (unchanged by this work).

## 10. Technical debt updates
none.

## 11. Documentation updates
`docs/nutrition-calculation-spec.md` rev 1.3; `docs/delivery-record/WP7.md` closure section.

## 12. Decisions required from ChatGPT
Does the two-decimal input constraint satisfy "at least 0.01" or should storage accept finer input and round on display?

## 13. Decisions required from the project owner
Approve NUT-017 rev 1.3; final WP 7 acceptance after the review (options: accept; accept with conditions; reject). Recommendation: accept after review.

## 14. Recommended next action
Reviewer: review HO-0042. Owner: decide rev 1.3 after the review. Claude Code: wait.
```

`PROGRAMME.md` (WP 7 row: Review `AWAITING_REVIEW`, Latest handoff `HO-0042`), `CURRENT-STATE.md` and the generated `DASHBOARD.md` are updated in the same handoff commit. On push, the workflow validates the records and opens issue `[AI review] HO-0042 — WP 7 closure: portion precision 0.01` with the commit, compare, raw-diff and checks links, the handoff and delivery-record links, and the sentence the owner can paste into ChatGPT. The issue is the owner's signal that a review is outstanding; `DASHBOARD.md` lists it under "Awaiting independent review".

## Step 2 — The owner gives ChatGPT access

The owner opens the existing ChatGPT conversation and pastes the sentence from the issue: "Review handoff HO-0042 at commit 0123456789abcdef0123456789abcdef01234567 in kreczmans-creator/repforge (branch `ccr-9fda2c32-wr163b`) using docs/ai-coordination/REVIEW-TEMPLATE.md; return the outcome and the complete review file." With the GitHub connector ChatGPT retrieves the handoff, the compare view (`compare/e45e4f7...0123456`), the changed source and test files, the checks page for the commit, D04/D06 acceptance criteria, ADRs, D05 and the delivery record, all linked from the issue. Without the connector the owner runs `python3 tools/coordination/check_coordination.py --evidence HO-0042` and pastes the single bundle. ChatGPT assesses the twelve dimensions and challenges the assumption in §4.

## Step 3 — ChatGPT writes the review; the owner commits it

ChatGPT produces the complete file. The owner saves it as `docs/ai-coordination/reviews/RV-0042.md` on the working branch (GitHub web editor: "Add file", one commit). No other edit is required; the next Claude Code session indexes it in `INBOX.md`.

```markdown
# RV-0042 — review of HO-0042: WP 7 closure, portion precision

- Author: ChatGPT (relayed by the owner)
- Date: 2026-11-11
- Status: OPEN
- Outcome: CHANGES_REQUIRED
- Handoff: HO-0042
- Commit reviewed: `0123456789abcdef0123456789abcdef01234567`

## 1. Review ID and handoff reference
RV-0042 reviewing HO-0042. Earlier reviews: none.

## 2. Exact commit reviewed
0123456789abcdef0123456789abcdef01234567, read through the GitHub connector (diff e45e4f7..0123456 and the test files). CI run pages opened by the owner and summarised to me; I did not open them myself.

## 3. Scope reviewed
Functional correctness: `portions.dart` and the inputs, verified against E39–E41. Architecture: value type in `lib/domain`, no layering breach. Domain model: portions as a real to 0.01, consistent. Persistence/migration: no schema change; existing rows unaffected (checked the migration tests). Error handling: typed error for a quantity rounding to 0, present. Security/privacy: no change. Tests: 14 new, named for behaviour; one gap (F1). Regression: prep batches not covered (F1). Requirements: owner decision 2026-11-04 met except F1. Documentation: spec rev 1.3 consistent; delivery record updated. Debt: none new. Acceptance evidence: four workflows green on the commit, confirmed from the checks page. Not reviewed: saved-meal UI beyond the multiplier path.

## 4. Findings classified by severity
| ID | Severity | Status | Finding | Evidence | Resolution |
|---|---|---|---|---|---|
| RV-0042-F1 | High | OPEN | Prep batch `portionsLeft` still rounds to 0.1 before subtraction, so drawing 1.25 portions from a batch of 2 leaves 0.8 instead of 0.75. | `app/lib/features/planning/prep_batch.dart:61`; no test covers a two-decimal draw | — |
| RV-0042-F2 | Low | OPEN | The §4 assumption on saved-meal multipliers is undocumented in the spec. | `docs/nutrition-calculation-spec.md` §2.1 | — |

## 5. Evidence and file references
F1 verified by reading the subtraction path and the absence of a test; F2 by reading the spec.

## 6. Required corrections
RV-0042-F1.

## 7. Non-blocking recommendations
RV-0042-F2: add one sentence to §2.1.

## 8. Regression tests required
`prep_batch_test`: "drawing 1.25 portions from 2 leaves 0.75"; a spec example E42 if the owner agrees.

## 9. Re-review conditions
Re-review needed after F1 is RESOLVED with the test and a green CI run on the fixing commit.

## 10. Overall recommendation
Outcome CHANGES_REQUIRED: F1 must be resolved and re-reviewed before APPROVED_FOR_OWNER_ACCEPTANCE. The answer to the handoff's §12 question: two-decimal input satisfies the owner's wording; recommend no further change.
```

## Step 4 — Claude Code reads the inbox, fixes, reports

Next session: `INBOX.md` and `CURRENT-STATE.md` are in context, and `reviews/RV-0042.md` is on disk. Claude Code (`/resolve-findings RV-0042`) adds the index entry `MSG-IN-0005` (`Author: ChatGPT (relayed by the owner; indexed by Claude Code)`), sets HO-0042 to `Review: RV-0042` and `Status: CHANGES_REQUIRED` (the checker would otherwise fail: a handoff's status must match its latest review's outcome), sets F1 to `IN_PROGRESS`, fixes it, adds the test, commits `89abcdef…`, waits for CI, and then edits only the two cells of F1:

```markdown
| RV-0042-F1 | High | RESOLVED | … | … | fixed in 89abcdef…; `prep_batch_test` "drawing 1.25 portions from 2 leaves 0.75"; CI 42000000011 success |
```

and submits the correction handoff (`/handoff --responds-to RV-0042`):

```markdown
# HO-0043 — WP 7 closure: portion precision 0.01 (corrections for RV-0042)

- Author: Claude Code
- Date: 2026-11-11
- Status: AWAITING_REVIEW
- Work package: WP 7 — Recipe management and meal planning (closure condition)
- Branch: `ccr-9fda2c32-wr163b`
- Commit: `89abcdef89abcdef89abcdef89abcdef89abcdef`
- Parent: `0123456789abcdef0123456789abcdef01234567`
- Review: none
- Responds to: RV-0042
- Supersedes: HO-0042
…
## 9. Outstanding findings
RV-0042-F1 RESOLVED at 89abcdef, `prep_batch_test` "drawing 1.25 portions from 2 leaves 0.75", CI 42000000011. RV-0042-F2 RESOLVED (spec §2.1 sentence). Both await re-review.
```

HO-0042's `Status:` line becomes `SUPERSEDED`. The workflow closes issue `[AI review] HO-0042` as superseded and opens `[AI review] HO-0043`. The checker enforces that HO-0043 is `AWAITING_REVIEW`: the review of 0123456 cannot be claimed for 89abcdef, so the corrected commit requires re-review.

## Step 5 — Re-review, owner decision, records

The owner starts the re-review from the HO-0043 issue. ChatGPT writes `RV-0043` (`Outcome: APPROVED_FOR_OWNER_ACCEPTANCE`, `Commit reviewed: 89abcdef…`, closing RV-0042-F1/F2 in its findings table and marking RV-0042 `Status: CLOSED`); the owner commits it. HO-0043 becomes `APPROVED_FOR_OWNER_ACCEPTANCE`; the dashboard moves it to "Awaiting owner decision". The owner then decides WP 7 acceptance and rev 1.3 approval. Claude Code records both in `DECISION-LOG.md` in the owner's words (`DL-00nn`, `Decided by: Owner`), updates `docs/delivery-record/WP7.md`, D06, `PROGRAMME.md` (WP 7 Acceptance `ACCEPTED`), `CURRENT-STATE.md`, sets HO-0043 to `ACCEPTED_BY_OWNER`, and starts the next eligible package (WP 8) under protocol §7.

## What the owner did in this cycle
1. Pasted the sentence from the issue into ChatGPT (one message).
2. Committed the review file ChatGPT returned (one commit).
3. Did the same for the re-review (one message, one commit).
4. Made the decision, which was always the owner's.

Nothing else was copied by hand. The diff, tests, CI results, requirements and records were all retrieved by ChatGPT from GitHub.
