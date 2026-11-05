# Delivery record — WP 9: Workout planning and workout execution

Date: 2026-11-05
Branch: `ccr-9fda2c32-wr163b`
Status: **in progress** (started by owner instruction on 2026-11-05. WP 8, its dependency, is delivered and awaiting owner acceptance; its decisions 1–5 are open. WP 6 device verification and D05 V-01 stay open and owner-owned.)

## Scope (D06 WP 9)
Plan builder, scheduling, session screen with per-set weight/reps/RPE or RIR, rest timer with local notification, previous-performance hints, personal records, volume per session, notes, history.
Acceptance (D06): logging a set takes ≤ 3 interactions; PRs detected per exercise and type; rest timer fires in background on Android and when the app is foregrounded on iOS (documented limitation).
Verification (D06): unit tests for PR and volume rules; integration test for a full session; manual device test for the timer (deferred to the owner's end-to-end and device campaign, by owner instruction).
Requirements: D04 TRN-013 (screens), TRN-014 (screens), TRN-015..027; PLT-007/PLT-008 for the rest-timer notification only.
Debt owned here: TD-42 (plan re-save with a later-archived exercise).

## Constraints from WP 8 (owner decisions still open)
WP 9 builds on the WP 8 implementation and must not settle WP 8 decisions 1–5 by implication:
1. **Taxonomy** — use the enums by identifier only; add, rename or remove no category, muscle group or equipment item; no logic keyed on labels.
2. **OQ-09 library source** — do not change the seed asset or the import.
3. **Legacy-data policy** — do not change the v6 migration, the M4 mapping or `legacy_quarantine`. Any schema v7 change is additive and reinterprets no existing value.
4. **TRN-020 exertion rule** — validate only through `TrainingRules.validExertion`, so the owner's decision changes one function.
5. **UI scope** — WP 9 adds the plan, schedule and session screens; it does not rework the WP 8 library screens beyond links into them.

## Open questions this package touches (not decided here)
| Question | WP 9 handling | Owner decision needed |
|---|---|---|
| OQ-05 rest-timer alert in background or locked | Follows D06 acceptance: Android background notification, iOS foreground alert with documented limitation; notifications off until the user opts in (PLT-007). Plugin choice in a proposed ADR. | Yes |
| OQ-12 default exertion scale | Keeps the existing setting (default RPE since WP 3) and per-set stored scale; changes no default. | Yes |
| OQ-18 day boundary and week start | Uses the existing settings (`dayStartHour`, `weekStartDay`, default Monday as TRN-027 states); changes no default. | Yes |
| TRN-028 progressive overload charts (P2) | Not in D06 WP 9 scope; no allocation in D06. Proposed for WP 11 (progress visualisation). | Allocation |

## Gap analysis against WP 8
| Requirement | WP 8 state | WP 9 change |
|---|---|---|
| TRN-013 plan builder, reorder by drag or move controls | model, validation, `reorder` | plan builder screen; TD-42 rule |
| TRN-014 split | model, `SaveSplit` | split editor screen |
| TRN-015 schedule by date, weekday, split cycle; move or skip without changing the plan | `scheduledWeekdays` on plan only | dated scheduled workouts (8 weeks), move, skip |
| TRN-016 start from plan (pre-filled with previous weights), past session or empty | none | start-session use cases |
| TRN-017 add, remove, replace, reorder exercises in a session | order stored per set only | session exercise entries; replace keeps recorded sets with the original |
| TRN-018 confirm a pre-filled set in ≤ 2 taps; numeric keyboard on weight | `RecordSet` | session screen |
| TRN-019 warm-up / working / failure per set | missing | set kind stored per set |
| TRN-020 scale from settings for new entries | setting and per-set scale exist | session screen uses them |
| TRN-021/022 rest timer: planned or default 90 s, pause, +15 s, skip; alert | rest stored per set/plan | timer rules, settings default, alert and opt-in notification |
| TRN-023 notes on session and each session exercise (≥ 2000 characters), shown in histories | session notes, per-set note | per-exercise notes |
| TRN-024 edit and delete past sessions, exercises, sets; delete undoable ≥ 10 s | none | edit/delete use cases, undo |
| TRN-025 history by session, 20 then more on scroll | query and detail screen (WP 8) | notes and set kinds in history |
| TRN-026 PRs per exercise and type, removed when no longer best | none | pure PR rules, PR indicator |
| TRN-027 volume per exercise, session, muscle group, week | none | pure volume rules |

## Decisions (proposed; owner confirmation requested at delivery)
1. **PRs are derived, not stored**: computed from recorded working and failure sets, so an edit or delete always updates them (TRN-024(1), TRN-026(3)).
2. **Scheduled workouts are stored as dated rows** generated for 8 weeks, so moving or skipping one never changes the plan (TRN-015(2)).
3. **Rest timer runs on wall-clock end time**, so it survives the app being backgrounded; correctness never depends on a background task (PLT-008(2)).

## What was built
Appended per stage.

## Independent review
Appended after review.

## Tests, CI
Appended at delivery.
