# RepForge

Cross-platform (Android and iOS) fitness, nutrition and body-composition app. Flutter and Dart, local-first SQLite.

| Path | What it is |
|---|---|
| `app/` | The Flutter application (source of truth). |
| `docs/` | Architecture decisions, work-package deliverables, engineering standards, delivery records. |
| `legacy/android/` | Read-only Kotlin prototype kept for reference (does not compile; see `docs/wp0/D01`). |
| `.github/workflows/` | CI: quality gates, Android debug APK, iOS simulator build, emulator integration tests. |

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

## Status

WP 1 (foundation and vertical slice): body-weight logging end to end. Roadmap: `docs/wp0/D06-work-package-roadmap.md`.
