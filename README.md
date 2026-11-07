# RepForge

Cross-platform (Android and iOS) fitness, nutrition and body-composition app for body recomposition. Flutter and Dart, local-first SQLite, no account required.

## Download the latest Android test build

| File | Use when |
|---|---|
| [RepForge-debug-arm64-v8a.apk](https://github.com/kreczmans-creator/repforge/releases/download/debug-latest/RepForge-debug-arm64-v8a.apk) | Most phones made since 2017 (smallest download) |
| [RepForge-debug-universal.apk](https://github.com/kreczmans-creator/repforge/releases/download/debug-latest/RepForge-debug-universal.apk) | Unsure which to pick |

All assets and checksums: [debug-latest release](https://github.com/kreczmans-creator/repforge/releases/tag/debug-latest). It is rebuilt automatically from every push to the active branch (`.github/workflows/debug-release.yml`). These are debug builds for testing only; Android will warn about an unknown source. No iOS test build is distributed yet (simulator builds only; device builds need Apple signing).

### Test-build certificate

CI debug builds (`android.yml` and the rolling `debug-release.yml`) restore the Android debug keystore from the GitHub Actions cache (key `repforge-debug-keystore-v1`) and create it only when the cache misses, so successive test builds carry one certificate and install over each other. If the cache entry is evicted a new certificate is generated and the tester must uninstall once (back up data first). No keystore is ever committed (`docs/engineering-standards.md` section 9); the debug identity signs test builds only.

## Releases

A release is a tag `vX.Y.Z` pushed to the repository, which runs `.github/workflows/release.yml` (or a manual run naming an existing tag). The workflow runs the quality gates and refuses the tag unless `app/pubspec.yaml` has version `X.Y.Z` and `CHANGELOG.md` has a `## [X.Y.Z]` heading; that section becomes the GitHub Release notes. It builds a signed Android APK and app bundle and requires the repository secrets `ANDROID_KEYSTORE` (base64), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD` and `ANDROID_KEY_ALIAS`; if any is missing the job fails and nothing is published (unsigned and debug-signed builds are never released). iOS is a simulator build only until Apple signing is configured. Changelog rule: every user-visible change adds a line under `[Unreleased]` in `CHANGELOG.md`; the releasing commit moves them under the new version heading and bumps the pubspec version. No tag has been cut yet (the pubspec version is 0.4.0+1). Status and owner actions: `docs/delivery-record/WP14.md`.

## Project outline

| Area | Status | Where |
|---|---|---|
| Product | Nutrition, recipes, strength training, body measurements, goals and analytics; offline-first; metric by default | `docs/wp0/D04-product-requirements-baseline.md` |
| Architecture | Flutter + Riverpod + drift (SQLite) + go_router + freezed; layered domain / application / data / presentation; platform adapters | `docs/wp0/D03-target-architecture.md`, `docs/adr/` |
| Delivered | WP 0 recovery baseline; WP 1 foundation: body-weight logging end to end, design-system basics, 29 automated tests, CI for Android, iOS simulator and emulator integration tests | `docs/delivery-record/` |
| Next | WP 2 design system, WP 3 domain models and persistence with backup, then nutrition (WP 5–6), recipes, training, measurements, analytics | `docs/wp0/D06-work-package-roadmap.md` |
| Legacy | Kotlin prototype kept read-only for reference; does not compile. Original ZIP uploads removed from the tree (ADR-0003), still in git history | `legacy/android/`, `docs/wp0/D01-project-recovery-report.md` |

## Repository layout

| Path | What it is |
|---|---|
| `app/` | The Flutter application (source of truth). |
| `docs/` | Architecture decisions, work-package deliverables, engineering standards, delivery records. |
| `legacy/android/` | Read-only Kotlin prototype. |
| `.github/workflows/` | CI: quality gates, Android debug APK, iOS simulator build, emulator integration tests, rolling debug release, tagged release (`release.yml`). |

## Build and test

Requires Flutter **3.47.9** (pinned in `app/.fvmrc` and CI). Android builds need JDK 17+; iOS builds need macOS with Xcode.

```bash
cd app
flutter pub get --enforce-lockfile
dart run build_runner build --delete-conflicting-outputs   # drift + freezed codegen
dart format . && flutter analyze --fatal-infos
flutter test                                               # unit + widget tests
flutter test integration_test -d <device>                  # on a device/emulator
flutter build apk --debug                                  # Android
flutter build ios --simulator --no-codesign                # iOS (macOS only)
```
