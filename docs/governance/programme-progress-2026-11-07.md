# RepForge programme progress snapshot — 2026-11-07 (overnight integration campaign)

**Status:** Provisional effort-weighted snapshot at the campaign release candidate on branch `claude/busy-hypatia-rhl3hu` (see `docs/verification/overnight-campaign-2026-11-06.md` for the final commit and CI evidence). Not a release-readiness or acceptance assessment. Supersedes the figures in `programme-progress-2026-11-06.md` only where stated.

## Programme roll-up (approved allocations: 105 full, 97 core)

| Measure | Earned points | Denominator | Weighted completion |
|---|---:|---:|---:|
| Full programme (WP 0–15) | 77.11 | 105 | **73.4 %** |
| Core programme (excluding optional WP 12 and WP 13) | 77.11 | 97 | **79.5 %** |

Earned points: the 2026-11-06 snapshot's 74.95 with WP 8 raised from 7.50 to 9.66 by the WP lead's evidence update at `e50a047` (`docs/delivery-record/WP8.md`), as the WP 8 record itself rolls up (77.11). WP 15 stays at 2.20. All other WP values are the prior provisional estimates.

## Sensitivity: the proposed WP 17 allocation (owner approval outstanding, OB-WP17-01)

WP 17 (9.00 proposed, 3.00 earned) is not in the approved denominator. If the owner approves the allocation as proposed:

| Measure | Earned points | Denominator | Weighted completion |
|---|---:|---:|---:|
| Full programme including WP 17 | 80.11 | 114 | **70.3 %** |
| Core programme including WP 17 | 80.11 | 106 | **75.6 %** |

Adding a new package lowers the percentage because its unearned points enter the denominator; this is the expected effect of the standard, not a loss of progress.

## Active work-package positions (evidence: the WP records' campaign sections, 2026-11-07)

| WP | Allocation | Earned | Progress | Remaining | Confidence | Implementation | Review | Owner acceptance |
|---|---:|---:|---:|---:|---|---|---|---|
| WP 8 | 18.0 | 9.66 | 53.7 % | 8.34 | Low–medium | 3b decision baseline unpushed; B-15 open (OB-WP8-04) | Review C not reached | Not accepted |
| WP 15 | 3.0 | 2.20 | 73.3 % | 0.80 | Medium (implemented) / low (decisions) | Stages 1–2 integrated | Independent re-check PASS; credit pending OB-PROG-01 (sensitivity 2.30, 76.7 %) | Not accepted (OB-WP15-05) |
| WP 17 (proposed) | 9.0 | 3.00 | 33.3 % | 6.00 | Medium (S3–S4) / low (S5–S6) | S3–S4 integrated with review corrections | Independent review and integration re-check done; credit pending OB-PROG-01 | Not accepted (OB-WP17-09) |

Other sensitivities: WP 15 +0.10 and WP 17 review line (up to 0.50) if OB-PROG-01 accepts agent reviews; WP 14 (3.0, 30 % provisional) gained CI-reliability and release-verification work overnight (emulator disk-space fix, APK signature and metadata checks, presentation-isolation test) that is not re-estimated here and stays at the provisional 0.90 until the WP 14 record is written.

## Rules applied
- Weighted effort points only; no arithmetic average of percentages.
- The 105-point historical baseline is unchanged; WP 17 is shown as a sensitivity until approved.
- No owner-acceptance credit was awarded overnight; implementation, review and acceptance credit are kept separate.
- Denominators and the snapshot date are stated with every figure.
