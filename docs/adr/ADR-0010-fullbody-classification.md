# ADR-0010: `fullBody` as a non-anatomical top-level anatomy node (amends ADR-0008 decision 2)

- Status: **Accepted** (owner, 2026-11-05; Q-F resolved). Proposed earlier the same day after WP 8 stage 4 review finding F08.
- Date: 2026-11-05
- Amends: ADR-0008 decision 2, last sentence. ADR-0008 otherwise stands.

## Context
ADR-0008 decision 2 says `fullBody` "becomes a non-anatomical target kind, not an anatomy node". The WP 8 delivery plan (§3–§5) and the owner's decision of 2026-11-05 ("retain `fullBody` as a non-anatomical top-level classification") treat it as a childless level-1 node flagged non-anatomical, and the stage 4 reference data follows that. The node form is needed because `exercise_targets.node_id` references `anatomy_nodes`, and stored WP 8 values (`fullBody` as a primary or secondary muscle) must remain valid after migration.

## Decision
`fullBody` is an anatomy node at level 1 with `non_anatomical = true` and no children.
1. It may **only** be the **single primary target** of qualifying whole-body or conditioning exercises.
2. It is **never a secondary target**, and **never accompanies anatomical primary targets**.
3. It is **excluded** from anatomical descendant roll-ups, anatomical coverage and attributed muscle set counts (OQ-19).
4. Reports may show it **separately**, explicitly labelled non-anatomical.
5. Existing stored uses that break rules 1–2 (for example a stored `fullBody` secondary) are **preserved historically** and **listed in the migration report**; they are never silently discarded. New system content that breaks rules 1–2 fails the integrity check; user content is reported.

## Consequences
- ADR-0008 decision 2's last sentence reads as amended here; all other ADR-0008 decisions are unchanged.
- No identifier changes.
- Integrity check IC-304 is an error for system content and a reported warning for user content (`docs/catalogue/quality-and-duplicates.md`).
