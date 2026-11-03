# RepForge

Cross-platform (Android and iOS) fitness, nutrition and body-composition app for body recomposition. Flutter and Dart, local-first SQLite, no account required.

## Download the latest Android test build

| File | Use when |
|---|---|
| [RepForge-debug-arm64-v8a.apk](https://github.com/kreczmans-creator/repforge/releases/download/debug-latest/RepForge-debug-arm64-v8a.apk) | Most phones made since 2017 (smallest download) |
| [RepForge-debug-universal.apk](https://github.com/kreczmans-creator/repforge/releases/download/debug-latest/RepForge-debug-universal.apk) | Unsure which to pick |

All assets and checksums: [debug-latest release](https://github.com/kreczmans-creator/repforge/releases/tag/debug-latest). It is rebuilt automatically from every push to the active branch (`.github/workflows/debug-release.yml`). These are debug builds for testing only; Android will warn about an unknown source. No iOS test build is distributed yet (simulator builds only; device builds need Apple signing).

## Project outline

| Area | Status | Where |
|---|---|---|
| Product | Nutrition, recipes, strength training, body measurements, goals and analytics; offline-first; metric by default | `docs/wp0/D04-product-requirements-baseline.md` |
| Architecture | Flutter + Riverpod + drift (SQLite) + go_router + freezed; layered domain / application / data / presentation; platform adapters | `docs/wp0/D03-target-architecture.md`, `docs/adr/` |
| Delivered | WP 0 recovery baseline; WP 1 foundation: body-weight logging end to end, design-system basics, 29 automated tests, CI for Android, iOS simulator and emulator integration tests | `docs/delivery-record/` |
| Next | WP 2 design system, WP 3 domain models and persistence with backup, then nutrition (WP 5–6), recipes, training, measurements, analytics | `docs/wp0/D06-work-package-roadmap.md` |
| Legacy | Kotlin prototype kept read-only for reference; does not compile | `legacy/android/`, `docs/wp0/D01-project-recovery-report.md` |

## Repository layout

| Path | What it is |
|---|---|
| `app/` | The Flutter application (source of truth). |
| `docs/` | Architecture decisions, work-package deliverables, engineering standards, delivery records. |
| `legacy/android/` | Read-only Kotlin prototype. |
| `.github/workflows/` | CI: quality gates, Android debug APK, iOS simulator build, emulator integration tests, rolling debug release. |

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
