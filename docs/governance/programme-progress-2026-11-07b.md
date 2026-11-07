# RepForge programme progress snapshot — 2026-11-07 (overnight programme acceleration campaign)

**Status:** Provisional effort-weighted snapshot at the campaign 2 release candidate on branch `claude/campaign-2026-11-07` (final commit and CI evidence in `docs/verification/overnight-campaign-2026-11-07.md`). Not a release-readiness or acceptance assessment. Supersedes `programme-progress-2026-11-07.md` only where stated. Snapshot date: 2026-11-07 (evidence baselines named per row).

## Programme roll-up (approved allocations: 105 full, 97 core)

| Measure | Earned points | Denominator | Weighted completion |
|---|---:|---:|---:|
| Full programme (WP 0–15) | 77.66 | 105 | **74.0 %** |
| Core programme (excluding optional WP 12 and WP 13) | 77.66 | 97 | **80.1 %** |

Earned points: the 2026-11-07 morning snapshot's 77.11 plus WP 14 raised from the provisional 0.90 to 1.45 by the WP 14 delivery record (`docs/delivery-record/WP14.md`, independently reviewed and re-checked, workflow steps validated on CI during the campaign). No other approved allocation changed. **The campaign recorded no new earned points for WP 8 or WP 11**, because the stage sub-allocations those packages delivered against are proposals the owner has not approved (standard section 5); their implemented and reviewed work is shown below as sensitivities, not as progress.

## Sensitivities (not in the roll-up until the owner decides)

| If the owner approves | Points | Full programme | Core programme |
|---|---:|---:|---:|
| WP 8 stage 3c sub-breakdown (OB-WP8-10): 0.58 implemented + 0.17 reviewed | +0.75 | 78.41 / 105 = 74.7 % | 78.41 / 97 = 80.8 % |
| WP 11 start and 7.0-point breakdown (OB-WP11-01) with the reviewers' provisional implementation view (domain stages A and C at 70 %; UI portions 1.70 of about 2.05; domain parts of B, D1, F, G1 not banded) | roughly +2.75 to +3.50, confidence low | about 76.7–77.4 % | about 83.1–83.9 % |
| WP 17 allocation (OB-WP17-01, 9.00 proposed, 3.00 earned) | denominator +9 | 80.66 / 114 = 70.8 % | 80.66 / 106 = 76.1 % |
| OB-PROG-01 (agent reviews count as review credit): WP 15 +0.10, WP 17 up to +0.50 | up to +0.60 | — | — |

WP 11 sensitivity arithmetic is deliberately a range: the plan's stages B, D1, F and G1 have no completion bands for partial delivery, so no exact figure can be stated until the owner approves bands (standard section 5). The WP 11 record (`docs/delivery-record/WP11.md`) carries the per-stage evidence.

## Active work-package positions (evidence: the WP records' campaign sections, 2026-11-07)

| WP | Allocation | Earned | Progress | Remaining | Confidence | Implementation | Review | Owner acceptance |
|---|---:|---:|---:|---:|---|---|---|---|
| WP 8 | 18.0 | 9.66 | 53.7 % | 8.34 | Low–medium | 3c pure domain merged (`fea71c8`), no runtime effect; 3b decision baseline on the WP 8 session's branch (`5e37008`), not integrated; B-15 open (OB-WP8-04) | 3c: independent review and re-check PASS | Not accepted; 3c sub-breakdown unapproved (OB-WP8-10) |
| WP 11 | 7.0 (proposed) | 0.00 | 0.0 % | 7.00 | Low (governance) / medium (code) | Domain, application and UI for stages A, B, C, D1, E, F (non-muscle), G1 computation delivered on `campaign/wp11`; D2 and G2 not started | Domain: two review rounds, final re-check PASS; UI: review with 6 Medium, fixes in progress | Not accepted; start and breakdown unapproved (OB-WP11-01) |
| WP 14 | 3.0 | 1.45 | 48.3 % | 1.55 | Medium (engineering) / low (owner rows) | Release workflow, signing config, cached debug keystore, NUT-023 source line, CHANGELOG | Independent review and re-check closed | Not accepted (OB-WP14-09) |
| WP 15 | 3.0 | 2.20 | 73.3 % | 0.80 | Medium / low | Unchanged this campaign | Unchanged | Not accepted (OB-WP15-05) |
| WP 17 (proposed) | 9.0 | 3.00 | 33.3 % | 6.00 | Medium / low | Unchanged this campaign | Unchanged | Not accepted (OB-WP17-09) |
| WP 12, WP 13 (optional) | 4.0 each | 0.00 | 0.0 % | 4.00 each | — | Decision packages only (ADR-0012, ADR-0013; OB-WP12-01, OB-WP13-01) | Reviewed as documents | Not started |

## Rules applied
- Weighted effort points only; no arithmetic average of percentages.
- The 105-point historical baseline is unchanged; WP 17 is shown as a sensitivity until approved.
- No owner-acceptance credit was awarded; implementation, review and acceptance credit are kept separate.
- Nothing was counted against an unapproved sub-allocation. Everything delivered against a proposal is a sensitivity.
- Denominators and the snapshot date are stated with every figure; each WP row names its record.
