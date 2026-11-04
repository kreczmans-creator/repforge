---
name: resolve-findings
description: Process a CHANGES_REQUIRED (or BLOCKED / REVIEW_INCOMPLETE) independent review under docs/ai-coordination/reviews: investigate every finding, fix with regression tests, record evidence in the review's Status/Resolution cells, and submit a correction handoff. Use at session start when a review with open findings exists.
argument-hint: "RV-NNNN"
---

# Resolve review findings (protocol Stage E)

1. **Read the whole review** `reviews/RV-NNNN.md` and its handoff. Confirm `Commit reviewed` equals the handoff's commit; if not, the review does not apply to that handoff: report it and stop.
2. **Index it** if `INBOX.md` has no entry: append `MSG-IN-NNNN` with `Author: ChatGPT (relayed by the owner; indexed by Claude Code)`, `Refs: RV-NNNN, HO-NNNN`. If the handoff's `Review:` or `Status:` lines do not yet reflect the review, set them (`Review: RV-NNNN`, `Status:` = the review's Outcome).
3. **For each finding** (Critical first): set `Status` to `IN_PROGRESS`; reproduce or probe the issue; fix the cause, not the symptom; add a regression test named for the behaviour; run `dart format .`, `flutter analyze --fatal-infos`, `flutter test` from `app/`. If a finding is wrong or out of scope, do not close it: leave `OPEN`, write the reasoning in `Resolution`, and raise it in the correction handoff §12 for the reviewer or §13 for the owner.
4. **Record evidence**: set `Status: RESOLVED` and `Resolution: fixed in <sha>; <test name>; <CI run ID or pending>`. Never RESOLVED without a commit and a test. Only the reviewer (re-review) or an owner decision makes a finding `CLOSED` or `ACCEPTED_BY_OWNER`.
5. **Update the delivery record** and D05 (new debt rows for findings the owner may accept as debt).
6. **Commit** the corrections (`fix(...)` or `test(...)` per Conventional Commits), wait for CI run IDs.
7. **Submit the correction handoff** with `/handoff --responds-to RV-NNNN`: `Supersedes` the reviewed handoff, which becomes `SUPERSEDED`. The corrected commit is re-reviewed; approval of the earlier commit never carries forward.
8. **Report**: findings resolved with evidence, findings left open and why, the new handoff ID.
