# ADR-0006: Barcode scanning through a platform adapter (mobile_scanner, permission_handler, minimal native capability shim)

- Status: **Accepted** (owner approval 2026-11-04, WP 6 review)
- Date: 2026-11-04

## Context
WP 6 adds "scan → lookup → portion → log" (D04 NUT-006, PLT-001..004). The owner requires scanner hardware and platform permissions to stay behind an adapter boundary, a fake adapter for tests, graceful degradation without a camera or without permission (manual code entry), and no duplication of the WP 5 barcode lookup contract (`FoodLookupService.byBarcode`). D03 §2.5 already names `mobile_scanner` as the intended plugin.

## Options considered
1. **`mobile_scanner`** (ML Kit on Android, AVFoundation/Vision on iOS) for detection, **`permission_handler`** for permission status/request/open-settings, and a **~20-line native MethodChannel shim** per platform for "does this device have a camera" (PLT-003 capability detection before showing the scan action).
2. `camera` + `google_mlkit_barcode_scanning`: two plugins, frame plumbing in Dart, larger surface for the same result.
3. `flutter_barcode_scanner` / `barcode_scan2`: full-screen native UI with no control over states, permission flow or dedupe; poorly maintained.
4. Capability detection via a third plugin (`camera.availableCameras()`) instead of the shim: a heavy dependency for one boolean.

## Decision
Option 1. Feature code depends only on the Flutter-free domain interface `BarcodeScanner` (`lib/domain/scanning/barcode_scanner.dart`: capability, permission status/request/open settings, a stream of raw codes, start/stop). One adapter (`lib/data/platform/mobile_scanner_barcode_scanner.dart`) owns every plugin import; the preview widget is supplied by the adapter through a presentation-level provider. The fake adapter (`lib/data/platform/fake_barcode_scanner.dart`) drives widget and integration tests. Barcode validation (EAN-13, EAN-8, UPC-A, UPC-E check digits; normalised 13-digit lookup key) is a domain rule. Lookup reuses `FoodLookupService.byBarcode` behind a `LookupBarcode` use case that is local-first and caches an online hit in the `foods` table (the "cached product table"); nothing is created or logged when lookup fails or finds nothing.

## Rationale
`mobile_scanner` is the maintained mainstream choice with the four formats PLT-002 names and a controller API that lets the app own start/stop and dedupe. `permission_handler` gives the denial/permanent-denial distinction the rationale-and-retry flow needs. The shim keeps capability detection honest (a device without a camera hides the action, PLT-004) without a third plugin. Everything plugin-specific is confined to two files, so a replacement (option 2) would not touch feature code.

## Consequences
- Two new pinned plugins and native camera permission entries on both platforms; iOS deployment target/Android SDK levels raised only if the plugin requires it (recorded in D03).
- Scanning cannot run in CI or on the iOS simulator; device verification is a WP 6 acceptance condition (checklist in `docs/verification/wp6-device-checklist.md`).
- No images are stored or transmitted; only the decoded digits leave the adapter (ADR-0005 privacy posture unchanged).
- TD-32 (no `Logger`) applies to adapter failures until resolved.

## Approval
Approved by the owner on 2026-11-04: `mobile_scanner` for detection, `permission_handler` for permission state, the minimal native capability channel, the Flutter-free domain interface, the fake adapter for tests, and reuse of the WP 5 lookup service and `foods` table. The pin `permission_handler` 12.0.1 is approved (13.x requires compileSdk 37, unsupported by AGP 9.1.0).

**Standing constraint:** plugin isolation is retained. No feature-level code may depend on plugin APIs in later work; plugin imports stay in `lib/data/platform/`.
