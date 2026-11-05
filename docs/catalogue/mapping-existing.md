# Mapping of existing records to the proposed reference data — proposed

- Status: **Proposed — for owner approval.** WP 8 stage 4 (documentation and reference data only). Nothing in `app/` changes. Stage 3 uses this mapping to re-express the 89 seed exercises as catalogue release 2.
- Machine-readable source: `docs/catalogue/mapping-existing.json` (format version 2). It holds the 19 muscle ids (`muscleIds`), the seven categories (`categories`), the seed provenance (`seedProvenance`) and the 89 exercises (`exercises`).
- Inputs (read only): `app/assets/seed/exercise_library.json` (89 exercises, format version 1), `docs/training-taxonomy.md`, `app/lib/data/db/tables.dart`.
- Answers part of OQ-22. Revision 2 (review findings F01, F04, F08, F13, F15, F21, F22, F23).

## 1. Principles
1. Every existing exercise id is kept. No exercise is renamed, merged or retired by this mapping.
2. Stored muscle values map one to one to nodes with the same id. Filters by an old id keep working because filtering includes descendants.
3. This mapping does **not** add primary targets. Where an extra primary target is arguable, the row says so and the owner decides through the single primary-target principle question (Q-P, section 8), because a new primary target changes the attributed set counts WP 9 reports.
4. **Release 2 must pass the integrity checks (F01).** The seed holds no mechanics, laterality or difficulty, so this mapping assigns all three to all 89 exercises under the editorial guide (sections 6 and 7). **These values, the attributes and the aliases added or removed are proposed content for owner review**, not facts from the seed.
5. **Mechanics for cardio and mobility.** The proposed default is an empty value for the 16 cardio and mobility exercises, with IC-207 not applied to those two categories. This is an open owner question (Q-M). If the owner prefers a forced value, the 16 rows are the only ones to change.
6. **Seed provenance (IC-212).** All 89 exercises carry provider `repforge` and author "RepForge editorial (WP 8 seed)", reviewer empty. The owner may name a person or role instead.
7. **Equipment roles (F21).** `proposedEquipment` lists the items; `equipmentRoles` overrides an item's default role in this exercise (load or support); `proposedClass` is derived by the rule in `equipment.md`. The only override is the barbell in the inverted row (support).
8. **fullBody (F08).** `lib-skipping` keeps `calves` as its only primary. The seed's `fullBody` secondary is preserved as stored and listed in the migration report; it is not promoted to primary. Whether `fullBody` may be a secondary is an owner question (Q-F).

Flag codes: **M** the meaning of a tag changes; **D** the current tag is debatable (kept as is); **E** the equipment tag is inaccurate and `proposedEquipment` fixes it; **R** refinement to a finer node, applied in the proposed list; **S** the secondary list changes (an addition or removal); **N** note on category or pattern. Flags were re-checked at revision 2 against these meanings (F22).

Flag counts: D 37, E 6, M 2, N 5, R 5, S 1; rows with no flag 36.

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
| `fullBody` | L1 | none | 6 | 1 | No. Flagged non-anatomical, childless L1 node (ADR-0010 proposed). Stored uses, including the one secondary use, are preserved; whether it may be secondary is an owner question. |

Counts are of the seed. Full definitions, inclusion and exclusion criteria are in `anatomy.md`.

## 3. (c) The seven existing categories and movement patterns
Categories stay. They are the coarse, one-per-exercise label (TRN-009). Patterns are a separate, richer classification. The categories are not derived from patterns, and patterns are not derived from categories.

| Category | Seed exercises | Pattern families that usually apply | Deviations in the seed |
|---|---|---|---|
| `push` | 16 | Upper-body push; elbow; shoulder joint | Lateral raise is `push` with `shoulderAbduction`. |
| `pull` | 18 | Upper-body pull; elbow; scapular; shoulder joint; wrist and grip | Curls and face pulls are `pull`. |
| `legs` | 24 | Lower-body compound; knee; hip; ankle and foot | Wall sit is `legs` with an isometric squat pattern. |
| `core` | 10 | Trunk movement; trunk stability; carries; wrist and grip; hip | Dead hang (`gripHold`), farmer's carry (`carryBilateral`) and hanging leg raise (`hipFlexion`) are `core`. |
| `fullBody` | 5 | Conditioning; power; mixed | Sled push, kettlebell swing, clean and press, burpee, thruster. The swing and the thruster trigger IC-311 (accepted warning). |
| `cardio` | 8 | Conditioning | All eight map to `walkRun`, `ergometer` or `skipping`. |
| `mobility` | 8 | Mobility and stretching | All eight map to `staticStretch`, `dynamicMobility` or `spinalMobility`. |

## 4. (b) The 89 existing exercises
Columns show the seed tag and the proposed tag side by side. Where they match, nothing changes. The first pattern listed is the primary pattern. Equipment is the proposed list; class is derived. Mechanics, laterality and difficulty are **proposed content** (empty mechanics = cardio and mobility default, Q-M).

| # | Id | Name | Category | Seed primary | Proposed primary | Seed secondary | Proposed secondary | Pattern(s) | Proposed equipment | Class | Mechanics | Laterality | Difficulty | Flag |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `lib-back-squat` | Barbell back squat | legs | `quadriceps` | `quadriceps` | `glutes`, `adductors`, `lowerBack` | `glutes`, `adductors`, `lowerBack` | `squat` | `barbell`, `squatRack` | freeWeight | compound | bilateral | intermediate |  |
| 2 | `lib-front-squat` | Barbell front squat | legs | `quadriceps` | `quadriceps` | `glutes`, `abs` | `glutes`, `abs` | `squat` | `barbell`, `squatRack` | freeWeight | compound | bilateral | intermediate |  |
| 3 | `lib-goblet-squat` | Goblet squat | legs | `quadriceps` | `quadriceps` | `glutes`, `adductors` | `glutes`, `adductors` | `squat` | `dumbbell` | freeWeight | compound | bilateral | beginner |  |
| 4 | `lib-hack-squat` | Hack squat | legs | `quadriceps` | `quadriceps` | `glutes` | `glutes` | `squat` | `machine` | machine | compound | bilateral | beginner |  |
| 5 | `lib-leg-press` | Leg press | legs | `quadriceps` | `quadriceps` | `glutes`, `adductors` | `glutes`, `adductors` | `squat` | `machine` | machine | compound | bilateral | beginner | **D** Classed as squat; a leg press is a machine press with a supported back (decision rule R7). Reviewer may prefer a separate pattern. |
| 6 | `lib-leg-extension` | Leg extension | legs | `quadriceps` | `quadriceps` | none | none | `kneeExtension` | `machine` | machine | isolation | bilateral | beginner |  |
| 7 | `lib-leg-curl` | Seated leg curl | legs | `hamstrings` | `hamstrings` | `calves` | `gastrocnemius` | `kneeFlexion` | `machine` | machine | isolation | bilateral | beginner | **R** Secondary calves refined to gastrocnemius (the muscle that crosses the knee); filters by calves still match. |
| 8 | `lib-lying-leg-curl` | Lying leg curl | legs | `hamstrings` | `hamstrings` | `calves` | `gastrocnemius` | `kneeFlexion` | `machine` | machine | isolation | bilateral | beginner | **R** As seated leg curl. |
| 9 | `lib-romanian-deadlift` | Romanian deadlift | legs | `hamstrings` | `hamstrings` | `glutes`, `lowerBack`, `forearms` | `glutes`, `lowerBack`, `forearms` | `hinge` | `barbell` | freeWeight | compound | bilateral | intermediate | **D** Glutes and lower back are arguably co-primary with hamstrings. Seed primary kept. Covered by the primary-target principle question (Q-P). |
| 10 | `lib-dumbbell-rdl` | Dumbbell Romanian deadlift | legs | `hamstrings` | `hamstrings` | `glutes`, `lowerBack`, `forearms` | `glutes`, `lowerBack`, `forearms` | `hinge` | `dumbbell` | freeWeight | compound | bilateral | intermediate | **D** As Romanian deadlift (Q-P). |
| 11 | `lib-deadlift` | Conventional deadlift | legs | `glutes` | `glutes` | `hamstrings`, `lowerBack`, `upperBack`, `forearms`, `quadriceps` | `hamstrings`, `lowerBack`, `upperBack`, `forearms`, `quadriceps` | `hinge` | `barbell` | freeWeight | compound | bilateral | intermediate | **D** Seed primary is glutes alone. Hamstrings and lower back are arguably co-primary. Adding a primary changes attributed set counts, so the owner decides (Q-P). |
| 12 | `lib-sumo-deadlift` | Sumo deadlift | legs | `glutes` | `glutes` | `adductors`, `hamstrings`, `quadriceps`, `lowerBack` | `adductors`, `hamstrings`, `quadriceps`, `lowerBack` | `hinge` | `barbell` | freeWeight | compound | bilateral | intermediate | **D** As conventional deadlift; adductors tagged secondary (Q-P). |
| 13 | `lib-trap-bar-deadlift` | Trap bar deadlift | legs | `quadriceps` | `quadriceps` | `glutes`, `hamstrings`, `upperBack`, `forearms` | `glutes`, `hamstrings`, `upperBack`, `forearms` | `hinge`, `squat` | `trapBar` | freeWeight | compound | bilateral | intermediate | **D** Hybrid of hinge and squat; hinge listed first (rule R7). Quadriceps primary is defensible, but the primary pattern is hinge, so the exercise counts toward no quadriceps slot (coverage-matrix.md section 11). |
| 14 | `lib-hip-thrust` | Barbell hip thrust | legs | `glutes` | `glutes` | `hamstrings`, `quadriceps` | `hamstrings`, `quadriceps` | `hipExtension` | `barbell`, `bench` | freeWeight | isolation | bilateral | intermediate | **D** Quadriceps as secondary is doubtful; listed for release-2 clean-up. |
| 15 | `lib-glute-bridge` | Glute bridge | legs | `glutes` | `glutes` | `hamstrings` | `hamstrings` | `hipExtension` | none | bodyweight | isolation | bilateral | beginner |  |
| 16 | `lib-walking-lunge` | Dumbbell walking lunge | legs | `quadriceps` | `quadriceps` | `glutes`, `hamstrings`, `adductors` | `glutes`, `hamstrings`, `adductors` | `lunge` | `dumbbell` | freeWeight | compound | alternating | intermediate |  |
| 17 | `lib-bodyweight-lunge` | Bodyweight lunge | legs | `quadriceps` | `quadriceps` | `glutes`, `hamstrings` | `glutes`, `hamstrings` | `lunge` | none | bodyweight | compound | unilateral | beginner |  |
| 18 | `lib-bulgarian-split-squat` | Bulgarian split squat | legs | `quadriceps` | `quadriceps` | `glutes`, `adductors` | `glutes`, `adductors` | `lunge` | `dumbbell`, `bench` | freeWeight | compound | unilateral | intermediate |  |
| 19 | `lib-step-up` | Dumbbell step-up | legs | `quadriceps` | `quadriceps` | `glutes` | `glutes` | `lunge` | `dumbbell`, `plyoBox` | freeWeight | compound | unilateral | beginner | **E** Equipment: bench in the seed; plyoBox is the closer requirement. Owner may keep bench. **D** Step-up is classed with lunge and split stance (rule R7). |
| 20 | `lib-bodyweight-squat` | Bodyweight squat | legs | `quadriceps` | `quadriceps` | `glutes` | `glutes` | `squat` | none | bodyweight | compound | bilateral | beginner |  |
| 21 | `lib-standing-calf-raise` | Standing calf raise | legs | `calves` | `gastrocnemius` | none | `soleus` | `plantarFlexion` | `machine` | machine | isolation | bilateral | beginner | **R** Refined to gastrocnemius (primary) and soleus (secondary); standing with the knee straight. |
| 22 | `lib-hip-abduction` | Machine hip abduction | legs | `abductors` | `abductors` | `glutes` | `gluteusMedius` | `hipAbduction` | `machine` | machine | isolation | bilateral | beginner | **R** Secondary glutes refined to gluteusMedius (functional double tag: one primary abductors, one secondary). **D** Gluteus medius is the main mover but sits under Glutes; the seed primary abductors holds only tensor fasciae latae. Whether gluteusMedius becomes a co-primary is part of Q-P (changes attributed counts). |
| 23 | `lib-hip-adduction` | Machine hip adduction | legs | `adductors` | `adductors` | none | none | `hipAdduction` | `machine` | machine | isolation | bilateral | beginner |  |
| 24 | `lib-bench-press` | Barbell bench press | push | `chest` | `chest` | `frontDelts`, `triceps` | `frontDelts`, `triceps` | `horizontalPush` | `barbell`, `bench`, `squatRack` | freeWeight | compound | bilateral | intermediate |  |
| 25 | `lib-db-bench-press` | Dumbbell bench press | push | `chest` | `chest` | `frontDelts`, `triceps` | `frontDelts`, `triceps` | `horizontalPush` | `dumbbell`, `bench` | freeWeight | compound | bilateral | intermediate |  |
| 26 | `lib-incline-bench-press` | Incline barbell bench press | push | `chest` | `chest` | `frontDelts`, `triceps` | `frontDelts`, `triceps` | `horizontalPush` | `barbell`, `bench`, `squatRack` | freeWeight | compound | bilateral | intermediate | **D** Incline emphasises the clavicular head only qualitatively. Optional refinement to pectoralisMajorClavicular (L4 tag, optional). |
| 27 | `lib-incline-db-press` | Incline dumbbell press | push | `chest` | `chest` | `frontDelts`, `triceps` | `frontDelts`, `triceps` | `horizontalPush` | `dumbbell`, `bench` | freeWeight | compound | bilateral | intermediate | **D** As incline barbell press. |
| 28 | `lib-machine-chest-press` | Machine chest press | push | `chest` | `chest` | `frontDelts`, `triceps` | `frontDelts`, `triceps` | `horizontalPush` | `machine` | machine | compound | bilateral | beginner |  |
| 29 | `lib-cable-fly` | Cable chest fly | push | `chest` | `chest` | `frontDelts` | `frontDelts` | `shoulderHorizontalAdduction` | `cable` | cable | isolation | bilateral | beginner |  |
| 30 | `lib-db-fly` | Dumbbell chest fly | push | `chest` | `chest` | `frontDelts` | `frontDelts` | `shoulderHorizontalAdduction` | `dumbbell`, `bench` | freeWeight | isolation | bilateral | intermediate |  |
| 31 | `lib-push-up` | Push-up | push | `chest` | `chest` | `frontDelts`, `triceps`, `abs` | `frontDelts`, `triceps`, `abs` | `horizontalPush`, `antiExtension` | none | bodyweight | compound | bilateral | beginner | **N** Abs retained as secondary; anti-extension listed as second pattern. |
| 32 | `lib-overhead-press` | Barbell overhead press | push | `frontDelts` | `frontDelts` | `triceps`, `sideDelts`, `upperBack` | `triceps`, `sideDelts`, `upperBack` | `verticalPush` | `barbell` | freeWeight | compound | bilateral | intermediate | **D** Upper back as secondary stands for upper trapezius; listed for clean-up. |
| 33 | `lib-db-shoulder-press` | Dumbbell shoulder press | push | `frontDelts` | `frontDelts` | `triceps`, `sideDelts` | `triceps`, `sideDelts` | `verticalPush` | `dumbbell`, `bench` | freeWeight | compound | bilateral | intermediate |  |
| 34 | `lib-lateral-raise` | Dumbbell lateral raise | push | `sideDelts` | `sideDelts` | `upperBack` | `upperBack` | `shoulderAbduction` | `dumbbell` | freeWeight | isolation | bilateral | beginner |  |
| 35 | `lib-triceps-pushdown` | Triceps pushdown | push | `triceps` | `triceps` | none | none | `elbowExtension` | `cable` | cable | isolation | bilateral | beginner |  |
| 36 | `lib-skull-crusher` | EZ bar skull crusher | push | `triceps` | `triceps` | none | none | `elbowExtension` | `ezBar`, `bench` | freeWeight | isolation | bilateral | intermediate |  |
| 37 | `lib-overhead-triceps-extension` | Overhead triceps extension | push | `triceps` | `triceps` | none | none | `elbowExtension` | `dumbbell` | freeWeight | isolation | bilateral | beginner |  |
| 38 | `lib-dips` | Dips | push | `triceps` | `triceps` | `chest`, `frontDelts` | `chest`, `frontDelts` | `verticalPush` | `dipBars` | bodyweight | compound | bilateral | intermediate | **D** Triceps and chest are co-primary in practice, depending on lean (Q-P). Pattern classed as vertical push (rule R8): debatable. |
| 39 | `lib-assisted-dip` | Assisted dip (machine) | push | `triceps` | `triceps` | `chest`, `frontDelts` | `chest`, `frontDelts` | `verticalPush` | `machine` | machine | compound | bilateral | beginner | **D** As dips. |
| 40 | `lib-pull-up` | Pull-up | pull | `lats` | `lats` | `biceps`, `upperBack`, `forearms` | `biceps`, `upperBack`, `forearms` | `verticalPull` | `pullUpBar` | bodyweight | compound | bilateral | intermediate |  |
| 41 | `lib-chin-up` | Chin-up | pull | `lats` | `lats` | `biceps`, `upperBack` | `biceps`, `upperBack` | `verticalPull` | `pullUpBar` | bodyweight | compound | bilateral | intermediate | **D** Biceps is arguably co-primary (Q-P). |
| 42 | `lib-assisted-pull-up` | Assisted pull-up (machine) | pull | `lats` | `lats` | `biceps`, `upperBack` | `biceps`, `upperBack` | `verticalPull` | `machine` | machine | compound | bilateral | beginner |  |
| 43 | `lib-band-assisted-pull-up` | Band-assisted pull-up | pull | `lats` | `lats` | `biceps`, `upperBack` | `biceps`, `upperBack` | `verticalPull` | `pullUpBar`, `resistanceBand` | band | compound | bilateral | intermediate |  |
| 44 | `lib-lat-pulldown` | Lat pulldown | pull | `lats` | `lats` | `biceps`, `upperBack`, `rearDelts` | `biceps`, `upperBack`, `rearDelts` | `verticalPull` | `cable` | cable | compound | bilateral | beginner | **E** Equipment lists cable and machine together, which means the exercise needs both. Proposed: cable only. |
| 45 | `lib-seated-cable-row` | Seated cable row | pull | `upperBack` | `upperBack` | `lats`, `biceps`, `rearDelts` | `lats`, `biceps`, `rearDelts` | `horizontalPull` | `cable` | cable | compound | bilateral | beginner | **D** Lats arguably co-primary. Row primaries are inconsistent across the seed (upperBack here, lats for one-arm row). This is the lead example of Q-P. |
| 46 | `lib-barbell-row` | Barbell bent-over row | pull | `upperBack` | `upperBack` | `lats`, `biceps`, `lowerBack`, `rearDelts` | `lats`, `biceps`, `lowerBack`, `rearDelts` | `horizontalPull` | `barbell` | freeWeight | compound | bilateral | intermediate | **D** As seated cable row (Q-P). |
| 47 | `lib-db-row` | One-arm dumbbell row | pull | `lats` | `lats` | `upperBack`, `biceps`, `rearDelts` | `upperBack`, `biceps`, `rearDelts` | `horizontalPull` | `dumbbell`, `bench` | freeWeight | compound | unilateral | beginner | **D** Primary lats while barbell and cable rows use upperBack. Harmonise once Q-P is answered. |
| 48 | `lib-chest-supported-row` | Chest-supported machine row | pull | `upperBack` | `upperBack` | `lats`, `biceps`, `rearDelts` | `lats`, `biceps`, `rearDelts` | `horizontalPull` | `machine` | machine | compound | bilateral | beginner |  |
| 49 | `lib-inverted-row` | Inverted row | pull | `upperBack` | `upperBack` | `lats`, `biceps`, `rearDelts` | `lats`, `biceps`, `rearDelts` | `horizontalPull` | `barbell`, `squatRack` (support: `barbell`) | bodyweight | compound | bilateral | beginner | **E** Equipment lists barbell and squatRack; the barbell is a fixed bar here, so it is a support item (equipmentRoles). The class is then bodyweight. |
| 50 | `lib-face-pull` | Face pull | pull | `rearDelts` | `rearDelts` | `upperBack` | `upperBack` | `shoulderHorizontalAbduction`, `shoulderExternalRotation` | `cable` | cable | isolation | bilateral | beginner | **D** Rear delts primary; infraspinatus and middle trapezius are likely co-targets. Second pattern external rotation. Mechanics isolation (F25). |
| 51 | `lib-rear-delt-fly` | Reverse pec deck | pull | `rearDelts` | `rearDelts` | `upperBack` | `upperBack` | `shoulderHorizontalAbduction` | `machine` | machine | isolation | bilateral | beginner |  |
| 52 | `lib-shrug` | Dumbbell shrug | pull | `upperBack` | `trapeziusUpper` | `forearms` | `forearms` | `scapularElevation` | `dumbbell` | freeWeight | isolation | bilateral | beginner | **R** Refined from upperBack to trapeziusUpper; filters by upperBack still match. |
| 53 | `lib-barbell-curl` | Barbell biceps curl | pull | `biceps` | `biceps` | `forearms` | `forearms` | `elbowFlexion` | `barbell` | freeWeight | isolation | bilateral | beginner |  |
| 54 | `lib-db-curl` | Dumbbell biceps curl | pull | `biceps` | `biceps` | `forearms` | `forearms` | `elbowFlexion` | `dumbbell` | freeWeight | isolation | bilateral | beginner |  |
| 55 | `lib-hammer-curl` | Hammer curl | pull | `biceps` | `biceps` | `forearms` | `forearms` | `elbowFlexion` | `dumbbell` | freeWeight | isolation | bilateral | beginner | **D** Brachialis and brachioradialis emphasis is qualitative. Promoting either to primary would change meaning. |
| 56 | `lib-preacher-curl` | EZ bar preacher curl | pull | `biceps` | `biceps` | none | none | `elbowFlexion` | `ezBar`, `preacherBench` | freeWeight | isolation | bilateral | beginner | **E** Equipment ezBar and bench; preacherBench proposed in place of bench. |
| 57 | `lib-cable-curl` | Cable biceps curl | pull | `biceps` | `biceps` | `forearms` | `forearms` | `elbowFlexion` | `cable` | cable | isolation | bilateral | beginner |  |
| 58 | `lib-plank` | Plank | core | `abs` | `abs` | `obliques`, `frontDelts` | `obliques`, `frontDelts` | `antiExtension` | none | bodyweight | compound | bilateral | beginner | **D** Front delts as secondary is doubtful; isometric hold. |
| 59 | `lib-side-plank` | Side plank | core | `obliques` | `obliques` | `abs`, `abductors` | `abs`, `abductors` | `antiLateralFlexion` | none | bodyweight | compound | unilateral | intermediate | **D** Abductors secondary stands for gluteus medius, which sits under Glutes. |
| 60 | `lib-weighted-plank` | Weighted plank | core | `abs` | `abs` | `obliques` | `obliques` | `antiExtension` | `plate` | freeWeight | compound | bilateral | beginner |  |
| 61 | `lib-dead-hang` | Dead hang | core | `forearms` | `forearms` | `lats`, `upperBack` | `lats`, `upperBack` | `gripHold` | `pullUpBar` | bodyweight | isolation | bilateral | beginner | **N** Category core; pattern gripHold. Category and pattern differ; allowed. |
| 62 | `lib-wall-sit` | Wall sit | legs | `quadriceps` | `quadriceps` | `glutes`, `calves` | `glutes`, `calves` | `squat` | none | bodyweight | compound | bilateral | beginner | **N** Category legs; timed isometric squat pattern. |
| 63 | `lib-hanging-leg-raise` | Hanging leg raise | core | `abs` | `abs` | `forearms`, `frontDelts` | `forearms`, `frontDelts`, `hipFlexors` | `hipFlexion`, `trunkFlexion` | `pullUpBar` | bodyweight | compound | bilateral | intermediate | **S** hipFlexors added as secondary (the pattern is hip flexion first). **D** Hip flexors arguably co-primary (Q-P); front delts as secondary is doubtful. |
| 64 | `lib-cable-crunch` | Cable crunch | core | `abs` | `abs` | `obliques` | `obliques` | `trunkFlexion` | `cable` | cable | isolation | bilateral | beginner |  |
| 65 | `lib-crunch` | Crunch | core | `abs` | `abs` | `obliques` | `obliques` | `trunkFlexion` | none | bodyweight | isolation | bilateral | beginner |  |
| 66 | `lib-pallof-press` | Pallof press | core | `obliques` | `obliques` | `abs`, `frontDelts` | `abs`, `frontDelts` | `antiRotation` | `cable` | cable | compound | bilateral | beginner | **D** Primary obliques stands for anti-rotation bracing; front delts secondary is doubtful. |
| 67 | `lib-ab-wheel` | Ab wheel rollout | core | `abs` | `abs` | `lats`, `obliques` | `lats`, `obliques` | `antiExtension` | `abWheel` | bodyweight | compound | bilateral | intermediate | **E** Seed lists no equipment so it shows as bodyweight-only; abWheel proposed. |
| 68 | `lib-farmers-carry` | Farmer's carry | core | `forearms` | `forearms` | `upperBack`, `abs`, `obliques` | `upperBack`, `abs`, `obliques` | `carryBilateral` | `dumbbell` | freeWeight | compound | bilateral | beginner | **N** Category core; forearms primary. Upper trapezius and trunk bracing are co-targets. |
| 69 | `lib-sled-push` | Sled push | fullBody | `quadriceps` | `quadriceps` | `glutes`, `calves`, `frontDelts` | `glutes`, `calves`, `frontDelts` | `sledPushPull` | `sled` | other | compound | bilateral | beginner | **E** Seed tags plate; sled proposed. Category fullBody. |
| 70 | `lib-kettlebell-swing` | Kettlebell swing | fullBody | `glutes` | `glutes` | `hamstrings`, `lowerBack`, `frontDelts` | `hamstrings`, `lowerBack`, `frontDelts` | `hinge` | `kettlebell` | kettlebell | compound | bilateral | intermediate | **D** Front delts as secondary is doubtful; hinge listed as pattern (ballistic, rule R6). |
| 71 | `lib-clean-and-press` | Dumbbell clean and press | fullBody | `frontDelts` | `frontDelts` | `glutes`, `quadriceps`, `upperBack`, `triceps` | `glutes`, `quadriceps`, `upperBack`, `triceps` | `explosiveLift`, `verticalPush` | `dumbbell` | freeWeight | compound | bilateral | intermediate | **D** Primary frontDelts understates the lower-body drive. Candidate for multiple primaries (Q-P). |
| 72 | `lib-burpee` | Burpee | fullBody | `fullBody` | `fullBody` | none | none | `fullBodyConditioning` | none | bodyweight | compound | bilateral | intermediate | **D** Only fullBody target. Consider anatomical secondaries; also depends on the fullBody-role question (Q-F). |
| 73 | `lib-thruster` | Barbell thruster | fullBody | `quadriceps` | `quadriceps` | `frontDelts`, `glutes`, `triceps` | `frontDelts`, `glutes`, `triceps` | `squat`, `verticalPush` | `barbell` | freeWeight | compound | bilateral | intermediate | **N** Two patterns in phase order: squat then verticalPush (rule R3). |
| 74 | `lib-treadmill-run` | Treadmill run | cardio | `fullBody` | `fullBody` | `quadriceps`, `calves` | `quadriceps`, `calves` | `walkRun` | `treadmill` | other | empty | alternating | beginner | **D** Structurally close to the outdoor run (equipment differs); legitimate equipment variation. |
| 75 | `lib-incline-walk` | Incline treadmill walk | cardio | `glutes` | `glutes` | `calves`, `hamstrings` | `calves`, `hamstrings` | `walkRun` | `treadmill` | other | empty | alternating | beginner | **D** Primary glutes is a strong claim for incline walking; quadriceps and calves are as defensible. |
| 76 | `lib-stationary-bike` | Exercise bike | cardio | `quadriceps` | `quadriceps` | `glutes`, `calves` | `glutes`, `calves` | `ergometer` | `bike` | other | empty | alternating | beginner |  |
| 77 | `lib-rowing-machine` | Rowing machine | cardio | `fullBody` | `fullBody` | `lats`, `quadriceps` | `lats`, `quadriceps` | `ergometer` | `rower` | other | empty | bilateral | intermediate | **D** fullBody primary with lats and quadriceps secondary; acceptable. |
| 78 | `lib-cross-trainer` | Cross-trainer | cardio | `fullBody` | `fullBody` | none | none | `ergometer` | `elliptical` | other | empty | alternating | beginner |  |
| 79 | `lib-skipping` | Skipping | cardio | `calves` | `calves` | `fullBody` | `fullBody` | `skipping` | `skippingRope` | other | empty | bilateral | intermediate | **D** Seed lists fullBody as a secondary. Proposal at revision 2: calves stays the only primary and the fullBody secondary is preserved as stored (ADR-0010 proposed) and listed in the migration report. Not promoted to primary. Depends on Q-F. |
| 80 | `lib-run-400m` | 400 m run | cardio | `fullBody` | `fullBody` | `quadriceps`, `calves`, `hamstrings` | `quadriceps`, `calves`, `hamstrings` | `walkRun` | none | bodyweight | empty | alternating | beginner | **D** Identical structure to the outdoor run (both distance logging, no equipment). Review for merge or relationship. |
| 81 | `lib-outdoor-run` | Outdoor run | cardio | `fullBody` | `fullBody` | `quadriceps`, `calves` | `quadriceps`, `calves` | `walkRun` | none | bodyweight | empty | alternating | beginner | **D** As 400 m run. |
| 82 | `lib-hip-flexor-stretch` | Hip flexor stretch | mobility | `quadriceps` | `hipFlexors` | `glutes` | `quadriceps`, `glutes` | `staticStretch` | none | bodyweight | empty | unilateral | beginner | **M** Seed primary quadriceps; the stretch targets iliopsoas. Primary moves to hipFlexors and quadriceps (rectus femoris) becomes secondary. Primary meaning changes. |
| 83 | `lib-hamstring-stretch` | Hamstring stretch | mobility | `hamstrings` | `hamstrings` | `lowerBack` | `lowerBack` | `staticStretch` | none | bodyweight | empty | bilateral | beginner |  |
| 84 | `lib-childs-pose` | Child's pose | mobility | `lats` | `lats` | `lowerBack` | `lowerBack` | `staticStretch` | none | bodyweight | empty | bilateral | beginner | **D** Lats primary; lower back and shoulders also lengthen. |
| 85 | `lib-cat-cow` | Cat-cow | mobility | `lowerBack` | `lowerBack` | `abs`, `upperBack` | `abs`, `upperBack` | `spinalMobility` | none | bodyweight | empty | bilateral | beginner | **D** Spinal mobility; erector spinae and thoracic spine. |
| 86 | `lib-thoracic-extension` | Thoracic spine extension | mobility | `upperBack` | `upperBack` | `lats` | `lats` | `spinalMobility` | none | bodyweight | empty | bilateral | beginner | **M** The seed tag upperBack means the scapular muscles in this model; the movement is thoracic spinal extension, whose muscle (erector spinae) is filed under Lower back. Candidates: erectorSpinae as primary, or keep upperBack with a stretched meaning. Owner decision. Lats secondary is doubtful. |
| 87 | `lib-worlds-greatest-stretch` | World's greatest stretch | mobility | `glutes` | `glutes` | `quadriceps`, `hamstrings`, `obliques` | `quadriceps`, `hamstrings`, `obliques` | `dynamicMobility` | none | bodyweight | empty | alternating | intermediate | **D** Multi-region movement; glutes primary is a choice. Hip flexors and thoracic spine are co-targets. |
| 88 | `lib-doorway-chest-stretch` | Doorway chest stretch | mobility | `chest` | `chest` | `frontDelts` | `frontDelts` | `staticStretch` | none | bodyweight | empty | bilateral | beginner |  |
| 89 | `lib-pigeon-pose` | Pigeon pose | mobility | `glutes` | `glutes` | `abductors` | `abductors` | `staticStretch` | none | bodyweight | empty | unilateral | intermediate | **D** Deep hip rotators (piriformis) are arguably primary; abductors secondary is doubtful. |

## 5. Changes to review first
1. `lib-hip-flexor-stretch` (M): primary moves from `quadriceps` to `hipFlexors`.
2. `lib-thoracic-extension` (M, new at revision 2): the seed tag `upperBack` does not match the movement (thoracic spinal extension); owner decision.
3. `lib-standing-calf-raise`, `lib-shrug`, `lib-leg-curl`, `lib-lying-leg-curl`, `lib-hip-abduction` (R): refinements to finer nodes (calf raise, shrug) or to a more exact secondary.
4. `lib-hanging-leg-raise` (S): `hipFlexors` added as a secondary.
5. `lib-skipping`: no longer promotes `fullBody`; `calves` stays the only primary (ADR-0010 alignment).
6. Equipment tags for `lib-ab-wheel`, `lib-sled-push`, `lib-preacher-curl`, `lib-step-up`, `lib-inverted-row` and `lib-lat-pulldown` (E).
7. The primary-target principle question (Q-P, section 8), which decides the D-flagged rows that propose extra primaries.

## 6. Proposed content assigned for release 2 (F01)
Mechanics, laterality and difficulty follow `editorial-guide.md` sections 6 and 7 (revision 2). Summary of the proposal:

| Dimension | Distribution over the 89 |
|---|---|
| Mechanics | compound 48, isolation 25, empty 16 (cardio and mobility) |
| Laterality | bilateral 74, unilateral 7, alternating 8 |
| Difficulty | beginner 55, intermediate 34, advanced 0 |
| Equipment class (derived) | band 1, bodyweight 26, cable 8, freeWeight 33, kettlebell 1, machine 13, other 7 |

Difficulty by category: cardio: beginner 6, intermediate 2; core: beginner 7, intermediate 3; fullBody: beginner 1, intermediate 4; legs: beginner 14, intermediate 10; mobility: beginner 6, intermediate 2; pull: beginner 14, intermediate 4; push: beginner 7, intermediate 9. No exercise is assigned `advanced` in the seed: none meets the owner definition (high technical demand, stability or complex execution); the first advanced entries (snatch, muscle-up, pistol squat) arrive with the population tranches. The distribution targets in `coverage-matrix.md` section 8 apply to tranches, not to release 2.

Proposed attributes (optional controlled attributes, `coverage-matrix.md` section 3) are recorded for rows where a slot or a duplicate check needs them: angle on the presses, grip on the curls and pull-ups, arm position on curls and triceps work, body position on leg curls, the skull crusher, the hip thrust and the glute bridge, knee position on the calf raise, stance on the deadlifts. They are proposals and optional.

Rows where the assignment needs a reason are explained in the JSON field `assignmentNote`.

## 7. Release-2 clean-up (F23)
Alias changes and doubtful secondaries are listed so that stage 3c and the editors can act on them. Removals of colliding aliases are required for release 2 to pass IC-502 to IC-504; the rest are for editor review. The JSON fields are `aliasesRemove`, `aliasesAdd`, `cleanup` and `doubtfulSecondaries`.

### 7.1 Alias variants that collide after normalisation (required)
| Exercise | Colliding alias | Collides with | Rule | Action |
|---|---|---|---|---|
| `lib-pull-up` | Pullup | name Pull-up | IC-502, IC-504 | Remove |
| `lib-chin-up` | Chinup | name Chin-up | IC-502, IC-504 | Remove |
| `lib-farmers-carry` | Farmers walk | alias Farmer's walk | IC-503 | Remove |

A script over the seed finds exactly these three collisions (names and aliases, `norm` and `squash`). Two further name pairs are within edit distance 2 (IC-508, warning): Machine hip abduction and Machine hip adduction, and Push-up and Pull-up. Both pairs are distinct exercises; disposition "distinct".

### 7.2 Other alias items (editor review)
| Exercise | Item |
|---|---|
| `lib-back-squat` | Alias "Squat" is ambiguous (editorial guide 2.1 uses Bodyweight squat to avoid it). Review. |
| `lib-goblet-squat` | No alias (IC-211 warning). Proposed alias added: "Dumbbell goblet squat". |
| `lib-deadlift` | Alias "Deadlift" is generic. Review. |
| `lib-sumo-deadlift` | No alias (IC-211 warning). Proposed aliases added. |
| `lib-bodyweight-lunge` | Alias "Lunge" is generic; walking and reverse lunges are different movements. Review. |
| `lib-standing-calf-raise` | Alias "Calf raise" is generic (seated and single-leg raises exist). Review. |
| `lib-cable-fly` | Alias "Cable crossover" names a specific cable fly (high pulleys). Review. |
| `lib-triceps-pushdown` | Alias "Tricep pushdown" is a misspelling of "triceps pushdown". Review. |
| `lib-overhead-triceps-extension` | Aliases "French press" and "Dumbbell triceps extension" are generic or ambiguous. Review. |
| `lib-dips` | Alias "Triceps dip" can mean the bench dip, a different exercise. Review. |
| `lib-lat-pulldown` | Alias "Wide-grip pulldown" names a grip variation. Review. |
| `lib-seated-cable-row` | Alias "Cable row" is generic (standing and single-arm cable rows exist). Review. |
| `lib-db-row` | Alias "Single-arm row" is generic (cable and machine single-arm rows exist). Review. |
| `lib-db-curl` | Alias "Bicep curl" is a misspelling of "biceps curl". Review. |
| `lib-hanging-leg-raise` | Alias "Hanging knee raise" names a different exercise (knees bent). It belongs to its own entry. Review. |
| `lib-crunch` | Alias "Sit-up crunch" mixes two different exercises (a sit-up is not a crunch). Review. |
| `lib-sled-push` | Alias "Prowler push" uses a trade name for a sled (IC-506 blocked-word candidate). Review. |
| `lib-treadmill-run` | Alias "Running" overlaps the outdoor run. Review. |
| `lib-stationary-bike` | Alias "Cycling" also names outdoor cycling. Review. |
| `lib-rowing-machine` | Alias "Rowing" is ambiguous with rowing exercises and the sport. Review. |
| `lib-thoracic-extension` | Alias "Foam roller thoracic extension" names a variant that needs a foam roller; an alias must refer to this exercise only. Remove, or add the variant after foamRoller is approved. |
| `lib-pigeon-pose` | Alias "Figure-four stretch" names a different stretch (supine or seated). Review. |

### 7.3 Doubtful secondaries (editor review)
These secondaries are kept in release 2 and listed for confirmation. A secondary that "stands for" a finer muscle is a refinement candidate.
| Exercise | Doubtful secondary | Note |
|---|---|---|
| `lib-hip-thrust` | `quadriceps` | Quadriceps involvement is minor. |
| `lib-overhead-press` | `upperBack` | Stands for upper trapezius. |
| `lib-lateral-raise` | `upperBack` | Stands for upper trapezius. |
| `lib-plank` | `frontDelts` | Isometric hold; front delts are a weak claim. |
| `lib-side-plank` | `abductors` | Stands for gluteus medius, which sits under Glutes. |
| `lib-wall-sit` | `calves` | Calves are a weak claim for an isometric squat hold. |
| `lib-hanging-leg-raise` | `frontDelts` | Front delts are a weak claim. |
| `lib-pallof-press` | `frontDelts` | Front delts are a weak claim. |
| `lib-kettlebell-swing` | `frontDelts` | Front delts are a weak claim. |
| `lib-thoracic-extension` | `lats` | Lats are a weak claim. |
| `lib-pigeon-pose` | `abductors` | Stands for gluteus medius; piriformis is arguably the primary. |

## 8. Open questions in this mapping
- **Q-P (primary-target principle).** One question: when a compound movement is shared by several muscles, are the primaries (a) only the muscle or muscles the movement is designed to load, one per exercise by default (the seed's practice), or (b) every muscle that does main work through the main range? The lead example is the row (`lats` for the one-arm row, `upperBack` for the barbell and cable rows). The same principle decides the other multi-primary candidates: deadlifts and Romanian deadlifts (glutes, hamstrings, lower back), dips (triceps, chest), chin-up (lats, biceps), hip abduction (abductors, gluteus medius), hanging leg raise (abs, hip flexors), clean and press, and thoracic extension. Any extra primary changes the attributed set counts WP 9 reports (OQ-19).
- **Q-F (fullBody role).** May `fullBody` be a secondary target, and may it be a primary beside anatomical primaries? Affects `lib-skipping`, the migration report, the reporting of non-anatomical values and the user exercises that already store it (ADR-0010).
- **Q-M (mechanics for cardio and mobility).** Empty by default (proposed), or forced.
- Thoracic extension (flag M) is part of Q-P: primary `upperBack` with a stretched meaning, or `erectorSpinae`.

## 9. Structural near-duplicates already in the seed
The revised signature and score (`quality-and-duplicates.md` section 2, IC-600) flag these pairs on the proposed mapping: `lib-back-squat` and `lib-front-squat`; `lib-run-400m` and `lib-outdoor-run`; `lib-hack-squat` and `lib-leg-press`; `lib-bulgarian-split-squat` and `lib-step-up` (close matches), plus seven informational pairs. `lib-treadmill-run` and `lib-outdoor-run` are no longer flagged as a close pair: equipment, logging type and name differ. `lib-leg-curl` and `lib-lying-leg-curl` are cleared by their recorded body position. Full results and dispositions are in `quality-and-duplicates.md` section 6.
