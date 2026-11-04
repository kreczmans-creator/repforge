# Current state

Author: Claude Code. Updated: 2026-11-04. This file is loaded into every Claude Code session through `CLAUDE.md`. It summarises; the delivery records, D05 and D06 are authoritative. **Implementation complete** and **accepted by the owner** are different states and are never conflated here.

## Branch and commit
- Branch: `claude/ai-coordination-infrastructure-pcf8bb` (based on `ccr-9fda2c32-wr163b`, the active development branch; `main` holds WP 0–1 only)
- Commit: `e45e4f7a10b66ea78764551b580076b5e70e1aec`
- If `git log -1` differs from the commit above, this file is stale: update it before relying on it.

## Work package
- Active engineering work: WP 7 closure condition (portion precision 0.01, spec rev 1.3) — not started on this branch.
- Governance work on this branch: GOV 1 — AI coordination infrastructure (this system). Delivery record: `docs/delivery-record/GOV1.md`.
- Next roadmap package after WP 6/7 closure: WP 8 (exercise library), per D06. WP 15 (nutrition entry units) added by owner allocation 2026-11-04.

## Implementation status
| Item | Implementation | Evidence |
|---|---|---|
| WP 6 barcode scanning | Complete at 501dc6c; four workflows green | `docs/delivery-record/WP6.md` |
| WP 7 recipes and meal planning | Complete at 110b8bb; four workflows green. Closure condition (portion precision 0.01) **not yet implemented** | `docs/delivery-record/WP7.md` |
| GOV 1 AI coordination | Files, checker and workflow written; first handoff HO-0001 pending the implementation commit | `docs/delivery-record/GOV1.md` |

## Acceptance status
| Item | Acceptance |
|---|---|
| WP 0–5 | Accepted by the owner (dates in D06) |
| WP 6 | **Conditionally accepted** 2026-11-04. Not closed: owner device checklist (Android; iOS or approved deviation), D05 V-01, TD-34 device verification, TD-36 variant |
| WP 7 | **Conditionally accepted** 2026-11-04. Not closed: portion precision 0.01 implementation, regression tests, fresh independent review, four workflows green on the final commit |
| GOV 1 | **Not accepted**; delivered for review (HO-0001) |
| Merge to `main` | **Not authorised** for any of the above |

## Outstanding owner decisions
- DL-0001 adopt the coordination protocol; DL-0002 ChatGPT read path; DL-0003 confirm branch protection on `main` (`DECISION-LOG.md`).
- WP 6 final acceptance after device verification (`docs/delivery-record/WP6.md` "Mandatory conditions").
- WP 7 final acceptance after the portion-precision closure condition (`docs/delivery-record/WP7.md`).
- NUT-017 specification revision 1.3 approval once revised.

## Outstanding review findings
- None in `reviews/` yet (system new). Findings recorded inside delivery records before this system: WP 7 final review N1–N4 (N3 → TD-38, N4 → TD-39, N1 and N2 fixed at 110b8bb); WP 6 F4/F6/F7 → TD-34/35/36 accepted as tracked debt.

## Outstanding verification requirements
- D05 V-01: WP 5 airplane-mode device verification (owner, physical Android device). Blocks WP 6 acceptance and R0.
- WP 6 device checklist `docs/verification/wp6-device-checklist.md` steps 1–15 (owner). iOS: signed build or recorded "not testable".
- TD-34 EAN-8/UPC-E lookup on real products (checklist step 5). TD-36 "Scan again" variant (step 12).
- WP 7: four workflows green on the final closure commit; fresh independent review.

## Blockers
- WP 6 closure and R0 are blocked on owner device verification (not on Claude Code).
- WP 7 closure is not blocked; it is unstarted implementation work.
- The coordination protocol is not live: ChatGPT reads and writes only through the owner (DL-0002).

## Next recommended actions
1. Owner: decide DL-0001..0003; perform the WP 6 device checklist and V-01 when a device session is possible.
2. ChatGPT: review HO-0001 (this system) using `REVIEW-TEMPLATE.md`.
3. Claude Code: implement the WP 7 portion-precision closure condition as the next engineering handoff, after the HO-0001 findings are addressed.
