# RepForge programme progress snapshot — 2026-11-06

**Status:** Provisional effort-weighted snapshot. This is not a formal release-readiness or acceptance assessment.

## Programme roll-up

| Measure | Earned points | Denominator | Weighted completion |
|---|---:|---:|---:|
| Full programme (WP 0–15) | 74.95 | 105 | **71.4%** |
| Core programme (excluding optional WP 12 and WP 13) | 74.95 | 97 | **77.3%** |

The original baseline was 72.75 / 105 (69.3%) full and 72.75 / 97 (75.0%) core. This snapshot replaces only the provisional WP 8 and WP 15 estimates with the first stage-level reconciliations below. All other WP values and point allocations remain the prior provisional baseline in `effort-points-and-progress-reporting.md`.

## Active work-package reconciliation

| WP | Allocation | Earned | Progress | Remaining | Confidence | Acceptance |
|---|---:|---:|---:|---:|---|---|
| WP 8 | 18.0 | 7.50 | **41.7%** | 10.50 | Low–medium | Active, not accepted |
| WP 15 | 3.0 | 2.20 | **73.3%** | 0.80 | Medium for implemented work; low for open scope/decisions | In progress, not accepted |

### WP 8 — exercise library and training architecture

The 18-point allocation is distributed across stages 1–6, stage 3 sub-stages, and final review. Earned credit is 7.50 points: stages 1–2 and their review fixes (4.00), stage 3a (2.00), approved stage 4 governance outputs (0.50), and the completed 3b-1 and 3b-3 gates (1.00).

No credit is assigned to 3b-2 because the delivery record says it is implemented but awaiting commit. Uncommitted 3b-4 work, 3b-5 to 3b-10, 3c, 3d, stages 5–6 and final acceptance remain unearned. The approved plan revision 3 authorises stage 3 in sequence; it does not constitute stage 3 acceptance or final WP acceptance.

Evidence source: [WP 8 delivery record](https://github.com/kreczmans-creator/repforge/blob/governance/wp-effort-point-baseline-reconciliation/docs/delivery-record/WP8.md) and [approved WP 8 delivery plan](https://github.com/kreczmans-creator/repforge/blob/ccr-9fda2c32-wr163b/docs/wp8-delivery-plan.md).

### WP 15 — nutrition entry units

The 3-point allocation is distributed across the entry-unit domain, the food portion sheet, the recipe ingredient sheet, custom-food serving scope disposition, specification/owner decisions, independent review and owner acceptance. Earned credit is 2.20 points for the domain and the two implemented entry sheets.

Custom-food serving entry remains unresolved; specification revision 1.4 is proposed, OQ-02 and the mg UI decision remain open, independent review remains outstanding, and owner acceptance has not occurred. The reported CI runs are green, but CI success does not replace independent review or owner acceptance.

Evidence source: [WP 15 delivery record on the parallel workstream branch](https://github.com/kreczmans-creator/repforge/blob/claude/repforge-parallel-implementation-flyjqw/docs/delivery-record/WP15.md), implementation commit `353fcd8`. This record is on the parallel branch and is not represented as merged into the active primary branch.

## Interpretation and limitations

- The denominator remains 105 points full / 97 points core; WP 12 and WP 13 remain optional extensions and are excluded only from the core view.
- This is a hybrid roll-up: WP 8 and WP 15 now have deliverable-level allocations; other WPs retain the earlier rough estimates. Therefore 71.4% / 77.3% are improved but still provisional.
- Effort points are relative sizing units, not hours or days.
- A percentage does not imply that a WP is accepted, closed, integrated or release-ready.
- The next update must reconcile any newly completed WP 8/15 gates and retrofit other active WPs at their next substantive status update, as required by `AGENTS.md`.
