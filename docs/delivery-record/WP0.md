# Delivery record — WP 0: Project recovery and technical baseline

Date: 2026-10-31
Branch: `ccr-ac6db77c-jcnexo` (feature branch; `main` untouched)
Commit SHAs: 3625e78 (deliverables, legacy extraction) and the follow-up commit that adds build evidence (see `git log -- docs/delivery-record/WP0.md`).

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
- Local reproduction (scratch directory, Gradle 8.11.1, SDK 35): unmodified archive fails identically to CI; with two edits (DAO declaration, barcode import) it builds `app-debug.apk` (17.7 MB) with 0 errors and 4 deprecation warnings; the explicit lifecycle dependency was shown unnecessary by ablation. `gradle test`: NO-SOURCE. `gradle lint`: 0 errors, 8 warnings. Edits not applied to the repository.

## Outstanding defects
- TD-03 and TD-05 (compile blockers in the legacy archive) left unfixed by design; D08 §3 describes the optional fix. TD-04 downgraded to hygiene after build verification.

## Known limitations of this investigation
- Camera, barcode and Google Play Services behaviour could not be exercised; no device.
- Framework scores in D02 are expert assessment, not measurements; WP 1 verifies them with a vertical slice.
- Library versions in D03 are not pinned; pinned in WP 1 after verification on both platforms.
