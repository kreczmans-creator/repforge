# Delivery record — WP 6: Barcode scanning and food logging

Date: 2026-11-04
Branch: `ccr-9fda2c32-wr163b`
Status: **in progress** (authorised by the owner 2026-11-04 after WP 5 acceptance; V-01 open and owner-owned, due at WP 6 acceptance).

## Scope (D06 WP 6, owner authorisation 2026-11-04)
`BarcodeScanner` interface and `mobile_scanner` adapter; Android and iOS camera permission handling with rationale and denial/retry paths; camera capability detection and unavailable-device behaviour; cached product table and persistence; scan → barcode lookup → portion → log; not-found path into custom food creation; integration tests with a fake scanner adapter; physical-device checklist for both platforms; fresh independent review before delivery. Engineering controls: reuse the WP 5 lookup contract; hardware and permissions behind the adapter boundary; test cancellation, permission denial, repeated scans, malformed barcodes, unknown products, offline lookup and duplicate submission; never create or log a product when lookup fails; coverage gate and four-workflow CI; ADRs, traceability, debt and this record updated.

## Decisions
- **ADR-0006 (proposed)**: `mobile_scanner` 7.5.0 for detection, `permission_handler` 13.0.2 for permission state, and a ~20-line native MethodChannel (`com.tempest.repforge/camera`, `hasCamera`) per platform for capability detection. All plugin imports live in `lib/data/platform/mobile_scanner_barcode_scanner.dart` and `camera_capability_channel.dart`.
- **Adapter boundary (PLT-001)**: feature code depends only on the Flutter-free `BarcodeScanner` interface (`lib/domain/scanning/barcode_scanner.dart`); the camera preview widget is supplied by the adapter through `scannerPreviewBuilderProvider`; `main.dart` binds the adapter on Android/iOS only, so tests and other platforms keep a throwing default and use `FakeBarcodeScanner`.
- **Barcode as a domain value**: EAN-13, EAN-8, UPC-A and UPC-E (PLT-002) validated by check digit; the lookup key is the 13-digit form Open Food Facts uses; UPC-E is expanded to UPC-A.
- **Lookup reuses WP 5**: `LookupBarcode` is local-first (`FoodRepository.byBarcode`), then `FoodLookupService.byBarcode`; an online hit is cached in `foods` (the "cached product table" — no new table; `foods.barcode` is indexed since WP 3) so a re-scan works offline; typed failures (offline, rate-limited, unavailable) pass through; nothing is created or logged when lookup fails or finds nothing.
- **Scan session state machine**: capability → permission (rationale on `denied`; "open settings" on `permanentlyDenied`/`restricted`) → scanning → lookingUp → found / notFound / failed. Hardware codes are accepted only while scanning (no double submission); the same code is ignored for 3 s after a result; every result stops the scanner until the user resumes; manual entry works in every state except during a lookup (PLT-002(2), PLT-004(1)); cancel and dispose stop the scanner and discard in-flight lookups.
- **Platform**: Android `CAMERA` permission and `camera.any` with `required="false"` (installs on devices without a camera); iOS `NSCameraUsageDescription`. No build-level changes were needed (minSdk 24, iOS 15.0 satisfy both plugins); `permission_handler_android` compiles against SDK 37 while the project uses 36 — recorded as an open check for the Android CI build.

## What was built
Appended per stage; see "Tests" and "CI evidence".

## Tests
Appended at delivery.

## Independent review
Appended at delivery (fresh reviewer, owner condition).

## Outstanding / debt
Appended at delivery.

## CI evidence
Appended at delivery.

## Physical-device verification
`docs/verification/wp6-device-checklist.md` (15 steps; step 15 is D05 V-01). Owner-performed; results recorded there and summarised here. iOS requires a development-signed build; if unavailable, recorded as "not testable", never as passed.
