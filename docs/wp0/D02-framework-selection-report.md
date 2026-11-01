# D02 — Framework Selection Report

Status: Accepted by owner on 2026-11-01 (ADR-0002)
Date: 2026-10-31
Scope: choice of cross-platform technology for RepForge on Android and iOS.

## 1. Decision context

- The only existing implementation is a single-activity Android prototype (Kotlin, Jetpack Compose, Room) of roughly 1,500 lines, shipped as a ZIP archive. It has never compiled in CI (see D01).
- The product must ship on Android and iOS from a shared codebase, offline-first, with camera/barcode scanning, a local relational database, charts and health-platform integration.
- Team shape: a single owner, developing with AI assistance, no dedicated iOS or Android specialist. This weights heavily towards one language, one toolchain, one test runner and predictable CI.
- No code in the existing prototype is large or sound enough for "reuse" to be a deciding factor (see D08). The decision is therefore made on product fit, not on sunk cost.

## 2. Options assessed

### Option A — Flutter (Dart)
Single Dart codebase renders its own UI on both platforms via Skia/Impeller. Native integration via platform channels and a large plugin ecosystem.

Relevant capability mapping (library choices to be pinned and verified in WP 1):

| Need | Candidate | Notes |
|---|---|---|
| State / DI | `riverpod` | Compile-time safe providers, testable without widgets |
| Local DB | `drift` (SQLite) | Type-safe SQL, versioned migrations, in-memory DB for unit tests, works on both platforms |
| Navigation | `go_router` | Declarative, deep-link ready |
| Barcode | `mobile_scanner` | ML Kit on Android, AVFoundation on iOS, one API |
| Health | `health` | Wraps Health Connect and HealthKit behind one API; capability gaps documented per platform |
| Notifications | `flutter_local_notifications` | Local only; no push needed |
| Background | `workmanager` | Limited on iOS by design (documented) |
| Secure storage | `flutter_secure_storage` | Keystore / Keychain |
| Charts | `fl_chart` | Pure Dart, themeable |
| Models | `freezed` + `json_serializable` | Immutable models, codegen |
| Tests | `flutter_test`, `mocktail`, `integration_test` | Unit, widget and on-device |
| Lint/format | `dart format`, `flutter analyze` + `very_good_analysis` | Deterministic in CI |

Strengths: one language for logic and UI; pixel-identical UI on both platforms; strongest widget-level test story of the three; mature CI patterns (GitHub Actions on `ubuntu` for Android, `macos` for iOS); web/desktop available later without re-architecture.

Weaknesses: Dart is new to the owner; the existing Kotlin code is not reusable; UI is not native-widget based (mitigated by Material 3 and Cupertino widgets); app binary larger than native.

### Option B — React Native (TypeScript)
JavaScript/TypeScript with native widgets via the New Architecture; Expo adds managed tooling (EAS) and config plugins.

Relevant capability mapping:

| Need | Candidate | Notes |
|---|---|---|
| State / DI | Zustand or Redux Toolkit; DI by module convention | No compile-time DI |
| Local DB | `expo-sqlite` / `op-sqlite` + Drizzle, or WatermelonDB | Viable; migration tooling less mature than drift |
| Navigation | React Navigation / Expo Router | Mature |
| Barcode | `expo-camera` or `react-native-vision-camera` + ML Kit frame processor | Two integration paths, native config |
| Health | `react-native-health` (HealthKit) and `react-native-health-connect` | Two separate libraries, two APIs |
| Notifications | `expo-notifications` | Mature |
| Background | `expo-background-fetch` / `expo-task-manager` | Same iOS limits |
| Charts | `victory-native` / `react-native-skia` | Good |
| Tests | Jest, React Native Testing Library, Maestro/Detox | Detox on iOS is CI-expensive |

Strengths: largest talent pool; TypeScript; Expo EAS makes iOS signing easy; hot reload.

Weaknesses: more moving parts (JS runtime, native modules, Metro, Hermes, New Architecture migration churn); two different health libraries; UI consistency needs more deliberate work; end-to-end testing on iOS is the least reliable of the three in CI; library breakage on upgrades is a recurring maintenance cost.

### Option C — Kotlin Multiplatform + Compose Multiplatform
Shared Kotlin for logic and (with Compose Multiplatform) UI; iOS via Kotlin/Native with a thin Swift host.

Relevant capability mapping:

| Need | Candidate | Notes |
|---|---|---|
| State / DI | Koin or kotlin-inject | Fine |
| Local DB | Room KMP (2.7+) or SQLDelight | Both credible |
| Navigation | Compose Navigation (multiplatform) / Decompose | Newer on iOS |
| Barcode | No single cross-platform library of note; needs `expect/actual` with ML Kit (Android) and AVFoundation/Vision (iOS, written in Swift or Kotlin/Native cinterop) | Owner-maintained native code on iOS |
| Health | Health Connect (Android) and HealthKit (iOS) via separate `expect/actual` implementations | Owner-maintained native code on iOS |
| Notifications / background / secure storage | Multiplatform libraries exist but are smaller and less proven | |
| Charts | Vico (multiplatform), Koala Plot | Younger than fl_chart |
| Tests | kotlin-test, Compose UI test (multiplatform), XCTest for iOS host | Compose UI tests on iOS are newer |

Strengths: keeps Kotlin; native performance; strongest typing; Compose skills carry over; shared logic model is excellent.

Weaknesses for RepForge specifically: every platform integration this product depends on (camera, barcode, HealthKit, notifications) must be written and maintained twice by the owner; iOS Compose UI and its tooling are the youngest of the three stacks; CI needs Xcode + Kotlin/Native toolchains and is the slowest to set up; a solo owner would carry Swift as a second language anyway.

## 3. Weighted decision matrix

Weights: Critical = 5, High = 3, Medium = 1. Scores 1 (poor) to 5 (excellent). Scores are the architect's assessment for this product and team; evidence and reasoning per row follow the table.

| Criterion | Weight | Flutter | React Native | KMP / CMP |
|---|---|---|---|---|
| Android and iOS support | 5 | 5 | 5 | 4 |
| Shared application code | 5 | 5 | 5 | 4 |
| UI quality and consistency | 3 | 5 | 3 | 3 |
| Camera and barcode integration | 3 | 4 | 4 | 2 |
| Offline-first operation | 5 | 5 | 4 | 5 |
| Local database support | 5 | 5 | 4 | 4 |
| Health platform integrations | 3 | 4 | 3 | 2 |
| Long-term maintainability | 5 | 4 | 3 | 4 |
| Developer productivity | 3 | 5 | 4 | 3 |
| Automated testing | 5 | 5 | 4 | 3 |
| CI/CD reliability | 5 | 4 | 3 | 3 |
| Performance | 3 | 4 | 3 | 5 |
| Ecosystem and library maturity | 3 | 5 | 5 | 3 |
| Future web/desktop potential | 1 | 5 | 3 | 3 |
| **Weighted total (max 270)** | | **251** | **209** | **192** |

Row rationale (abridged):

- Platform support / shared code: Flutter and RN ship one codebase for both; KMP shares logic fully but shared UI on iOS is the newest part of its stack and still needs a Swift host and per-platform integrations.
- UI consistency: Flutter owns its rendering, so one design system renders identically; RN relies on native widgets and needs more styling discipline; CMP on iOS is consistent but younger.
- Camera/barcode: Flutter and RN each have one widely used plugin; KMP has no equivalent and needs two native implementations.
- Offline-first / local DB: all three can do SQLite well. drift's migration and testing story is the most complete; RN's SQLite options are fragmented; Room KMP is credible but newer.
- Health: Flutter's `health` plugin wraps both platforms; RN needs two libraries; KMP needs two hand-written integrations.
- Maintainability: Flutter and KMP are statically typed with stable tooling; RN upgrades are the most frequent source of breakage.
- Testing: Flutter widget tests run headless on Linux CI in seconds; RN unit tests are good but UI tests need simulators; CMP iOS UI testing is immature.
- CI/CD: all three need macOS for iOS; Flutter's pipeline is the most documented and least configuration-heavy; RN adds Metro/Node layers; KMP adds Kotlin/Native + Xcode toolchain coupling.
- Performance: all adequate for a forms-and-charts app; KMP is native.
- Ecosystem: Flutter and RN are both large; KMP's multiplatform library pool is smaller.

## 4. Recommendation

**Adopt Flutter (Dart) for RepForge.** Record as ADR-0002.

Why this is the right choice for RepForge, not just in general:

1. RepForge is a data-entry and charting application with four platform touchpoints (camera/barcode, health platforms, notifications, secure storage). Flutter is the only option where each of those is one plugin with one API across both platforms, which matters most for a solo owner.
2. The product's core risk is data integrity (food logs, training logs, measurements). drift gives versioned migrations, type-safe queries and in-memory databases for unit tests, so the domain and persistence layers can be tested on Linux CI with no emulator.
3. The design-system requirement (section 6 of the brief) is easiest to meet when the framework renders the UI itself; one theme produces one identical result on both platforms.
4. The owner's acceptance criteria require reliable CI. Flutter's `analyze → test → build apk` path runs on free Linux runners in a few minutes; only the iOS build needs macOS.
5. Rejecting KMP is a deliberate trade: it would keep Kotlin, but it would make the owner responsible for Swift implementations of every integration and for the least mature UI and test tooling of the three. For a two-platform product with no iOS specialist, that is the wrong place to spend risk budget.
6. Rejecting React Native: it is viable, but its advantages (JS talent pool, Expo signing) matter less to a solo owner than its disadvantages (upgrade churn, fragmented health/DB libraries, weaker UI-test reliability).

## 5. Consequences

- The existing Android Kotlin prototype is **not migrated**. It is retained read-only as reference (see D08). Its reusable value is domain knowledge, the seed recipe data (as data, with provenance labels), colour tokens, and the Open Food Facts request shapes.
- Dart becomes the single application language. Platform-specific code is limited to plugin configuration and, where unavoidable, small Swift/Kotlin shims behind Dart interfaces.
- iOS builds require a macOS runner and an Apple Developer account for signing; see D07.

## 6. What would change this recommendation

- If the owner already has, or will hire, Kotlin + Swift engineering capacity, KMP becomes competitive (score gap narrows on integration and testing rows).
- If a web product became a first-class requirement within 12 months, Flutter's lead widens.
- If React Native/Expo were already in use elsewhere in the owner's business, the ecosystem familiarity could justify Option B.

## 7. Verification plan for the decision (WP 1)

Before any feature work, WP 1 builds a thin vertical slice in Flutter: one drift table, one riverpod provider, one screen, one `mobile_scanner` scan, one unit test, one widget test, one integration test, Android APK and iOS simulator build in CI. If any of these cannot be demonstrated, this report is revisited before WP 2.
