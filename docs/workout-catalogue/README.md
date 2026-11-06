# Workout template catalogue (draft)

## Purpose
Draft content for owner decision **D-4** in `docs/verification/parallel-workstream-assessment-2026-11-06.md` (30 plans across 10 categories, referencing only the current 89 exercises). It is **not shipped**: there is no importer yet, and loading it needs a plan-metadata schema (category, difficulty, emphasis, equipment, target muscles, estimated minutes) that `WorkoutPlan` / `PlanExercise` do not have today. Exertion (RPE/RIR) and per-exercise instructions are also outside the current `PlanExercise`. No loads are prescribed.

File: `workout-templates-draft.json`. Every `exerciseId` is an id from `app/assets/seed/exercise_library.json`. `equipment` and `targetMuscles` are derived from the referenced exercises.

## Categories
| Category | Templates |
|---|---|
| chestTriceps | 3 |
| backBiceps | 3 |
| legs | 3 |
| upperBody | 3 |
| lowerBody | 3 |
| push | 3 |
| pull | 3 |
| fullBody | 3 |
| arms | 3 |
| shouldersCore | 3 |
| **Total** | **30** |

## Check
`python3 -I docs/workout-catalogue/check_catalogue.py` (run from the repository root)

It verifies counts, unique ids, library membership, type-appropriate fields (reps, duration or metres), the CHECK ranges (sets, reps, rest, RPE, RIR), and equipment/muscle consistency. It is a documentation-level check, not part of the app build.

## Library limits on variety
- **Heavy overlap between categories:** legs and lowerBody, upperBody/push/pull, and arms/chestTriceps/backBiceps share a small exercise pool, so templates in different categories repeat many exercises.
- **chestTriceps (bodyweight):** only push-up, dips and a chest stretch exist; plank pads it out.
- **backBiceps (dumbbell):** only rows, shrugs and curls; a dumbbell RDL stands in for extra back work.
- **arms:** only about 10 arm exercises; the dumbbell template adds push-ups and a farmer's carry.
- **shouldersCore (bodyweight):** there is no bodyweight shoulder exercise, so that variant is core-only.
- **Bodyweight and mobility variants:** few movements exist, so pull and lowerBody lean on stretches and cat-cow.
- **No isolated hip-hinge or vertical-push variety** beyond the listed exercises; cardio is not used in any template.
