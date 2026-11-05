# ADR-0010: `fullBody` as a non-anatomical top-level anatomy node (amends ADR-0008 decision 2)

- Status: **Proposed** (WP 8 stage 4 review finding F08; owner approval required)
- Date: 2026-11-05
- Amends: ADR-0008 decision 2, last sentence. ADR-0008 otherwise stands.

## Context
ADR-0008 decision 2 says `fullBody` "becomes a non-anatomical target kind, not an anatomy node". The WP 8 delivery plan (§3–§5) and the owner's decision of 2026-11-05 ("retain `fullBody` as a non-anatomical top-level classification") treat it as a childless level-1 node flagged non-anatomical, and the stage 4 reference data follows that. The node form is needed because `exercise_targets.node_id` references `anatomy_nodes`, and stored WP 8 values (`fullBody` as a primary or secondary muscle) must remain valid after migration.

## Decision (proposed)
`fullBody` is an anatomy node at level 1 with `non_anatomical = true` and no children. It is:
- excluded from anatomical descendant roll-ups in filters, from coverage measurement and from per-muscle attributed set counts (OQ-19), or shown separately and labelled non-anatomical;
- allowed for system content only as a primary target of conditioning or whole-body exercises where no defensible anatomical subset exists (editorial guide);
- whether it may appear as a secondary target, or as a primary alongside anatomical primaries, is an owner decision; until decided, existing stored uses are preserved and listed in the migration report.

## Consequences
- ADR-0008 decision 2's last sentence reads as amended here; all other ADR-0008 decisions are unchanged.
- No identifier changes.
