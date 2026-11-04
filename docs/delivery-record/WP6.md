# Delivery record — WP 6: Barcode scanning and food logging

Date: 2026-11-04
Branch: `ccr-9fda2c32-wr163b`
Status: **in progress** (authorised by the owner 2026-11-04 after WP 5 acceptance; V-01 open and owner-owned, due at WP 6 acceptance).

## Scope (D06 WP 6, owner authorisation 2026-11-04)
`BarcodeScanner` interface and `mobile_scanner` adapter; Android and iOS camera permission handling with rationale and denial/retry paths; camera capability detection and unavailable-device behaviour; cached product table and persistence; scan → barcode lookup → portion → log; not-found path into custom food creation; integration tests with a fake scanner adapter; physical-device checklist for both platforms; fresh independent review before delivery. Engineering controls: reuse the WP 5 lookup contract; hardware and permissions behind the adapter boundary; test cancellation, permission denial, repeated scans, malformed barcodes, unknown products, offline lookup and duplicate submission; never create or log a product when lookup fails; coverage gate and four-workflow CI; ADRs, traceability, debt and this record updated.

## Decisions
- **ADR-0006 (proposed)**: `mobile_scanner` 7.5.0 for detection, `permission_handler` 12.0.1 for permission state, and a ~20-line native MethodChannel (`com.tempest.repforge/camera`, `hasCamera`) per platform for capability detection. All plugin imports live in `lib/data/platform/mobile_scanner_barcode_scanner.dart` and `camera_capability_channel.dart`.
- **Adapter boundary (PLT-001)**: feature code depends only on the Flutter-free `BarcodeScanner` interface (`lib/domain/scanning/barcode_scanner.dart`); the camera preview widget is supplied by the adapter through `scannerPreviewBuilderProvider`; `main.dart` binds the adapter on Android/iOS only, so tests and other platforms keep a throwing default and use `FakeBarcodeScanner`.
- **Barcode as a domain value**: EAN-13, EAN-8, UPC-A and UPC-E (PLT-002) validated by check digit; the lookup key is the 13-digit form Open Food Facts uses; UPC-E is expanded to UPC-A.
- **Lookup reuses WP 5**: `LookupBarcode` is local-first (`FoodRepository.byBarcode`), then `FoodLookupService.byBarcode`; an online hit is cached in `foods` (the "cached product table" — no new table; `foods.barcode` is indexed since WP 3) so a re-scan works offline; typed failures (offline, rate-limited, unavailable) pass through; nothing is created or logged when lookup fails or finds nothing.
- **Scan session state machine**: capability → permission (rationale on `denied`; "open settings" on `permanentlyDenied`/`restricted`) → scanning → lookingUp → found / notFound / failed. Hardware codes are accepted only while scanning (no double submission); the same code is ignored for 3 s after a result; every result stops the scanner until the user resumes; manual entry works in every state except during a lookup (PLT-002(2), PLT-004(1)); cancel and dispose stop the scanner and discard in-flight lookups.
- **Platform**: Android `CAMERA` permission and `camera.any` with `required="false"` (installs on devices without a camera); iOS `NSCameraUsageDescription`. No build-level changes were needed (minSdk 24, iOS 15.0 satisfy both plugins). First Android CI build (run 41841805057) failed: `permission_handler` 13.0.2 pulls `permission_handler_android` 14.1.1, which requires compileSdk 37 while AGP 9.1.0 supports at most 36. Resolved by pinning `permission_handler` 12.0.1 (`permission_handler_android` 13.0.1, compileSdk 35) rather than raising AGP/compileSdk mid-package; the plugin API used by the adapter is unchanged. Recorded in D03.

## What was built
| Stage | Commit | Content |
|---|---|---|
| 1 — domain, use case, session | e26e761 | `lib/domain/scanning/barcode.dart` (validation, formats, lookup key, UPC-E expansion), `barcode_scanner.dart` (interface, capability and permission enums); `LookupBarcode`; `ScanSession` notifier; `FakeBarcodeScanner`; providers (`barcodeScannerProvider` throwing default, `lookupBarcodeProvider`, `scanSessionProvider`, `scannerPreviewBuilderProvider`) |
| 2 — adapter and platform | e26e761, a8ac6a9 | `MobileScannerBarcodeScanner` (mobile_scanner 7.5.0, permission_handler 12.0.1), `CameraCapabilityChannel` with Kotlin/Swift `hasCamera` shims, manifest and Info.plist entries, `main.dart` binding on Android/iOS only; D03 pin table |
| 3 — UI and tests | 08800c2 | `/fuel/scan` screen for every session state (viewfinder preview, manual entry, rationale, open settings, found → portion sheet, not found → `new-food?barcode=`, offline/validation failures); scan action on the search screen hidden with explanation when no camera; `CustomFoodScreen.initialBarcode`; `scannerCapabilityProvider`; widget tests; emulator integration test |

## Tests
Local at 08800c2 (Flutter 3.47.9): **429 tests pass**, analyzer and formatter clean, hand-written coverage **88.7 %** (gate 80 %). New in WP 6 (53):
- `test/domain/scanning/barcode_test.dart` (11): EAN-13/EAN-8/UPC-A check digits, UPC-E classification and expansion (04252614 → 042100005264), rejects wrong check digit, letters, seven digits, inner whitespace.
- `test/features/nutrition/application/lookup_barcode_test.dart` (9): local hit without online call; online hit cached then found offline; not found stores nothing; offline/rate-limited/unavailable pass through typed, nothing written; invalid input; UPC-A under 13-digit key; raw-digit fallback.
- `test/features/nutrition/application/scan_session_test.dart` (22): capability/permission paths (denied rationale, permanently denied, restricted), codes ignored outside scanning, same code ignored for 3 s, malformed hardware code fails without lookup, offline failure typed, manual entry in every non-lookup state, cancel/dispose stop and unsubscribe, cancel discards in-flight lookup, resume re-checks permission.
- `test/data/platform/camera_capability_channel_test.dart` (4): true/false/missing handler/PlatformException.
- `test/features/nutrition/presentation/scan_screen_test.dart` (11, through the real router): action hidden and explained without a camera; manual entry without a camera; rationale → allow → scanning; permanently denied → open settings; known code → portion sheet → logged and popped; dismissed sheet resumes; unknown → not found → custom food pre-filled, created and logged; offline → retry, nothing stored; malformed manual entry; repeated emission → one lookup; cancel stops the scanner.
- `integration_test/app_test.dart` "scan a known barcode and log it (fake scanner)": seeded barcode scanned twice, 25 g logged (125 kcal), later emission does nothing, not-found path creates and logs nothing.

## Independent review
Appended at delivery (fresh reviewer, owner condition).

## Outstanding / debt
Appended at delivery.

## CI evidence
Appended at delivery.

## Physical-device verification
`docs/verification/wp6-device-checklist.md` (15 steps; step 15 is D05 V-01). Owner-performed; results recorded there and summarised here. iOS requires a development-signed build; if unavailable, recorded as "not testable", never as passed.
