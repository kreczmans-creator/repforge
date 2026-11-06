# RepForge training taxonomy (controlled lists, WP 8)

- Status: **Proposed for owner approval** with WP 8 (2026-11-05). Normative for code once approved: the domain enums, the seed library and the filters use exactly these values.
- Requirements: D04 TRN-009 (category), TRN-010 (primary and secondary muscle groups), TRN-011 (equipment).
- Stored by the identifier in the first column; labels are display text and may be reworded without a migration.
- **WP 8 note (2026-11-05):** the owner approved a four-level anatomy with multiple primary and secondary targets (D04 §7). WP 8 stage 3 (ADR-0008, proposed) keeps every identifier below as a node or reference value; this list stays authoritative until WP 8 stage 3 is authorised and delivered. TRN-010(1) is amended to one or more primary targets.

## Categories (TRN-009) — exactly one per exercise
| Identifier | Label | Meaning |
|---|---|---|
| `push` | Push | Upper-body pressing (chest, shoulders, triceps) |
| `pull` | Pull | Upper-body pulling (back, rear delts, biceps) |
| `legs` | Legs | Lower-body (squat, hinge, lunge, isolation) |
| `core` | Core | Trunk flexion, rotation, anti-extension, carries |
| `fullBody` | Full body | Compound movements spanning upper and lower body |
| `cardio` | Cardio | Conditioning measured by time or distance |
| `mobility` | Mobility | Range-of-motion and stretching work |

## Muscle groups (TRN-010) — exactly one primary, zero or more secondary
| Identifier | Label |
|---|---|
| `chest` | Chest |
| `frontDelts` | Front delts |
| `sideDelts` | Side delts |
| `rearDelts` | Rear delts |
| `triceps` | Triceps |
| `biceps` | Biceps |
| `forearms` | Forearms |
| `upperBack` | Upper back (traps, rhomboids) |
| `lats` | Lats |
| `lowerBack` | Lower back |
| `abs` | Abs |
| `obliques` | Obliques |
| `glutes` | Glutes |
| `quadriceps` | Quadriceps |
| `hamstrings` | Hamstrings |
| `adductors` | Adductors |
| `abductors` | Abductors |
| `calves` | Calves |
| `fullBody` | Full body (cardio and conditioning) |

A primary group is never repeated in the secondary list.

## Equipment (TRN-011) — zero or more per exercise; zero means bodyweight only
| Identifier | Label |
|---|---|
| `barbell` | Barbell |
| `ezBar` | EZ bar |
| `trapBar` | Trap bar |
| `dumbbell` | Dumbbells |
| `kettlebell` | Kettlebell |
| `cable` | Cable station |
| `machine` | Machine (selectorised or plate-loaded) |
| `smithMachine` | Smith machine |
| `bench` | Bench |
| `squatRack` | Squat rack |
| `pullUpBar` | Pull-up bar |
| `dipBars` | Dip bars |
| `resistanceBand` | Resistance band |
| `plate` | Weight plate |
| `medicineBall` | Medicine ball |
| `rings` | Gymnastic rings |
| `treadmill` | Treadmill |
| `bike` | Exercise bike |
| `rower` | Rowing machine |
| `elliptical` | Cross-trainer |
| `skippingRope` | Skipping rope |

**Filter by available equipment** (TRN-011(2)): an exercise is shown when every item it requires is in the user's available set; bodyweight-only exercises (no items) are always shown.

## Exercise library content (OQ-09)
- **Assumption pending owner decision:** RepForge's own content — exercise names, aliases and classifications only; no images, videos or third-party text. Exercise names and anatomical classifications are factual and carry no licence. If the owner chooses a licensed or open dataset instead, only the seed asset changes.
- Library exercises are marked **supplied**; editing one creates a **custom copy** and leaves the supplied exercise unchanged (TRN-008(2)).
