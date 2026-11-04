---
name: handoff
description: Create a structured implementation handoff for independent ChatGPT review under docs/ai-coordination (HO-NNNN), plus the matching OUTBOX message and CURRENT-STATE update. Use after a meaningful unit of work is committed and CI run IDs are known.
argument-hint: "<work package or title>"
---

# Create a coordination handoff

Follow `docs/ai-coordination/AI-COORDINATION-PROTOCOL.md` §5 and §9. Do these steps in order; do not skip the checks.

1. **Confirm the implementation is committed.** `git status` must be clean for the files the handoff describes. Record `git rev-parse HEAD` as the implementation commit. If supporting docs are still uncommitted, commit them first; the handoff commit comes after.
2. **Collect evidence, do not assert it.** Test counts come from the actual command output. CI run IDs come from the Actions API for that SHA (`mcp__github__actions_list` / `actions_get`, or the Actions page). A workflow that has not finished is `pending`. A workflow that was not triggered is `not triggered (path filter)`.
3. **Pick the next ID.** `ls docs/ai-coordination/handoffs/` — the next free `HO-NNNN`. Never reuse a number.
4. **Write `docs/ai-coordination/handoffs/HO-NNNN.md`** from `docs/ai-coordination/HANDOFF-TEMPLATE.md`: all metadata lines, all fourteen numbered sections, `none` where empty. Section 9 lists every non-closed finding from `docs/ai-coordination/reviews/` that touches this work. Section 13 never contains an owner answer, only the question, the options and a recommendation.
5. **Append `MSG-OUT-NNNN`** to `docs/ai-coordination/OUTBOX.md` (next free number), `Refs: HO-NNNN`, subject "Ready for independent review: …".
6. **Update `docs/ai-coordination/CURRENT-STATE.md`**: commit (after step 8 it will be the handoff commit; say so), implementation status, acceptance status unchanged unless the owner decided, next actions.
7. **Update** D05 rows, the delivery record and `DECISION-LOG.md` if anything changed; mirror no decision that the owner did not state.
8. **Validate**: `python3 tools/coordination/check_coordination.py`. Fix every error. Warnings about the new handoff having no review are expected.
9. **Commit** with `docs(coordination): handoff HO-NNNN — <title>` and push to the working branch. CURRENT-STATE keeps the implementation SHA as its `Commit:` line; the handoff commit sits on top of it, and the next session reconciles (protocol §9 step 1).
10. **Report** to the user: the handoff ID, the implementation SHA, the handoff commit SHA, the open decisions, and that ChatGPT's review is awaited through the owner.
