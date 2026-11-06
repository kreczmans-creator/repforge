# WP 11 Analytics: architecture and implementation plan (proposal, not authorised)

- Status: **Proposal. No implementation is authorised.** The owner has not approved this plan or the stage breakdown in section 9.
- Date: 2026-11-06. Repository state read: branch `claude/busy-hypatia-rhl3hu`, head `cee71dd` (merge of WP 15 and WP 17); independently reviewed and corrected against head `54a88f3` on 2026-11-07. Proposal only: nothing in this document is authorised.
- Governance: `docs/governance/effort-points-and-progress-reporting.md` and `AGENTS.md`.
- Sources: `docs/wp0/D03-target-architecture.md`, `docs/wp0/D04-product-requirements-baseline.md`, `docs/wp0/D06-work-package-roadmap.md`, `docs/wp8-delivery-plan.md`, `docs/schema-v8.md`, `docs/delivery-record/WP8.md`, `WP9.md`, `WP10.md`, `WP17.md`, and the code paths cited in each section.

## 1. Purpose and status

D06 states the WP 11 objective as "goals and weekly insight without automated coaching." This document turns that objective into a plan the owner can approve or change. It contains no code.

| Item | Value |
|---|---|
| Work package | WP 11, Analytics and progress visualisation |
| Allocated effort points | **7.0** (baseline in `docs/governance/effort-points-and-progress-reporting.md` section 2) |
| Earned points | 0.00 (0 %), remaining 7.00 |
| Estimate confidence | Low. Three scope items may not be covered by the 7.0 baseline (section 10, decision 1). |
| Evidence baseline | 2026-11-06. No WP 11 code exists. The Goals tab is a placeholder (section 7). |
| Blockers and dependencies | Owner authorisation to start. WP 8 stage 3d for per-muscle figures. Schema ownership (section 6). |
| Scope changes | None recorded. Three additions need an estimate review decision (section 10, decision 1). |
| Acceptance status | Not accepted. Not started. |

Programme view: WP 11 sits in the core programme. The full denominator is 105 points and the core denominator is 97 points, as in the standard. Both are unchanged by this document.

D06 dependencies for WP 11: WP 5, WP 9, WP 10, and WP 8 stage 3 (expanded anatomy and exercise taxonomy) for training analytics such as volume per muscle (OQ-19 rule). WP 5, WP 9 and WP 10 are accepted. WP 8 stage 3 is not accepted (`docs/delivery-record/WP8.md`, stage 3b decision baseline).

The owner decisions are listed in section 10.

## 2. Requirements traced

Source: `docs/wp0/D04-product-requirements-baseline.md` section 4.5, and the WP 11 entry in D06. The D04 traceability table assigns 12 GOL requirements to WP 11.

### 2.1 Goals and analytics (GOL)

| Id | Short text | Priority | Existing partial coverage (read from code) |
|---|---|---|---|
| GOL-001 | Daily calorie target, 800 to 10,000 kcal | P1 | Range check and editor exist (WP 4): `validateTarget` in `app/lib/domain/goals/daily_targets.dart` (800 to 10,000), editor in `app/lib/features/settings/presentation/settings_screen.dart`. No delivery record marks GOL-001 as met. |
| GOL-002 | Macro targets in g; show implied energy; warn if more than 10 % from calorie target | P1 | Targets saved (same files). I found no implied-energy warning in `app/lib/features/settings` or `app/lib/domain/goals`. |
| GOL-003 | Body weight goal: target, direction, optional date; progress uses trend value | P1 | `GoalKind.bodyWeight` and its range exist (`goals.dart`, `daily_targets.dart`). No editor, no direction field, no progress. |
| GOL-004 | Goals for any body measurement | P2 | `GoalKind.measurement` and `Goal.site` exist. No editor, no progress. |
| GOL-005 | Training goals: sessions per week; target for a chosen exercise | P2 | `GoalKind.sessionsPerWeek` exists. No exercise-target kind. No editor, no progress. |
| GOL-006 | Record the date each target is set or changed; earlier days stay evaluated against the earlier target; history viewable | P1 | Rows are kept: `replaceActive` marks the old row inactive and inserts a new one (`app/lib/data/repositories/drift_goal_repository.dart`). But `GoalRepository` (`app/lib/domain/goals/goals.dart`) has only two reads, `active()` and `watchActive()`, and `DailyTargets.fromGoals` reads active goals only. So past days are judged against today's target. Not met. |
| GOL-007 | Weekly summary of nutrition, training and body; "not enough data" instead of zero | P1 | Nutrition-only "Last 7 days" screen (`app/lib/features/nutrition/presentation/weekly_summary_screen.dart`). No training or body part. |
| GOL-008 | Progress indicator per goal with visible basis and tap-through | P1 | None. |
| GOL-009 | Compare this week with last week and this month with last month (energy, protein, volume, weight) | P2 | Measurement-only period comparison: `comparePeriods` in `app/lib/domain/measurements/measurement_comparison.dart`. |
| GOL-010 | Recomposition view: weight trend, waist trend, strength trend on one date axis | P2 | None. Parts exist (`weightTrend`, `RfTrendChart`). |
| GOL-011 | No coaching or recommendations until GOL-012 is met and the owner approves | P1 | Constraint on every stage. No feature of this kind exists. |
| GOL-012 | Measurable data-quality criteria (proposed 28 days, 80 % of days logged, 90 % of energy verified or user-entered, weight on 3 days per week) | P2 | None. Thresholds are proposals (OQ-15). |

### 2.2 Requirements allocated to WP 11 elsewhere

| Id | Text | Where the allocation is recorded | State in code |
|---|---|---|---|
| NUT-019 | Calculated totals carry the weakest provenance of their inputs (P1) | D06 WP 11 entry (added 2026-11-04); `docs/delivery-record/WP7.md` line 108 | `weakestProvenance` exists in `app/lib/domain/nutrition/nutrition.dart`. `NutrientTotals` and `DailySummary` carry no provenance. `ProvenanceBadge` appears per entry only (`fuel_screen.dart` line 352). Day totals have no badge. |
| TRN-027 | Volume per exercise, session, muscle group and week (P1) | `docs/delivery-record/WP9.md` lines 154 and 256 ("proposed for WP 11") | Rules and `GetWeeklyVolume` exist and are tested. No screen calls `getWeeklyVolumeProvider`. |
| TRN-028 | Progressive overload tracking per exercise (P2) | `docs/delivery-record/WP9.md` line 31 ("proposed for WP 11") | None. |

TRN-027 and TRN-028 are "proposed", not formally allocated in D06. NUT-019 is allocated in D06. Decision 1 asks the owner to settle this.

### 2.3 Requirements WP 11 consumes but does not own

NUT-015 and NUT-016 (daily and weekly nutrition summary, WP 5), NUT-017 (calculation specification, `docs/nutrition-calculation-spec.md`), NUT-021 and GEN-006 (no invented data), BCM-005 to BCM-008 (trend, comparison, progress; WP 10), TRN-019 (warm-up sets excluded), TRN-024 (edits recalculate), TRN-025 and TRN-026 (history and PRs; WP 9), OQ-19 (attributed set counts), UXD-009 (chart accessibility), GEN-009 (no analytics SDK).

## 3. Existing data sources

All paths are under `app/lib/` unless stated. Schema version in production is 7 (`data/db/app_database.dart`, `schemaVersion => 7`).

### 3.1 Tables (schema v7, `data/db/tables.dart`)

| Table | Used for | Notes |
|---|---|---|
| `food_log_entries` | Nutrition intake | Stores a nutrient snapshot, a `day` key and a per-entry provenance (`FoodLogEntry` in `domain/nutrition/nutrition.dart`). |
| `measurements` | Body weight and sites | Body weight is a measurement with site `weight`. `DriftWeightRepository` is a facade over `DriftMeasurementRepository`. |
| `workout_sessions`, `session_exercises`, `session_sets` | Training history | `WorkoutSession.endedAt` is nullable. Set kinds include warm-up. |
| `exercises` | Exercise names and one primary muscle (v7) | v8 replaces the muscle columns with targets (section 8). |
| `goals` | Targets and goals | Columns: `kind`, `site`, `target`, `start_date`, `end_date`, `active`, plus sync columns. |
| `settings` | `dayStartHour`, `weekStartDay` | `domain/settings/settings.dart`. |
| `scheduled_workouts`, `workout_plans`, `training_splits` | Planned training | Not needed for the GOL requirements. |

### 3.2 Repositories and use cases that already compute analytics-like values

| Capability | Where | Status |
|---|---|---|
| Daily nutrition totals vs targets | `DailySummary.fromEntries` in `domain/goals/daily_targets.dart`, wired in `features/dashboard/application/dashboard_providers.dart` (`todaySummaryProvider`) | Exists. Uses today's target only. |
| Weekly nutrition summary (last 7 days) | `WeeklySummary` in `domain/nutrition/summaries.dart`; `weeklySummaryProvider` in `features/nutrition/application/nutrition_providers.dart` | Exists. Average over logged days, "days logged" count, unknown-nutrient counts. Fixed 7-day window ending on the selected day (not a calendar week). Compared to current targets. |
| Body weight trend | `weightTrend` in `domain/measurements/weight_trend.dart` | Exists. 7-day window, at least 3 readings, daily means (BCM-006 decision). |
| Measurement progress and comparison | `progressSummary`, `comparePeriods` in `domain/measurements/`; screen `features/measurements/presentation/progress_screen.dart` | Exists for measurements. |
| Training volume | `VolumeRules` in `domain/training/volume.dart` | Exists: per set, exercise, session, muscle (single primary), week. Warm-up and uncompleted sets excluded. Only weighted sets add kg. |
| Weekly volume use case | `GetWeeklyVolume` in `features/training/application/records_use_cases.dart` | Exists, unused by any screen. It loads exercises one by one with `byId`. |
| Personal records | `PersonalRecordRules` in `domain/training/personal_records.dart`; `GetExerciseRecords` | Exists. Weighted sets at 1 to 12 reps, bodyweight reps, timed, distance. Assisted and cardio sets give no PR. Derived, never stored. |
| Exercise history | `WorkoutSessionRepository.sessionsForExercise` (limit and offset), `performedSets` in `domain/training/training_repository.dart` | Exists. The UI reads a fixed 20 (`exerciseHistoryLimit`). |
| Attributed set counts per anatomy node | `attributeSetCounts` in `domain/library/set_attribution.dart` | Exists as pure code. No production caller. Needs v8 targets. |
| Recent food sources | `FoodLogRepository.recentSources` | Exists (WP 17). Not an analytics input. |

### 3.3 What does not exist yet

- Session counts per week. No code counts completed sessions per week or per day.
- Training frequency per muscle or per exercise.
- Rate of weight change.
- Target history reads and per-day target resolution.
- Adherence to targets (D04 defines no measure).
- Goal progress for any goal kind.
- Day-total provenance (NUT-019).
- Any chart for training data.

## 4. Required domain models

New code goes under `app/lib/domain/analytics/`. All models are immutable, read-only aggregates built from existing rows. They follow D03 section 2.3 (freezed or plain immutable classes, no Flutter imports). **No new tables.**

| Model (file) | Fields | Purpose |
|---|---|---|
| `AnalyticsPeriod` (`analytics_period.dart`) | `from`, `to` (inclusive `CalendarDate`), `kind` (week, month, custom), label | One period type for every aggregator. Reuse `CalendarDate` (`domain/core/calendar_date.dart`) and `DateRange` (`domain/measurements/measurement_period.dart`). |
| `Metric<T>` (`metric.dart`) | sealed: `MetricValue(value, basis)` or `NotEnoughData(have, need, reason)` | Enforces GOL-007(2), BCM-008 and GEN-006: a missing value is never zero. |
| `MetricBasis` (`metric.dart`) | `period`, `sampleCount`, `sources` (what was read), `weakestProvenance?` | Makes the basis visible (GOL-008(1)). |
| `TargetHistory` (`target_history.dart`) | list of target periods per `GoalKind` and site: value, `effectiveFrom`, `effectiveTo?` ; method `targetsOn(day)` | GOL-006. Built from all goal rows, including inactive ones. |
| `DayNutrition` (`nutrition_analytics.dart`) | `day`, `totals` (`NutrientTotals`), `targetsInEffect` (`DailyTargets`), `provenance` (weakest label or null), `hasMissingData` | NUT-019, NUT-021, GOL-006. |
| `NutritionWeek` (`nutrition_analytics.dart`) | `period`, `days` (list of `DayNutrition`), `loggedDays`, `notLoggedDays`, `averagePerLoggedDay` (per nutrient `Metric`), `adherence` | NUT-016, GOL-007, GOL-009. |
| `TargetAdherence` (`nutrition_analytics.dart`) | per nutrient: days with a target, days logged, days inside the band | Band definition is decision 5. |
| `WeightSummary` (`body_analytics.dart`) | `latestRaw`, `latestTrend?`, `readingsInWindow`, `rateOfChange` (`Metric`) | GOL-003, GOL-007. Wraps `weightTrend`. |
| `RateOfChange` (`body_analytics.dart`) | `perWeek`, `fromDate`, `toDate`, `pointsUsed` | New. Method is open (section 5.3). |
| `WeekTraining` (`training_analytics.dart`) | `period`, `sessionsCompleted`, `workingSets`, `volume` (`VolumeTotals`), `byExercise`, `activeDays` | GOL-005, GOL-007, TRN-027. Reuses `VolumeRules`. |
| `MuscleSetSummary` (`training_analytics.dart`) | `primary`, `secondary` (`AttributedTotals` per anatomy node), `nonAnatomical`, `notice` | TRN-027(3), OQ-19. Wraps `attributeSetCounts`. Carries `attributedSetCountsNotice`. |
| `ExerciseProgress` (`training_analytics.dart`) | list of `ExerciseProgressPoint` (session date, top-set weight, session volume, estimated 1RM?), `trendStatement` per measure | TRN-028. Statements are "increased", "level", "decreased" or "first session". No instruction text. |
| `RecordEvent` (`training_analytics.dart`) | `PrKey`, value, set id, session id, date | PR list for a period. Derived by `PersonalRecordRules.chronological` and `recordSetIds`. |
| `GoalProgress` (`goal_progress.dart`) | `goal`, `current` (`Metric`), `target`, `percent?`, `basis`, `drillDown` (a route reference to the underlying entries) | GOL-008. |
| `WeeklyReport` (`weekly_report.dart`) | `period`, `nutrition`, `training`, `body`, each a section that may be `NotEnoughData` | GOL-007. |
| `PeriodComparison<T>` (`period_comparison.dart`) | `earlier`, `later`, `difference?` per measure | GOL-009. Extends the idea in `measurement_comparison.dart`. |
| `RecompositionSeries` (`recomposition.dart`) | three series on one date axis with `pointCount` each | GOL-010. |
| `DataQualityReport` (`data_quality.dart`) | per criterion: observed, required, pass or fail, reason; overall result | GOL-012. Pure computation. No UI that gives advice. |

Rules for all models:

1. Aggregators are pure functions over rows already loaded. Repositories load. Use cases orchestrate (D03 sections 2.2 and 2.3).
2. Every figure that can be missing returns `Metric`, not a number.
3. No model stores a computed value in the database.

## 5. Aggregation requirements

### 5.1 Training metrics

| Metric | Rule | Source | Open question |
|---|---|---|---|
| Volume (kg) | Sum of weight times reps for completed, non-warm-up weighted sets (TRN-027(1), TRN-019). | `VolumeRules.ofSet` | Failure sets count today (`kind != warmUp`). D04 does not say. Confirm. |
| Sets | Count of completed non-warm-up sets, all types. | `VolumeTotals.sets` | None. |
| Own measures for other types | Reps (bodyweight, assisted), seconds (timed, cardio), metres (distance, cardio). Never added to kg (TRN-027(2)). | `VolumeTotals` | None. |
| Sessions per week | Count of sessions with `endedAt` set whose start falls in the week. | `sessionsBetween` | D04 does not define "completed session." Is a session with no completed set counted? Is an unfinished session counted? |
| Week boundary | Monday to Sunday unless the user changes it (TRN-027(3)). Use `weekStartDay` and `dayStartHour`. | `VolumeRules.weekStart` | See decision 7. |
| Frequency | Distinct days with at least one counted session per week; sessions per muscle node per week. | New | Per-muscle frequency needs v8 targets. |
| Per-muscle volume | Attributed set counts: primary gets full credit, secondary reported separately, shown with the OQ-19 notice. kg volume per muscle follows the same attribution and is labelled the same way (D04 section 7, 2026-11-05 clarification). When a primary and a secondary of one exercise roll up to one parent, only primary credit counts at that level. A `fullBody` primary is shown separately as non-anatomical. | `attributeSetCounts` | None. Waits for WP 8 stage 3d (section 8). |
| PRs | Heaviest weight at each rep count 1 to 12; longest duration; longest distance; most reps. Warm-ups excluded. Derived, never stored. | `PersonalRecordRules` | Assisted and cardio have no PR rule. WP 9 recorded this as a requirements gap (`docs/delivery-record/WP9.md` lines 81 and 290; also `docs/verification/parallel-workstream-assessment-2026-11-06.md` line 98). See decision 9. |
| Per-exercise history | Sets grouped by session date, newest first. | `sessionsForExercise`, `performedSets` | Paging belongs to WP 8 stage 6 (OQ-25). WP 11 must not duplicate it. |
| Progressive overload | Per session: top-set weight, session volume, estimated 1RM "if applicable"; compare with the previous session of that exercise (TRN-028). | `performedSets` | The 1RM formula is not defined. See decision 6. |
| Exercise goal progress | Best set so far against a target (GOL-005(2)). | `performedSets` | Needs a goal that names an exercise (section 6, decision 2). |

Edits and deletes must change every figure on the next read (TRN-024(1)). Compute on read satisfies this without extra code.

### 5.2 Nutrition metrics

| Metric | Rule | Source | Open question |
|---|---|---|---|
| Daily totals vs targets | Totals are the sum of entry snapshots. Target is the one in effect on that day (GOL-006(1)). | `DailySummary`, `TargetHistory` | Needs a history read (section 6). |
| Weekly average | Average over days with entries. State the number of days logged. Days without entries are "not logged", never 0 (NUT-016). | `WeeklySummary.averagePerLoggedDay` | Today the window is the last 7 days ending on the selected day. GOL-007 and GOL-009 imply calendar weeks and months. |
| Unknown nutrients | A nutrient with null on some entries is summed over the known values and flagged (NUT-021). | `NutrientTotals.unknownCount` | None. |
| Day-total provenance | Weakest label among the entries of the day, order verified, crowdsourced, user-entered, estimated (`docs/nutrition-calculation-spec.md` section 8; `provenanceStrength`). Show on daily and weekly totals (NUT-019). | `weakestProvenance` over `FoodLogEntry.provenance` | Use the order in `provenanceStrength`, not a new one. |
| Adherence | Share of logged days inside a band around the target, per nutrient. | New | D04 defines no adherence measure. Decision 5. |
| Macro-implied energy | 4, 4 and 9 kcal per g; warn over 10 % from the calorie target (GOL-002). | New, in the goals editor | Part of GOL-002, which WP 4 left open. |

The energy figure follows the carbohydrate convention in `docs/nutrition-calculation-spec.md` section 4. WP 11 must call the existing NUT-017 code and add no second formula.

### 5.3 Body metrics

| Metric | Rule | Source | Open question |
|---|---|---|---|
| Weight trend | Use `weightTrend` unchanged (7-day trailing, at least 3 readings, daily means first). | `domain/measurements/weight_trend.dart` | None. Decided in D04 section 7 (WP 10 D1). |
| Latest weight and trend value | Both shown; goal progress uses the trend value (GOL-003(2)). If no trend point exists, say so. | `WeightSummary` | When the latest trend point is old, which one is "latest"? Define a maximum age. |
| Rate of change | Change in the trend value per week between two trend points. No interpolation (BCM-005 decision). | New | Method not defined: first and last trend point in the window, or a straight-line fit. Decision 8 (grouped with the trend rules). |
| Measurement progress | First, latest, difference per site (BCM-008). | `progressSummary` | None. |
| Waist trend for recomposition | Raw waist readings with the BCM-005 gap rule (join if 7 days or less apart). No moving average is defined for waist. | `site_screen.dart` shows the pattern | Whether waist needs a trend line is not stated. |
| Goal progress | Weight: distance left, using the trend value. Measurement: latest reading against target (GOL-004(1)). | `GoalProgress` | Direction (section 6). |

### 5.4 Cross-domain rules

1. Day boundary. Nutrition and training use `dayStartHour` (`diaryDayKey`). Body readings use the local calendar date (`CalendarDate.fromInstant`). A weekly report must pick one rule per section and say so. Decision 7.
2. Time axis. GOL-010 needs one date axis across three sources. Use calendar dates and show the count of points behind each series.
3. Descriptive output only. No text may tell the user what to eat, lift or change (GOL-011). Statements such as "increased since last session" are allowed (TRN-028(2)).
4. Missing data. Every section of the weekly report can read "not enough data." A section never shows zero in its place.
5. Retired and archived exercises. History keeps them (`docs/wp8-delivery-plan.md` section 15, item 6a). Analytics must resolve their names.

## 6. Persistence requirements

### 6.1 Recommendation: compute on read

All aggregates in section 4 can be derived from rows that exist. Reasons:

- Edits and deletes then update every figure at once (TRN-024(1)).
- No migration, no backup change and no restore change.
- D03 section 4 already feeds the UI from drift streams.
- A cache table would add a second source of truth. WP 8 rejected the same pattern for muscle columns (`docs/wp8-delivery-plan.md` section 5).

Cost to watch: `sessionsBetween` loads whole sessions with sets, and `GetWeeklyVolume` calls `exercises.byId` once per exercise. For a long history this needs measurement. The WP 8 trial used 5,000 exercises and 100,000 sets as a large profile (`docs/schema-v8.md`, host timing note). A similar profile is a reasonable load test for WP 11. If a measured figure fails, add an indexed query first, then consider a cache with the owner's approval.

### 6.2 Schema ownership

| Version | Owner | State |
|---|---|---|
| v7 | Production | Live. |
| v8 | WP 8 stage 3b | Defined in `docs/schema-v8.md`. Isolated in `data/db/v8/`. Not connected. Production stays on 7. Stage 3b is not accepted. |
| v9 | WP 17 stage S6 | Held until v8 is connected and accepted (`docs/delivery-record/WP17.md`; `docs/workout-catalogue/plan-metadata-schema-proposal.md`). Its content is plan metadata, recipe tags and image. |

**WP 11 adds no table and no column before v8 is connected and accepted and the v9 content is settled.** The parallel-workstream assessment (`docs/verification/parallel-workstream-assessment-2026-11-06.md` line 28) records that any table or column change to the shared `tables.dart` breaks the WP 8 CI comparison of the v8 dump.

### 6.3 What would need schema change

| Need | Why existing columns do not hold it | Zero-schema alternative |
|---|---|---|
| Direction of a weight goal (GOL-003) | `goals` has `target` and dates, not a direction or a starting value. | Derive direction at read time from the latest trend value and the target. Fails when the user has passed the target. |
| Exercise target goal (GOL-005(2)) | No exercise id or reps column. `site` is a text column typed for measurement sites. | Defer. Or keep in `settings` as JSON, which hides structured data in a key-value table. Not recommended. |
| Goal history reads (GOL-006) | Rows exist. Only a read method is missing. | Add `history()` to `GoalRepository`. Domain interface and Drift implementation only. No schema change. |
| Saved goal kinds | `kind` is free text in `goals`, so new `GoalKind` names need no schema change. | None needed. |
| Cached aggregates | Not needed. | Compute on read. |
| Weekly summary snapshots (freeze a week as shown) | Not required by any GOL text. | Not planned. |

Decision 2 and decision 3 cover the two real choices.

### 6.4 Backup

`DriftBackupRepository` is at format 2 in production (`data/repositories/drift_backup_repository.dart`, `formatVersion = 2`). Format 3 is a WP 8 deliverable (stage 3b-7). Because WP 11 stores nothing new, it needs no backup work.

## 7. UI dependencies

### 7.1 Existing placeholders and components

| Item | Path | Fact |
|---|---|---|
| Goals tab | `app/lib/app/router.dart` | `RfRoutes.goals = '/goals'` (line 121). The branch builds `PillarPlaceholderScreen(title: 'Goals', caption: 'Targets and weekly summaries', feature: 'Calorie, macro, weight and training goals', workPackage: 'WP 11')` (lines 400 to 408). A `TODO(placeholder)` comment sits at line 138. The nav item key is `nav-goals`. |
| Placeholder widget | `app/lib/features/shell/pillar_placeholder_screen.dart` | WP 11 replaces the builder and removes the TODO. |
| Trend chart | `app/lib/ui/components/rf_trend_chart.dart` | `RfTrendChart` takes `RfTrendSeries` lists. Features: markers, dashed lines, `joinPrevious` gaps, `showDataTable` (UXD-009(2)). Used today in `features/measurements/presentation/site_screen.dart`. |
| Stat tile | `app/lib/ui/components/rf_stat_tile.dart` | `RfStatTile(label, value, unit, caption, progress)`. Used in home, fuel and weekly summary screens. |
| Other | `rf_card.dart`, `rf_section_header.dart`, `rf_states.dart` (empty, error, loading), `rf_macro_bar.dart` | Every screen needs the three states (D03 section 2.1). |
| Weekly nutrition screen | `features/nutrition/presentation/weekly_summary_screen.dart` | Reuse its tile layout. |
| Targets editor | `features/settings/presentation/settings_screen.dart` | Owns GOL-001 and GOL-002 input today. |

A multi-series chart with a shared axis (GOL-010) may need an `RfTrendChart` extension: a second value axis or normalised series. `RfTrendChart` has one `unit` string. This is a design-system question for the owner (decision 12). I did not find any secondary-axis support in the file.

### 7.2 Screens WP 11 would deliver

1. Goals home (replaces the placeholder): active goals with progress indicators (GOL-008), entry points to the weekly summary and comparisons.
2. Goal editor for body weight, measurement and sessions per week (GOL-003 to GOL-005). Calorie and macro editing stays in Settings unless the owner moves it (GOL-001, GOL-002).
3. Target history view (GOL-006(2)).
4. Weekly summary: nutrition, training and body sections (GOL-007).
5. Period comparison (GOL-009).
6. Training analytics: weekly volume, per-muscle attributed set counts with the OQ-19 notice, sessions per week (TRN-027).
7. Exercise progress and PR list (TRN-028, TRN-026).
8. Recomposition view (GOL-010, P2).
9. Day-total provenance badge on the Fuel day total and weekly totals (NUT-019). This changes WP 5 screens, so it needs the owner's consent (section 8).

Each screen needs empty, loading and error states, widget tests, and a text summary or data table for each chart (UXD-009).

## 8. Integration boundaries

| Package | WP 11 reads | WP 11 must not change |
|---|---|---|
| WP 4 (accepted) | `Goal`, `GoalRepository`, `DailyTargets`, `AppSettings.weekStartDay`, `dayStartHour` | Existing meaning of `replaceActive` and `SaveDailyTargets`. Adding a `history()` read method is a change to a closed interface and needs decision 3. |
| WP 5 (accepted) | `FoodLogEntry`, `NutrientTotals`, `weakestProvenance`, NUT-017 code | Calculation rules, rounding, carbohydrate convention. |
| WP 7 (accepted) | Nothing directly. Recipe entries reach the log as snapshots. | Recipe code. |
| WP 8 (active) | Exercise names; after stage 3d, `targets` per exercise and the reference tree (`AnatomyTree`); `attributeSetCounts` | Schema v8, the isolated zone `data/db/v8/` and `data/repositories/v8/`, the library domain. The isolation test `test/architecture/schema_v8_isolation_test.dart` forbids outside imports of the v8 zone. WP 11 must read exercises through `ExerciseRepository` and, once 3d lands, its successor port. |
| WP 9 (accepted, closed) | `WorkoutSession`, `SessionSet`, `VolumeRules`, `PersonalRecordRules`, `GetWeeklyVolume` | Volume and PR rules. WP 11 may add a caller. If WP 11 needs a rule change (for example PRs for assisted sets), that is a new owner decision, not a silent edit. |
| WP 10 (accepted) | `Measurement`, `weightTrend`, `progressSummary`, `comparePeriods`, `DateRange` | The trend method and gap rule (D04 section 7). |
| WP 15 (active) | Canonical stored quantities only | Entry-unit handling. Analytics reads canonical grams and millilitres. |
| WP 17 (active) | Nothing. | S3b-ii (NUT-014 remainder) needs a saved-meal id on log entries and v9. WP 11 must not rely on that column. |
| WP 12, 13 (optional) | Nothing | Not dependencies. WP 13 health data would later add inputs. Out of scope. |
| WP 14 (continuous) | CI gates | Four workflows plus the coverage gate (`.github/workflows/`, `app/tool/coverage_gate.dart`). |

D06 sets the WP 11 release point as R2 beta after WP 11.

## 9. Stage breakdown (proposed, 7.0 points)

The standard (section 4, item 2) requires sub-allocations that sum to the WP total. This table sums to **7.00**. It is a proposal. The owner approves it (decision 1). Earned points stay at 0.00 until evidence exists (standard section 5).

| Stage | Deliverables | Points | Acceptance evidence |
|---|---|---:|---|
| A. Foundations | `lib/domain/analytics` core: `AnalyticsPeriod`, `Metric`, `MetricBasis`, week and day rules from settings, `TargetHistory`, `GoalRepository.history()` if approved | 0.75 | Unit tests for period edges (week start, day start hour, daylight-saving change), `TargetHistory` tests for GOL-006(1) (a change on 2026-11-10 leaves earlier days on the old target). Architecture test: no Flutter import in domain. |
| B. Nutrition analytics | `DayNutrition`, `NutritionWeek`, adherence, NUT-019 provenance on day and week totals, badge on Fuel and weekly screens | 1.00 | Tests with fixture entries: weakest label rule, "N of 7 days logged", unknown-nutrient flags, historical targets. Widget tests for the badge. Matches NUT-016 acceptance. |
| C. Body analytics | `WeightSummary`, `RateOfChange`, weight and measurement `GoalProgress` | 0.75 | Tests with fixtures: fewer than 3 readings gives no trend, 85.0 to 80.0 shows 5.0 to go using the trend value (GOL-003(1)), waist goal against latest reading (GOL-004(1)). |
| D1. Training analytics without muscles | `WeekTraining`, sessions per week, frequency, PR events, `ExerciseProgress`, UI for volume and progress | 1.00 | Tests: 80x5 plus 80x4 gives 720 kg; warm-ups excluded; "2 of 3 sessions" (GOL-005(1)); increased, level, decreased statements. Load test on a large profile. |
| D2. Per-muscle figures | `MuscleSetSummary` on v8 targets, OQ-19 notice on every screen showing them | 0.50 | Tests against `docs/wp8-delivery-plan.md` section 8 rules, the OQ-19 roll-up rule (D04 section 7, stage 3a decisions) and the ADR-0010 `fullBody` rule. Needs WP 8 stage 3d connected and accepted. |
| E. Goals management | Goals home, editors for body weight, measurement and sessions per week, progress indicators with basis and tap-through, target history view, router change | 1.00 | Widget tests for each state; indicator shows current, target, percent and date range (GOL-008); tap-through opens entries. Exercise-target goal only if decision 2 allows. |
| F. Weekly summary and comparison | `WeeklyReport`, `PeriodComparison`, recomposition view | 1.00 | Summaries match fixture data (D06 acceptance). "Not enough data" shown where inputs are missing (GOL-007(2)). Two periods compared with one empty shows "not available" (GOL-009(2)). Chart text summary or table (UXD-009). |
| G1. Data-quality check | `DataQualityReport` with the owner's thresholds; release checklist item for GOL-011 | 0.50 | Tests for each criterion with pass and fail reason (GOL-012(2)). Evidence that no recommendation text exists (search and widget test). |
| G2. Integration and acceptance | Regression of WP 4 to 10 tests, accessibility pass, independent review, delivery record `docs/delivery-record/WP11.md` with the standard's progress section, owner acceptance | 0.50 | Full suite and coverage gate at or above 80 %; four workflows green; review findings resolved or accepted; owner acceptance recorded. |
| **Total** | | **7.00** | |

Dependencies between stages: A before everything; B, C and D1 can run in parallel after A; E needs B, C and D1 for its indicators; F needs B, C and D1; D2 needs WP 8 stage 3d; G1 needs the owner's thresholds; G2 last.

What can start before WP 8 is accepted: A, B, C, D1, E (without exercise goals), F (without per-muscle), G1. What waits: D2 and any per-muscle part of F.

## 10. Owner decisions required

| # | Decision | Options | Recommendation |
|---|---|---|---|
| 1 | Authorise WP 11 start, approve the section 9 breakdown, and settle scope. NUT-019 is in D06. TRN-027 screens and TRN-028 are only "proposed" in the WP 9 record. The 7.0 baseline may not include them. | (a) Approve as written; TRN-028 is built last and dropped if points run short. (b) Order an estimate review (standard section 6) that may raise the total. (c) Remove TRN-028 from WP 11. | (a), with D2 and TRN-028 marked as the first items to descope. State the choice in D04 section 7. |
| 2 | How to store GOL-003 direction and GOL-005 exercise goals. | (a) Derive direction at read time; defer exercise goals to the first schema version after v9. (b) Store goal details as JSON in `settings`. (c) Ask WP 8 or WP 17 to add `goals` columns inside v9. | (a). It needs no schema change and keeps WP 8 and WP 17 gates intact. Accept that a user who passes the target gets an "at target" state. |
| 3 | Add a `history()` read to `GoalRepository` (WP 4, closed) for GOL-006. | (a) Add a read-only method; no schema change. (b) Use only active rows and accept that GOL-006(1) is not met. | (a). Without it, past weeks are judged against today's target, which D04 forbids. |
| 4 | Sequencing against WP 8. | (a) Start A to F (non-muscle) now; D2 after stage 3d. (b) Wait for stage 3 acceptance. | (a). D06 requires WP 8 only for per-muscle figures. |
| 5 | Definition of nutrition adherence. D04 gives none. | (a) Share of logged days within plus or minus 10 % of target. (b) Plus or minus 5 %. (c) Show only days logged and averages; no adherence figure. | (c) for the first release; add (a) later if wanted. D04 states a 10 % tolerance only for macro energy (GOL-002), which is a different test. |
| 6 | Estimated 1RM formula for TRN-028 ("if applicable"). | (a) Epley. (b) Brzycki. (c) No 1RM; show top-set weight and volume only. | (c) until the owner chooses a formula. D04 names none. |
| 7 | One day and week boundary for the weekly report (OQ-18, still open). Nutrition and training use `dayStartHour`. Body uses the local calendar date. | (a) Apply `dayStartHour` to all three. (b) Keep each domain's rule and label it. | (b). It does not change accepted WP 10 behaviour. State the rule on screen. |
| 8 | Rate-of-change method for weight. | (a) Difference between first and last trend point in the window, divided by weeks. (b) Least-squares slope over daily means. | (a). It is easier to explain and check by hand. |
| 9 | PR rules for assisted and cardio sets (WP 9 requirements gap). | (a) Leave without PRs. (b) Define: assisted = most reps; cardio = longest duration or distance. | (a) for now. Decide with TRN-026 wording later. |
| 10 | GOL-012 thresholds and where the check shows (OQ-15). | Proposed: 28 days, food logged on 80 % of days, 90 % of energy verified or user-entered, weight on 3 days per week. Show: (a) developer or settings status only; (b) not shown. | Keep the proposed thresholds as written, show the result in a Settings status line, and ship no recommendation feature. The owner must sign the figures. |
| 11 | Does the NUT-019 badge change the closed WP 5 Fuel screens? | (a) Yes, in stage B. (b) Show it only on the new weekly summary. | (a). D06 allocates NUT-019 to WP 11 for daily and weekly totals. |
| 12 | Chart for GOL-010 with different units on one axis. | (a) Extend `RfTrendChart` with indexed or dual-axis series. (b) Three stacked charts that share one date axis. | (b). It needs no change to the design system and keeps UXD-009 text tables simple. |

## 11. Risks

| Risk | Effect | Mitigation |
|---|---|---|
| Scope that the 7.0 baseline may not cover (NUT-019, TRN-027 screens, TRN-028) | Overrun hidden by a fixed total | Decision 1. Report variance separately (standard section 6). |
| Target history not available | GOL-006 fails; past weeks look wrong | Decision 3. Test the GOL-006(1) example. |
| Per-muscle figures read the old single-primary model | Wrong figures once v8 connects; breaks OQ-19 | D2 waits for 3d. Use `attributeSetCounts`, not `VolumeRules.byMuscle`, for muscle figures. Show the notice. |
| WP 8 stage 3d changes the exercise port during WP 11 work | Rework | Build D1 against `WorkoutSessionRepository` only. Keep the exercise lookup behind one function. |
| Schema collision | A new column breaks WP 8's CI dump comparison | Section 6.2. No schema work in WP 11. |
| Slow queries on long histories | Weekly screens stall | Large-profile load test in D1. Indexed query before any cache. |
| Different day boundaries across domains | A late-night entry lands in different weeks in different sections | Decision 7. Label the rule. |
| Averages hide missing data | User sees a false picture; breaks GEN-006 | `Metric` type. Show days logged and "not enough data." |
| Descriptive text drifts into advice | Breaks GOL-011 | Fixed vocabulary for statements. Review checklist item in G2. |
| Chart accessibility | Fails UXD-009 | Data table or text summary for every chart; test at 320 dp. |
| Closed WP interfaces reopened (WP 4 goals, WP 5 Fuel screens) | Regression in accepted code | Each change named in decisions 3 and 11; regression run in G2. |
| Optional work in WP 17 changes log entries (S3b-ii, v9) | Analytics assumptions break | WP 11 reads only existing columns. |
