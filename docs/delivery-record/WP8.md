# Delivery record — WP 8: Exercise library and training architecture

Date: 2026-11-05
Branch: `ccr-9fda2c32-wr163b`
Status: **in progress** (next defined package after WP 7's acceptance on 2026-11-05; depends on WP 4, accepted. WP 6 device verification and D05 V-01 remain open and owner-owned; they do not block WP 8.)

## Scope (D06 WP 8)
Exercise library (seeded, editable), categories, muscle groups, equipment, exercise type with type-specific set fields, workout plan and split models, history queries.
Acceptance (D06): a set of each exercise type can be stored and read back with correct fields; invalid combinations rejected at use-case level. Verification: unit tests; schema migration test.
Requirements: D04 TRN-001..012 (P1), TRN-013 (P1, model and reorder; the plan-builder screen is WP 9), TRN-014 (P2, split model), TRN-007 (P2, cardio energy).
Debt owned here: TD-23 (exercise archive guard), TD-25 (database CHECK constraints with the next schema version).

## Gap analysis against the WP 3 training model
| Requirement | WP 3 state | WP 8 change |
|---|---|---|
| TRN-005 timed set with optional added load; mm:ss entry | duration only | add optional added load; `parseDuration('mm:ss')` domain rule |
| TRN-006 km display at ≥ 1000 m | none | display rule, stored metres unchanged |
| TRN-007 cardio energy expended, labelled, not in nutrition balance | missing | optional energy with provenance; never read by nutrition |
| TRN-008 supplied vs custom, custom copy on edit, search by name and aliases ignoring case/diacritics | `isCustom` only | aliases, search key, copy-on-edit use case |
| TRN-009/010/011 controlled lists, filters | free text | enums per `docs/training-taxonomy.md`; filter queries (muscle: primary first; equipment: subset of available) |
| TRN-012 custom exercises, archive hides from pickers, kept in history | archive exists; TD-23 guard missing | validation use case; TD-23 guard |
| TRN-013 rep **range**, duration or distance targets, rest, reorder | single target reps | reps min–max, duration, distance targets; reorder rule |
| TRN-014 split: named workouts over a 1–14-day cycle with rest days | free-text `split` | split model and table |
| D06: invalid set/exercise combinations rejected at use-case level | no set-writing use case | `RecordSet` use case validating type match, reps 1–100, exertion, load/assistance steps, positive durations and distances (this also makes the WP 3 deferral of `validReps`/`validExertion` enforceable on the first exposed set-writing path) |
| History queries | sets for an exercise | per-exercise history by session, last performance |
| TD-25 | no CHECK constraints | CHECK constraints on training tables in schema v6 |

## Decisions (owner confirmation requested at delivery)
1. **Controlled lists**: `docs/training-taxonomy.md` (7 categories, 19 muscle groups, 21 equipment items), proposed for approval.
2. **OQ-09 exercise library source**: assumed RepForge's own content (names, aliases, classifications; no media). Owner decision required; replacing the seed asset is self-contained.
3. **UI scope**: WP 8 delivers the Train tab's exercise library (browse, search, filter, detail, custom exercise create/edit/archive). The plan builder, scheduling and session screens are WP 9.

## What was built
Appended per stage.

## Tests, review, CI
Appended at delivery.
