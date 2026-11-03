# D07 — CI/CD Strategy

Status: Proposed
Date: 2026-10-31

## 1. Assessment of the current workflow

File: `.github/workflows/build-android-apk.yml` (commit de7c0b1).

| Aspect | Finding |
|---|---|
| Source of code | Unzips `RepForge-v0.3.0-Android-source.zip` from the repo root at build time. The ZIP is the only source; nothing in git is directly buildable. |
| Trigger | `workflow_dispatch` and pushes that touch the ZIP or the workflow. A code change inside the ZIP is invisible to review. |
| Guard step | The "Check source archive exists" step tests for the v0.3.0 ZIP but its error message names `RepForge-Android-Project.zip`. Harmless but misleading. |
| Toolchain | Temurin JDK 17, android-actions/setup-android@v3, `sdkmanager "platforms;android-35" "build-tools;35.0.0"`, Gradle 8.11.1 via gradle/actions. This part now works (runs 8 and 9 reach Kotlin compilation). |
| Gradle wrapper | None in the archive; the workflow installs Gradle itself. Local and CI Gradle versions can drift. |
| Quality gates | None. No lint, no tests, no formatting, no dependency audit. |
| Artifact | Debug APK upload is defined but has never executed because the build never succeeds. |
| Node warning | Actions pinned to Node 20 versions (`checkout@v4`, `setup-java@v4`, etc.) are being force-run on Node 24; upgrade to the current majors in WP 1. |

Verdict: the workflow infrastructure is now adequate for a Gradle build, but it cannot be kept because it builds the wrong thing (a ZIP) and has no gates. It is replaced in WP 1, not patched.

## 2. Target pipeline (Flutter)

### 2.1 Workflows

| Workflow | Trigger | Runner | Steps | Artifacts |
|---|---|---|---|---|
| `ci.yml` | every push and PR | ubuntu-latest | checkout → Flutter (pinned via `.fvmrc`/`subosito/flutter-action`) → `flutter pub get` → `dart format --set-exit-if-changed` → `flutter analyze` → `dart run build_runner build --delete-conflicting-outputs` (verify generated code is up to date) → `flutter test --coverage` → upload coverage | coverage report |
| `android.yml` | push to main, PR, manual | ubuntu-latest | ci steps → `flutter build apk --debug` → (main only) `flutter build appbundle --release` with signing from secrets | `app-debug.apk`, `app-release.aab` |
| `ios.yml` | push to main, manual | macos-latest | ci steps → `flutter build ios --simulator --no-codesign` → (when signing configured) `flutter build ipa` with Fastlane match or App Store Connect API key from secrets | simulator `.app`, `.ipa` |
| `integration.yml` | nightly + manual | ubuntu-latest (Android emulator via `reactivecircus/android-emulator-runner`), macos-latest (iOS simulator) | `flutter test integration_test` | screenshots, logs |
| `debug-release.yml` | push to `main` or the active branch touching `app/**`, manual | ubuntu-latest | build per-ABI and universal debug APKs → move tag `debug-latest` → create/update prerelease → upload assets + SHA256SUMS (added 2026-11-03) | rolling GitHub Release with stable download URLs |
| `deps.yml` | weekly | ubuntu-latest | `dart pub outdated`, `osv-scanner` | report (not yet added; WP 14) |
| `release.yml` | tag `v*` | ubuntu + macos | build signed artefacts → create GitHub Release with changelog | APK/AAB/IPA (not yet added; WP 14) |

### 2.2 Required checks for merge to main
`format`, `analyze`, `test`, `android-debug`. iOS build required once a macOS runner budget is confirmed (see limitations).

### 2.3 Versioning
- Semantic version in `pubspec.yaml` (`version: 0.4.0+4`); build number = CI run number for internal builds.
- Changelog maintained in `CHANGELOG.md` (Keep a Changelog format); release workflow refuses a tag without a matching entry.

### 2.4 Secrets and signing
- Android: upload keystore stored as base64 in `ANDROID_KEYSTORE`, passwords in `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_PASSWORD`; decoded at build time to a temp file; never committed. Play App Signing recommended so the upload key can be rotated.
- iOS: requires an Apple Developer Program membership (paid). Signing via App Store Connect API key (`APP_STORE_CONNECT_KEY_ID`, `_ISSUER_ID`, `_KEY_P8`) and Fastlane `match` with a private certificates repo, or manual provisioning profiles stored as secrets. Until configured, iOS CI builds `--no-codesign` for the simulator only.
- All secrets live in GitHub Environments (`internal`, `release`) with required reviewers for `release`.

## 3. Limitations to document
- macOS runners cost roughly ten times Linux minutes on GitHub; limit iOS builds to main and tags until needed.
- HealthKit, camera and Health Connect cannot be exercised in CI; manual device test checklist is part of each release (D06, WP 14).
- Integration tests on emulators are slower and flakier than unit tests; keep them nightly and small.
- iOS simulator builds prove compilation and layout, not signing or App Store compliance.

## 4. Transition plan
1. **Done in WP 1:** `ci.yml`, `android.yml`, `ios.yml` and `integration.yml` exist and pass (`docs/delivery-record/WP1.md`). The old workflow `build-android-apk.yml` is renamed in its `name:` to "Legacy ZIP build (manual only)" and runs only on `workflow_dispatch`.
2. **Done 2026-11-03 (WP 2, first task):** the owner confirmed the APK on a physical device, PR #1 was merged, and the ZIPs plus `build-android-apk.yml` were removed under ADR-0003. The remaining workflows are the Flutter ones in §2.1.
