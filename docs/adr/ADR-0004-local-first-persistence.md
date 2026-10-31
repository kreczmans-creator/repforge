# ADR-0004: Local-first persistence with SQLite via drift; cloud sync deferred

- Status: Proposed
- Date: 2026-10-31

## Context
The product must record food, training and measurements without an internet connection (owner brief §4.2). Personal body data is sensitive. No backend exists.

## Options considered
1. Remote-first (API backend as system of record, local cache).
2. Local-first SQLite with optional later sync.
3. Local NoSQL store (Hive/Isar) with optional later sync.

## Decision
Option 2: SQLite via drift is the system of record on device. Every row carries UUID, `createdAt`, `updatedAt`, `deletedAt?` so a sync layer can be added later without a schema rewrite. JSON backup/export ships before any cloud feature. Cloud sync, accounts and a backend are deferred to WP 12 and require a privacy policy.

## Rationale
Relational data (recipes → ingredients → foods; sessions → sets → exercises) suits SQL; drift provides versioned migrations and in-memory databases for tests, which directly addresses the data-integrity risk (R-07). Remote-first would make routine logging depend on connectivity, which the brief forbids.

## Consequences
- Migration tests are mandatory for every schema version.
- Encryption at rest is a separate decision in WP 3.
- Sync conflict resolution is designed, not implemented, until WP 12.
