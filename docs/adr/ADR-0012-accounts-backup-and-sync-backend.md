# ADR-0012: Accounts, backup and sync backend

- Status: **Proposed — owner decision required.** Nothing in this record is authorised. The Decision section is empty until the owner fills it.
- Date: 2026-11-07 (proposed)
- Work package: WP 12 (optional, 4 points allocated, 0 earned; `docs/governance/effort-points-and-progress-reporting.md` line 31)
- Related: ADR-0004, ADR-0005, ADR-0011; D04 DAT-009 to DAT-013, GEN-009, PLT-009, OQ-06, OQ-08; D03 §3.3; D05 TD-21

## Context

### What WP 12 asks for
D06 (`docs/wp0/D06-work-package-roadmap.md`, "WP 12") lists this scope: decide the backend (this ADR), authentication, a sync protocol with UUIDs, timestamps and tombstones, a conflict policy, a privacy policy and account deletion. The dependencies are WP 3 (accepted), an owner decision and a privacy policy. The acceptance test is: two devices converge after offline edits on both, and deletion removes server data. D06 marks the package optional and puts it after release R2.

### What already exists in the code
- **Sync columns.** The mixin `SyncColumns` gives `id` (text UUID), `createdAt`, `updatedAt` and a nullable `deletedAt` (`app/lib/data/db/tables.dart` lines 3 to 9). Thirteen tables use it, for example `Measurements`, `FoodLogEntries`, `Recipes`, `WorkoutSessions`, `WorkoutPlans` and `Goals`. In schema v8, only `ExercisesV8` uses it (`app/lib/data/db/v8/tables_v8.dart` line 33).
- **Gaps.** Ten tables in `tables.dart` have no `SyncColumns`. They include the child tables `SavedMealItems`, `RecipeIngredients`, `PlanExercises`, `SessionExercises`, `SessionSets` and `SplitDays`, plus `Settings` (which has `updatedAt` but no UUID). A sync layer must treat a parent and its children as one unit, or the schema must add columns. The v8 reference tables carry no sync columns.
- **Tombstones exist as soft delete.** Deleting a session sets `deletedAt` and `updatedAt` (`app/lib/data/repositories/drift_workout_session_repository.dart` lines 72 to 81). The same pattern appears in `drift_measurement_repository.dart` (line 108). I found no code that purges tombstones.
- **Time format.** `docs/delivery-record/WP3.md` line 73 says stored dates are ISO-8601 text with an offset and are not normalised to UTC. Sync ordering must normalise them first.
- **Backup.** `DriftBackupRepository` exports every table as raw rows in JSON, format version 2, schema version from the database (`app/lib/data/repositories/drift_backup_repository.dart` lines 18 to 41). Soft-deleted rows are included because the export uses `SELECT *`. Restore deletes all rows and then inserts the file contents in one transaction (same file, `importJson`). So restore is replace-only. It is not a merge and cannot serve as sync. D04 OQ-17 (replace or merge) is still open.
- **File hand-off.** Backup and CSV files leave the app through the `UserFileGateway` share sheet (ADR-0011, accepted).
- **No account code.** There is no secure token store in `app/lib` (searched for `secure_store` and `flutter_secure_storage`; no match). `dio` exists for food lookup only (`app/lib/data/external/open_food_facts_client.dart`). The schema version in code is 7 (`app/lib/data/db/app_database.dart` line 70); v8 and v9 changes are still planned (D06, WP 8 and WP 17).

### Privacy constraints already decided
- ADR-0005: no analytics and no network transmission of personal data; Android `allowBackup` is `false` (`app/android/app/src/main/AndroidManifest.xml` line 15); the iOS iCloud exclusion needs a native hook that does not exist (D05 TD-21, not verified as done; I found no exclusion code in `app/ios`). ADR-0005 says to revisit before WP 12: data that leaves the device needs transport encryption, a privacy policy and account deletion.
- D04 GEN-009: with sync off, a network capture shows no personal data leaving the device, and no third-party analytics or advertising SDK ships in the first release.
- D04 DAT-009 to DAT-013: sign-in only when the user enables sync; sync is optional, off by default and lists what it syncs; conflicts resolve deterministically with a recoverable conflict log; the user can delete the account and all cloud data (proposed period: 30 days). DAT-010 to DAT-013 are priority P3.
- D04 PLT-009: tokens live in Keystore or Keychain only.
- Open questions: OQ-08 (is sync intended at all, which provider, which sign-in, which data) and OQ-06 (retention after account deletion and for deleted records). I found no recorded owner answer to either.

## The decision the owner must make
Does RepForge get user accounts and cloud sync, and if so, who runs the backend? The owner must also answer the scope parts of OQ-08: which sign-in methods, and which data is in scope.

## Options considered

| | A. No accounts in v1; file backup only | B. Own backend with a RepForge sync protocol | C. Third-party sync service |
|---|---|---|---|
| What it is | Keep JSON backup and CSV export. Close WP 12 as not pursued. | A RepForge server (self-hosted or on managed hosting) with sign-in, a change feed and an account-deletion endpoint. | A hosted database or sync engine with its own SDK and auth (for example a Postgres-based service or a SQLite sync engine; vendor not chosen here). |
| Privacy policy | Short: data stays on the device except user-chosen exports and food lookup. | Full policy. RepForge is the data controller and runs breach response. Body and nutrition data may count as health data under some laws; legal review needed (this ADR gives no legal advice). | Full policy plus a named processor and any sub-processors, data location and a data processing agreement. GEN-009(2) needs a check that the SDK contains no analytics. |
| Account deletion | Not applicable. DAT-012 (delete local data) already covers it. | Build and test a delete-everything endpoint, backups and logs included; state the retention period (OQ-06). | Depends on vendor tools; the vendor must delete backups too. Verify in writing. |
| Conflict policy | None needed. | We choose and own it (see below). | Vendor-defined, often last-write-wins per row. Must be checked against DAT-011 (per-field, with conflict log). |
| Cost | None. | Hosting, storage, monitoring, patching and on-call time. Amount not estimated here; the owner must give a budget. | Usage-based fee, possibly a free tier; vendor lock-in. Amount not estimated; verify current pricing. |
| Offline behaviour | Unchanged: fully offline. | Writes stay local; a queue pushes when online; pull on foreground (PLT-008(2): no background reliance). | Same, but queue and retry logic sit inside the vendor SDK. |
| Schema impact | None. | Add sync columns to 10 tables or sync aggregates; add a normalised UTC time; a migration with tests (GEN-007). | Same schema work, in the shape the vendor needs. |
| Test strategy | Existing backup tests. | Two in-memory drift databases plus a fake or containerised server; random offline edits on both; assert identical state after sync. A real deletion test: delete the account, then query the server and find no rows. | Same tests against a vendor test project; the deletion check depends on vendor tools. |
| Effort (points) | 0 | Needs a new allocation approved by the owner (current 4 points looks too small for a backend; not re-estimated here). | Needs a new allocation; likely smaller than B but not estimated here. |

### Conflict policy that B and C must settle (D03 §3.3, DAT-011)
- **Minimum (D03):** row-level last-writer-wins with tombstones.
- **Required by DAT-011:** later edit wins per field, the losing value goes to a recoverable conflict log, and both devices end identical.
- **Known risks:** device clocks can be wrong, so ordering by device `updatedAt` alone can lose a correct edit. A server receive time or a hybrid logical clock reduces this. A delete on one device and an edit on another needs a stated rule (for example: edit after delete restores the row). Child rows need the aggregate rule above. Catalogue and reference data (`foods` seed, exercise releases, ADR-0009) should not sync; each device installs the same release.

## Decision
Not decided. Owner to record the chosen option, the date and any conditions here.

## Recommendation (proposal)
Choose **Option A for now**, and record a revisit trigger.

Reasons:
1. OQ-08 asks whether sync is wanted at all. There is no recorded owner need for multi-device use, and D04 ranks sync P3.
2. The schema still changes (v8 in progress under WP 8, v9 planned under WP 17). A sync protocol built now must be versioned against a moving schema.
3. Options B and C add health-adjacent personal data on a server, a privacy policy, deletion duties and a recurring cost. Option A keeps GEN-009 true by construction.
4. Backup already works offline, and the backup screen is delivered through ADR-0011.

Revisit when: the owner names a multi-device need, the schema is stable after v9, and a budget and a legal reviewer exist. If sync is then wanted, a short follow-up ADR should compare B and C with a real vendor and price.

Independent of this choice, the owner may separately authorise two small items that are listed under WP 12 today: the iOS iCloud exclusion hook (TD-21) and scheduled local backup (DAT-008, P2). Neither needs an account.

## What WP 12 can implement before the decision
Nothing beyond what exists. Sync columns, soft delete, UUIDs and the format 2 backup are already in place. A sync port, a stub server client or an account screen without an approved backend would be a placeholder, which `docs/engineering-standards.md` §10 restricts to the labelled `RfNotYetAvailable` screen. No code is proposed in this campaign.

## What the decision unlocks
- **Option A:** record the decision; mark DAT-009 to DAT-011 and DAT-013 as not planned (an owner amendment to D04 §7); keep WP 12 in the roadmap as closed-not-pursued or deferred; optionally schedule TD-21 and DAT-008. The 4 points stay out of the core view either way.
- **Option B or C:** an approved effort allocation, then stages in this order: privacy policy and legal review; sync-ready schema migration with tests; secure token store behind a port in `lib/data/platform` (PLT-009); auth; sync engine with a fake server and the two-device convergence test; account deletion with a server-side check; owner acceptance on two real devices.

## Consequences
- Whatever the owner chooses, ADR-0004 and ADR-0005 stay in force until this ADR is accepted and supersedes the relevant lines.
- New dependencies (HTTP client for sync, auth SDK, secure storage) each need the `docs/engineering-standards.md` §4 checks: permissive licence, release within 12 months, and an ADR when architecture is affected.
- Evidence for these claims: the files named above, read on 2026-11-07.
