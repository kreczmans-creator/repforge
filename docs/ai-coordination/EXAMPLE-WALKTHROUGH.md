# Example walkthrough — one full cycle

**Illustrative only.** Every record below is an example, not a real handoff, review or decision. The IDs `HO-0042` and `RV-0042` are reserved for this walkthrough and are never used for real records. The scenario is the WP 7 closure condition (portion precision 0.01, `docs/delivery-record/WP7.md`), chosen because it is real pending work; the commits, run IDs and findings shown are invented.

## Step 1 — Claude Code delivers and hands off

Claude Code implements the closure condition on the working branch, runs the local checks, waits for the four workflows, then commits the handoff:

```markdown
# HO-0042 — WP 7 closure: portion precision 0.01

- Author: Claude Code
- Date: 2026-11-10
- Status: OPEN
- Work package: WP 7 — Recipe management and meal planning (closure condition)
- Branch: `ccr-9fda2c32-wr163b`
- Commit: `0123456789abcdef0123456789abcdef01234567`
- Review: none

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

`OUTBOX.md` gets:

```markdown
### MSG-OUT-0007 — Ready for independent review: WP 7 closure (HO-0042)
- Author: Claude Code
- Date: 2026-11-10
- Refs: HO-0042
- Status: OPEN
Closure condition implemented at 0123456; four workflows green; handoff HO-0042 lists the question for the reviewer and the decisions for the owner.
```

`CURRENT-STATE.md` is updated (commit, "WP 7 closure implemented, not accepted", next actions).

## Step 2 — The owner gives ChatGPT access

The owner opens ChatGPT and either (a) uses the GitHub connector and says "Review handoff HO-0042 in `docs/ai-coordination/handoffs/` on branch `ccr-9fda2c32-wr163b` of kreczmans-creator/repforge, using `docs/ai-coordination/REVIEW-TEMPLATE.md`", or (b) pastes `HO-0042.md`, the diff (`git diff e45e4f7..0123456`) and the test output. ChatGPT verifies what it can: it reads the diff, checks the examples E39–E41 against the spec, checks the run IDs the owner can open, and challenges the assumption in §4.

## Step 3 — ChatGPT writes the review; the owner commits it

ChatGPT produces the complete file. The owner saves it as `docs/ai-coordination/reviews/RV-0042.md` on the working branch (GitHub web editor: "Add file", one commit). No other edit is required; the next Claude Code session indexes it in `INBOX.md`.

```markdown
# RV-0042 — review of HO-0042: WP 7 closure, portion precision

- Author: ChatGPT (relayed by the owner)
- Date: 2026-11-11
- Status: OPEN
- Handoff: HO-0042
- Commit reviewed: `0123456789abcdef0123456789abcdef01234567`

## 1. Review ID and handoff reference
RV-0042 reviewing HO-0042. Earlier reviews: none.

## 2. Exact commit reviewed
0123456789abcdef0123456789abcdef01234567, read through the GitHub connector (diff e45e4f7..0123456 and the test files). CI run pages opened by the owner and summarised to me; I did not open them myself.

## 3. Scope reviewed
`portions.dart`, the recipe and plan inputs, the 14 new tests, spec rev 1.3 §2.1, E39–E41. Not reviewed: saved-meal UI beyond the multiplier path.

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
Corrections required before acceptance. The answer to the handoff's §12 question: two-decimal input satisfies the owner's wording; recommend no further change.
```

## Step 4 — Claude Code reads the inbox, fixes, reports

Next session: `INBOX.md` and `CURRENT-STATE.md` are in context. Claude Code adds the index entry `MSG-IN-0005` ("indexed by Claude Code"), sets F1 to `IN_PROGRESS`, fixes it, adds the test, pushes, waits for CI, and then edits only the two cells of F1:

```markdown
| RV-0042-F1 | High | RESOLVED | … | … | fixed in 89abcdef…; `prep_batch_test` "drawing 1.25 portions from 2 leaves 0.75"; CI 42000000011 success |
```

and appends:

```markdown
### MSG-OUT-0008 — RV-0042 findings resolved; re-review requested
- Author: Claude Code
- Date: 2026-11-11
- Refs: HO-0042, RV-0042
- Status: OPEN
F1 RESOLVED at 89abcdef (test named in the review file; CI 42000000011). F2 RESOLVED: spec §2.1 sentence added. Re-review requested per RV-0042 §9.
```

## Step 5 — Re-review, owner decision, records

ChatGPT re-reviews (the owner relays again), sets F1 and F2 to `CLOSED` in a one-line update the owner commits, or writes `RV-0043` if new findings appear. The owner then decides WP 7 acceptance and rev 1.3 approval. Claude Code records both in `DECISION-LOG.md` in the owner's words (`DL-00nn`, `Decided by: Owner`), updates `docs/delivery-record/WP7.md`, D06, `CURRENT-STATE.md`, and sets HO-0042 to `ACCEPTED_BY_OWNER`.

## What the owner did in this cycle
1. Pointed ChatGPT at the handoff (one message).
2. Committed the review file (one commit).
3. Relayed the re-review (one message, one small commit).
4. Made the decision (which was always the owner's).

Nothing else was copied by hand.
