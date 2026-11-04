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

## Independent review (fresh reviewer, owner condition)
A reviewer with no part in the implementation read `fb6ead5..08800c2` against the eleven owner controls, re-derived the UPC-E expansion against the standard, brute-forced the EAN-8/UPC-E check-digit collision, probed the session with gated fakes, and read both native shims. Findings and resolution:

| ID | Finding (verified) | Severity | Resolution |
|---|---|---|---|
| F1 | 58 % of valid UPC-E codes also satisfy the EAN-8 check digit; `validateBarcode` tried EAN-8 first and the adapter forwarded only the digits, so e.g. `02345659` got lookup key `0000002345659` instead of `0023456000059`. PLT-002 UPC-E effectively broken for lookup. | High | **Fixed (501dc6c)**: the hardware format crosses the boundary (`ScannedCode{raw, format?}`); hinted validation; unhinted ambiguous codes expose both keys, tried locally and online; raw 8 digits also tried online for EAN-8. Regression tests fail on the old logic. |
| F2 | `_running` was set after `await start()`, so cancel/dispose/manual submit during a real camera start skipped `stop()` and left the camera on. | High | **Fixed (501dc6c)**: `_running` set before the await; a stop waits for the in-flight start and runs after it; stop exactly once per start (scan-screen test tightened from `>= 1` to `1`). |
| F3 | No permission re-check after returning from system settings: a user who allowed the camera stayed on the dead screen. | Medium | **Fixed (501dc6c)**: lifecycle observer re-checks on resume while the permission screen is showing; "Check again" button; widget tests. |
| F4 | EAN-8 online key form could not be verified against live Open Food Facts (proxy). | Medium (unverified) | TD-34; checklist step 5 extended. |
| F5 | Re-scan of a custom food created from not-found untested; stale not-found state allowed creating a second food with the same barcode. | Low | **Fixed (501dc6c)**: `CreateCustomFood` rejects an existing barcode; the screen resumes scanning after creation. |
| F6 | Adapter swallows plugin failures with `debugPrint` (standards §5). | Low | TD-35 (with TD-32). |
| F7 | iOS shim's registrar guard fails silently. | Low | TD-35. |

**Re-verification (same reviewer, commit 501dc6c):** F1, F2, F3 and F5 RESOLVED with probes repeated (`02345659` hinted/unhinted keys; dispose/cancel/manual-submit during a gated start → stopped exactly once; lifecycle and "Check again" paths; duplicate-barcode guard incl. edit and deleted-food cases). No new defect beyond one low-severity stop/start interleaving within the camera start window, recorded as TD-36. Noted for device verification: on Android the permission dialog pauses the activity, so the lifecycle re-check supersedes the in-flight request and correctness rests on the plugin's status report (checklist steps 3 and 13).

Control status after the fixes: 1, 3, 4, 6, 8, 10, 11 met; 2 met (F3); 5 met (F5); 7 met (F1 tests, start/stop race tests); 9 met (F2). Integration test judged robust (every state change waited for with `pumpUntil`). Verified true by the reviewer: plugin imports confined to `lib/data/platform`; no second barcode lookup implementation; every lookup failure/not-found path creates and logs nothing; channel/method names, result types and threading of both shims correct; pins exact; adapter bound on Android/iOS only.

## Outstanding / debt
- D05 **V-01** (WP 5 airplane-mode verification) and the WP 6 device checklist: owner-performed; both block WP 6 acceptance.
- TD-32 (no `Logger`), TD-34 (EAN-8/UPC-E online key form), TD-35 (adapter failure visibility, iOS guard), TD-36 (stop/start interleaving in the camera start window).
- iOS: scanning cannot run on the simulator; device verification needs a development-signed build (D07 §2.4).
- ADR-0006 status Proposed; owner decision requested with acceptance.

## CI evidence
Appended at delivery.

## Physical-device verification
`docs/verification/wp6-device-checklist.md` (15 steps; step 15 is D05 V-01). Owner-performed; results recorded there and summarised here. iOS requires a development-signed build; if unavailable, recorded as "not testable", never as passed.
