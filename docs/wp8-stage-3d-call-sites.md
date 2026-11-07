# WP 8 stage 3d: inventory of v7 exercise call sites (preparation)

- Status: **Inventory only.** It authorises no work. Stage 3d (adapt WP 8 and WP 9 code and screens) stays gated by `docs/wp8-delivery-plan.md` section 21 and `docs/wp8-stage-3c-3d-5-6-preparation.md` section 4. Nothing in `app/lib/` changes with this document.
- Date: 2026-11-07. Read against branch `campaign/wp8-3c`, base `391fe1b`. Line numbers are of that tree and move when the files change; re-run the greps in section 6 before use.
- Scope: every production call site (code under `app/lib/`, generated files and the isolated v8 zone excluded) of `ExerciseRepository`, of `Exercise.primaryMuscle`, `Exercise.secondaryMuscles` and `Exercise.archived`, and of the rest of the v7 exercise model that 3d adapts (`supplied`, `copiedFromId`, `equipment`, `aliases`).
- Regression net added with this document: `app/test/features/training/v7_exercise_characterisation_test.dart` (37 tests, tests only). Section 5 maps each rule to a test.
- Not decided here: when production switches to v8 (D-3d-1), how a blocked exercise is shown (C-2), the custom-copy choices (C-6), R-C3, the R-C8 wording (D-3d-2) and the order of WP 17 S4 and 3d (D-3d-4). The inventory marks where such a decision touches a site; it chooses nothing.

## 1. The v7 exercise model

| What | Where | Notes |
|---|---|---|
| `Exercise` value (freezed): `id`, `name`, `type`, `category`, `primaryMuscle` (one, required), `secondaryMuscles`, `equipment`, `aliases`, `supplied`, `copiedFromId`, `archived`, `createdAt`, `updatedAt` | `app/lib/domain/training/training.dart:80-109` (`isCustom` at :105, `searchKey` at :109) | 3d replaces `primaryMuscle` and `secondaryMuscles` with `targets`, `supplied` with `source`. |
| `MuscleGroup` (19 values, includes the non-anatomical `fullBody`), `Equipment`, `ExerciseCategory`, `ExerciseType` | `training.dart:9` (`ExerciseType`), `:21` (`ExerciseCategory`), `:25` (`MuscleGroup`), `:49` (`Equipment`) | The 19 ids are the WP 8 preserved muscle ids. |
| `ExerciseQuery` (text, category, muscle, availableEquipment, includeArchived) and the pure filter | `app/lib/domain/training/exercise_query.dart:9-112` | Muscle filter at :71-76 (primary or secondary); primary-first ordering at :99-111; archived at :67. |
| `validateExercise` | `app/lib/domain/training/training_validation.dart:79-121` | Primary not among secondary (:90-97); de-duplication of secondary and equipment (:113-119). |
| `VolumeRules.byMuscle` | `app/lib/domain/training/volume.dart:141-164` | Single primary at :151-152; each secondary separately at :153-155. The rule OQ-19 replaces. |
| Port `ExerciseRepository`: `watchAll({includeArchived})`, `watchLibrary(query)`, `search(query)`, `byId`, `exists`, `upsert`, `archive(id, archived:)`, `delete` | `app/lib/domain/training/training_repository.dart:6-31` | The v8 read side already implements it: `app/lib/data/repositories/v8/v8_exercise_read_port.dart:41` (unconnected). |
| v7 storage: table `Exercises` (`primary_muscle` text, `secondary_muscles_json`, `equipment_json`, `aliases_json`, `search_key`, `supplied`, `copied_from_id`, `archived`) | `app/lib/data/db/tables.dart:268-284` | Schema v7. |

## 2. Data layer

| File:line | What it reads or writes |
|---|---|
| `app/lib/data/repositories/drift_exercise_repository.dart:10` | The only production implementation of `ExerciseRepository` (class). |
| `:17-26` `watchAll` | Reads non-deleted rows; excludes `archived` unless `includeArchived` (:20-22); ordered by name in SQL. |
| `:29-40` `watchLibrary` | Reads non-deleted rows, `archived` excluded in SQL (:35-37), the rest filtered and ordered in Dart by `filterExercises` (:39). |
| `:43-44` `search` | One-shot of `watchLibrary`. |
| `:47-52` `byId` | Reads one non-deleted row, archived included. |
| `:55-60` `exists` | Reads id presence, deleted and archived included (used by the seed importer). |
| `:63-65` `upsert` | **Writes** the whole row (`insertOnConflictUpdate`). |
| `:68-79` `archive` | **Writes** `archived` and `updated_at` of a non-deleted row (TD-23). |
| `:82-91` `delete` | **Writes** `deleted_at` (soft delete). |
| `app/lib/data/mappers/training_mappers.dart:52-82` `exerciseToEntity` | Reads `primary_muscle`, `secondary_muscles_json` (:55-56), `supplied`, `copied_from_id`, `archived` (:76-78). A row with an identifier outside the taxonomy maps to null and the repository skips it (:50-51, :59-66). |
| `training_mappers.dart:84-102` `exerciseToRow` | **Writes** `primary_muscle` (:90), `secondary_muscles_json` (:91-93), `supplied`, `copied_from_id`, `archived` (:97-99). |
| `app/lib/data/db/app_database.dart:296-305` | v6 migration of `exercises` (`supplied` from `is_custom`). Historical; stays with v7. |
| `app/lib/data/db/app_database.dart:493` and `app/lib/data/db/migration/historical_steps.dart:360` | Quarantine of unreadable `exercises` rows in old migrations. Historical. |
| `app/lib/data/repositories/drift_backup_repository.dart:181` | Backup restore adapts a legacy `exercises` row with `is_custom`. Backup format 3 is stage 3b-7 work and is not touched here. |
| `app/lib/data/repositories/drift_settings_repository.dart:29,152-157` | `seedExercisesVersion` setting read and written by the seed importer; ADR-0009 replaces it by per-provider release records. |

## 3. Application layer (use cases and providers)

| File:line | Site | Reads | Writes |
|---|---|---|---|
| `app/lib/app/providers.dart:205-210` | `exerciseRepositoryProvider`: the production wiring of `DriftExerciseRepository` over `AppDatabase` (v7) | | Where D-3d-1 connects v8. |
| `app/lib/features/training/application/exercise_use_cases.dart:24` | `SaveCustomExercise.exercises` | `byId` (:56); `existing.supplied` (:61); `existing.type` | `upsert` (:104) of an `Exercise` built with `primaryMuscle` and `secondaryMuscles` (:88-101); keeps `archived` and `copiedFromId` of the existing row (:97-98). Requires a primary muscle, field `primary` (:49-53). |
| `exercise_use_cases.dart:123` | `CopySuppliedExercise.exercises` | `byId` (:140); `source.supplied` (:144); `source.primaryMuscle` and `secondaryMuscles` (:158-159) | `upsert` (:168) of a new custom exercise with `copiedFromId: source.id` (:162); `archived` is not copied. C-6 touches this site. |
| `exercise_use_cases.dart:183` | `ArchiveExercise.exercises` | | `archive` (:187). |
| `app/lib/features/training/application/import_exercise_library.dart:55` | `ImportExerciseLibrary.exercises` | `exists` (:78); `seedExercisesVersion` (:64) | `upsert` (:82). Parses `primaryMuscle` and `secondaryMuscles` from the seed file (:129-130), `supplied: true` (:132). Release 2 (stage 3c) supersedes it. |
| `app/lib/features/training/application/plan_use_cases.dart:26` | `SavePlan.exercises` | `byId` (:64); `exercise.archived` (:73): a newly added archived exercise is refused, one already in the plan is kept (TD-42); `exercise.type` (:84) | |
| `app/lib/features/training/application/plan_actions.dart:28` | `DuplicatePlan.exercises` | `byId` (:42): an exercise that no longer exists is dropped; archived ones are kept | |
| `plan_actions.dart:123` | `SaveSessionAsPlan.exercises` | `byId` (:149); `exercise.archived` (:153): archived or removed exercises are left out and named | |
| `app/lib/features/training/application/record_set.dart:48` | `RecordSet.exercises` | `byId` (:75); `exercise.archived` (:79) refuses with "An archived exercise cannot be used. Restore it first."; `exercise.type` | |
| `app/lib/features/training/application/session_use_cases.dart:130,150-161` | `_startWith` (shared by the two start use cases) | `byId` (:150); `exercise.archived` (:151): skipped with `StartWarning` (`archived` or `missing`, :156-158) | |
| `session_use_cases.dart:217` | `StartSessionFromPlan.exercises` | via `_startWith` | |
| `session_use_cases.dart:307` | `StartSessionFromPast.exercises` | via `_startWith` | |
| `session_use_cases.dart:523` and `:551-566` | `AddSessionExercise.exercises` and `_usable` | `byId` (:555); `exercise.archived` (:559) | |
| `session_use_cases.dart:628` and `:652` | `ReplaceSessionExercise.exercises` | `_usable` for the new exercise | |
| `session_use_cases.dart:747` and `:788-800` | `EditSet.exercises` | `byId` (:789); for a deleted exercise builds a placeholder `Exercise` with `primaryMuscle: MuscleGroup.fullBody` (:792-800) to validate by the set's type | |
| `app/lib/features/training/application/records_use_cases.dart:50` | `GetWeeklyVolume.exercises` | `byId` (:83) per exercise id of the sessions, passed to `VolumeRules.byWeek` (:87), which reads `primaryMuscle` and `secondaryMuscles`. No screen calls it today. | |
| `app/lib/features/training/application/session_view.dart:69` | `LoadSessionView.exercises` | `byId` (:109) into `SessionView.exercises`; screens read `name`, `type`, `archived` from it | |
| `session_view.dart:156` | `loadSessionViewProvider` wiring | | |
| `app/lib/features/training/application/training_providers.dart:22` | `exerciseLibraryProvider` | `watchLibrary(query)` | |
| `training_providers.dart:27,37,44,49,58,67,80,98,117,128,165,180,194,286` | Wiring of `exerciseRepositoryProvider` into `SaveCustomExercise` (:27), `CopySuppliedExercise` (:37), `ArchiveExercise` (:44), `RecordSet` (:49), `SavePlan` (:58), `DuplicatePlan` (:67), `SaveSessionAsPlan` (:80), `ImportExerciseLibrary` (:98), `StartSessionFromPlan` (:117), `StartSessionFromPast` (:128), `AddSessionExercise` (:165), `ReplaceSessionExercise` (:180), `EditSet` (:194), `GetWeeklyVolume` (:286) | | |
| `app/lib/features/training/application/exercise_library_providers.dart:58-69` | `exerciseByIdProvider` | `watchAll(includeArchived: true)` and picks the id (:61-67): archived exercises stay reachable for history and the detail screen | |
| `app/lib/main.dart:29,45-47` | Runs `importExerciseLibraryProvider` once at start | seed importer | `upsert` through the importer |

## 4. Screens (read-only consumers; 3d changes what they show, not what the use cases do)

| File:line | Reads | Notes |
|---|---|---|
| `app/lib/features/training/presentation/exercise_library_screen.dart:98-108` | Builds `ExerciseQuery` (text, category, muscle, available equipment, `includeArchived` from the "show archived" toggle) and watches `exerciseLibraryProvider` | Filters by muscle with node plus descendants after 3d. |
| `exercise_library_screen.dart:264-267` | `e.primaryMuscle`, `e.secondaryMuscles.contains(_muscle)`: the "secondary match" marker | |
| `exercise_library_screen.dart:294` | `muscleGroupLabel(e.primaryMuscle)` in the row meta line | |
| `exercise_library_screen.dart:319-325` | `ExerciseSourceBadge(e)` and the "Archived" caption (`e.archived`) | |
| `app/lib/features/training/presentation/exercise_picker.dart:36-40, 104-107` | `ExerciseQuery(text, category)` (archived excluded by default) and the subtitle `type · primaryMuscle` | Used by `session_screen.dart:116,127` and `plan_editor_screen.dart:166` (`pickExercise`). |
| `app/lib/features/training/presentation/exercise_detail_screen.dart:94-95` | `exerciseByIdProvider` | |
| `exercise_detail_screen.dart:46-79` | `e.supplied`: "Edit creates your copy" flow | C-6. |
| `exercise_detail_screen.dart:81-90, 129, 173-190` | `e.archived`: archive and unarchive action (custom exercises only), "Archived" label | R-C8 (retired versus archived) touches this site. |
| `exercise_detail_screen.dart:145-156` | `primaryMuscle` and `secondaryMuscles` fields | |
| `exercise_detail_screen.dart:232-250` | `e.supplied`, `e.copiedFromId`, original name via `exerciseByIdProvider` | |
| `app/lib/features/training/presentation/exercise_editor_screen.dart:65-75` | `_seed`: `e.primaryMuscle`, `e.secondaryMuscles` | The editor requires one primary after 3d (at least one primary target). |
| `exercise_editor_screen.dart:162-197` | Calls `copySuppliedExerciseProvider` or `saveCustomExerciseProvider` with `primaryMuscle` and `secondaryMuscles` | **Writes** through the use cases. |
| `exercise_editor_screen.dart:231-249, 266-268` | `exerciseByIdProvider`, `e.supplied != _isCopy` guard, `exerciseHasHistoryProvider` (type lock) | |
| `exercise_editor_screen.dart:105-130, 413` | Secondary muscle chips and their error field `secondaryMuscles` | |
| `app/lib/features/training/presentation/source_badge.dart:15` | `exercise.supplied` | `source` after 3d. |
| `app/lib/features/training/presentation/session_screen.dart:501-502` | `view.exercises[entry.exerciseId]` name | |
| `session_screen.dart:622-633` | Deleted exercise note; `exercise.archived`: "This exercise is archived. Restore it to log more sets." and no set row | C-2 (blocked exercise on the unchanged WP 9 port) touches this site. |
| `app/lib/features/training/presentation/session_starter.dart:154-158` | `StartSkipReason.archived` and `missing` texts | |
| `session_screen.dart:443` | `StartWarning` list shown after starting | |
| `app/lib/features/training/presentation/plan_editor_screen.dart:278-282, 335-342` | `exerciseByIdProvider(...).value`; `ex.archived && !_originalExerciseIds.contains(...)` marks the row that caused an archived error | Mirrors `SavePlan` (TD-42). |
| `plan_editor_screen.dart:485-487, 615-621` | Name, type and "Archived" suffix of a plan row | |
| `app/lib/features/training/presentation/session_detail_screen.dart:276` | `view.exercises[...]?.name ?? 'Removed exercise'` | |

## 5. Rules to preserve, and the test that pins each

| Rule (v7 behaviour) | Pinned by (in `v7_exercise_characterisation_test.dart`, or an existing test) |
|---|---|
| The `Exercise` field list and defaults (the shape 3d replaces) | "the v7 Exercise value" group |
| The seed holds 89 supplied active exercises with one primary each; counts by primary muscle and by category; 162 secondary entries; named rows (`lib-back-squat`, `lib-inverted-row`, `lib-skipping` with a `fullBody` secondary) | "the bundled v7 library as imported at first start" |
| Import is once; a removed exercise stays removed | same group (and `import_exercise_library_test.dart`) |
| Picker order, muscle filter (primary matches first, then secondary), `fullBody` filterable, equipment subset and bodyweight-only, text over name and aliases, category, intersection, stream = search = pure filter, the providers the screens watch | "selection (library, picker, filters)" (and `exercise_library_test.dart`, `available_equipment_test.dart`) |
| Archived leaves default lists and pickers but stays reachable by id, history and the detail provider; deleted is never listed but its id exists | "archived handling" |
| `SavePlan` refuses a newly added archived exercise and keeps one already listed (TD-42) | same group (and `training_use_cases_test.dart`) |
| Start from a plan skips archived and deleted exercises with a warning of the right reason | same group (and `session_use_cases_test.dart`) |
| Add, replace and record refuse an archived exercise with one message and field | same group |
| Editing a set of an archived exercise works; a deleted exercise is validated by the set's type | same group |
| Save a workout as a plan leaves out archived and removed exercises and names them | same group |
| Copy does not carry `archived`; editing an archived custom exercise keeps it archived | same group |
| Primary required (field `primary`); primary not among secondary (field `secondaryMuscles`); duplicates collapse in order; lists survive storage in order; unknown identifiers are skipped, not guessed; copy keeps source muscles unless the edit gives its own; supplied cannot be edited, only supplied is copied | "the muscle fields" |
| Per-muscle volume: full for the single primary, separately for each secondary, warm-ups and uncompleted sets excluded, unknown exercises not attributed, bodyweight sets add repetitions only | "per-muscle volume today" (and `volume_test.dart`) |

Where 3d changes behaviour on purpose, the pinned test is changed in the same commit with a note naming the decision: the muscle fields (targets), `supplied` (`source`), the per-muscle volume rule (OQ-19, the only WP 9 volume change in plan section 8) and, after the owner's R-C8 decision is implemented, archived versus retired in pickers. Every other pinned behaviour stays as it is.

## 6. How the inventory was produced

Run from `app/`; generated files and the isolated v8 zone are excluded:

```
grep -rn "ExerciseRepository\b" lib --include=*.dart
grep -rn "primaryMuscle\|secondaryMuscles" lib --include=*.dart
grep -rn "\.archived\|archived:" lib --include=*.dart
grep -rn "exerciseRepositoryProvider\|\.supplied\|copiedFromId\|exerciseByIdProvider" lib --include=*.dart
```

Excluded on purpose: `lib/data/db/v8/**`, `lib/data/repositories/v8/**` (the unconnected v8 zone, including `v8_exercise_read_port.dart`, whose behaviour is tested against v7 by `test/data/repositories/v8/wp9_start_from_plan_contract_test.dart`), `lib/domain/library/**` (3a domain), and `lib/data/db/migration/v7_to_v8.dart` (stage 3b-4 migration).
