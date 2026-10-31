# Delivery record — WP 0: Project recovery and technical baseline

Date: 2026-10-31
Branch: `ccr-ac6db77c-jcnexo` (feature branch; `main` untouched)
Commit SHA: (filled at commit time, see git log for this file)

## Files changed
- Added `docs/README.md`, `docs/engineering-standards.md`
- Added `docs/wp0/D01` … `D08`
- Added `docs/adr/README.md`, `ADR-0001` … `ADR-0004`
- Added `legacy/android/**` (verbatim extraction of `RepForge-v0.3.0-Android-source.zip`, plus `NOTICE.md`)
- Added `docs/delivery-record/WP0.md` (this file)
- No existing file was modified or deleted. Both ZIPs and the workflow remain as they were on `main`.

## Architectural decisions
- ADR-0001 Accepted (record decisions).
- ADR-0002, ADR-0003, ADR-0004 Proposed; owner decision required before WP 1.

## Tests executed
- No automated tests exist in the project. None could be run.
- Evidence gathering instead: GitHub Actions logs for runs 8 and 9 retrieved in full and grepped for compiler diagnostics; archive checksums compared with the extracted tree; local Gradle reproduction (results in D01 §5).

## Build results
- CI: 9 of 9 runs failed; latest run 41243131372 fails in `:app:kspDebugKotlin`.
- Local reproduction: see D01 §5.

## Outstanding defects
- TD-03, TD-04, TD-05 (compile blockers in the legacy archive) left unfixed by design; D08 §3 describes the optional fix.

## Known limitations of this investigation
- Camera, barcode and Google Play Services behaviour could not be exercised; no device.
- Framework scores in D02 are expert assessment, not measurements; WP 1 verifies them with a vertical slice.
- Library versions in D03 are not pinned; pinned in WP 1 after verification on both platforms.
