# ADR-0002: Adopt Flutter as the cross-platform framework

- Status: Proposed (owner decision required)
- Date: 2026-10-31

## Context
RepForge must ship on Android and iOS from a shared codebase (owner brief §1.2). The existing implementation is an Android-only Kotlin/Compose prototype that has never compiled and has no tests (D01). The team is a solo owner with AI assistance and no iOS specialist.

## Options considered
1. Flutter (Dart).
2. React Native (TypeScript, Expo).
3. Kotlin Multiplatform with Compose Multiplatform.
Full assessment and weighted matrix: D02.

## Decision
Adopt Flutter. Reimplement the application; do not migrate the Kotlin prototype.

## Rationale
Highest weighted score (251 vs 209 and 192) driven by the criteria the owner marked Critical: shared code, offline-first, local database, testing and CI reliability. Each of RepForge's platform integrations (camera/barcode, health, notifications, secure storage) is a single plugin with one API in Flutter, which minimises platform-specific code for a solo owner.

## Consequences
- Dart is the application language; Kotlin/Swift are limited to generated hosts and rare shims.
- Existing Kotlin code is retained read-only for reference (D08).
- iOS builds require a macOS runner and, for distribution, an Apple Developer account (D07).
- If the owner has Kotlin and Swift capacity, this ADR should be revisited in favour of KMP (D02 §6).
