# Mapping of existing records to the proposed reference data — proposed

- Status: **Proposed — for owner approval.** WP 8 stage 4 (documentation and reference data only). Nothing in `app/` changes. Stage 3 uses this mapping to re-express the 89 seed exercises as catalogue release 2.
- Machine-readable source: `docs/catalogue/mapping-existing.json`.
- Inputs (read only): `app/assets/seed/exercise_library.json` (89 exercises, format version 1), `docs/training-taxonomy.md`.
- Answers part of OQ-22.

## 1. Principles
1. Every existing exercise id is kept. No exercise is renamed, merged or retired by this mapping.
2. Stored muscle values map one to one to nodes with the same id. Filters by an old id keep working because filtering includes descendants.
3. This mapping does **not** add primary targets. Where an extra primary target is arguable, the row says so and the owner decides, because a new primary target changes the attributed set counts WP 9 reports.
4. Mechanics, laterality and difficulty are not assigned here. The seed holds none of them; stage 3 and stage 5 fill them under the editorial guide.
5. Only four rows change a tag: two refinements to a finer node and two changes of meaning. They carry flags `R` and `M`.

Flag codes: **M** the meaning of a tag changes; **D** the current tag is debatable (kept as is); **E** the equipment tag is inaccurate and a proposed equipment item would fix it; **R** refinement to a finer node; **N** note on category or pattern.

## 2. (a) The 19 existing muscle ids
| Existing id | Node level | Parent node | Used as primary (of 89) | Used as secondary | Meaning changes? |
|---|---|---|---|---|---|
| `chest` | L2 | `regionChest` | 9 | 2 | No. |
| `frontDelts` | L4 | `deltoid` | 3 | 17 | No. Same muscle, now at its anatomical level. |
| `sideDelts` | L4 | `deltoid` | 1 | 2 | No. Same muscle, now at its anatomical level. |
| `rearDelts` | L4 | `deltoid` | 2 | 6 | No. Same muscle, now at its anatomical level. |
| `triceps` | L3 | `upperArmPosterior` | 5 | 10 | No. Same muscle, now at its anatomical level. |
| `biceps` | L3 | `upperArmAnterior` | 5 | 10 | No. Same muscle, now at its anatomical level. |
| `forearms` | L2 | `regionArm` | 2 | 11 | No. |
| `upperBack` | L2 | `regionBack` | 6 | 16 | No. |
| `lats` | L2 | `regionBack` | 7 | 8 | No. |
| `lowerBack` | L2 | `regionBack` | 1 | 9 | No. |
| `abs` | L2 | `regionTrunk` | 6 | 6 | No. |
| `obliques` | L2 | `regionTrunk` | 2 | 7 | No. |
| `glutes` | L2 | `regionHip` | 8 | 20 | No. |
| `abductors` | L2 | `regionHip` | 1 | 2 | No. |
| `adductors` | L2 | `regionHip` | 1 | 6 | No. |
| `quadriceps` | L2 | `regionThigh` | 17 | 9 | No. |
| `hamstrings` | L2 | `regionThigh` | 5 | 11 | No. |
| `calves` | L2 | `regionLowerLeg` | 2 | 9 | No. |
| `fullBody` | L1 | none | 6 | 1 | No. Non-anatomical; valid only as a primary target. |

Full definitions, inclusion and exclusion criteria are in `anatomy.md`.

## 3. (c) The seven existing categories and movement patterns
Categories stay. They are the coarse, one-per-exercise label (TRN-009). Patterns are a separate, richer classification. The categories are not derived from patterns, and patterns are not derived from categories.

| Category | Seed exercises | Pattern families that usually apply | Deviations in the seed |
|---|---|---|---|
| `push` | 16 | Upper-body push; elbow; shoulder joint | Lateral raise is `push` with `shoulderAbduction`. |
| `pull` | 18 | Upper-body pull; elbow; scapular; shoulder joint; wrist and grip | Curls and face pulls are `pull`. |
| `legs` | 24 | Lower-body compound; knee; hip; ankle and foot | Wall sit is `legs` with an isometric squat pattern. |
| `core` | 10 | Trunk movement; trunk stability; carries | Dead hang (`gripHold`) and farmer's carry (`carryBilateral`) are `core`. |
| `fullBody` | 5 | Conditioning; power; mixed | Sled push, kettlebell swing, clean and press, burpee, thruster. |
| `cardio` | 8 | Conditioning | All eight map to `walkRun`, `ergometer` or `skipping`. |
| `mobility` | 8 | Mobility and stretching | All eight map to `staticStretch`, `dynamicMobility` or `spinalMobility`. |

## 4. (b) The 89 existing exercises
Flag counts: M 2, D 37, E 5, R 5, N 4, no flag 36.

Columns show the seed tag and the proposed tag side by side. Where they match, nothing changes. The first pattern listed is the primary pattern.

| # | Id | Name | Category | Seed primary | Proposed primary | Seed secondary | Proposed secondary | Pattern(s) | Flag |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `lib-back-squat` | Barbell back squat | legs | `quadriceps` | `quadriceps` | `glutes`, `adductors`, `lowerBack` | `glutes`, `adductors`, `lowerBack` | `squat` |  |
| 2 | `lib-front-squat` | Barbell front squat | legs | `quadriceps` | `quadriceps` | `glutes`, `abs` | `glutes`, `abs` | `squat` |  |
| 3 | `lib-goblet-squat` | Goblet squat | legs | `quadriceps` | `quadriceps` | `glutes`, `adductors` | `glutes`, `adductors` | `squat` |  |
| 4 | `lib-hack-squat` | Hack squat | legs | `quadriceps` | `quadriceps` | `glutes` | `glutes` | `squat` |  |
| 5 | `lib-leg-press` | Leg press | legs | `quadriceps` | `quadriceps` | `glutes`, `adductors` | `glutes`, `adductors` | `squat` | **D** Classed as squat; a leg press is a machine press with a supported back. Reviewer may prefer a separate pattern. |
| 6 | `lib-leg-extension` | Leg extension | legs | `quadriceps` | `quadriceps` | none | none | `kneeExtension` |  |
| 7 | `lib-leg-curl` | Seated leg curl | legs | `hamstrings` | `hamstrings` | `calves` | `calves` | `kneeFlexion` | **R** Secondary calves stands for gastrocnemius. |
| 8 | `lib-lying-leg-curl` | Lying leg curl | legs | `hamstrings` | `hamstrings` | `calves` | `calves` | `kneeFlexion` | **R** Secondary calves stands for gastrocnemius. |
| 9 | `lib-romanian-deadlift` | Romanian deadlift | legs | `hamstrings` | `hamstrings` | `glutes`, `lowerBack`, `forearms` | `glutes`, `lowerBack`, `forearms` | `hinge` | **D** Glutes and lower back are arguably co-primary with hamstrings. Seed primary kept. |
| 10 | `lib-dumbbell-rdl` | Dumbbell Romanian deadlift | legs | `hamstrings` | `hamstrings` | `glutes`, `lowerBack`, `forearms` | `glutes`, `lowerBack`, `forearms` | `hinge` | **D** As Romanian deadlift. |
| 11 | `lib-deadlift` | Conventional deadlift | legs | `glutes` | `glutes` | `hamstrings`, `lowerBack`, `upperBack`, `forearms`, `quadriceps` | `hamstrings`, `lowerBack`, `upperBack`, `forearms`, `quadriceps` | `hinge` | **D** Seed primary is glutes alone. Hamstrings and lower back are arguably co-primary. Adding a primary changes attributed set counts, so the owner decides. |
| 12 | `lib-sumo-deadlift` | Sumo deadlift | legs | `glutes` | `glutes` | `adductors`, `hamstrings`, `quadriceps`, `lowerBack` | `adductors`, `hamstrings`, `quadriceps`, `lowerBack` | `hinge` | **D** As conventional deadlift; adductors tagged secondary. |
| 13 | `lib-trap-bar-deadlift` | Trap bar deadlift | legs | `quadriceps` | `quadriceps` | `glutes`, `hamstrings`, `upperBack`, `forearms` | `glutes`, `hamstrings`, `upperBack`, `forearms` | `hinge`, `squat` | **D** Hybrid of hinge and squat; hinge listed first. Quadriceps primary is defensible. |
| 14 | `lib-hip-thrust` | Barbell hip thrust | legs | `glutes` | `glutes` | `hamstrings`, `quadriceps` | `hamstrings`, `quadriceps` | `hipExtension` | **D** Quadriceps as secondary is doubtful; review. |
| 15 | `lib-glute-bridge` | Glute bridge | legs | `glutes` | `glutes` | `hamstrings` | `hamstrings` | `hipExtension` |  |
| 16 | `lib-walking-lunge` | Dumbbell walking lunge | legs | `quadriceps` | `quadriceps` | `glutes`, `hamstrings`, `adductors` | `glutes`, `hamstrings`, `adductors` | `lunge` |  |
| 17 | `lib-bodyweight-lunge` | Bodyweight lunge | legs | `quadriceps` | `quadriceps` | `glutes`, `hamstrings` | `glutes`, `hamstrings` | `lunge` |  |
| 18 | `lib-bulgarian-split-squat` | Bulgarian split squat | legs | `quadriceps` | `quadriceps` | `glutes`, `adductors` | `glutes`, `adductors` | `lunge` |  |
| 19 | `lib-step-up` | Dumbbell step-up | legs | `quadriceps` | `quadriceps` | `glutes` | `glutes` | `lunge` | **D** Step-up is classed with lunge and split stance. Equipment: bench in seed; plyoBox is the closer requirement. |
| 20 | `lib-bodyweight-squat` | Bodyweight squat | legs | `quadriceps` | `quadriceps` | `glutes` | `glutes` | `squat` |  |
| 21 | `lib-standing-calf-raise` | Standing calf raise | legs | `calves` | `gastrocnemius` | none | `soleus` | `plantarFlexion` | **R** Refined to gastrocnemius (primary) and soleus (secondary); standing with the knee straight. |
| 22 | `lib-hip-abduction` | Machine hip abduction | legs | `abductors` | `abductors` | `glutes` | `glutes` | `hipAbduction` | **D** Gluteus medius is the main mover but sits under Glutes; the seed primary abductors holds only tensor fasciae latae. Consider adding gluteusMedius as primary (changes attributed counts). |
| 23 | `lib-hip-adduction` | Machine hip adduction | legs | `adductors` | `adductors` | none | none | `hipAdduction` |  |
| 24 | `lib-bench-press` | Barbell bench press | push | `chest` | `chest` | `frontDelts`, `triceps` | `frontDelts`, `triceps` | `horizontalPush` |  |
| 25 | `lib-db-bench-press` | Dumbbell bench press | push | `chest` | `chest` | `frontDelts`, `triceps` | `frontDelts`, `triceps` | `horizontalPush` |  |
| 26 | `lib-incline-bench-press` | Incline barbell bench press | push | `chest` | `chest` | `frontDelts`, `triceps` | `frontDelts`, `triceps` | `horizontalPush` | **D** Incline emphasises the clavicular head only qualitatively. Optional refinement to pectoralisMajorClavicular. |
| 27 | `lib-incline-db-press` | Incline dumbbell press | push | `chest` | `chest` | `frontDelts`, `triceps` | `frontDelts`, `triceps` | `horizontalPush` | **D** As incline barbell press. |
| 28 | `lib-machine-chest-press` | Machine chest press | push | `chest` | `chest` | `frontDelts`, `triceps` | `frontDelts`, `triceps` | `horizontalPush` |  |
| 29 | `lib-cable-fly` | Cable chest fly | push | `chest` | `chest` | `frontDelts` | `frontDelts` | `shoulderHorizontalAdduction` |  |
| 30 | `lib-db-fly` | Dumbbell chest fly | push | `chest` | `chest` | `frontDelts` | `frontDelts` | `shoulderHorizontalAdduction` |  |
| 31 | `lib-push-up` | Push-up | push | `chest` | `chest` | `frontDelts`, `triceps`, `abs` | `frontDelts`, `triceps`, `abs` | `horizontalPush`, `antiExtension` | **R** Abs retained as secondary; anti-extension listed as second pattern. |
| 32 | `lib-overhead-press` | Barbell overhead press | push | `frontDelts` | `frontDelts` | `triceps`, `sideDelts`, `upperBack` | `triceps`, `sideDelts`, `upperBack` | `verticalPush` | **D** Upper back as secondary stands for upper trapezius. |
| 33 | `lib-db-shoulder-press` | Dumbbell shoulder press | push | `frontDelts` | `frontDelts` | `triceps`, `sideDelts` | `triceps`, `sideDelts` | `verticalPush` |  |
| 34 | `lib-lateral-raise` | Dumbbell lateral raise | push | `sideDelts` | `sideDelts` | `upperBack` | `upperBack` | `shoulderAbduction` |  |
| 35 | `lib-triceps-pushdown` | Triceps pushdown | push | `triceps` | `triceps` | none | none | `elbowExtension` |  |
| 36 | `lib-skull-crusher` | EZ bar skull crusher | push | `triceps` | `triceps` | none | none | `elbowExtension` |  |
| 37 | `lib-overhead-triceps-extension` | Overhead triceps extension | push | `triceps` | `triceps` | none | none | `elbowExtension` |  |
| 38 | `lib-dips` | Dips | push | `triceps` | `triceps` | `chest`, `frontDelts` | `chest`, `frontDelts` | `verticalPush` | **D** Triceps and chest are co-primary in practice, depending on lean. Pattern classed as vertical push: debatable. |
| 39 | `lib-assisted-dip` | Assisted dip (machine) | push | `triceps` | `triceps` | `chest`, `frontDelts` | `chest`, `frontDelts` | `verticalPush` | **D** As dips. |
| 40 | `lib-pull-up` | Pull-up | pull | `lats` | `lats` | `biceps`, `upperBack`, `forearms` | `biceps`, `upperBack`, `forearms` | `verticalPull` |  |
| 41 | `lib-chin-up` | Chin-up | pull | `lats` | `lats` | `biceps`, `upperBack` | `biceps`, `upperBack` | `verticalPull` | **D** Biceps is arguably co-primary. |
| 42 | `lib-assisted-pull-up` | Assisted pull-up (machine) | pull | `lats` | `lats` | `biceps`, `upperBack` | `biceps`, `upperBack` | `verticalPull` |  |
| 43 | `lib-band-assisted-pull-up` | Band-assisted pull-up | pull | `lats` | `lats` | `biceps`, `upperBack` | `biceps`, `upperBack` | `verticalPull` |  |
| 44 | `lib-lat-pulldown` | Lat pulldown | pull | `lats` | `lats` | `biceps`, `upperBack`, `rearDelts` | `biceps`, `upperBack`, `rearDelts` | `verticalPull` | **E** Equipment lists cable and machine together; a single class applies at coverage (cable). |
| 45 | `lib-seated-cable-row` | Seated cable row | pull | `upperBack` | `upperBack` | `lats`, `biceps`, `rearDelts` | `lats`, `biceps`, `rearDelts` | `horizontalPull` | **D** Lats arguably co-primary. Row primaries are inconsistent across the seed (upperBack here, lats for one-arm row). |
| 46 | `lib-barbell-row` | Barbell bent-over row | pull | `upperBack` | `upperBack` | `lats`, `biceps`, `lowerBack`, `rearDelts` | `lats`, `biceps`, `lowerBack`, `rearDelts` | `horizontalPull` | **D** As seated cable row. |
| 47 | `lib-db-row` | One-arm dumbbell row | pull | `lats` | `lats` | `upperBack`, `biceps`, `rearDelts` | `upperBack`, `biceps`, `rearDelts` | `horizontalPull` | **D** Primary lats while barbell and cable rows use upperBack. Harmonise during enrichment. |
| 48 | `lib-chest-supported-row` | Chest-supported machine row | pull | `upperBack` | `upperBack` | `lats`, `biceps`, `rearDelts` | `lats`, `biceps`, `rearDelts` | `horizontalPull` |  |
| 49 | `lib-inverted-row` | Inverted row | pull | `upperBack` | `upperBack` | `lats`, `biceps`, `rearDelts` | `lats`, `biceps`, `rearDelts` | `horizontalPull` | **E** Equipment lists barbell and squatRack; the barbell is a fixed bar here. Coverage baseline counts it as bodyweight. |
| 50 | `lib-face-pull` | Face pull | pull | `rearDelts` | `rearDelts` | `upperBack` | `upperBack` | `shoulderHorizontalAbduction`, `shoulderExternalRotation` | **D** Rear delts primary; infraspinatus and middle trapezius are likely co-targets. Second pattern external rotation. |
| 51 | `lib-rear-delt-fly` | Reverse pec deck | pull | `rearDelts` | `rearDelts` | `upperBack` | `upperBack` | `shoulderHorizontalAbduction` |  |
| 52 | `lib-shrug` | Dumbbell shrug | pull | `upperBack` | `trapeziusUpper` | `forearms` | `forearms` | `scapularElevation` | **R** Refined from upperBack to trapeziusUpper; filters by upperBack still match. |
| 53 | `lib-barbell-curl` | Barbell biceps curl | pull | `biceps` | `biceps` | `forearms` | `forearms` | `elbowFlexion` |  |
| 54 | `lib-db-curl` | Dumbbell biceps curl | pull | `biceps` | `biceps` | `forearms` | `forearms` | `elbowFlexion` |  |
| 55 | `lib-hammer-curl` | Hammer curl | pull | `biceps` | `biceps` | `forearms` | `forearms` | `elbowFlexion` | **D** Brachialis and brachioradialis emphasis is qualitative. Promoting either to primary would change meaning. |
| 56 | `lib-preacher-curl` | EZ bar preacher curl | pull | `biceps` | `biceps` | none | none | `elbowFlexion` | **E** Equipment ezBar and bench; preacherBench proposed. |
| 57 | `lib-cable-curl` | Cable biceps curl | pull | `biceps` | `biceps` | `forearms` | `forearms` | `elbowFlexion` |  |
| 58 | `lib-plank` | Plank | core | `abs` | `abs` | `obliques`, `frontDelts` | `obliques`, `frontDelts` | `antiExtension` | **D** Front delts as secondary is doubtful; isometric hold. |
| 59 | `lib-side-plank` | Side plank | core | `obliques` | `obliques` | `abs`, `abductors` | `abs`, `abductors` | `antiLateralFlexion` | **D** Abductors secondary stands for gluteus medius, which sits under Glutes. |
| 60 | `lib-weighted-plank` | Weighted plank | core | `abs` | `abs` | `obliques` | `obliques` | `antiExtension` |  |
| 61 | `lib-dead-hang` | Dead hang | core | `forearms` | `forearms` | `lats`, `upperBack` | `lats`, `upperBack` | `gripHold` | **N** Category core; pattern gripHold. Category and pattern differ; allowed. |
| 62 | `lib-wall-sit` | Wall sit | legs | `quadriceps` | `quadriceps` | `glutes`, `calves` | `glutes`, `calves` | `squat` | **N** Category legs; timed isometric squat pattern. |
| 63 | `lib-hanging-leg-raise` | Hanging leg raise | core | `abs` | `abs` | `forearms`, `frontDelts` | `forearms`, `frontDelts` | `hipFlexion`, `trunkFlexion` | **D** Hip flexors arguably co-primary; front delts as secondary is doubtful. |
| 64 | `lib-cable-crunch` | Cable crunch | core | `abs` | `abs` | `obliques` | `obliques` | `trunkFlexion` |  |
| 65 | `lib-crunch` | Crunch | core | `abs` | `abs` | `obliques` | `obliques` | `trunkFlexion` |  |
| 66 | `lib-pallof-press` | Pallof press | core | `obliques` | `obliques` | `abs`, `frontDelts` | `abs`, `frontDelts` | `antiRotation` | **D** Primary obliques stands for anti-rotation bracing. |
| 67 | `lib-ab-wheel` | Ab wheel rollout | core | `abs` | `abs` | `lats`, `obliques` | `lats`, `obliques` | `antiExtension` | **E** Seed lists no equipment so it shows as bodyweight-only; abWheel proposed. |
| 68 | `lib-farmers-carry` | Farmer's carry | core | `forearms` | `forearms` | `upperBack`, `abs`, `obliques` | `upperBack`, `abs`, `obliques` | `carryBilateral` | **N** Category core; forearms primary. Upper trapezius and trunk bracing are co-targets. |
| 69 | `lib-sled-push` | Sled push | fullBody | `quadriceps` | `quadriceps` | `glutes`, `calves`, `frontDelts` | `glutes`, `calves`, `frontDelts` | `sledPushPull` | **E** Seed tags plate; sled proposed. Category fullBody. |
| 70 | `lib-kettlebell-swing` | Kettlebell swing | fullBody | `glutes` | `glutes` | `hamstrings`, `lowerBack`, `frontDelts` | `hamstrings`, `lowerBack`, `frontDelts` | `hinge` | **D** Front delts as secondary is doubtful; hinge listed as pattern (ballistic). |
| 71 | `lib-clean-and-press` | Dumbbell clean and press | fullBody | `frontDelts` | `frontDelts` | `glutes`, `quadriceps`, `upperBack`, `triceps` | `glutes`, `quadriceps`, `upperBack`, `triceps` | `explosiveLift`, `verticalPush` | **D** Primary frontDelts understates the lower-body drive. Candidate multiple primaries (changes attributed counts). |
| 72 | `lib-burpee` | Burpee | fullBody | `fullBody` | `fullBody` | none | none | `fullBodyConditioning` | **D** Only fullBody target. Consider anatomical secondaries. |
| 73 | `lib-thruster` | Barbell thruster | fullBody | `quadriceps` | `quadriceps` | `frontDelts`, `glutes`, `triceps` | `frontDelts`, `glutes`, `triceps` | `squat`, `verticalPush` | **N** Two patterns: squat then vertical push. |
| 74 | `lib-treadmill-run` | Treadmill run | cardio | `fullBody` | `fullBody` | `quadriceps`, `calves` | `quadriceps`, `calves` | `walkRun` | **D** Structural near-duplicate of outdoor run; differs by equipment only. Legitimate (equipment) variation. |
| 75 | `lib-incline-walk` | Incline treadmill walk | cardio | `glutes` | `glutes` | `calves`, `hamstrings` | `calves`, `hamstrings` | `walkRun` | **D** Primary glutes is a strong claim for incline walking; quadriceps and calves are as defensible. |
| 76 | `lib-stationary-bike` | Exercise bike | cardio | `quadriceps` | `quadriceps` | `glutes`, `calves` | `glutes`, `calves` | `ergometer` |  |
| 77 | `lib-rowing-machine` | Rowing machine | cardio | `fullBody` | `fullBody` | `lats`, `quadriceps` | `lats`, `quadriceps` | `ergometer` | **D** fullBody primary with lats and quadriceps secondary; acceptable. |
| 78 | `lib-cross-trainer` | Cross-trainer | cardio | `fullBody` | `fullBody` | none | none | `ergometer` |  |
| 79 | `lib-skipping` | Skipping | cardio | `calves` | `calves`, `fullBody` | `fullBody` | none | `skipping` | **M** Seed lists fullBody as a secondary target. fullBody is non-anatomical and valid only as a primary target, so it moves to primary beside calves. |
| 80 | `lib-run-400m` | 400 m run | cardio | `fullBody` | `fullBody` | `quadriceps`, `calves`, `hamstrings` | `quadriceps`, `calves`, `hamstrings` | `walkRun` | **D** Near-duplicate of outdoor run and treadmill run by structure. Review for merge or relationship. |
| 81 | `lib-outdoor-run` | Outdoor run | cardio | `fullBody` | `fullBody` | `quadriceps`, `calves` | `quadriceps`, `calves` | `walkRun` | **D** As 400 m run. |
| 82 | `lib-hip-flexor-stretch` | Hip flexor stretch | mobility | `quadriceps` | `hipFlexors` | `glutes` | `quadriceps`, `glutes` | `staticStretch` | **M** Seed primary quadriceps; the stretch targets iliopsoas. Primary moves to hipFlexors and quadriceps (rectus femoris) becomes secondary. Primary meaning changes. |
| 83 | `lib-hamstring-stretch` | Hamstring stretch | mobility | `hamstrings` | `hamstrings` | `lowerBack` | `lowerBack` | `staticStretch` |  |
| 84 | `lib-childs-pose` | Child's pose | mobility | `lats` | `lats` | `lowerBack` | `lowerBack` | `staticStretch` | **D** Lats primary; lower back and shoulders also lengthen. |
| 85 | `lib-cat-cow` | Cat-cow | mobility | `lowerBack` | `lowerBack` | `abs`, `upperBack` | `abs`, `upperBack` | `spinalMobility` | **D** Spinal mobility; erector spinae and thoracic spine. |
| 86 | `lib-thoracic-extension` | Thoracic spine extension | mobility | `upperBack` | `upperBack` | `lats` | `lats` | `spinalMobility` | **D** Upper back stands for thoracic spinal extensors and mid-back; lats secondary is doubtful. |
| 87 | `lib-worlds-greatest-stretch` | World's greatest stretch | mobility | `glutes` | `glutes` | `quadriceps`, `hamstrings`, `obliques` | `quadriceps`, `hamstrings`, `obliques` | `dynamicMobility` | **D** Multi-region movement; glutes primary is a choice. Hip flexors and thoracic spine are co-targets. |
| 88 | `lib-doorway-chest-stretch` | Doorway chest stretch | mobility | `chest` | `chest` | `frontDelts` | `frontDelts` | `staticStretch` |  |
| 89 | `lib-pigeon-pose` | Pigeon pose | mobility | `glutes` | `glutes` | `abductors` | `abductors` | `staticStretch` | **D** Deep hip rotators (piriformis) are arguably primary; abductors secondary is doubtful. |

## 5. Changes to review first
1. `lib-hip-flexor-stretch` (M): primary moves from `quadriceps` to `hipFlexors`.
2. `lib-skipping` (M): `fullBody` leaves the secondary list and becomes a primary target beside `calves`.
3. `lib-standing-calf-raise` and `lib-shrug` (R): refinements to finer nodes.
4. Equipment tags for `lib-ab-wheel`, `lib-sled-push`, `lib-preacher-curl`, `lib-inverted-row` and `lib-lat-pulldown` (E).
5. Candidate extra primary targets (D): deadlifts, Romanian deadlifts, dips, chin-up, rows, hanging leg raise, hip abduction, clean and press. The owner decides each, knowing that it changes attributed set counts.

## 6. Structural near-duplicates already in the seed
`lib-treadmill-run`, `lib-outdoor-run` and `lib-run-400m` share a primary target, a primary pattern and laterality. They differ by equipment, distance logging or setting. Treat `lib-treadmill-run` and `lib-outdoor-run` as an equipment variation of one canonical run, and decide whether `lib-run-400m` stays as a distinct distance entry. `lib-leg-curl` (seated) and `lib-lying-leg-curl` differ by body position and are a legitimate variation pair.
