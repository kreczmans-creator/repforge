# WP 6 physical-device checklist — barcode scanning (Android and iOS)

Scope: D06 WP 6 acceptance ("scan of a known EAN logs a correctly scaled entry on Android and iOS physical devices; unavailable camera hides the scan action with explanation") plus the open item D05 V-01 (WP 5 airplane-mode verification, six steps in `docs/delivery-record/WP5.md`). iOS requires a development-signed build on a device (D07 §2.4); if no Apple developer signing is available, record "not testable" with the reason — do not mark passed.

Record for each device: model, OS version, app build commit, tester, date.

| # | Step | Expected | Android result | iOS result |
|---|---|---|---|---|
| 1 | Fresh install (or clear app data). Open Fuel → Log food. | "Scan barcode" action visible (device has a camera). | | |
| 2 | Tap Scan. | Permission rationale shown before the system prompt. | | |
| 3 | Deny the system prompt. | Screen explains the camera is needed, offers Retry and manual code entry; nothing crashes. | | |
| 4 | Tap Retry and grant. | Live camera preview appears within 2 s. | | |
| 5 | Scan a printed EAN-13 you know is in Open Food Facts (e.g. 3017624010701, Nutella) with network on. Then an EAN-8 product and a UPC-E product (small packs; note the printed digits). | Each found within 3 s (PLT-002); portion sheet opens with the product name and per-100 values. Record which digits were printed and whether the product resolved (TD-34). | | |
| 6 | Log 25 g. | Diary entry shows 25 g with nutrients scaled from per-100; dashboard total updated. | | |
| 7 | Scan the same label again immediately (hold it in view). | One detection only; no duplicate lookup or duplicate entry (duplicate-submission prevention). | | |
| 8 | Enable airplane mode; scan the same barcode. | Found from the local cache without network; portion sheet opens. | | |
| 9 | Still offline, scan a barcode never scanned before. | "Offline" failure state with Retry and "Search manually"; nothing created or logged. | | |
| 10 | Network on; scan a barcode Open Food Facts does not know (e.g. an in-house label) or type 2000000000008 manually. | "Not found" state with "Create custom food" (barcode pre-filled) and "Search manually"; nothing logged. | | |
| 11 | Manual entry: type `12345` then `3017624010702`. | First: "Enter 8, 12 or 13 digits."; second: "That barcode is not valid." (check digit); no lookup performed. | | |
| 12 | Press back during scanning, then during a lookup. | Scanner stops; no entry created; returning to the diary shows no change. | | |
| 13 | Revoke the camera permission in system settings ("Don't allow"), reopen Scan. | Explains permission is denied permanently, offers "Open settings" and manual entry. | | |
| 14 | Android only: emulator image without camera, or a device with the camera disabled by policy. | Scan action hidden; a one-line explanation where the action would be. | | n/a |
| 15 | V-01: perform the six WP 5 airplane-mode steps. | All pass; record in the WP 5 table. | | n/a |

Any failure is a WP 6 defect (or, for step 15, a WP 5 defect that reopens WP 5).
