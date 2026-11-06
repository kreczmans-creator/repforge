# RepForge Work-Package Effort Points and Progress Reporting

**Status:** Proposed programme-control standard — owner approval required before it becomes a mandatory acceptance gate  
**Applies to:** WP 0–WP 15 baseline and all subsequent work packages  
**Branch:** `governance/effort-point-progress-reporting`

## 1. Purpose

This standard establishes a consistent, auditable way to estimate relative work-package effort and report programme completion. Effort points represent **relative delivery effort**, not elapsed time, story points completed by an individual, complexity, or percentage complete.

The programme-level completion figure is calculated from approved work-package effort points and evidence-based completion percentages. It must not be calculated by averaging work-package percentages.

## 2. Baseline effort-point allocation

The following allocation records the programme planning baseline used for the initial completion estimate. It totals **105 effort points**.

| Work package | Scope (short label) | Effort points | Baseline completion estimate | Earned points at baseline |
|---|---|---:|---:|---:|
| WP 0 | Recovery and technical baseline | 2 | 100% | 2.00 |
| WP 1 | Flutter foundation | 5 | 100% | 5.00 |
| WP 2 | Application foundation and design system | 6 | 100% | 6.00 |
| WP 3 | Domain models and local persistence | 9 | 100% | 9.00 |
| WP 4 | Navigation, dashboard and settings | 5 | 95% | 4.75 |
| WP 5 | Nutrition and food database | 9 | 90% | 8.10 |
| WP 6 | Barcode scanning and food logging | 5 | 90% | 4.50 |
| WP 7 | Recipes and meal planning | 8 | 100% | 8.00 |
| WP 8 | Exercise library and training architecture | 18 | 35% | 6.30 |
| WP 9 | Training execution and history | 9 | 100% | 9.00 |
| WP 10 | Measurements and CSV export | 8 | 100% | 8.00 |
| WP 11 | Analytics | 7 | 0% | 0.00 |
| WP 12 | Optional accounts, backup and sync extension | 4 | 0% | 0.00 |
| WP 13 | Optional health integrations extension | 4 | 0% | 0.00 |
| WP 14 | Continuous QA and release engineering | 3 | 30% | 0.90 |
| WP 15 | Nutrition entry units | 3 | 40% | 1.20 |
| **Total** | | **105** | | **72.75** |

The completion percentages are provisional expert estimates from the programme status snapshot, not measurements produced by the repository or signed-off acceptance percentages. Earned points are therefore provisional too.

WP 12 and WP 13 are optional roadmap extensions. The full-programme denominator includes them; the core-product view excludes them. The core denominator is **97 points**.

## 3. Calculation

For each work package:

`Earned points = Allocated effort points \times Evidence	ext{-}based completion%`

Programme completion:

`Programme completion = Sum(earned points) / Sum(allocated effort points) \times 100`

The baseline snapshot calculates to:

- **Full programme:** 72.75 / 105 = **69.3%**
- **Core programme excluding optional WP 12 and WP 13:** 72.75 / 97 = **75.0%**

Always state which denominator is being reported. Do not silently exclude optional work packages.

## 4. Mandatory work-package reporting requirements

Every active work package must maintain an effort-and-progress section in its delivery plan or delivery record. The work-package lead/agent must:

1. **Declare the allocation.** Record the approved total effort points for the WP and the basis for the estimate before substantive implementation begins. Use the programme allocation above for WP 0–WP 15 unless an owner-approved change is recorded.
2. **Break down the work.** Allocate the WP's points across its stages, deliverables or acceptance criteria. The sub-allocations must sum exactly to the WP total. Allocate points to the actual deliverable, not to meetings, elapsed time or activity.
3. **Report at each progress update.** State total allocated points, earned points, percentage complete, points remaining, and the evidence supporting each earned increment.
4. **Report blockers and forecast.** Identify blocked/unstarted work, dependencies, scope changes, and any estimate variance. Do not award progress for work that is merely planned, assigned, started, or awaiting review.
5. **Reconcile at stage gates.** Update the breakdown when a stage is accepted, rejected, reworked, descoped or materially changed. Preserve the previous values and explain the change.
6. **Close on evidence.** A WP may report 100% only when all in-scope deliverables and acceptance criteria are met and the required acceptance authority has accepted the WP. Implementation complete but awaiting review/owner acceptance must remain below 100%.
7. **Keep the record current.** Update the progress section in the same change that materially changes WP status, or in the next formal progress report. The programme roll-up must cite the source WP records and snapshot date.

A suitable reporting table is:

| Stage / deliverable | Effort points | Earned points | Status | Evidence / acceptance reference |
|---|---:|---:|---|---|
| Example deliverable | 2.0 | 1.0 | In review | Commit, test report, review record |

The WP summary must also state:

- Allocated effort points
- Earned effort points
- Completion percentage
- Remaining effort points
- Estimate confidence (high / medium / low)
- Last updated date and evidence baseline
- Blockers, dependencies and scope changes
- Acceptance status (not accepted / conditionally accepted / accepted / closed)

## 5. Rules for earning progress

Progress is earned against completed, verifiable deliverables and their acceptance evidence.

- **Not started:** 0% earned.
- **In progress:** earn only the portion represented by demonstrably completed sub-deliverables. Do not use elapsed time or subjective activity as a proxy.
- **Implemented but not reviewed:** implementation credit may be earned for the implemented sub-deliverable, but review/verification/acceptance points remain unearned.
- **Review failed or changes requested:** retain credit only for portions that remain valid and evidenced; remove or reallocate credit for invalidated work and explain the adjustment.
- **Owner acceptance outstanding:** do not mark the WP 100% or accepted.
- **Accepted/closed:** 100% only where the recorded scope and acceptance criteria are fully satisfied. Explicitly recorded deferred items remain visible and must not be silently treated as complete.

Where the work cannot sensibly be divided into discrete deliverables, the WP lead must define objective completion bands before work proceeds and document the evidence required to move between bands.

## 6. Estimate governance and scope changes

- The initial points are a **relative programme baseline**, not a claim that one point equals a fixed number of hours or days.
- Points are not increased merely because work is taking longer than expected. Record variance separately.
- A scope increase, material new dependency or newly discovered requirement must trigger an estimate review. Record the old allocation, proposed allocation, rationale, impact on the programme denominator and owner decision.
- Do not change historical allocations or completion snapshots retrospectively without an explicit, traceable decision.
- New WPs must receive an effort-point allocation and stage breakdown before implementation is authorised. The programme owner approves the allocation.
- If an optional WP is deferred or cancelled, retain it in the full-programme record with its status and points; report the core denominator separately rather than silently deleting it.

## 7. Adoption and transition

This standard is intended to become a requirement for all active and future RepForge work packages after owner approval.

On approval:
- WP 8 and WP 15 must add stage-level point breakdowns and include the required figures in each progress report.
- Any other active WP must add the same section at its next substantive status update.
- Closed WPs retain their historical delivery records. Their baseline allocations and percentages above are programme-level estimates; they are not grounds to reopen accepted work packages.
- The programme status report must publish both full and core weighted completion, the snapshot date, and links to the underlying WP evidence.

Until owner approval, this document is a proposed governance change and must not be represented as an already-authorised acceptance gate.
