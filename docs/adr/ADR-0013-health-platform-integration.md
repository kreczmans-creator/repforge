# ADR-0013: Health platform integration (Health Connect and HealthKit)

- Status: **Proposed — owner decision required.** Nothing in this record is authorised. The Decision section is empty until the owner fills it.
- Date: 2026-11-07 (proposed)
- Work package: WP 13 (optional, 4 points allocated, 0 earned; `docs/governance/effort-points-and-progress-reporting.md` line 32)
- Related: ADR-0005, ADR-0006, ADR-0007, ADR-0011; D04 PLT-003 to PLT-006, OQ-16, TRN-007; D03 §2.5; D05 R-06

## Context

### Scope and acceptance (D06)
D06 "WP 13" says: exchange weight and workouts with Health Connect and HealthKit. Scope: a `HealthSync` adapter, permission flows, read weight, write workouts and nutrition where supported, and a per-platform capability table. Dependencies: WP 9 and WP 10 (both accepted). Acceptance: **a documented matrix of what syncs on each platform, verified on devices.** D04 sets both integrations at priority P3 "Could / later" (PLT-005, PLT-006). OQ-16 asks whether the integrations are read-only or also write; I found no recorded owner answer.

### Requirements that already apply
- PLT-003: one capability service reports Health Connect or HealthKit as available, unavailable or permission denied.
- PLT-004: the app degrades gracefully when a capability or permission is missing.
- PLT-005: permission is requested per data type at the point of use; if Health Connect is missing, the feature is hidden or shows an install-or-unavailable state.
- PLT-006: permission per data type at the point of use; revoking permission in system settings stops reads and writes without error dialogs.
- Standards §11 (`docs/engineering-standards.md`): permissions on first use with rationale text. The brief mentions "D04 §11" for the permission flow; D04 has no section 11, so this ADR uses PLT-004 to PLT-006 and standards §11 instead.
- TRN-007: energy expended on a cardio entry is user-entered or estimated and is never added to nutrition automatically.
- GEN-009: minimise collection and transmission of personal fitness data.

### What exists in the code
- No health code and no health dependency: `app/pubspec.yaml` has no health package, and a search of `app/lib` for "health" in file names and content finds nothing. D03 line 27 reserves "WP 13 health" for the work package that needs it.
- Adapter pattern to copy: a Flutter-free port in `lib/domain/...` and one adapter in `lib/data/platform/` with a fake, enforced by `app/test/architecture/plugin_isolation_test.dart`. That test lists the plugins by name in a regular expression (`mobile_scanner`, `permission_handler`, `share_plus`, `file_selector`, `flutter_local_notifications`, `timezone`). **A health package is not covered until its name is added** to that test. Existing ports: `UserFileGateway` (`app/lib/domain/files/user_file_gateway.dart`), `RestAlertScheduler` (`app/lib/domain/training/rest_alert_scheduler.dart`); adapters and fakes in `app/lib/data/platform/`.
- A hand-written Android channel already exists (`MainActivity.kt`, camera check). `MainActivity` extends `FlutterActivity` (not `FlutterFragmentActivity`). Some health packages need the fragment variant; verify.
- Weight: stored in the `Measurements` table with `site = weight`, in kg (`app/lib/data/db/tables.dart` lines 11 to 26; `MeasurementSite.weight` in `app/lib/domain/measurements/measurements.dart`). **The table has no source or external-id column**, so an imported reading cannot be marked as imported, and a re-import cannot be matched to an earlier one. Importing needs a schema migration (GEN-007) or a mapping table.
- Workout: `WorkoutSession` has `name`, `startedAt`, optional `endedAt`, `notes`, sets and exercises (`app/lib/domain/training/training.dart` lines 213 to 232). Set data (load, reps, assistance, duration, distance, heart rate, cardio energy) lives in `SessionSets`. A summary export needs only start, end, a title and a type.
- Nutrition: each `FoodLogEntry` stores kcal, protein, carbs, fat, fibre and a provenance label (`tables.dart` lines 72 to 92).
- CI: iOS builds use `--no-codesign` for the simulator (D07 §2.4). D07 §3 states that HealthKit, camera and Health Connect cannot be exercised in CI. D03 §2.5 states the iOS simulator lacks HealthKit data and HealthKit needs an entitlement and a real device.

## Candidate packages
Versions and release dates below come from my memory of pub.dev, not from a check made for this record. **Treat every release date and version as uncertain** and re-check on pub.dev before any decision. I did not access the network.

| Candidate | Covers | Licence (believed) | Maintenance (believed) | Notes |
|---|---|---|---|---|
| `health` (CARP / Copenhagen Research Platform) | Health Connect and HealthKit; read and write; weight, workouts, nutrition types | MIT | Active through 2025 with frequent major releases; latest release date not known to me | One package for both platforms. Large API surface and several transitive packages. Package notes have asked for `FlutterFragmentActivity`, manifest `queries`/permission-rationale entries and a minimum Android SDK; verify against AGP 9.1.0 and compileSdk 36 as ADR-0011 did. |
| Separate Android-only and iOS-only packages (for example `health_connect`, `health_kit_reporter`) | One platform each | Not checked | Smaller projects; maintenance not known to me | Two packages, two behaviours. Higher risk of an unmaintained dependency. |
| Own platform channels (Kotlin with `androidx.health.connect:connect-client`, Swift with HealthKit) | Exactly the types we choose | Own code; Jetpack library believed Apache-2.0 | We maintain it | No Dart package risk; more native code, no CI execution of either. The camera channel shows the pattern is already used. |

### Standards §4 checks still to run (none has been run)
1. Permissive licence for the package and every transitive package (read each LICENSE file).
2. A release within 12 months of the decision date.
3. Exact pin in `pubspec.yaml`, a version at least two weeks old, and a lockfile diff reviewed.
4. Compatibility with Flutter 3.47.9, Dart 3.13.7, AGP 9.1.0, compileSdk 36, Android `minSdk` (follows Flutter's default) and iOS 15.0; R8 release build; the `android.builtInKotlin=false` setting (see ADR-0011).
5. Weekly `osv-scanner` and `dart pub outdated` clean for the new packages.
6. An ADR (this one) accepted before the dependency is added.
7. Platform policy checks outside the repository: Google Play's health permission declaration for Health Connect, and Apple's review notes for the HealthKit entitlement. Exact current rules to be read from the vendors' own documentation by the owner or an agent with network access.

## Design of the port

### Domain (`lib/domain/health/`, Flutter-free)
- `HealthSync` (interface). Methods return `Result<T, AppError>` and never throw, as `UserFileGateway` does:
  - `Future<HealthCapabilities> capabilities()` — per data type and direction: `available`, `unavailable` (not installed, not supported), `needsPermission`, `denied`.
  - `Future<Result<HealthPermissionOutcome>> requestPermission(HealthDataType type, HealthDirection direction)` — one type at a time (PLT-005(1), PLT-006(1)).
  - `Future<Result<List<HealthWeightSample>>> readWeight({required DateTime from, required DateTime to})`.
  - `Future<Result<HealthWriteOutcome>> writeWorkout(HealthWorkout workout)` and `writeNutrition(HealthNutritionEntry entry)`.
- Value types: `HealthDataType` (weight, workout, nutrition), `HealthDirection` (read, write), `HealthWeightSample` (kg, time, source label, external id), `HealthWorkout` (RepForge session id, title, start, end, optional energy flagged as user-entered), `HealthNutritionEntry` (day, meal, kcal, nullable macros).
- Idempotent writes: send the RepForge UUID as the platform's client or sync identifier so a repeat write updates instead of duplicating. Health Connect has a client record id; HealthKit has a sync identifier and version in metadata (both to be verified on device).

### Data layer (`lib/data/platform/`)
- One adapter, for example `health_package_health_sync.dart`, is the only importer of the chosen package. The architecture test gains a rule for it, as for ADR-0011.
- `FakeHealthSync` for widget and integration tests, with scripted capabilities, denials and samples, in the same folder (like `fake_user_file_gateway.dart`).
- `UnavailableHealthSync` as the default provider; `main.dart` binds the real adapter on Android and iOS only, as the existing gateway does.
- A pure mapping layer (RepForge entry to `HealthWorkout`, sample to `Measurement`) lives in domain or application code and is unit-tested without a device.

### Behaviour rules proposed
- Everything is off until the user turns an integration on in Settings. No health call is made before that (GEN-009).
- Read weight into `Measurements` with a visible source label. Skip a sample whose external id was already imported. Never overwrite a user-entered reading.
- Never write back a reading that came from the same platform (prevents loops).
- Workout write is summary only. Nutrition write is a later stage (see recommendation).
- Revoking permission in system settings makes the next call return `denied`; the UI shows a neutral message, not an error dialog (PLT-006(2)).

## Permission flow (standards §11, PLT-004 to PLT-006)
1. The user opens Settings, then "Health", and sees a plain-language rationale per data type: what is read or written, why, and that nothing leaves the device through RepForge.
2. The user turns on one data type. Only then does the app request that one permission.
3. If the platform shows no prompt (already denied, or Health Connect missing), the screen explains the state and offers the system settings or the Health Connect install page. The app never repeats the request in a loop.
4. Turning a type off stops further reads and writes. Data already written to the platform stays there; the screen says so. Data already imported stays in RepForge until the user deletes it.
5. HealthKit does not tell an app whether read access was denied; denied reads look like empty data. The UI must not claim "no data" as proof of denial (to verify on device).

## Per-platform capability matrix (draft; every cell unverified until device tests pass)

| Capability | Android: Health Connect | iOS: HealthKit |
|---|---|---|
| Availability | Built into the system on recent Android versions; on older versions the user installs the Health Connect app. D03 §2.5 says "API 26+, HC app may be absent". Exact version thresholds: verify in Android documentation. | iPhone only for v1 (iPad support to verify). Needs the HealthKit capability and a real provisioned build. Simulator has no usable data (D03 §2.5). |
| Read weight | Expected yes, with a read permission for weight | Expected yes, with a read authorisation for body mass |
| Write weight | Expected yes | Expected yes |
| Write workout (summary) | Expected yes as an exercise session (start, end, type, title) | Expected yes as a workout (start, end, type) |
| Per-set load and reps | Not expected to be representable. Summary only. | Not expected to be representable. Summary only. |
| Write nutrition | Expected yes as nutrition records (energy and macros) | Expected yes as dietary samples, one per nutrient |
| Read denied detectable | Yes, through the permission check | No by design (see flow step 5) |
| Idempotent re-write | Client record id (verify) | Sync identifier and version (verify) |
| Background sync | None planned (PLT-008(2)) | None planned |
| Verifiable in CI | Compile and unit tests only | Compile and unit tests only |

## What cannot be verified in CI, and the owner's device checklist
CI proves compilation, the architecture rules and the logic against the fake. It cannot prove real permission prompts, real data exchange or store-policy acceptance (D07 §3, D03 §6).

Devices and accounts the owner needs: one Android phone on a recent Android version and one older phone if older versions are in scope; Health Connect installed where required; one iPhone on a supported iOS; an Apple Developer Program membership and a signed build with the HealthKit capability (D07 §2.4).

Checklist (record device model, OS version, package version, date and result for each line):
1. Fresh install: no health prompt appears before the user enables Health in Settings.
2. Enable weight read: the rationale shows, one permission prompt appears, a weight from another app imports once.
3. Re-run import: no duplicates. Edit the weight in the other app: behaviour recorded.
4. Deny permission: neutral message, other flows unaffected. Re-enable from system settings.
5. Revoke in system settings while the app runs: next sync stops without an error dialog.
6. Write a finished workout: it appears in the platform's health app with the right start, end and title. Write it again: no duplicate.
7. Delete the session in RepForge: record what happens to the platform copy (expected: unchanged; the screen says so).
8. Write nutrition for one day: totals match the RepForge day; delete behaviour recorded.
9. Health Connect missing (Android): install-or-unavailable state shows; nothing else breaks.
10. Airplane mode: all flows work offline (local platform stores).
11. Uninstall and reinstall: no stale permission state.
12. Release build (R8 on Android; archive build on iOS): repeat items 2 and 6.
13. Fill the capability matrix above with the observed results and attach screenshots to the delivery record.

## Decision
Not decided. Owner to record the scope (OQ-16), the package choice and the date here.

## Recommendation (proposal)
1. **Scope (OQ-16):** stage 1 is weight read plus workout summary write. Stage 2, nutrition write, only after stage 1 passes on devices, because it widens the permission scope and the privacy review (OQ-16 note) and can double-count with other apps.
2. **Package:** prefer the single `health` package, subject to the §4 checks above; if it fails any check, use own platform channels. Do not add a package until this ADR is accepted.
3. **Timing:** start WP 13 only when the owner has the devices, the Apple membership and time for the checklist. Until then WP 13 stays at 0 earned points.
4. **Schema:** approve a small migration to record the source and external id of imported weight readings, or choose a mapping table. This should be sequenced after v8 and v9 (D06, WP 8 and WP 17).

## Why no implementation ships in this campaign
A `HealthSync` port with no verified adapter would be a placeholder. `docs/engineering-standards.md` §10 forbids a stubbed integration in a release build and allows only the labelled `RfNotYetAvailable` screen. The acceptance test needs real devices, which the delivery agents do not have, and the package has not passed the §4 checks. The `overnight-campaign-2026-11-07.md` ledger records the same conclusion.

## Consequences
- Accepting this ADR adds one pinned dependency (or native code), one port, one adapter, one fake and an updated architecture test.
- Native changes will be needed in both apps (Android manifest permissions and a rationale entry; iOS entitlement and usage strings). Each must be recorded in D03.
- WP 13 earns progress only from evidence: device matrix results and owner acceptance.
