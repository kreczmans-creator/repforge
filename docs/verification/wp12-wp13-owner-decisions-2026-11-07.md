# WP 12 and WP 13 owner decisions — summary (2026-11-07)

These are proposals. Nothing here is authorised. Full reasoning is in `docs/adr/ADR-0012-accounts-backup-and-sync-backend.md` and `docs/adr/ADR-0013-health-platform-integration.md`. Both work packages are optional, have 4 points each and 0 earned (`docs/governance/effort-points-and-progress-reporting.md` lines 31 and 32). They sit in the full-programme denominator of 105 and outside the core denominator of 97.

## WP 12 — accounts, backup and sync (ADR-0012)

| Item | Content |
|---|---|
| Question needing owner authority | Does RepForge get user accounts and cloud sync (OQ-08), and if so, who runs the backend? |
| Options | A. No accounts in v1; JSON and CSV file backup only. B. Own backend with a RepForge sync protocol. C. Third-party sync service. |
| Technical consequences | A: none; GEN-009 stays true. B and C: privacy policy and legal review, account deletion with a server-side check, secure token store, sync columns added to 10 child and settings tables or sync by aggregate, UTC time normalisation (`docs/delivery-record/WP3.md` line 73), conflict policy per DAT-011, running cost, and a new effort allocation. |
| Recommended | A for now, with a revisit trigger: a named multi-device need, a stable schema after v9, a budget and a legal reviewer. |
| Evidence | `app/lib/data/db/tables.dart` lines 3 to 9 (`SyncColumns`); `app/lib/data/repositories/drift_backup_repository.dart` (format 2, replace-only restore); `app/lib/data/repositories/drift_workout_session_repository.dart` lines 72 to 81 (soft delete); `docs/adr/ADR-0004-local-first-persistence.md`; `docs/adr/ADR-0005-encryption-at-rest-and-local-privacy.md`; D04 DAT-009 to DAT-013, GEN-009, OQ-06, OQ-08; D06 "WP 12"; D05 TD-21. |
| Blocks other work? | No. No work package depends on WP 12 (D06 dependency graph). It blocks only WP 12 itself, and release R3. The owner may separately authorise the iCloud exclusion hook (TD-21) and scheduled local backup (DAT-008) under any option. |

## WP 13 — health platform integration (ADR-0013)

| Item | Content |
|---|---|
| Question needing owner authority | What is the scope of Health Connect and HealthKit exchange (OQ-16), which package or native route may be added, and when will the owner supply devices and accounts for verification? |
| Options | Scope: read only; or weight read plus workout summary write (stage 1) then nutrition write (stage 2); or full read and write at once. Package: the single `health` package; separate per-platform packages; own platform channels. |
| Technical consequences | New pinned dependency or native code; a `HealthSync` port in `lib/domain`, one adapter and a fake in `lib/data/platform`; an update to `app/test/architecture/plugin_isolation_test.dart` (the plugin list is by name); native manifest and entitlement changes; a schema migration to record the source of imported weight (`Measurements` has no source column); Apple Developer membership and a signed build; the standards §4 checks, not yet run. |
| Recommended | Two stages: weight read plus workout summary write first, nutrition write only after stage 1 passes on devices. Prefer the `health` package if it passes the §4 checks; otherwise own channels. Start only when devices and the Apple membership are ready. |
| Evidence | `app/pubspec.yaml` (no health package); `app/lib/data/platform/` and `app/test/architecture/plugin_isolation_test.dart` (adapter rule); `app/lib/data/db/tables.dart` lines 11 to 26 (`Measurements`); `app/lib/domain/training/training.dart` lines 213 to 232 (`WorkoutSession`); D04 PLT-003 to PLT-006, OQ-16; D03 §2.5; D07 §2.4 and §3; `docs/engineering-standards.md` §4, §10, §11; `docs/adr/ADR-0011-file-export-and-import.md` (package verification pattern). Package versions and dates are from memory and unverified. |
| Blocks other work? | No. Nothing depends on WP 13 (D06: it depends on WP 9 and WP 10, both accepted). It blocks only WP 13 itself and release R3. |

## Why no code ships now
WP 12 has no approved backend. WP 13 has no verified adapter and cannot be verified without devices. A port or client with no working implementation would be a placeholder, which `docs/engineering-standards.md` §10 restricts. Both packages stay at 0 earned points. This document does not change any allocation or any historical record.

## Register-entry drafts
Field order follows `OwnerBlocker` in `app/lib/domain/delivery/owner_blocker.dart`. Draft text only; nothing is applied to `owner_blocker_register.dart`. Note: the enum `BlockerWorkPackage` has no WP 12 or WP 13 value. Adding the two values is a change under `app/` and was not made. Until then the closest existing value is `programme`. No delivery record exists for either package (`docs/delivery-record/` has no WP12.md or WP13.md); the ADR path is used instead.

### OB-WP12-01
- id: OB-WP12-01
- workPackage: WP 12 (needs a new enum value; `programme` until then)
- stage: Decision (before stage 1)
- reference: OQ-08, OQ-06, DAT-009 to DAT-013, ADR-0012
- title: Decide whether RepForge has accounts and cloud sync, and who runs the backend
- description: WP 12 is optional. The owner must choose between no accounts with file backup only, an own backend with a RepForge sync protocol, or a third-party sync service. The choice sets the privacy policy, account deletion, conflict policy, cost and test plan.
- category: Owner decision
- priority: Low
- initialStatus: Awaiting owner
- assignee: Owner action
- whyBlocked: A backend, a privacy policy and a budget are product and legal decisions. The delivery agents cannot choose them. D06 lists "owner decision" and "privacy policy" as dependencies. Code beyond the existing sync columns and backup would be a placeholder.
- actionRequired: Read ADR-0012, choose option A, B or C, and record the choice in the ADR Decision section and in D04 section 7 (answering OQ-08).
- recommendation: Option A (no accounts in v1; file backup only), with a revisit trigger: a named multi-device need, a stable schema after v9, a budget and a legal reviewer.
- consequences: A closes WP 12 as not pursued and keeps GEN-009 true. B or C needs a new effort allocation, a legal review, a schema migration and a sync test harness before any code. Deferral changes nothing in the core programme.
- dependencies: OQ-06 retention policy; for B or C, a budget and a legal reviewer; WP 8 v8 and WP 17 v9 schema acceptance
- evidence:
  - ADR proposal: docs/adr/ADR-0012-accounts-backup-and-sync-backend.md
  - Sync columns: app/lib/data/db/tables.dart lines 3 to 9
  - Backup format 2: app/lib/data/repositories/drift_backup_repository.dart
  - Requirements: D04 DAT-009 to DAT-013, GEN-009, OQ-08
  - Roadmap entry: D06 "WP 12"
- deliveryRecord: none exists; docs/adr/ADR-0012-accounts-backup-and-sync-backend.md until a WP 12 record is created

### OB-WP13-01
- id: OB-WP13-01
- workPackage: WP 13 (needs a new enum value; `programme` until then)
- stage: Decision (before stage 1)
- reference: OQ-16, PLT-005, PLT-006, ADR-0013
- title: Decide health integration scope and package, and provide devices for verification
- description: WP 13 is optional. The owner must decide whether Health Connect and HealthKit are read only or also write (OQ-16), approve a package or native route after the standards section 4 checks, and supply the devices and the Apple Developer account for the device matrix.
- category: Owner decision
- priority: Low
- initialStatus: Awaiting owner
- assignee: Owner action
- whyBlocked: Scope and the privacy review are owner decisions. Acceptance needs real devices, a signed iOS build and store-policy checks, which the delivery agents cannot do (D07 section 3). A port without a verified adapter would be a placeholder (standards section 10).
- actionRequired: Read ADR-0013, decide the scope for stage 1 and stage 2, approve or reject the package route, and say when devices and accounts are available. After approval, an agent runs the standards section 4 checks and the owner runs the device checklist.
- recommendation: Stage 1 is weight read plus workout summary write; stage 2 is nutrition write after stage 1 passes on devices. Prefer the `health` package if it passes the checks, otherwise own platform channels. Start when devices and the Apple membership are ready.
- consequences: Deferral keeps WP 13 at 0 earned points and changes nothing in the core programme. Approval adds a dependency or native code, a schema migration for imported weight, and native manifest and entitlement changes, each recorded in D03.
- dependencies: Owner devices (Android and iPhone); Apple Developer Program membership; standards section 4 checks on the chosen package; schema sequencing after WP 8 v8 and WP 17 v9
- evidence:
  - ADR proposal: docs/adr/ADR-0013-health-platform-integration.md
  - Adapter rule: app/test/architecture/plugin_isolation_test.dart
  - Existing adapters: app/lib/data/platform/
  - Requirements: D04 PLT-003 to PLT-006, OQ-16
  - Limits of CI: D07 section 3; D03 section 2.5
  - Roadmap entry: D06 "WP 13"
- deliveryRecord: none exists; docs/adr/ADR-0013-health-platform-integration.md until a WP 13 record is created
