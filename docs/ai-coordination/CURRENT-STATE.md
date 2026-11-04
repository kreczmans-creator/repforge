# Current state

Author: Claude Code. Updated: 2026-11-04. Imported into every Claude Code session through `CLAUDE.md`. Concise and authoritative for status; delivery records, D05, D06 and `PROGRAMME.md` hold the detail. Implementation delivered, technical approval and formal owner acceptance are different states and are never conflated here.

## Branch and commit
- Branch: `claude/ai-coordination-infrastructure-pcf8bb` (based on `ccr-9fda2c32-wr163b`, the active development branch; `main` holds WP 0–1 only)
- Commit: `04d44a748c189aee0fea73e68ec29101d22fc271`
- The commit above is the implementation commit this state describes. The state is stale when `HEAD` is not a descendant of it, or when `app/` has changed since it (`git diff --stat <commit> HEAD -- app`). A newer commit that only adds coordination records does not make it stale.

## Current implementation package
- GOV 1 — AI coordination infrastructure (governance; this system). Delivery record `docs/delivery-record/GOV1.md`.
- Engineering: none in progress. Next owed engineering work is the WP 7 closure condition (portion precision 0.01): step 1 of 4 done (spec rev 1.3 at e45e4f7); implementation, regression tests, fresh review and four green workflows outstanding.

## Latest handoff
- HO-0001 — GOV 1 (this system) at 04d44a7, status AWAITING_REVIEW. The workflow mirrors it into the issue `[AI review] HO-0001`; the owner starts the ChatGPT review from there.

## Latest review status
- No review on file under `reviews/`. The protocol has not yet carried a ChatGPT review; it is not reported as live or bidirectional until it has.

## Outstanding corrections
- None owed under `reviews/`. Pre-protocol items: WP 7 final review N3 → TD-38, N4 → TD-39; WP 6 F4/F6/F7 → TD-34/35/36 (owner-accepted debt).

## Outstanding owner decisions
- DL-0001 adopt protocol v2; DL-0002 ChatGPT read path; DL-0003 branch protection on `main`; DL-0005 WP 15 wording; DL-0006 authorise WP 8 start (`DECISION-LOG.md`).
- WP 6 final acceptance after device verification; WP 7 final acceptance after the precision closure; NUT-017 rev 1.3 approval (delivery records).

## Outstanding verification requirements
- D05 V-01 airplane-mode verification (owner, physical Android). Blocks WP 6 acceptance and R0.
- WP 6 device checklist steps 1–15 (owner); iOS signed build or recorded "not testable"; TD-34 step 5; TD-36 variant at step 12.
- WP 7: four workflows green on the final closure commit; fresh independent review.

## Next eligible package
- WP 8 — Exercise library and training architecture (depends on WP 4, accepted). Start authorised by protocol §7 subject to DL-0006; corrections and the WP 7 closure condition come first.

## Programme progress
- Accepted or closed: WP 0–5. Conditionally accepted: WP 6, WP 7. Delivered awaiting review: GOV 1 (HO-0001). Not started: WP 8–13, WP 15. Continuous: WP 14. Merge to `main`: not authorised for anything after WP 1. See `DASHBOARD.md`.

## Next recommended actions
1. Owner: decide DL-0001, DL-0002, DL-0003, DL-0005, DL-0006; start the ChatGPT review of the GOV 1 handoff using its review issue; perform the WP 6 device checklist and V-01 when a device session is possible.
2. ChatGPT: review the GOV 1 handoff against the twelve dimensions; return the outcome and the complete review file for `reviews/`.
3. Claude Code: on the next session, process any review on file; then implement the WP 7 portion-precision closure condition as the next handoff; then WP 8 if DL-0006 permits.
