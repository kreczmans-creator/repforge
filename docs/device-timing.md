# Device timing of the version 8 migration (WP 8 3b-9)

Status: harness ready; **device runs outstanding** (they need the owner's
devices). Until the v7 → v8 migration (3b-4) exists, the harness times the
historical chain v5 → v7 on the same profile as a **stand-in**. Its output
says so. Stand-in figures are not v8 migration timings and are not 3b-9
evidence.

Owner decision (D04 §7, 2026-11-06, "Device timing"): one mid-range Android
phone and one supported iPhone, with recorded specifications. Platform
evidence, not universal compatibility. At least three runs per device from an
identical restored start; median and worst duration, model, OS, SQLite
version, database size and outcome; a normal run and a recovery or retry run.
The profile is a stress profile; any material difference from the real
production profile is recorded.

## What runs

| Part | File |
|---|---|
| Profile builder (5,000 exercises, 100,000 sets, seed 2026110603) | `app/test/migration_v8/large/large_profile.dart` |
| Timing procedure (shared by host and device) | `app/test/migration_v8/timing/timing_harness.dart` |
| Migration under test (registry; 3b-4 adds v7 → v8 here) | `app/test/migration_v8/recovery/migration_registry.dart` |
| Device harness | `app/integration_test/migration_v8_timing_test.dart` |
| Driver (profile mode, `reportData`) | `app/test_driver/integration_test.dart` |
| Device script (model and OS capture, run, result files) | `app/tool/device_timing.sh` |
| Host timing (tag `heavy`) | `app/test/migration_v8/timing/host_timing_test.dart` |

Procedure (`runTimingCampaign`):
1. Build the profile once in a new temporary directory on the device, in the
   shape the migration starts from (v7 for 3b-4; v5 for the stand-in). This
   file is the restored start.
2. At least three normal runs. Each starts from a fresh copy whose state
   digest is checked equal to the start's. The timer covers the database
   open that runs the migration, through the app engine
   (`NativeDatabase.createInBackground`, as `drift_flutter` opens the app
   database).
3. One recovery/retry run: a fresh copy, a failure injected at the last
   step's version write (the most work lost), the rolled-back state checked
   (previous version, integrity ok), then a timed retry.
4. Every normal run and the retry must end in the same state.

Safety: the harness works only in a new directory under the app's cache
directory. It asserts that this directory is not the application-support
directory, which holds `repforge.sqlite`, and that the app's database file
is unchanged afterwards (size and modification time). It never opens that
file. The script does install the profile build of the app, so use a device
where that is acceptable. Back up the app's data first if the device holds
real data.

Without `--dart-define=RUN_V8_TIMING=true` (CI's emulator job runs every file
in `integration_test/`), the same procedure runs on a small smoke profile in
seconds.

## Procedure

Prerequisites: Flutter 3.47.9 on the PATH, the repository at the commit under
test, `flutter pub get` in `app/`. Profile mode needs a physical device
(no emulator or simulator). Debug-mode timings are not evidence.

### Android (mid-range phone)
1. Enable developer options and USB debugging; connect; `adb devices` lists
   the phone.
2. Charge above 50 %, close other apps, keep the screen on, and leave battery
   saver off. Note the room temperature if it is unusual.
3. From `app/`: `tool/device_timing.sh android <serial>`
   (`<serial>` from `adb devices`; optional if only one device).
4. The script records `manufacturer model (SoC, ABI, RAM)` and
   `Android release (API level)` through `adb shell getprop`, then runs
   `flutter drive --profile ... --dart-define=RUN_V8_TIMING=true`.

### iOS (supported iPhone)
1. Xcode 15 or later; the iPhone is unlocked, trusted and in developer mode.
   A signing team is set for the Runner target.
2. `xcrun devicectl list devices` gives the identifier.
3. From `app/`: `tool/device_timing.sh ios <identifier>`.
4. The script records the marketing name, product type and iOS version
   through `xcrun devicectl device info details` (check them against
   Settings › General › About on first use), then runs `flutter drive
   --profile`.

### Results
The script writes `app/build/device_timing/<platform>-<model>-<time>/`:
- `device.txt`: platform, model, OS, Flutter version, start time;
- `report_data.json`: the result through `reportData` (driver);
- `result_from_log.json`: the same result rebuilt from the
  `V8_TIMING_JSON` log lines;
- `drive.log`: the full log.

`build/` is not committed. Copy the two JSON files and `device.txt` into
the delivery record (or attach them) and fill in the template below.
Repetitions: `V8_TIMING_REPS=5 tool/device_timing.sh ...` (minimum 3).

## Results template

Copy once per device.

| Item | Value |
|---|---|
| Date (UTC), commit | |
| Device (model, SoC, RAM) | |
| OS version | |
| Build mode | profile (AOT) |
| Migration | v7 → v8 (3b-4) / stand-in v5 → v7 (say which) |
| SQLite version (`sqliteVersion`) | |
| Profile | 5,000 exercises, 100,000 sets, 303 no-primary, 150 unknown equipment, 40 duplicate equipment, 2,000 invalid TRN-020, seed 2026110603 |
| Database size before / after (bytes) | |
| Runs (ms) | |
| Median / worst (ms) | |
| Recovery run: failed attempt / retry (ms), outcome | |
| Outcome (`outcome`) | pass / FAIL |
| Material differences from the real production profile | |
| Notes (battery, temperature, other load) | |

## Host baseline (not device evidence)

`flutter test --run-skipped --tags heavy --concurrency=1
test/migration_v8/timing/` (Linux VM, 4 vCPU, JIT, SQLite 3.54.1). Stand-in
historical chain v5 → v7 on the large profile. These figures show the
harness works and give a relative baseline only.

See the WS5 hand-back for the latest figures. The kill and heavy suites
upload their JSON reports as the CI artefact `migration-v8-ws5-reports`.

Observations from the host runs:
- The engine matters. The app engine (background isolate) took about three
  times as long as the same run in the calling isolate. The v6 → v7 backfill
  sends about 75,000 statements, and each one crosses the isolate boundary.
  An AOT child process took about 11 s against about 20 s in the JIT test
  process. Device figures must come from profile builds through the app
  engine, as the harness does.
- With the app engine, an error thrown by the migration reaches the caller
  wrapped in drift's `DriftRemoteException`. Code that reacts to a specific
  migration failure (for example the `quick_check` stop) must unwrap it.

## Material differences from the real production profile

To be completed with the owner's profile. Known differences:
- The profile is synthetic and larger than a typical user database (stress
  profile by decision).
- The reference bootstrap and the migration report are written by the
  v7 → v8 migration itself, so they are not in the v7 input. They appear in
  the v8 result once 3b-4 exists.
- The stand-in v5 input has no session entries, splits, schedules or
  quarantine rows (v6/v7 tables). The v7 input has them.
