# ADR-0011: Exporting and importing user files through a platform adapter (share_plus, file_selector)

- Status: **Accepted** (owner, 2026-11-05, WP 10 decision D2). Package compatibility (Android debug and release with R8, iOS) is verified before implementation; WP 10 stage 3 proceeds after the file-output implementation has been reviewed.
- Date: 2026-11-05

## Context
WP 10 must deliver a CSV export of body measurements (BCM-009(1); D06 acceptance "export opens in a spreadsheet") and, per D06 and the WP 3 record, the screen for the existing full JSON backup export and restore (`DriftBackupRepository`, DAT-004/005). The app has no way to hand a file to the user or to read a file the user chooses. ADR-0006 requires every plugin to stay behind a Flutter-free port in `lib/data/platform/` with a fake for tests. No network use is involved; files stay under the user's control (ADR-0005 privacy posture).

## Options considered
1. **`share_plus`** for exports (writes a temporary file and opens the system share sheet: save to Files or Drive, email, another app) and **`file_selector`** (Flutter team) to pick a backup file for restore.
2. `file_picker` for both directions: one plugin, but its "save file" support differs by platform and it carries a larger native surface.
3. Save into the app's documents folder only: no plugin, but on iOS and Android the user cannot easily reach the file, so "opens in a spreadsheet" fails.

## Decision
Option 1, behind a port `UserFileGateway` (export bytes with a file name and MIME type; pick a file of given types and return its bytes), with one adapter in `lib/data/platform/` and a fake for widget and integration tests. Versions pinned exactly to releases at least two weeks old: `share_plus` 13.3.1 (2026-10-01) and `file_selector` 1.1.0 (2025-11-21), subject to the Android build (AGP 9.1.0, compileSdk 36, release build with R8) and the iOS build; any SDK or manifest change is recorded in D03.

## Rationale
The share sheet is the platform-native way to put a file where the user wants it, and works the same for CSV and JSON. `file_selector` is maintained by the Flutter team and only reads a user-chosen file. The port keeps platform code out of feature code and lets every export and restore path be tested without a device.

## Consequences
- Two new pinned plugins; CI must stay green on Android (debug and release) and iOS.
- Temporary export files are written to the app cache and removed after sharing where the platform allows.
- Device behaviour of the share sheet and file picker is verified in the owner's device campaign.
- No second backup mechanism: the screen calls the existing `DriftBackupRepository`.

## Implementation record (stage 3a, 2026-11-05; uncommitted at the time of writing)
- Resolved: `share_plus` 13.3.1 (with `share_plus_platform_interface` 7.2.0, `cross_file` 0.3.5+5) and `file_selector` 1.1.0 (with `file_selector_android` 0.5.2+11, `file_selector_ios` 0.5.3+7, `file_selector_platform_interface` 2.7.0; desktop and web implementations as resolved). All published at least 17 days before 2026-11-05. Exact pins in `pubspec.yaml`; the lockfile diff is additions only.
- Compatibility (Dart 3.13.7 / Flutter 3.47.9, compileSdk 36, minSdk 24, AGP 9.1.0, iOS 15.0, R8) is recorded in `docs/delivery-record/WP10.md` (Stage 3a) and D03. No SDK bump was needed; `file_selector_ios` requires Flutter 3.47 or newer (the app already requires 3.47.9). Licences: all 17 new packages are BSD-3-Clause. file_selector 1.1.0 (2025-11-21) passes the 12-month release rule only until 2026-11-21 (tracked in WP10.md; federated packages are recent). One residual risk is left to CI: `file_selector_android` uses the Kotlin DSL `kotlin {}` accessor while this project sets `android.builtInKotlin=false`.
- Native changes: **none** in the app. share_plus merges its own `FileProvider` and receiver into the manifest; no Info.plist keys; no ProGuard rules.
- Port `UserFileGateway` (`lib/domain/files/user_file_gateway.dart`, Flutter-free): `exportFile` returns `ExportOutcome` (`shared`, `dismissed`, `resultUnknown`) and `pickFile` returns `PickedFile?` (`null` = cancelled; 50 MB limit, `FileTooLargeError`: checked before reading on iOS; on Android the plugin has already read the file into memory, so the limit only rejects it; the plugin's temporary copy is deleted after the attempt when its symlink-resolved location is under the cache, temporary or `Directory.systemTemp` directory; the exact iOS picker location is not verified, so this is best effort). `shared` does not mean "saved" and `dismissed` is neutral. Export folders are removed after sharing and stale ones (over one hour) at the next export (a share sheet open for over an hour can be swept by a concurrent export; accepted); on Android share_plus keeps its own app-private copy in `cache/share_plus` until the next share, which must not be deleted early. Added to the port beyond the minimum: `uniformTypeIdentifiers` (iOS filters only by UTI), optional `ShareAnchor` (iPad), `maxBytes`. `AppError` gained `UnavailableError` and `FileTooLargeError`. Adapter `ShareAndSelectorUserFileGateway` is the only importer of both plugins (architecture test); `FakeUserFileGateway` serves widget and integration tests; `userFileGatewayProvider` defaults to `UnavailableUserFileGateway` and `main.dart` binds the adapter on Android and iOS.
- Status remains Accepted. Stage 3b (CSV export UI and backup screen) follows the review of this adapter.
