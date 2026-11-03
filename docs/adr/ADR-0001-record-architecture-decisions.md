# ADR-0001: Record architecture decisions

- Status: Accepted
- Date: 2026-10-31

## Context
RepForge has had no written record of why its stack, structure or workflow look the way they do. The owner has required that every significant decision be documented before further feature work.

## Options considered
1. Decisions in commit messages only.
2. A single living architecture document.
3. Numbered Architecture Decision Records (ADRs) in the repository.

## Decision
Use numbered ADRs under `docs/adr/`, one file per decision, in this format.

## Rationale
ADRs are small, reviewable in pull requests, and preserve the context at the time of the decision. A living document loses history; commit messages are not discoverable.

## Consequences
- Every work package that changes architecture adds or supersedes an ADR.
- ADRs start as Proposed and move to Accepted only by the owner.
