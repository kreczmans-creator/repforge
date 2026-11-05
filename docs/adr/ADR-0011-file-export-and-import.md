# ADR-0011: Exporting and importing user files through a platform adapter (share_plus, file_selector)

- Status: **Proposed** (WP 10 decision D2; owner approval required before WP 10 stage 3)
- Date: 2026-11-05

## Context
WP 10 must deliver a CSV export of body measurements (BCM-009(1); D06 acceptance "export opens in a spreadsheet") and, per D06 and the WP 3 record, the screen for the existing full JSON backup export and restore (`DriftBackupRepository`, DAT-004/005). The app has no way to hand a file to the user or to read a file the user chooses. ADR-0006 requires every plugin to stay behind a Flutter-free port in `lib/data/platform/` with a fake for tests. No network use is involved; files stay under the user's control (ADR-0005 privacy posture).

## Options considered
1. **`share_plus`** for exports (writes a temporary file and opens the system share sheet: save to Files or Drive, email, another app) and **`file_selector`** (Flutter team) to pick a backup file for restore.
2. `file_picker` for both directions: one plugin, but its "save file" support differs by platform and it carries a larger native surface.
3. Save into the app's documents folder only: no plugin, but on iOS and Android the user cannot easily reach the file, so "opens in a spreadsheet" fails.

## Decision (proposed)
Option 1, behind a port `UserFileGateway` (export bytes with a file name and MIME type; pick a file of given types and return its bytes), with one adapter in `lib/data/platform/` and a fake for widget and integration tests. Versions pinned exactly to releases at least two weeks old: `share_plus` 13.3.1 (2026-10-01) and `file_selector` 1.1.0 (2025-11-21), subject to the Android build (AGP 9.1.0, compileSdk 36, release build with R8) and the iOS build; any SDK or manifest change is recorded in D03.

## Rationale
The share sheet is the platform-native way to put a file where the user wants it, and works the same for CSV and JSON. `file_selector` is maintained by the Flutter team and only reads a user-chosen file. The port keeps platform code out of feature code and lets every export and restore path be tested without a device.

## Consequences
- Two new pinned plugins; CI must stay green on Android (debug and release) and iOS.
- Temporary export files are written to the app cache and removed after sharing where the platform allows.
- Device behaviour of the share sheet and file picker is verified in the owner's device campaign.
- No second backup mechanism: the screen calls the existing `DriftBackupRepository`.
