# Device timing of the version 8 migration (WP 8 3b-9)

Status: the harness times the real v7 → v8 migration (registry entry
`v7to8`, sub-stage 3b-4). **Device runs: OUTSTANDING.** They need the
owner's physical devices. No figure in this repository is device evidence:
host figures are a relative baseline only, and a device run becomes 3b-9
evidence only once the owner records it with the device specifications and
accepts it.

History: until sub-stage 3b-9 switched it (2026-11-07), the device harness
timed the historical chain v5 → v7 as a stand-in. Stand-in figures were
never v8 timings or 3b-9 evidence. The host test still times the
historical chain as a second subject of the harness; its output says
`STAND-IN` and `not device evidence`.

Owner decision (D04 §7, 2026-11-06, "Device timing"): one mid-range Android
phone and one supported iPhone, with recorded specifications. Platform
evidence, not universal compatibility. Data: 5,000 exercises, 100,000 sets,
the full reference bootstrap, the 303 synthetic no-primary exercises, a
representative report and user data. At least three runs per device from an
identical restored start; median and worst duration, model, OS, SQLite
version, database size and outcome; a normal run and a recovery or retry
run. The profile is a stress profile; any material difference from the
real production profile is recorded.

## What runs

| Part | File |
|---|---|
| Profile builder (5,000 exercises, 100,000 sets, seed 2026110603) | `app/test/migration_v8/large/large_profile.dart` |
| Timing procedure (shared by host and device) | `app/test/migration_v8/timing/timing_harness.dart` |
| Migration under test (`v7to8`: `AppDatabaseV8` with the deterministic registry configuration) | `app/test/migration_v8/recovery/migration_registry.dart` |
| Migration code | `app/lib/data/db/migration/v7_to_v8.dart`, `app/lib/data/db/v8/app_database_v8.dart` (not connected to the app) |
| Device harness | `app/integration_test/migration_v8_timing_test.dart` |
| Driver (profile mode, `reportData`) | `app/test_driver/integration_test.dart` |
| Device script (model, hardware and OS capture, run, result files) | `app/tool/device_timing.sh` |
| Host timing (tag `heavy`) | `app/test/migration_v8/timing/host_timing_test.dart` |
| Smoke procedure on the host (normal suite) | `app/test/migration_v8/recovery/recovery_tools_test.dart`, group "timing harness" |

Procedure (`runTimingCampaign`, the same code on host and device):
1. Build the v7 D04 profile once, with the same deterministic builder as
   the host, in a new directory under the app's cache directory. This file
   is the restored start. Its state digest must equal the host reference
   `v7 602dbcd0601b46b7`.
2. At least three normal runs. Each starts from a fresh copy whose state
   digest is checked equal to the start's. The timer covers the database
   open that runs the migration, through the app engine
   (`NativeDatabase.createInBackground`, as `drift_flutter` opens the app
   database): the `quick_check` preflight, the v7 → v8 step and the close.
   The time of every chain checkpoint and every phase of the step is
   recorded (per-phase durations below).
3. One recovery/retry run: a fresh copy, a failure injected inside the step
   at phase `v8.setsClassified` (mid-step: exercises mapped, rebuilt and
   linked, sets classified; the sets rebuild, integrity review and report
   not yet done). The rolled-back state is checked: version 7, integrity
   `ok`, state equal to the start, and the run id `run-1` kept in the run
   ledger (R-32). Then a timed retry, which must reuse that run id and
   clear the ledger.
4. Every normal run and the retry must end in the same state, equal to the
   host reference `v8 7fc53371acfa16d7`.
5. One seed run: a copy of the start with the v7 setting
   `seedExercisesVersion` = 1 (`updated_at` 2025-03-01T09:00:00.000Z), so
   the migration reads the bundled seed and records release 1 (R-30 /
   B-07 option b). It must record one `catalogue_releases` row with the
   pinned hash and no R-30 warning, and end in the host reference
   `v8 63595160a687407b`. The D04 profile itself holds no such setting, so
   its runs never read the seed (`seed.readsByNormalRuns` and
   `seed.readsByRecoveryRuns` must be 0; otherwise `FAIL`).
6. Record counts of the input and the migrated database: rows per table,
   exercises, sets, blocked exercises by reason, catalogue releases,
   reference bootstrap, and the migration report per run, reconciled
   (outcomes sum to the records examined; entries per action equal the
   stored counts).

`outcome` is `pass` only when every run migrated, the recovery recovered,
the seed run recorded release 1, the bundled seed hashes to the pinned
v7-era value, the report reconciles and (D04 profile) the start, end and
seed-run digests equal the host references. Otherwise `FAIL`, with the
reasons in `failures`. A full run without the device's model and OS is
`INCOMPLETE`; an exception is `ERROR` with the message and stack.

Seed bytes (R-30): on the device the harness loads
`assets/seed/exercise_library.json` from the app's asset bundle
(`rootBundle`), the bytes the app ships, and passes them to the registry's
v8 configuration. Nothing in `lib/` changes for this. The result reports
the size, SHA-256 and whether it equals the pinned v7-era hash
`839d9ca28f043e61ed502b4bf765ca1ff8110fc21b54e84d98014c3b8d5e0b22`.

Safety: the harness works only in a new directory under the app's cache
directory. Before it creates the directory it asserts that the directory is
inside the cache directory, is not inside the application-support directory
(which holds `repforge.sqlite`) and does not contain it. Afterwards it
asserts that `repforge.sqlite` and its `-journal`, `-wal` and `-shm` files
are unchanged (existence, size, modification time), and that no
`repforge.sqlite` appeared in the work directory. It never opens the app's
database. It deletes the work directory at the end, also on failure. The
script installs the profile build of the app, so use a device where that is
acceptable, and back up the app's data first if the device holds real data.

Without `--dart-define=RUN_V8_TIMING=true` (CI's emulator job runs every
file in `integration_test/`) the same procedure runs on the small smoke
profile (60 exercises, 600 sets) in seconds. A smoke or debug-mode run says
`not device evidence` in `evidence`.

### Phases

`runs[].phases` and `phaseMedianMs` cut each timed open at the marks below.
Each segment ends at the named mark.

| Mark | The segment before it covers |
|---|---|
| `7:stepStarted` | background isolate start, open, `quick_check` preflight, foreign keys off, `BEGIN` |
| `v8.started` | run ledger read, file fingerprint (reads the whole file), ledger write |
| `v8.baselineTaken` | baseline of foreign keys and integrity findings |
| `v8.tablesCreated` | new v8 tables and indexes |
| `v8.runRecorded` | `migration_runs` row |
| `v8.bootstrapInserted` | reference bootstrap |
| `v8.exercisesMapped` | mapping of every exercise (domain rules) |
| `v8.exercisesRebuilt` | `exercises` rebuild |
| `v8.exerciseLinksWritten` | targets, equipment links, blocks, quarantine rows |
| `v8.setsClassified` | TRN-020 classification of every set |
| `v8.setsRebuilt` | `session_sets` rebuild |
| `v8.releaseRecorded` | release 1 (R-30) |
| `v8.integrityReviewed` | integrity run (pre-existing damage, R-31) |
| `v8.reportWritten` | report entries and counts |
| `v8.foreignKeysChecked` | foreign key check against the baseline |
| `v8.selfChecked` | self-checks (reconciliation, stored report equals built report) |
| `7:workDone`, `7:versionWritten`, `7:committed` | `user_version` = 8 and the commit |
| `closed` | foreign keys on, run ledger cleared, `beforeOpen`, first query, close |

## Owner procedure

Prerequisites: Flutter 3.47.9 on the PATH, python3, the repository at the
commit under test. Profile mode needs a physical device (no emulator or
simulator). Debug-mode timings are not evidence. Each script run gives
3 normal runs, the recovery/retry run and the seed run; once per device is
enough, and more repetitions are optional.

Before each run: charge above 50 %, close other apps, keep the screen on,
leave battery saver or low power mode off, and note the room temperature if
it is unusual. The device does not need to hold any RepForge data.

### Android (mid-range phone)
1. Enable developer options and USB debugging; connect; accept the USB
   debugging prompt.
2. From the repository root:
   ```sh
   cd app
   flutter pub get
   adb devices                       # note the serial
   tool/device_timing.sh android <serial>
   ```
   The serial is optional when only one device is connected.
3. The script records `manufacturer model (SoC, ABI, RAM)`,
   `Android release (API level)`, battery state and free storage through
   `adb`, then runs:
   ```sh
   flutter drive --profile \
     --driver=test_driver/integration_test.dart \
     --target=integration_test/migration_v8_timing_test.dart \
     -d <serial> \
     --dart-define=RUN_V8_TIMING=true \
     --dart-define=V8_TIMING_REPS=3 \
     --dart-define=DEVICE_MODEL="<model>" \
     --dart-define=DEVICE_OS="<os>"
   ```

### iOS (supported iPhone)
1. Xcode 15 or later; the iPhone is unlocked, trusted and in developer
   mode. A signing team is set for the Runner target
   (`open ios/Runner.xcworkspace`, Signing & Capabilities).
2. From the repository root:
   ```sh
   cd app
   flutter pub get
   flutter devices                   # note the iPhone's device id (UDID)
   tool/device_timing.sh ios <udid>
   ```
   `xcrun devicectl list devices` lists the same iPhone; it accepts the
   UDID as well.
3. The script records the marketing name, product type, chip and iOS
   version through `xcrun devicectl device info details` (check them
   against Settings › General › About on first use; devicectl reports no
   RAM size, so add it from the model's specification), then runs the same
   `flutter drive --profile` command with `-d <udid>`.

More repetitions: `V8_TIMING_REPS=5 tool/device_timing.sh ...` (minimum 3).

### Results
The script writes `app/build/device_timing/<platform>-<model>-<time>-<pid>/`:
- `device.txt`: platform, model and hardware, OS, commit and uncommitted
  file count (`unknown` when git is unavailable), repetitions, battery and
  storage (Android), Flutter version, start time;
- `report_data.json`: the result through `reportData` (driver);
- `result_from_log.json`: the same result rebuilt from the
  `V8_TIMING_JSON` log lines;
- `drive.log`: the full log.

It prints a summary: runs, median and worst, SQLite version, size, the
recovery and seed runs, the digests against the host and the outcome.
`build/` is not committed. Copy `device.txt` and the two JSON files into
the delivery record (or attach them) and fill in the template below.

## Results template

Copy once per device. Field names in brackets are keys of the result JSON.

| Item | Value |
|---|---|
| Date (UTC), commit (`device.txt`) | |
| Device model and hardware: SoC or chip, ABI, RAM (`environment.deviceModel`) | |
| CPU cores (`environment.processors`) | |
| OS version (`environment.deviceOs`) | |
| Build mode (`environment.buildMode`) | profile (AOT) |
| Evidence label (`evidence`) | |
| Migration (`migration`, `standIn`) | `v7to8`, false |
| Engine (`engine`) | app engine (background isolate) |
| SQLite version and source id (`sqliteVersion`, `sqliteSourceId`) | |
| Profile (`profile.spec`) | 5,000 exercises, 100,000 sets, 303 no-primary, 150 unknown equipment, 40 duplicate equipment, 2,000 invalid TRN-020, seed 2026110603 |
| Input record counts (`records.input.rowCounts`, `records.input.measured`) | |
| Start digest (`profile.startDigest`); equals host `v7 602dbcd0601b46b7`? (`hostReference.startMatches`) | |
| Migrated record counts: exercises, sets (`records.migrated.exercises`, `.sets`) | |
| Blocked exercises, total and by reason (`records.migrated.blockedExercises`, `.blockedExercisesByReason`) | |
| Reference bootstrap rows (`records.migrated.referenceBootstrap`) | |
| Report: runs, entries per table and action, counts; reconciled (`records.migrated.report`) | |
| End digest (`endState`); equals host `v8 7fc53371acfa16d7`? (`hostReference.endMatches`) | |
| Database size before / after, bytes (`dbBytesBefore`, `dbBytesAfter`) | |
| Runs, ms (`runs[].ms`) | |
| Median / worst, ms (`medianMs`, `worstMs`) | |
| Per-phase medians, ms (`phaseMedianMs`) | |
| Recovery: injected at, failed attempt / retry ms, version and integrity after the failure, ledger run id, outcome (`recovery`) | |
| Seed: source, bytes, SHA-256, equals the pin (`seed`) | |
| Seed run: ms, release 1 row, R-30 warnings, digest equals host `v8 63595160a687407b`? (`seedRun`, `hostReference.seedRunEndMatches`) | |
| App database unchanged (`appDatabaseCheck`) | |
| Outcome (`outcome`) | pass / FAIL / INCOMPLETE / ERROR |
| Errors (`failures`, `error`, `recovery.failure` (expected: the injected one), `recovery.retryError`, `seedRun.error`) | |
| Material differences from the real production profile (section below; add anything device-specific) | |
| Notes (battery, temperature, other load; `device.txt`) | |

## Host baseline (not device evidence)

`flutter test --run-skipped --tags heavy --concurrency=1
test/migration_v8/timing/` (Linux VM, 4 vCPU, JIT, SQLite 3.54.1). These
figures show the harness works and give a relative baseline only.

Run of 2026-11-07 (working tree over 5e37008, harness `ws5-timing/2`):

| Migration | Engine | Runs (ms) | Median / worst (ms) | Recovery: injected at; failed attempt / retry (ms) | Seed run (ms) | Size before / after (bytes) | End digest | Outcome |
|---|---|---|---|---|---|---|---|---|
| v7 → v8 (`v7to8`) | App engine (background isolate) | 9,320; 8,413; 7,743 | 8,413 / 9,320 | `v8.setsClassified`; 5,535 / 8,284, recovered | 7,687 | 24,506,368 / 37,629,952 | `v8 7fc53371acfa16d7` | pass |
| v7 → v8 (`v7to8`) | Calling isolate | 3,005; 3,023; 2,771 | 3,005 / 3,023 | `v8.setsClassified`; 1,439 / 2,897, recovered | 2,702 | 24,506,368 / 37,629,952 | `v8 7fc53371acfa16d7` | pass |
| Historical v5 → v7 (STAND-IN) | App engine (background isolate) | 19,627; 18,929; 19,452 | 19,452 / 19,627 | `6:versionWritten`; 18,894 / 17,398, recovered | — | 15,384,576 / 24,571,904 | `v7 cb68ca68ae2be071` | pass |
| Historical v5 → v7 (STAND-IN) | Calling isolate | 7,442; 7,312; 7,488 | 7,442 / 7,488 | `6:versionWritten`; 7,509 / 6,934, recovered | — | 15,384,576 / 24,571,904 | `v7 cb68ca68ae2be071` | pass |

Per-phase medians of the v7 → v8 runs, app engine (ms): open and preflight
131; `v8.started` 362; baseline 108; tables 23; bootstrap 13; exercises
mapped 215, rebuilt 952, links written 2,902; sets classified 1,321,
rebuilt 325; integrity review 439; report 1,114; foreign keys 109;
self-checks 282; commit 54; close 7.

Migrated D04 record counts (the same on every run): 5,000 exercises,
100,000 sets; 484 blocked exercises (497 block rows: `noPrimaryTarget`
303, `unknownEquipment` 150, `invalidSecondaryTarget` 44); report run
`run-1` with 5,653 entries and integrity run `run-1:integrity` with 128,
reconciled; 2,522 `legacy_quarantine` rows (25 earlier); bootstrap
1 provider, 31 anatomy nodes, 21 equipment items; no catalogue release
(no seed setting). Seed run: one release 1 row with the pinned hash, no
R-30 warning, seed read once (30,818 bytes).

Host reference digests (`StateDigest`, the same on every platform when the
same rows are built and migrated). A device run must report the same
values; otherwise it did not build or migrate the same data, and the
harness reports `FAIL` with the difference in `failures`:

| Database | Digest |
|---|---|
| D04 profile at v7 (the v7 → v8 input; `profile.startDigest`) | `v7 602dbcd0601b46b7` |
| After the v7 → v8 migration (`endState`; run id `run-1`, fixed clock) | `v8 7fc53371acfa16d7` |
| Seed run: the input plus `seedExercisesVersion` = 1, migrated (`seedRun.digest`) | `v8 63595160a687407b` |
| Historical stand-in start: D04 profile at v5 | `v5 e18285a1cb9d27d2` |
| Historical stand-in end: after v5 → v7 | `v7 cb68ca68ae2be071` |

The kill and heavy suites upload their JSON reports as the CI artefact
`migration-v8-ws5-reports` (`build/migration_v8_ws5/host_timing.json`).

Observations from the host runs:
- The engine matters. The app engine (background isolate) takes about three
  times as long as the same run in the calling isolate, because every
  statement crosses the isolate boundary. Device figures must come from
  profile builds through the app engine, as the harness does.
- With the app engine, an error thrown by the migration reaches the caller
  wrapped in drift's `DriftRemoteException`. Code that reacts to a specific
  migration failure (for example the `quick_check` stop) must unwrap it.
- The v8 step's fingerprint reads the whole database file once before the
  first write (`v8.started`); on the D04 input that is about 24 MB.

## Material differences from the real production profile

The profile is a stress profile by decision. It differs from a real user's
database as follows (to be completed against the owner's own profile):
- **Size:** 5,000 exercises and 100,000 sets is far above a typical library
  and history.
- **Session rhythm:** a session every 6 hours from 2023-01-01 (4,531
  sessions, 24,968 session entries), with about 22 sets per session (3 to
  8 entries of 2 to 6 sets). Real training is daily at most, with fewer
  sets.
- **Exercise choice:** skewed toward low ids (cube of a uniform draw), so a
  few exercises carry most sets. Real usage is skewed too, but not in this
  shape.
- **Extremes, on purpose:** every 50th session entry has a 4,000-character
  note; some exercise names are about 2,000 characters; non-ASCII and quoted
  text; boundary values (load 0 and 1000 kg, 100 reps, heart rate 250,
  rest 3,600 s).
- **Dangling references:** 97 sets (in 26 entries) and 5 plan exercises name
  exercises that do not exist. Production can leave a few after deletions,
  not this many. The migration's integrity run reports them.
- **Legacy values at a fixed rate:** 303 exercises without a mappable
  primary, 150 with unknown equipment, 40 with a duplicate equipment id and
  2,000 sets (2 %) with invalid TRN-020 values. The unmapped "traps"
  secondaries also block 44 exercises (unreadable secondary target). In
  all: 497 block rows on 484 exercises.
- **Other data:** 1,000 measurements, 300 foods, 3,000 food log entries,
  40 recipes, 15 saved meals, 200 meal plan items, 25 earlier quarantine
  rows. These are modest and evenly spread.
- **Seed setting:** the D04 profile has no `seedExercisesVersion` setting.
  A real v7 install that imported the exercise library holds it (value 1),
  so its migration reads and hashes the 30,818-byte bundled seed and writes
  a release 1 record. The seed run covers that path separately; its cost is
  the difference between the seed run and a normal run. The seed run adds
  only the setting: the profile does not contain the seed's own exercises
  as supplied rows (its 89 supplied exercises are synthetic). Timing is
  unaffected, because the migration only hashes the seed bytes; it does not
  compare or reconcile the seed's exercises with the database.
- **Cold start:** the first app-engine run of a campaign also pays one-off
  costs (background isolate start, first library load, cold file cache,
  JIT warm-up on the host). It is usually the slowest of the runs and
  inflates the worst figure; the median is the steadier measure. On the
  host: 9,320 ms for the first v7 → v8 run against a median of 8,413 ms.
- **Not in the v7 input:** the reference bootstrap (1 provider, 31 anatomy
  nodes, 21 equipment items) and the migration report (a migration run and
  an integrity run) are written by the v7 → v8 migration itself. They
  appear only in the v8 result (`records.migrated`).
- **Historical stand-in (v5 input) only:** no session entries, splits,
  schedules or quarantine rows (v6/v7 tables). The chain creates the 24,968
  session entries in the v6 → v7 backfill and quarantines 364 rows in
  v5 → v6.
