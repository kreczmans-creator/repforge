# RepForge Engineering Standards

Status: Proposed (applies from WP 1). Enforced by CI where a tool exists; otherwise by review.

## 1. Language and formatting
- Dart 3, null-safe. `dart format` with default line length; CI fails on unformatted code.
- Lints: `very_good_analysis` (or `flutter_lints` plus the stricter rules listed in `analysis_options.yaml`); zero warnings policy in CI.

## 2. Naming
- Files `snake_case.dart`; types `UpperCamelCase`; members `lowerCamelCase`; constants `lowerCamelCase` (Dart style), no `SCREAMING_CASE`.
- Design-system widgets prefixed `Rf` (e.g. `RfCard`). Use cases named as verbs (`LogFoodEntry`). Repositories end in `Repository`; adapters end in `Adapter`; DTOs end in `Dto`.
- Units in names when a bare number would be ambiguous: `weightKg`, `quantityG`, `durationSec`. Prefer value types (`Grams`) over suffixes where practical.
- Same word for the same thing: *food* (a nutritional item), *entry* (a logged food), *recipe*, *portion* (the amount logged), *serving* (the recipe's defined unit), *exercise*, *session* (a performed workout), *plan* (a template), *set*, *measurement*.

## 3. Structure
- Layout per D03 §5. Features own their `application` and `presentation`; shared domain lives in `lib/domain`; data in `lib/data`.
- Import rule enforced by review and by an import-lint rule: `presentation` may not import `lib/data`; `domain` imports nothing from Flutter.

## 4. Dependency management
- All packages pinned to exact versions in `pubspec.yaml`; `pubspec.lock` committed.
- A new dependency requires: justification in the PR, licence check (permissive only), maintenance check (release within 12 months), and an ADR if it affects architecture.
- Weekly `dart pub outdated` and `osv-scanner` report in CI.

## 5. Error handling and logging
- Use cases return `Result<T, AppError>`; never throw across a layer boundary.
- No `catch (e)` that swallows; either map to `AppError` or rethrow.
- Logging via the `Logger` interface only; no `print`. No personal data in logs.

## 6. Data validation
- Validate at the use-case boundary: ranges, units, dates (ISO-8601), non-empty names.
- Database constraints mirror validation (NOT NULL, CHECK where drift supports it, foreign keys on).

## 7. Testing
- Unit tests for every domain rule and use case; widget tests for every screen state; integration tests for each P1 user flow.
- Tests mirror `lib/` paths under `test/`. Test names describe behaviour: `'scales protein by portion weight'`.
- Fakes over mocks for adapters; `mocktail` where a mock is clearer.
- Coverage threshold set in WP 1 and never lowered without an ADR.

## 8. Documentation
- Public domain types and use cases carry doc comments.
- Each work package updates: `docs/delivery-record/WP<n>.md`, affected ADRs, `CHANGELOG.md`.
- README explains how to build, test and run on both platforms in under one screen.

## 9. Git
- Branches: `main` (protected), `wp/<n>-<slug>` for work packages, `fix/<slug>` for defects.
- Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`, `refactor:`); subject ≤ 72 chars; body explains why.
- Pull request per work package or smaller; CI green and one review (owner) before merge; squash merge.
- Never commit secrets, keystores, provisioning profiles, or generated build output.

## 10. Placeholders and mock data
- Any mock data, placeholder screen or stubbed integration carries a `// TODO(placeholder)` comment at its definition so removal can be tracked.
- Mock data and stubbed integrations never ship in a release build.
- A placeholder screen may ship in a release build only when it is the `RfNotYetAvailable` component (visibly labelled "NOT YET AVAILABLE" with the work package that delivers the feature) and contains no other content. This keeps the five-pillar navigation stable across work packages without pretending a feature exists.

## 11. Security and privacy
- Permissions requested on first use with rationale text.
- No analytics or crash reporting without explicit opt-in.
- Export files written only to user-chosen locations.
