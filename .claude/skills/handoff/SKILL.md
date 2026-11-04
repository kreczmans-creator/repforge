---
name: handoff
description: Submit a committed unit of work for independent review under docs/ai-coordination (handoffs/HO-NNNN.md), update PROGRAMME, CURRENT-STATE and the dashboard, validate, commit and push. Use after implementation is committed and CI run IDs are known; also for correction handoffs that respond to a review.
argument-hint: "<work package or title> [--responds-to RV-NNNN]"
---

# Submit a handoff (protocol Stages B–C)

Two commits: the implementation commit (already made) and the handoff commit (this skill). The handoff commit is the one the checker and CI validate; the implementation commit alone is not expected to be checker-clean.

1. **Confirm** `git status` is clean for everything the handoff describes. Record `git rev-parse HEAD` (implementation commit) and `git rev-parse HEAD^` (parent). If this handoff covers several commits, Parent is the parent of the first.
2. **Collect evidence; never assert it.** Test counts from actual output. CI run IDs for that exact SHA from the Actions API (`mcp__github__actions_list` with the branch filter, then match `head_sha`) or the Actions page. Unfinished → `pending`; not run → `not triggered (path filter)`.
3. **Next ID**: `ls docs/ai-coordination/handoffs/`; never reuse.
4. **Write `handoffs/HO-NNNN.md`** from `HANDOFF-TEMPLATE.md`: every metadata line, all fourteen sections, `none` where empty. `Status: AWAITING_REVIEW`. For a correction: `Responds to: RV-NNNN`, `Supersedes: HO-<previous>`, and set the previous handoff's `Status:` line to `SUPERSEDED` (the only line of it that changes). §9 lists every non-closed finding touching this work. §13 lists owner-reserved items with their `DL-` queue rows; never an answer.
5. **Queue owner decisions**: append `DL-NNNN` rows with `Decided by: Pending owner decision` for each §13 item that is not already queued.
6. **Update** `PROGRAMME.md` (the WP row: Implementation `DELIVERED` or `IN_PROGRESS`, Review `AWAITING_REVIEW`, Latest handoff `HO-NNNN`), `CURRENT-STATE.md` (commit = implementation SHA; latest handoff; next actions), D05 and the delivery record if they changed.
7. **Regenerate** the dashboard: `python3 tools/coordination/check_coordination.py --write-dashboard`.
8. **Validate**: `python3 tools/coordination/check_coordination.py --verify-commits`. Fix every error. A warning that HO-NNNN awaits review is expected.
9. **Commit** `docs(coordination): handoff HO-NNNN — <title>` and push to the working branch. The workflow validates and opens or updates the review issue `[AI review] HO-NNNN`.
10. **Report** to the user: handoff ID, implementation SHA, handoff commit SHA, queued owner decisions, and that the owner starts the ChatGPT review from the issue.
