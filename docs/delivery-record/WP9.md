# Delivery record — WP 9: Workout planning and workout execution

Date: 2026-11-05
Branch: `ccr-9fda2c32-wr163b`
Status: **in progress, stages 1, 2 and 3a built** (started by owner instruction on 2026-11-05. WP 8, its dependency, is delivered and awaiting owner acceptance; its decisions 1–5 are open. WP 6 device verification and D05 V-01 stay open and owner-owned.)

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
| OQ-02 imperial units | Loads are entered and shown in kg only; no pound entry or display is added (GEN-003 metric default). | Yes |
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
| Stage | Commit | Content |
|---|---|---|
| 1 — domain, schema v7, use cases (no UI) | ebff8d0 | set kind; session exercise entries with notes; start, finish, edit and delete session use cases; personal-record and volume rules; scheduled workouts; rest-timer rules and settings; TD-42; schema v7 (additive); providers. CI 42003487020, Android 42003486896, iOS 42003486889, integration 42003486856 — all success. |
| 2 — screens for plans, splits and scheduling | eb2485e | plan list with archive and restore; plan builder with exercise picker, reorder by drag and by buttons, TD-42 errors, unsaved-changes guard; split editor; schedule screen (8 weeks by date; schedule by date, weekdays or split; move and skip); routes; widget tests. CI 42009074987, Android 42009075284, iOS 42009074969, integration 42009075205 — all success. |
| Stage 1 review fixes | 66a2a00 | F1–F10, N1–N3 (see Independent review). CI 42013923681, Android 42013923697, iOS 42013923648, integration 42013923649 — all success. |
| 3a — session screen, rest timer UI, history UI | (this commit) | session screen (entries with notes, pre-filled next-set row, set kind, exertion, rest, edit and delete sets, add/remove/replace/reorder exercises, finish); rest timer panel (wall clock, pause, +15 s, skip, foreground alert behind `RestAlert`); PR badges; volume per exercise and session; start from empty, plan, scheduled occurrence and past session; history list (20 then more), workout detail, edit details, delete with Undo; settings for default rest and the notification preference; routes; widget tests. No plugin or platform notification code (stage 3b, ADR-0007). |

### Stage 1 — domain, schema v7, use cases (no UI)
- **TRN-019 set kind**: `SetKind` warm-up / working / failure on `SessionSet`, stored in `session_sets.set_kind` (existing rows `working`); `RecordSet` and `EditSet` take it.
- **TRN-017/023 session exercises**: `session_exercises` (ordered entries with a note of at most 4000 characters), created by the migration from each session's distinct (exercise order, exercise) of its sets. Sets link to their entry (`session_exercise_id`); `position` is authoritative and `exercise_order` mirrors it. Use cases `AddSessionExercise`, `RemoveSessionExercise`, `ReplaceSessionExercise`, `ReorderSessionExercises`, `SetSessionExerciseNote`, `SetSessionNote`.
- **TRN-016/024 sessions**: `StartEmptySession`, `StartSessionFromPlan` (pre-fill returned as data: plan targets and `lastPerformance`; no set stored), `StartSessionFromPast`, `FinishSession`, `EditSessionDetails`, `EditSet`, `DeleteSet`, `DeleteSession` (soft delete) and `RestoreSession`.
- **TRN-026 / TRN-027** pure rules `personal_records.dart` and `volume.dart`, derived from history and never stored; use cases `GetExerciseRecords`, `GetWeeklyVolume`.
- **TRN-015 scheduling**: `scheduled_workouts` rows; `ScheduleOnDate`, `ScheduleWeekdays`, `ScheduleSplitCycle`, `MoveScheduledWorkout`, `SkipScheduledWorkout`, `ScheduledWorkoutsInRange`; starting from a plan links the occurrence to the session.
- **TRN-021** pure `RestTimer` (wall-clock end); settings `defaultRestSeconds` (90) and `restTimerNotifications` (off). The notification itself and the alert are stage 2 or later (UI and platform).
- **TD-42** resolved: `SavePlan` refuses only newly added archived exercises.
- **Schema v7** is additive (see `docs/data-model.md`, Migrations 6 → 7); the v6 migration, the legacy taxonomy mapping and `legacy_quarantine` are unchanged in behaviour (the one edit to the v5 → v6 step lists the two new `session_sets` columns in `newColumns`, because drift copies into the current table shape). Pre-v7 backups restore with entries created by the same backfill.

Assumptions and decisions for the owner to confirm (none touches WP 8 decisions 1–5):
1. **Archived or deleted exercise when starting from a plan or past session**: skipped with a reported warning, the session still starts, the plan is unchanged. (Alternative: refuse.)
2. **Several entries per exercise are allowed** (review F1; the owner never decided a one-entry rule): adding an exercise already in the session makes a second entry, a plan listing an exercise twice starts a session with both, and sets are recorded against an entry id. Replacing an entry with the exercise it already holds is refused; recorded sets of a replaced exercise stay with the original entry and the new exercise gets a new entry right after it (an entry with no sets is changed in place).
3. **Note limit 4000 characters** for session, exercise and set notes (TRN-023 asks for at least 2000).
4. **PR definitions**: weighted = heaviest at each exact rep count 1–12; bodyweight = most reps and timed = longest duration, both ignoring any added load; assisted and cardio have **no PR** (D04 defines none, recorded as a gap, nothing invented). The first set in a slot is a PR; ties are not. The older `TrainingRules.isPersonalRecord` and `volumeKg` remain but are not used by the app.
5. **Volume**: bodyweight added load is not kg volume (D04 TRN-027(2)); a session counts in the week of its start (set times are not stored); secondary muscle volume is reported separately and never added to primary.
6. **Delete**: a session delete is soft and restorable any time (no purge exists); deleting a set or an exercise entry removes the rows (the confirmation is the screen's); deleting a session puts its linked scheduled occurrence back to planned and keeps the session id on it; restoring the session re-links only that occurrence, while it is still planned and still carries that id (review F10, N1, N2).
7. **Scheduling**: duplicate rule by (plan, source date, origin), skipped and moved occurrences are not regenerated by weekday or split generation; scheduling on a date is refused only when the plan has a planned or done occurrence there; only a planned occurrence can be moved or skipped and only a skipped one restored; the same plan cannot be planned twice on one date; archived plans cannot be scheduled or started.
8. **Backup**: `formatVersion` is 2 (review F10), `schemaVersion` in the file is 7; restore accepts format 1 and 2. The WP 8 app refuses format 2 (it refuses anything above 1).
9. **Entry ids** created by the backfill are `legacy:<session>:<position>`; ids made by the app are UUIDs.

Local gate for stage 1: `dart format` clean, `flutter analyze --fatal-infos` clean, 1005 tests pass, coverage gate 90.9 % (minimum 80 %). CI is run at commit.

### Stage 2 — screens for plans, splits and scheduling
- **Routes** (Train tab, entered from two buttons on the library header, library screens otherwise unchanged): `/train/plans` (plans and splits list), `/train/plans/new`, `/train/plans/:id` (plan builder), `/train/splits/new`, `/train/splits/:id` (split editor), `/train/schedule`.
- **Plan list (TRN-013)**: non-archived plans, archive and restore (`ArchivePlan`), create; the splits are listed on the same screen.
- **Plan builder (TRN-013)**: name; exercises chosen in a searchable picker (archived exercises hidden); per exercise sets, rep range (weighted, bodyweight, assisted), duration as mm:ss through `parseDuration` (timed, distance, cardio), distance in metres (distance, cardio), optional load through `LoadKg.of` (all but distance and cardio) and rest seconds. Reorder by drag handle and by `plan-move-up-<i>` / `plan-move-down-<i>`. Errors from `SavePlan` (including the TD-42 archived-exercise refusal) show next to the field or on the exercise row; leaving with unsaved changes asks first.
- **Split editor (TRN-014)**: name, 1 to 14 days, each a workout or a rest day, saved by `SaveSplit`.
- **Schedule (TRN-015)**: scheduled workouts of the next 8 weeks grouped by date (earlier and later 8-week pages); schedule a workout on a date, on weekdays or from a split cycle; move (date picker) and skip (after a confirmation). Use-case errors show in the sheet next to the field, or in a snackbar for move and skip.

Assumptions and decisions for the owner to confirm (none touches WP 8 decisions 1–5):
1. **Load unit**: a target load is typed in kg whatever the unit setting (the field says kg), because `LoadKg.of` only accepts 0.25 kg steps and a typed pound value would be rejected or rounded. Pound entry and display depend on OQ-02 (open); not added in WP 9.
2. **Plans keep their weekdays and split**: the builder does not edit `scheduledWeekdays` or `split`; saving an existing plan passes the stored values back to `SavePlan`, so they are preserved.
3. **A plan needs at least one exercise in the screen** (`SavePlan` itself allows none); this is the only rule checked in the screen rather than by a use case. Empty rep fields mean no rep target; the rest field empty means the default rest.
4. **Field to row mapping**: `SavePlan` reports the first failing exercise by field only, so the screen finds the row by validating each row with `validatePlanExercise`; the rep-range message shows once, under "Reps to".
5. **Splits cannot be deleted or archived** from the screens: no use case exists and none was added. A new split starts as 7 rest days.
6. **Today** for the schedule is the diary day (`dayStartHour` applied), the same as the diary; dates are local calendar dates. The weekday chips follow `weekStartDay`.
7. **Skip can be undone** (review F3): skipping asks for confirmation; a skipped occurrence shows a Restore button (`UnskipScheduledWorkout`), a done occurrence shows no actions.
8. **Wiring added in `lib/features/training/application`** (new files only, nothing in stage 1 files changed): `archive_plan.dart` (`ArchivePlan`, there was no use case to archive a plan) and `plan_providers.dart` (plan, split and schedule read providers, so screens never touch a repository).
9. **Drag reorder** is started from a handle (no long-press), so scrolling the list is not hijacked; the buttons are the accessible path.

Local gate for stage 2: `dart format` clean, `flutter analyze --fatal-infos` clean, 1034 tests pass (29 added: plan list, plan builder, split editor, schedule, route resolution, narrow width and 1.3x text), coverage gate 91.3 % (minimum 80 %). CI is run at commit.

### Stage 3a — session screen, rest timer UI, history UI
- **Routes**: `/train/session/:id` (session screen; also opens finished sessions to correct sets), `/train/history` (history list), `/train/history/:id` (workout detail). Links: Train tab (`start-empty-session`, `open-history`, and a `continue-session` card while a workout is unfinished), plans list (`plan-start-<planId>`), schedule rows (`schedule-start-<occurrenceId>`, links the occurrence), history rows and detail (`history-repeat-<id>`, `detail-repeat`).
- **Session screen (TRN-016..021, TRN-023, TRN-024, TRN-026, TRN-027)**: ordered entries with notes; each entry shows `Plan: ...` and `Last: 80 kg × 5` hints, its logged sets (kind, exertion, rest, note, PR badge, edit, delete) and one pre-filled next-set row with a `Log set` button. Confirming a correct pre-filled set is one tap (test counts it). Editing a set opens a sheet whose first field has focus with a numeric keyboard. Entries: add, replace, remove (confirmation when it has sets), move up/down, note. Session note, edit details (name, start, length), finish.
- **Rest timer (TRN-021, TRN-022(1))**: `RestTimerController` (Riverpod notifier over the pure `RestTimer`) starts when a set is confirmed, from the set's rest, else the plan row's rest, else `defaultRestSeconds`; pause, resume, +15 s, skip; time derives from the injected clock. The foreground alert is the domain interface `RestAlert` (`lib/domain/training/rest_alert.dart`); the default `HapticRestAlert` uses `HapticFeedback` and `SystemSound` only. No plugin, no platform code.
- **History (TRN-024, TRN-025)**: newest first, 20 per page, more on scroll and through a `Show more` button; detail with notes, set kinds, exertion, PR badges and volume; delete asks, then an Undo snackbar of 12 s (`persist: false`, because Flutter keeps snackbars that have an action until dismissed); Undo calls `RestoreSession`. The exercise detail history now shows set kind and PR badges.
- **Settings**: `default-rest` field (0 to 3600 s, validated by `SaveSettings`) and a `rest-notifications-switch` that only persists `restTimerNotifications` (labelled so; permission and scheduling are stage 3b).
- **New application code** (no new write use case was needed; every write goes through a stage 1 use case): `LoadSessionView` (read use case: session, exercises, per-entry pre-fill, PR set ids), providers `sessionViewProvider`, `sessionHistoryProvider`, `activeSessionProvider`, `exerciseRecordSetIdsProvider`, `startWarningsProvider`, `restTimerProvider`, `restAlertProvider`.
- **Stable keys for the stage 3b integration test**: `plan-start-<planId>`, `start-empty-session`, `add-exercise`, `picker-exercise-<exerciseId>`, `newset-<entryId>-load|reps|duration|metres|hr|exertion|rest|note`, `newset-<entryId>-kind-warmUp|working|failure`, `newset-details-<entryId>`, `newset-log-<entryId>`, `set-<setId>`, `set-text-<setId>`, `set-edit-<setId>`, `set-delete-<setId>`, `delete-set-confirm`, `editset-load|reps|...`, `editset-save`, `pr-badge-<setId>`, `entry-volume-<entryId>`, `session-volume`, `prev-hint-<entryId>`, `rest-timer-panel`, `rest-remaining`, `rest-pause`, `rest-resume`, `rest-extend`, `rest-skip`, `finish-session`, `detail-title`, `history-session-<id>`, `detail-delete`, `delete-session-confirm`, `session-deleted-snackbar`, `default-rest`, `save-default-rest`, `rest-notifications-switch`.

Assumptions and decisions for the owner to confirm (none touches WP 8 decisions 1–5):
1. **Tap count**: with a pre-filled row, logging a set is **1 tap** (`Log set`); TRN-018(1) allows 2 and D06 allows 3. The widget test `a pre-filled set is confirmed in at most 2 taps` counts taps through a helper and asserts 1. The numeric keyboard "opens automatically on the weight field" is implemented for the edit-set sheet (first field autofocus). The inline next-set row does not autofocus, so a screen with several exercises does not open the keyboard unasked; tapping its weight field opens the same numeric keyboard.
2. **Pre-fill order**: the entry's last non-warm-up set, else the set at the same position in the previous session with the exercise (the last one when it had fewer), else the plan row (low end of the rep range, target load). The previous session is the most recent other, non-deleted session that started no later than this one. A plan row maps to entries by order: the k-th entry of an exercise takes the k-th plan row of it.
3. **Kg only**: loads are typed in kg through `LoadKg.of` (strict, 0.25 kg steps, never rounded) and the session screens always display kg, whatever the units setting (OQ-02 open). The older exercise-detail history keeps using the units setting.
4. **Exertion**: a new set uses the settings scale; a set that has an exertion keeps its scale on edit (the sheet shows the stored scale). The screen only turns text into numbers; `TrainingRules.validExertion` is applied by `RecordSet` and `EditSet`, so an out-of-range value (RPE 11) is refused with the use-case message and nothing is stored. The settings screen note still says RIR 0 to 10 while the rule is 0 to 5 (WP 3 text, left unchanged here).
5. **Inline row details**: kind, exertion, rest and set note are behind a `Type, effort, rest` toggle so the common path stays one tap; a validation error in those fields opens the toggle. Cardio energy cannot be entered in the session screen (the WP 8 library had no entry screen either); duration, distance and average heart rate can.
6. **Rest timer**: starts for every confirmed set including warm-ups; a rest of 0 s starts no timer; at 0 s the panel reads `Rest over` (with how long ago it ended when seen late) until skipped or the next set; `+15 s` on a finished timer restarts it. There is one timer for the app, so a new confirmed set replaces a running one. Finishing a session skips the timer. A one-shot timer fires the alert promptly and the panel's one-second tick covers a late wake-up; neither is needed for correctness of the displayed time.
7. **Reorder** is by up and down buttons (accessible path), no drag in the session screen. **Add exercise** reuses the stage 2 picker, which hides archived exercises. An archived exercise already in a session shows a note instead of the set row; a deleted one shows `Removed exercise`.
8. **Finish** is one tap with no confirmation and opens the workout summary; a finished workout can be reopened with `Edit sets` (sets can also be added). A session with no sets can be finished.
9. **Undo window** 12 s (`sessionUndoWindow`), above the 10 s requirement. The Undo callback holds the `RestoreSession` use case taken before the screen closes, so it works after navigation. Deleting is only offered on the workout detail screen, not in the list.
10. **Edit details** takes name, start date, start time and length in whole minutes (empty = in progress); the end time is start plus length. Validation (name, end not before start) is `EditSessionDetails`.
11. **History paging** uses the live session stream with a growing limit (20, 40, ...), so changes show at once; sessions with the same start time follow the repository order.
12. **Start warnings** (archived or deleted exercise left out) are held in a provider by session id and shown on the session screen until dismissed; they are lost when the app restarts.
13. **Settings default rest** is a text field with its own save button (0 to 3600 s, whole seconds); the notification switch saves at once and is labelled as saving the choice only.
14. **Exercise history** (WP 8 detail) shows set kind text and PR badges; that is the only change to the WP 8 library screens besides the Train tab links (start, history, continue card).
15. **Not done in this stage**: background notification, permission request, plugin and manifest changes, `RestAlertScheduler` (stage 3b, ADR-0007); integration test (stage 3b); manual device check of the haptic alert; drag reorder; per-muscle and weekly volume on a screen (`GetWeeklyVolume` exists, no screen asks for it in TRN-027's session and history items; weekly figures belong with WP 11).

Local gate for stage 3a: `dart format` clean, `flutter analyze --fatal-infos` clean, 1108 tests pass (49 added: session screen, history and detail, full flow, settings, layout at 360x690 and 1.3x text, defaults and form parsing, rest controller and alert, session view, routes), coverage gate 91.5 % (minimum 80 %). CI is run at commit.

### Gaps found at stage 3a (owner decision or allocation needed at delivery)
- **TRN-018(2)** numeric keyboard on the weight field: the edit-set sheet focuses the weight field with a numeric keyboard; the inline next-set row does not autofocus, so the keyboard does not cover a multi-exercise screen unasked. Pre-filled sets need no typing (one tap).
- **TRN-027** volume per muscle group and per week: rules and `GetWeeklyVolume` exist and are tested; no screen shows them (D06 WP 9 names "volume per session"). Proposed for WP 11 with TRN-028.
- **TRN-007** cardio energy: stored and validated since WP 8, but the session screen offers no entry field.
- The settings help text said RIR 0–10 (WP 3); corrected to the TRN-020 rule in this commit.

## Independent review
### Stage 1 (fresh reviewer, range 034ec8b..ebff8d0, code read and probe tests)
No high findings. Schema v7, backfill, backup, write-path validation, PR, volume and rest-timer rules verified by probes.

| ID | Finding | Severity | Resolution |
|---|---|---|---|
| F1 | A plan with the same exercise twice starts a session with the second occurrence silently dropped (assumption 2) | Medium | Fixed (product decision: no one-entry-per-exercise rule). A session may hold an exercise in several entries; `RecordSet` records against `sessionExerciseId` and validates against that entry's exercise; add and replace no longer refuse a present exercise (replace still refuses the same exercise); start-from-plan keeps every plan row with its own targets and pre-fill; start-from-past copies every entry. Tests: `review_fixes_test.dart` group F1 |
| F2 | `EditSet` replaces every field: omitted kind becomes working (changes PRs and volume); exertion, rest and note cleared; exertion scale can change on edit (TRN-020(2)) | Medium | Fixed. `EditSet` arguments are optional and null keeps the stored value (data, completed, kind, exertion, rest, note); `clearExertion`, `clearRest`, `clearNote` remove; a value with its clear flag is refused. A different exertion scale on a set that has one is refused (TRN-020(2)), same-scale changes allowed. Tests: group F2 |
| F3 | A skipped dated occurrence blocks scheduling the plan on that date again, yet a weekday schedule creates it; message contradicts the doc comment; no un-skip | Medium | Fixed. `ScheduleOnDate` refuses only a planned or done occurrence of the plan on that date (message says so); a skipped one does not block. New `UnskipScheduledWorkout` (skipped to planned, refused if the date is now planned or done) and a Restore button on skipped rows. Tests: group F3, schedule screen widget test |
| F4 | Schedule generation writes many rows without a transaction | Low | Fixed. `ScheduleWeekdays` and `ScheduleSplitCycle` write all rows inside the `Transactor` (new required `transactor` argument). Tests: failing repository injected on the 3rd and 5th write, nothing stored |
| F5 | `scheduleDate` takes the UTC date of a UTC instant, not the local date | Low | Fixed. `scheduleDate` converts a UTC value to local time first. Tests: group F5 (compares with `toLocal()`; on a UTC machine the old code agrees, so the failing run used `TZ=Pacific/Auckland`) |
| F6 | Weekly volume range not aligned to week boundaries | Low | Fixed. `GetWeeklyVolume` widens `from` and `to` to whole weeks (`VolumeRules.weekStart` with `weekStartDay` and `dayStartHour`); a range ending exactly on a week start adds no week. Tests: group F6 |
| F7 | PR tie between sessions with equal start time broken by random id | Low | Fixed. `PerformedSet` carries the session `createdAt`; order is start, creation time, session id, exercise order, set order (repository query and rule). Tests: group F7 (ids sort against creation order) |
| F8 | Backfill merges the same exercise at two orders into one entry | Low | Fixed (affects only devices not yet on v7). One entry per (session, `exercise_order`, exercise) group, never merged across orders; A@0, B@1, A@2 gives three entries in order; the join to an existing entry was removed. Stored `exercise_order` still untouched; idempotent. Tests: `migration_v7_test` and a v6 backup restore test |
| F9 | Exercise history carries no session or entry notes (TRN-023(2)) | Low | Fixed. `ExerciseSessionHistory` has `sessionNote` and `entryNotes` (this exercise's entries, session order); the exercise detail history shows them under the session heading. Set notes are not shown there (they were not before). Tests: group F9, widget test |
| F10 | Backup `formatVersion` 1 lets a v6 app restore a v7 file and silently drop set kinds, entry notes and schedules; a done occurrence whose session is deleted cannot be started again | Low | Fixed. `formatVersion` is now 2 (restore accepts 1 and 2). The WP 8 app (b1ab45a) refuses any `formatVersion` above 1, so it does refuse a version 2 file; see data-model.md. `DeleteSession` sets a linked occurrence from done back to planned in one transaction and keeps the session id as the released link; `RestoreSession` re-links only that occurrence while it is still planned and carries the id (corrected after re-verification N1/N2). Tests: group F10 (incl. N1, N2), backup tests |

### Re-verification of the stage 1 fixes (same reviewer, code read and probe tests)
F1–F9 resolved; F10 partly resolved, completed as below. Targeted suites (157 tests) and the stage 2 and WP 8 screen tests pass, also under `TZ=Pacific/Auckland` and `TZ=America/Los_Angeles`.

| ID | Finding | Severity | Resolution |
|---|---|---|---|
| N1 | Undo re-linked by "planned on the session's start date": an occurrence started a day late stayed planned after delete-and-undo, so it could be started twice | Low | Fixed: delete keeps the session id on the released occurrence; restore re-links only that one. Test N1 (failed on the previous code) |
| N2 | Undo of a session started without an occurrence marked an unrelated planned occurrence on that date done | Low | Fixed by the same change. Test N2 (failed on the previous code) |
| N3 | Stale statements in data-model.md (RecordSet joins by exercise; PR order without creation time; occurrence stays done; "foreign keys stay on") | Low | Fixed |
| N4 | `clearExertion` followed by a value on the other scale succeeds (two explicit user actions) | Low | Accepted: an explicit clear then a new entry is a new recording under TRN-020(2); recorded for owner awareness |

F5's regression test cannot fail under CI's UTC time zone; it was shown failing on the old code under `TZ=Pacific/Auckland`. The fix tests were run locally under that zone at this commit.

Local gate for the stage 1 review fixes: `dart format` clean, `flutter analyze --fatal-infos` clean, 1059 tests pass, coverage 91.4 %; fix and schedule tests also pass under `TZ=Pacific/Auckland`.


## Tests, CI
Appended at delivery.
