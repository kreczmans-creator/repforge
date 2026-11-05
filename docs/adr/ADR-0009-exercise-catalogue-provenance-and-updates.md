# ADR-0009: Exercise catalogue provenance, providers and idempotent updates

- Status: **Proposed** (WP 8 stage 3; owner approval required before implementation)
- Date: 2026-11-05
- Implements owner decisions of 2026-11-05: original RepForge-authored content with compatible openly licensed datasets allowed; multiple content providers; separation of system-supplied, user-created and imported exercises; catalogue updates never silently overwrite user customisations; idempotent import and update; provenance, validation, duplicate detection and integrity reporting.

## Context
WP 8's `ImportExerciseLibrary` imports a bundled file once per seed version and never updates an existing supplied exercise, so corrections and enrichment cannot ship. Exercises carry only `supplied` (true/false) and `copiedFromId`. The amendment needs a catalogue that grows over many releases, from more than one provider, with provenance and integrity evidence.

## Options considered
1. Keep import-once and ship only new exercises: cannot correct or enrich content.
2. **Versioned catalogue releases applied by an idempotent reconciler**: each provider ships a release; records carry a revision; the reconciler inserts, updates system-owned fields, and retires; user-owned data is never written.
3. Replace all system rows on each release: simple, but breaks references and risks user data.

## Decision (proposed)
Option 2.
1. **Source** of an exercise: `system` (from a content provider's catalogue release), `user` (created in the app, including a custom copy of a system exercise), `imported` (brought in by the user from a file or another app; proposed definition, OQ-21). Source is immutable after creation.
2. **Providers**: a registry of content providers (identifier, name, licence, attribution text, source URL). RepForge's own content is provider `repforge`. An openly licensed dataset is admitted only with its licence recorded and compatible with distribution in the app, and attribution shown where required. No proprietary third-party content.
3. **Catalogue release**: per provider, a versioned bundled asset (format version 2) containing reference data and exercises with `id`, `revision` and content. Validation is all-or-nothing per release.
4. **Reconciler** (one transaction per release, recorded in an import log with provider, release, counts and content hash):
   - new identifier → insert as `system`;
   - known identifier with a higher revision → update system-owned fields only (name, aliases, classifications, targets, relationships between system exercises, content, media references);
   - identifier absent from the release → `retired` (kept, hidden from discovery, readable in history; never deleted, identifier never reused);
   - same revision → no write (idempotent; a re-run changes nothing).
   User-owned data is never written by the reconciler: user and imported exercises, user state (favourites, hidden, last used), custom copies, user relationships, plans and history. A custom copy whose source was revised gets a "source updated" marker for the screen; its content is not changed.
5. **Duplicate detection**: normalised name and alias collisions across all sources are reported; within a system release they fail validation. A structural signature (primary targets, primary pattern, equipment set, laterality, mechanics) flags near-duplicates for editorial review without blocking.
6. **Integrity report**: generated from the shipped catalogue in CI — completeness of classifications, targets and content per exercise, relationship graph validity, duplicates, retired references, and the WP 8 coverage matrix. A failing integrity check fails the build for system content.

## Rationale
Revisions and a reconciler make releases repeatable and safe. Keeping system edits read-only for users (edits create copies, as in WP 8) means updates never collide with user changes. Retirement instead of deletion protects history and plans.

## Consequences
- The `seedExercisesVersion` setting is replaced by per-provider release records; the WP 8 seed becomes release 1 of provider `repforge` (identifiers unchanged).
- Backups include the import log and user state; the backup format version increases (older apps refuse the new file, as since WP 3).
- Editorial process (WP 8 stage 4) owns release content; the owner reviews each WP 8 stage 5 tranche.
