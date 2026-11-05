# Coverage matrix and minimum targets (OQ-23) — proposed

- Status: **Proposed — for owner approval.** Catalogue population (WP 8 stage 5) does not start until the owner approves these minimums. WP 8 stage 4 (documentation only).
- Requirements: owner decision 6 (structured coverage matrix is the formal acceptance mechanism for population; minimums per region before population; explicit gap report; raw count is not enough), LIB-001..LIB-005.
- Inputs: `reference/anatomy.json`, `reference/movement-patterns.json`, `reference/equipment.json`; baseline from `app/assets/seed/exercise_library.json` (89 exercises, read only).

## 1. How the minimums are derived
The minimums are not a headcount target. They follow the anatomy.

1. **Which nodes need direct coverage.** Each L2 group in `anatomy.json` is a row. Its L3 and L4 children that exercises can load on their own are listed as sub-targets.
2. **Which patterns are anatomically legitimate.** For each group, the patterns that load it are listed as **function slots**. A slot is one function of the muscle, for example "incline press" for the clavicular head of the chest.
3. **How many exercises a slot needs.** A slot needs one exercise for each legitimate way of loading it, that is each implement class, grip, angle or stance that changes how the movement feels. Slots with a long list of legitimate options (flat press) have a higher minimum than slots with few (neck flexion).
4. **Group minimum = sum of slot minimums.** The sum is the minimum number of exercises with a primary target in the group.
5. **Other dimensions are set from the same structure.** Compound and isolation minimums follow the slots that are multi-joint or single-joint. Equipment class minimums follow which classes can load the movement; a class that cannot is marked N/A with a reason. Laterality minimums follow whether the movement has legitimate unilateral and bilateral forms.
6. **Raw count never decides acceptance.** A group passes only when every dimension in section 5 passes. A group with enough exercises and one empty slot fails.

All figures are proposals for owner review.

## 2. Counting rules
1. An exercise counts toward a group when at least one of its **primary** targets is the group's node or a descendant of it. An exercise with primary targets in two groups counts in both. Group figures therefore do not add up to the number of exercises.
2. A **sub-target** counts the same way at its own node. "Any role" counts primary or secondary.
3. `fullBody` targets never count toward an anatomical group.
4. Retired exercises, and user and imported exercises, never count.
5. **Equipment class of an exercise.** Ignore support items (role `support`). From the remaining items choose the first class in this order: Smith machine, cable, machine, kettlebell, band, free weight, other. With no remaining item the class is bodyweight. Example: dumbbell and bench is free weight; pull-up bar alone is bodyweight; cable and machine is cable. Cardio machines are class other.
6. **Variation family.** A family is a canonical exercise plus the exercises reachable from it through `variationOf`. Family depth is the number of variations in it.
7. **Compound** and **isolation** are the mechanics field. Unilateral counts the laterality values `unilateral` and `alternating`.
8. **Difficulty** is the owner's definition (technical complexity, not load or fitness).
9. Counts are made on the shipped catalogue release, and the tool reports the figures (see `quality-and-duplicates.md`).

## 3. Region-by-region rationale and slots
### Tranche 5.1: Chest

**Chest** (nodes: `chest`; minimum 41 exercises with a primary target in the group)

- Anatomical basis: Pectoralis major has clavicular and sternocostal fibres, so presses and flys at several angles are needed. The pecs adduct the arm horizontally (flys) and press (presses). Serratus anterior and pectoralis minor move the shoulder blade and need protraction work.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `horizontalPush`: Flat press (bar, dumbbell, machine, Smith, band, cable): 6
  - `horizontalPush`: Incline press: 5
  - `horizontalPush`: Decline or low-angle press: 3
  - `horizontalPush`: Push-up family and other bodyweight presses: 6
  - `horizontalPush`: Single-arm and unilateral presses: 4
  - `shoulderHorizontalAdduction`: Flys: flat, incline, cable crossover, band, ring: 10
  - `verticalPush`: Chest-emphasis dips and steep-incline presses: 3
  - `scapularProtraction`: Serratus and pectoralis minor work: 4
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `pectoralisMajorClavicular`: primary 6, any role 8: Incline work
  - `pectoralisMajorSternocostal`: primary 10, any role 14: Flat and decline work
  - `pectoralisMinor`: primary 0, any role 3: Tag as secondary; primary not defensible
  - `serratusAnterior`: primary 3, any role 5: Protraction exercises
- Equipment classes marked N/A, with reason: Other: No chest exercise needs an implement outside the other seven classes.
- Mechanics: compound 24, isolation 12. Laterality: bilateral 24, unilateral or alternating 10. Variation depth: at least 6 canonical families with three or more variations each.

### Tranche 5.2: Back

**Upper back** (nodes: `upperBack`; minimum 30 exercises with a primary target in the group)

- Anatomical basis: The trapezius works in three parts (elevation, retraction, depression) and the rhomboids retract. Rows load retraction; shrugs load elevation; low-angle work loads the lower trapezius.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `horizontalPull`: Rows: bar, dumbbell, machine, cable, Smith, band, bodyweight, kettlebell, single-arm: 12
  - `scapularRetraction`: Retraction and mid-back isolation: 5
  - `scapularElevation`: Shrugs and elevation: 6
  - `scapularDepression`: Depression and lower trapezius: 2
  - `verticalPull`: Wide-grip pulldown and pull-up variants tagged upper back: 5
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `trapeziusUpper`: primary 5, any role 6: Shrugs
  - `trapeziusMiddle`: primary 4, any role 6: Retraction work
  - `trapeziusLower`: primary 2, any role 4: Depression and Y-raises
  - `rhomboids`: primary 3, any role 8: Retraction work
- Equipment classes marked N/A, with reason: Other: No upper-back exercise needs an implement outside the other seven classes.
- Mechanics: compound 17, isolation 8. Laterality: bilateral 17, unilateral or alternating 8. Variation depth: at least 5 canonical families with three or more variations each.

**Lats** (nodes: `lats`; minimum 28 exercises with a primary target in the group)

- Anatomical basis: The latissimus dorsi extends and adducts the arm. Vertical pulls load it through the full range; rows load it in a shorter range; straight-arm work isolates the shoulder extension.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `verticalPull`: Pull-ups, chin-ups and pulldowns with different grips: 12
  - `horizontalPull`: Lat-emphasis rows: 11
  - `shoulderExtension`: Straight-arm pulldowns and pullovers: 5
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `latissimusDorsi`: primary 20, any role 24: Pulls and rows
  - `teresMajor`: primary 0, any role 4: Secondary tag on rows
- Equipment classes marked N/A, with reason: Other: No lat exercise needs an implement outside the other seven classes.
- Mechanics: compound 20, isolation 4. Laterality: bilateral 16, unilateral or alternating 8. Variation depth: at least 5 canonical families with three or more variations each.

### Tranche 5.3: Shoulders and neck

**Shoulders (deltoid)** (nodes: `shoulders`; minimum 43 exercises with a primary target in the group)

- Anatomical basis: The deltoid has three heads with different jobs: front (flexion, pressing), side (abduction), rear (extension, horizontal abduction). Each head needs its own isolation and compound coverage.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `verticalPush`: Overhead presses: bar, dumbbell, machine, Smith, kettlebell, landmine, band, pike: 14
  - `shoulderAbduction`: Lateral raises and variants: 12
  - `shoulderFlexion`: Front raises and variants: 5
  - `shoulderHorizontalAbduction`: Rear-delt flys, face-pull style work: 12
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `frontDelts`: primary 10, any role 14: Presses and front raises
  - `sideDelts`: primary 12, any role 16: Lateral raises and upright rows
  - `rearDelts`: primary 12, any role 16: Reverse flys and face pulls
- Equipment classes marked N/A, with reason: Other: No deltoid exercise needs an implement outside the other seven classes.
- Mechanics: compound 14, isolation 24. Laterality: bilateral 22, unilateral or alternating 12. Variation depth: at least 5 canonical families with three or more variations each.

**Rotator cuff** (nodes: `rotatorCuff`; minimum 12 exercises with a primary target in the group)

- Anatomical basis: The four cuff muscles rotate and centre the humerus. Work is low load and single-joint: external rotation (infraspinatus, teres minor), internal rotation (subscapularis) and abduction (supraspinatus).
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `shoulderExternalRotation`: External rotation variants: 7
  - `shoulderInternalRotation`: Internal rotation variants: 3
  - `shoulderAbduction`: Supraspinatus-targeted raises: 2
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `infraspinatus`: primary 3, any role 6: External rotation
  - `teresMinor`: primary 0, any role 3: Secondary tag
  - `subscapularis`: primary 2, any role 4: Internal rotation
  - `supraspinatus`: primary 2, any role 4: Raises
- Equipment classes marked N/A, with reason: Smith: Fixed-path bars suit no cuff exercise.; KB: Bottoms-up kettlebell work is a stability drill, not a cuff target.; Other: No implement outside the listed classes.
- Mechanics: compound N/A, isolation 10. Laterality: bilateral 3, unilateral or alternating 8. Variation depth: at least 2 canonical families with three or more variations each.

**Neck** (nodes: `regionNeck`; minimum 8 exercises with a primary target in the group)

- Anatomical basis: Neck flexors, extensors and side flexors each need one isolation pattern. Load is low and exercises are single-joint. Safety wording must be conservative.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `neckFlexion`: Neck flexion: 3
  - `neckExtension`: Neck extension: 3
  - `neckLateralFlexion`: Neck side flexion: 2
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `neckFlexors`: primary 3, any role 3: Flexion
  - `neckExtensors`: primary 3, any role 3: Extension
  - `neckLateralFlexors`: primary 2, any role 2: Side flexion
- Equipment classes marked N/A, with reason: Cable: Cable neck work is not widely accepted.; Smith: Not applicable.; KB: Not applicable.; Other: Not applicable.
- Mechanics: compound N/A, isolation 8. Laterality: bilateral 5, unilateral or alternating 2. Variation depth: at least 1 canonical families with three or more variations each.

### Tranche 5.4: Arms

**Biceps and brachialis** (nodes: `upperArmAnterior`; minimum 28 exercises with a primary target in the group)

- Anatomical basis: The elbow flexors bend the elbow in different forearm positions: biceps (supinated), brachialis (any), brachioradialis (neutral; filed under Forearms). Long and short biceps heads shift with arm position.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `elbowFlexion`: Curl variants by implement, grip, angle and arm position: 28
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `bicepsLongHead`: primary 6, any role 6: Arm behind or beside the body
  - `bicepsShortHead`: primary 6, any role 6: Arm in front
  - `brachialis`: primary 5, any role 5: Hammer and reverse curls
- Equipment classes marked N/A, with reason: Smith: Fixed-path bars give no curl advantage.; Other: No implement outside the listed classes.
- Mechanics: compound 4, isolation 20. Laterality: bilateral 14, unilateral or alternating 10. Variation depth: at least 4 canonical families with three or more variations each.

**Triceps** (nodes: `upperArmPosterior`; minimum 30 exercises with a primary target in the group)

- Anatomical basis: The triceps extend the elbow; the long head also crosses the shoulder, so overhead and neutral-arm positions load it differently.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `elbowExtension`: Pushdowns, extensions, kickbacks by implement and arm position: 22
  - `horizontalPush`: Close-grip presses and push-ups: 4
  - `verticalPush`: Dip variants: 4
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `tricepsLongHead`: primary 6, any role 6: Overhead work
  - `tricepsLateralHead`: primary 4, any role 4: Pushdowns and presses
  - `tricepsMedialHead`: primary 3, any role 3: Reverse-grip and close-grip work
- Equipment classes marked N/A, with reason: Other: No implement outside the listed classes.
- Mechanics: compound 8, isolation 16. Laterality: bilateral 14, unilateral or alternating 8. Variation depth: at least 4 canonical families with three or more variations each.

**Forearms and grip** (nodes: `forearms`; minimum 26 exercises with a primary target in the group)

- Anatomical basis: Flexors and extensors of wrist and fingers, pronators and supinators, and brachioradialis. Grip holds use the finger flexors.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `wristFlexion`: Wrist curls: 6
  - `wristExtension`: Reverse wrist curls: 6
  - `elbowFlexion`: Reverse and hammer curls (brachioradialis): 4
  - `forearmRotation`: Pronation and supination: 3
  - `gripHold`: Hangs and pinches: 4
  - `carryUnilateral`: Carries with a forearm emphasis: 3
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `wristFlexors`: primary 6, any role 10: Curls and grips
  - `wristExtensors`: primary 6, any role 8: Reverse curls
  - `brachioradialis`: primary 4, any role 4: Reverse curls
  - `forearmPronators`: primary 0, any role 2: Rotation work
  - `forearmSupinators`: primary 0, any role 2: Rotation work
- Equipment classes marked N/A, with reason: Mach: Few machines load the wrist.; Smith: Not applicable.; Other: No implement outside the listed classes.
- Mechanics: compound 3, isolation 14. Laterality: bilateral 12, unilateral or alternating 8. Variation depth: at least 3 canonical families with three or more variations each.

### Tranche 5.5: Hips and legs

**Glutes** (nodes: `glutes`; minimum 36 exercises with a primary target in the group)

- Anatomical basis: Gluteus maximus extends the hip; medius and minimus abduct and stabilise the pelvis. Bilateral and single-leg options both occur.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `hipExtension`: Hip thrusts, bridges, kickbacks, back-extension style: 18
  - `hinge`: Hinge variants with a glute emphasis: 8
  - `lunge`: Lunge and step variants with a glute emphasis: 5
  - `hipAbduction`: Gluteus medius and minimus work: 5
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `gluteusMaximus`: primary 25, any role 30: Extension work
  - `gluteusMedius`: primary 8, any role 10: Abduction and single-leg stability
  - `gluteusMinimus`: primary 0, any role 4: Secondary tag
- Equipment classes marked N/A, with reason: Other: No implement outside the listed classes.
- Mechanics: compound 18, isolation 12. Laterality: bilateral 16, unilateral or alternating 14. Variation depth: at least 5 canonical families with three or more variations each.

**Abductors** (nodes: `abductors`; minimum 10 exercises with a primary target in the group)

- Anatomical basis: Hip abduction is a single-joint movement. Most work loads gluteus medius too; tag both when relevant.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `hipAbduction`: Hip abduction variants: 10
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `tensorFasciaeLatae`: primary 0, any role 3: Secondary or primary tag
- Equipment classes marked N/A, with reason: Smith: Not applicable.; KB: Not applicable.; Other: Not applicable.
- Mechanics: compound N/A, isolation 10. Laterality: bilateral 4, unilateral or alternating 5. Variation depth: at least 2 canonical families with three or more variations each.

**Adductors** (nodes: `adductors`; minimum 11 exercises with a primary target in the group)

- Anatomical basis: Hip adduction with the adductor muscles. Compound exercises that load adductor magnus (wide squats, sumo stance) count if tagged primary.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `hipAdduction`: Hip adduction variants: 11
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `adductorMagnus`: primary 0, any role 4: Adduction and wide-stance lifts
- Equipment classes marked N/A, with reason: Smith: Not applicable.; KB: Not applicable.; Other: Not applicable.
- Mechanics: compound 2, isolation 7. Laterality: bilateral 5, unilateral or alternating 4. Variation depth: at least 2 canonical families with three or more variations each.

**Hip flexors** (nodes: `hipFlexors`; minimum 9 exercises with a primary target in the group)

- Anatomical basis: Iliopsoas lifts the thigh. Hanging and lying raises, standing drives and cable work give coverage.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `hipFlexion`: Hip flexion variants: 9
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `iliopsoas`: primary 6, any role 9: Hip flexion
- Equipment classes marked N/A, with reason: Smith: Not applicable.; KB: Not applicable.; Other: Not applicable.
- Mechanics: compound 2, isolation 6. Laterality: bilateral 3, unilateral or alternating 4. Variation depth: at least 2 canonical families with three or more variations each.

**Deep hip rotators** (nodes: `hipExternalRotators`; minimum 6 exercises with a primary target in the group)

- Anatomical basis: Small rotators behind the hip; light, controlled work.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `hipRotation`: Hip rotation variants: 6
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `piriformis`: primary 0, any role 3: Rotation and stretches
- Equipment classes marked N/A, with reason: Free wt: Not applicable.; Mach: Not applicable.; Smith: Not applicable.; KB: Not applicable.; Other: Not applicable.
- Mechanics: compound N/A, isolation 6. Laterality: bilateral 2, unilateral or alternating 3. Variation depth: at least 1 canonical families with three or more variations each.

**Quadriceps** (nodes: `quadriceps`; minimum 42 exercises with a primary target in the group)

- Anatomical basis: Four heads extend the knee; squats, lunges and extensions load them through different ranges. Rectus femoris also flexes the hip.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `squat`: Squat variants by implement, stance, depth and tempo: 22
  - `lunge`: Lunges, split squats, step-ups, single-leg squats: 14
  - `kneeExtension`: Leg extension and variants: 6
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `rectusFemoris`: primary 0, any role 5: Extensions and spread-stance work
- Equipment classes marked N/A, with reason: Other: No implement outside the listed classes.
- Mechanics: compound 30, isolation 8. Laterality: bilateral 24, unilateral or alternating 14. Variation depth: at least 6 canonical families with three or more variations each.

**Hamstrings** (nodes: `hamstrings`; minimum 22 exercises with a primary target in the group)

- Anatomical basis: Hamstrings extend the hip and flex the knee. Hinges load the hip function; curls load the knee function.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `hinge`: Hinge variants with a hamstring emphasis: 12
  - `kneeFlexion`: Leg curl variants: 10
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `bicepsFemorisShortHead`: primary 0, any role 3: Knee-flexion work
- Equipment classes marked N/A, with reason: Other: No implement outside the listed classes.
- Mechanics: compound 12, isolation 10. Laterality: bilateral 12, unilateral or alternating 8. Variation depth: at least 4 canonical families with three or more variations each.

**Calves** (nodes: `calves`; minimum 14 exercises with a primary target in the group)

- Anatomical basis: Gastrocnemius works best with a straight knee; soleus with a bent knee. Both need coverage.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `plantarFlexion`: Calf raise variants: standing, seated, single-leg, leg-press: 14
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `gastrocnemius`: primary 8, any role 10: Straight-knee raises
  - `soleus`: primary 6, any role 8: Bent-knee raises
- Equipment classes marked N/A, with reason: Cable: Cable calf raises are impractical.; Other: No implement outside the listed classes.
- Mechanics: compound N/A, isolation 14. Laterality: bilateral 8, unilateral or alternating 5. Variation depth: at least 3 canonical families with three or more variations each.

**Shin and outer lower leg** (nodes: `anteriorLowerLeg`, `lateralLowerLeg`, `deepPosteriorLowerLeg`; minimum 7 exercises with a primary target in the group)

- Anatomical basis: Tibialis anterior, fibularis muscles and tibialis posterior support the ankle. Light, single-joint work.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `dorsiflexion`: Dorsiflexion: 3
  - `ankleInversionEversion`: Inversion and eversion: 4
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `tibialisAnterior`: primary 3, any role 3: Dorsiflexion
  - `fibularisLongus`: primary 0, any role 3: Eversion
  - `tibialisPosterior`: primary 0, any role 2: Inversion
- Equipment classes marked N/A, with reason: Cable: Not applicable.; Smith: Not applicable.; KB: Not applicable.; Other: Not applicable.
- Mechanics: compound N/A, isolation 7. Laterality: bilateral 3, unilateral or alternating 3. Variation depth: at least 1 canonical families with three or more variations each.

### Tranche 5.6: Trunk

**Abs** (nodes: `abs`; minimum 28 exercises with a primary target in the group)

- Anatomical basis: Rectus abdominis flexes the trunk and resists extension; transversus abdominis braces. Bodyweight work is legitimate and common.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `trunkFlexion`: Crunches, sit-ups, reverse crunches, cable and machine variants: 12
  - `antiExtension`: Planks, rollouts, dead bugs, body saws: 10
  - `hipFlexion`: Hanging and lying leg raises with an abdominal emphasis: 6
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `rectusAbdominis`: primary 25, any role 28: Flexion and anti-extension
  - `transversusAbdominis`: primary 0, any role 6: Bracing exercises
- Equipment classes marked N/A, with reason: Smith: A fixed bar adds nothing to abdominal work.
- Mechanics: compound 6, isolation 12. Laterality: bilateral 18, unilateral or alternating 4. Variation depth: at least 5 canonical families with three or more variations each.

**Obliques** (nodes: `obliques`; minimum 24 exercises with a primary target in the group)

- Anatomical basis: Obliques rotate, side-flex and resist rotation and side flexion. Unilateral and alternating work is the norm.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `trunkRotation`: Rotations and woodchops: 8
  - `trunkLateralFlexion`: Side bends: 6
  - `antiRotation`: Pallof-style and single-arm holds: 6
  - `antiLateralFlexion`: Side planks and carries: 4
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `externalOblique`: primary 0, any role 6: Rotation
  - `internalOblique`: primary 0, any role 6: Rotation
- Equipment classes marked N/A, with reason: Smith: Not applicable.
- Mechanics: compound 3, isolation 12. Laterality: bilateral 6, unilateral or alternating 10. Variation depth: at least 4 canonical families with three or more variations each.

**Lower back** (nodes: `lowerBack`; minimum 22 exercises with a primary target in the group)

- Anatomical basis: Erector spinae extend and brace the spine; quadratus lumborum resists side flexion; multifidus stiffens the spine.
- Function slots (each slot minimum is the number of distinct exercises needed to cover that function across the legitimate implements, angles and grips; the group minimum is the sum):
  - `trunkExtension`: Back extensions and reverse hyperextensions: 8
  - `hinge`: Good mornings and loaded hinges tagged lower back: 6
  - `hipExtension`: Hip extension with spinal bracing: 4
  - `antiLateralFlexion`: Quadratus lumborum work: 4
- Sub-target minimums (exercises tagged at the node or a descendant; first number as primary, second as primary or secondary):
  - `erectorSpinae`: primary 15, any role 20: Extension and bracing
  - `quadratusLumborum`: primary 0, any role 4: Anti-side-flexion work
  - `multifidus`: primary 0, any role 4: Bird dog and similar
- Mechanics: compound 8, isolation 8. Laterality: bilateral 12, unilateral or alternating 5. Variation depth: at least 3 canonical families with three or more variations each.


## 4. Minimum targets per group (summary)
Equipment columns: free weight, machine, cable, Smith machine, band, kettlebell, bodyweight, other. A number is the minimum count of exercises in the group with that class. N/A means the class cannot legitimately load the group (reasons are in section 3). Compound and isolation minimums are independent of the slot total; N/A means no minimum.

| Group | Slot total | Compound | Isolation | Bilateral | Unilateral or alternating | Free wt | Mach | Cable | Smith | Band | KB | BW | Other |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Chest | 41 | 24 | 12 | 24 | 10 | 14 | 5 | 5 | 3 | 3 | 2 | 9 | N/A |
| Upper back | 30 | 17 | 8 | 17 | 8 | 8 | 4 | 5 | 2 | 3 | 2 | 6 | N/A |
| Lats | 28 | 20 | 4 | 16 | 8 | 5 | 5 | 5 | 1 | 3 | 2 | 6 | N/A |
| Shoulders (deltoid) | 43 | 14 | 24 | 22 | 12 | 14 | 6 | 7 | 2 | 4 | 3 | 5 | N/A |
| Rotator cuff | 12 | N/A | 10 | 3 | 8 | 3 | 1 | 3 | N/A | 3 | N/A | 2 | N/A |
| Neck | 8 | N/A | 8 | 5 | 2 | 1 | 2 | N/A | N/A | 3 | N/A | 2 | N/A |
| Biceps and brachialis | 28 | 4 | 20 | 14 | 10 | 8 | 3 | 6 | N/A | 3 | 2 | 3 | N/A |
| Triceps | 30 | 8 | 16 | 14 | 8 | 8 | 4 | 6 | 2 | 3 | 2 | 5 | N/A |
| Forearms and grip | 26 | 3 | 14 | 12 | 8 | 8 | N/A | 3 | N/A | 2 | 3 | 4 | N/A |
| Glutes | 36 | 18 | 12 | 16 | 14 | 10 | 5 | 5 | 2 | 4 | 3 | 7 | N/A |
| Abductors | 10 | N/A | 10 | 4 | 5 | 1 | 2 | 2 | N/A | 3 | N/A | 2 | N/A |
| Adductors | 11 | 2 | 7 | 5 | 4 | 1 | 2 | 2 | N/A | 2 | N/A | 4 | N/A |
| Hip flexors | 9 | 2 | 6 | 3 | 4 | 1 | 1 | 2 | N/A | 2 | N/A | 3 | N/A |
| Deep hip rotators | 6 | N/A | 6 | 2 | 3 | N/A | N/A | 2 | N/A | 2 | N/A | 2 | N/A |
| Quadriceps | 42 | 30 | 8 | 24 | 14 | 14 | 8 | 2 | 4 | 2 | 4 | 8 | N/A |
| Hamstrings | 22 | 12 | 10 | 12 | 8 | 6 | 4 | 2 | 2 | 2 | 3 | 3 | N/A |
| Calves | 14 | N/A | 14 | 8 | 5 | 3 | 5 | N/A | 2 | 1 | 1 | 2 | N/A |
| Shin and outer lower leg | 7 | N/A | 7 | 3 | 3 | 1 | 1 | N/A | N/A | 3 | N/A | 2 | N/A |
| Abs | 28 | 6 | 12 | 18 | 4 | 3 | 3 | 4 | N/A | 2 | 2 | 12 | 2 |
| Obliques | 24 | 3 | 12 | 6 | 10 | 3 | 2 | 5 | N/A | 2 | 2 | 7 | 3 |
| Lower back | 22 | 8 | 8 | 12 | 5 | 6 | 3 | 1 | 1 | 2 | 2 | 6 | 1 |

Reading the table: the class minimums of a group never add up to more than its slot total, because each exercise has exactly one class.

## 5. Conditioning and mobility (tranche 5.7)
These sets are not anatomical groups. They are measured by category and pattern.

| Dimension | Minimum | Rationale |
|---|---|---|
| Exercises with category `cardio` | 20 | Machines, outdoor work and skipping, in several modalities. |
| Exercises with category `fullBody` | 20 | Compound lifts spanning upper and lower body, and whole-body circuits. |
| Pattern `walkRun` | 6 | Walk, jog, run, sprint, incline, intervals. |
| Pattern `ergometer` | 8 | Bike, rower, cross-trainer and any approved cardio machine, in steady and interval forms. |
| Pattern `skipping` | 3 | Skipping rope variants. |
| Pattern `sledPushPull` | 4 | Needs `sled` approved. |
| Pattern `crawl` | 4 | Bear, crab and similar. |
| Pattern `fullBodyConditioning` | 10 | Circuits and drills. |
| Patterns `verticalJump`, `horizontalJump`, `lateralJump` | 6, 4, 3 | Jump and plyometric forms. |
| Pattern `upperPlyometric` | 4 | Throws, slams, explosive push-ups. |
| Pattern `explosiveLift` | 8 | Clean and snatch derivatives and high pulls. |
| Patterns `carryBilateral`, `carryUnilateral` | 4, 6 | Carries with different implements. |
| Distinct cardio machines | 4 | The four existing cardio machines are enough. |
| Category `mobility` | 60 | See below. |
| Pattern `staticStretch` | 30 | One or more per anatomical group (below). |
| Pattern `dynamicMobility` | 14 | Joint-range drills. |
| Pattern `spinalMobility` | 6 | Cervical, thoracic and lumbar. |
| Pattern `softTissueRelease` | 4 | Conditional on approving `foamRoller`. |
| Anatomical L2 groups with at least one mobility exercise (primary or secondary) | all 21 coverage groups; at least two for chest, upper back, lats, shoulders, biceps, triceps, forearms, glutes, quadriceps, hamstrings, abs, lower back, hip flexors, adductors and calves | A stretch or drill for every group; two for the groups that people train most. |

Mechanics for `cardio` and `mobility` exercises: see the open question in section 11.

## 6. Difficulty distribution
Difficulty uses the owner's definitions (`editorial-guide.md`, section 6).

| Scope | Beginner | Intermediate | Advanced |
|---|---|---|---|
| Each regional tranche (5.1 to 5.6) | 30 to 45 % | 40 to 55 % | 10 to 20 % |
| Tranche 5.7 conditioning | 30 to 45 % | 40 to 55 % | 10 to 20 % |
| Tranche 5.7 mobility | 50 to 70 % | 25 to 40 % | 0 to 10 % |
| Each group with a slot total of 20 or more | at least 20 % | at least 30 % | at least 5 % and at least 2 exercises |
| Each group with a slot total below 20 | at least 1 | at least 1 | optional; record the reason if none |

No system exercise may have an empty difficulty at tranche acceptance.

## 7. Variation depth and diversity
| Measure | Minimum or cap |
|---|---|
| Canonical families with at least three variations, per group | the "families" figure in section 3 (3 to 6) |
| Flagship families with at least five variations | barbell bench press, barbell back squat, conventional deadlift, barbell overhead press, pull-up, barbell row, hip thrust, barbell biceps curl, triceps extension, lateral raise, plank, leg curl |
| Progression or regression chains of at least three steps | at least two per compound-heavy tranche (5.1, 5.2, 5.3, 5.5, 5.6), where a legitimate chain exists (for example push-up, squat, pull-up, plank) |
| Unilateral exercises with a bilateral counterpart in the catalogue that lack a `unilateralCounterpartOf` link | 0 |
| Exercises that derive from a catalogue exercise (equipment, grip, stance, angle, range) and lack a `variationOf` link | 0 |
| Share of one canonical family in one group | at most 30 % of the group's exercises |
| Share of one equipment class in one group | at most 55 %; at most 60 % for abs and obliques (bodyweight) |
| Distinct primary patterns per group with more than one slot | at least the number of slots with a different pattern |

## 8. Whole-catalogue gates at tranche acceptance
1. 100 % of system exercises in the tranche have: at least one primary target, mechanics (see section 11 for cardio and mobility), laterality, difficulty, at least one pattern, equipment (or an empty list on purpose), and the four instruction sections.
2. Zero integrity errors (`quality-and-duplicates.md`).
3. Every uncleared near-duplicate flag has a recorded disposition.
4. The gap report in section 10 shows no unmet requirement, or the owner has accepted each remaining gap in writing.

## 9. Current baseline from the 89-exercise seed
The seed records only a primary muscle, secondary muscles, category, logging type and equipment. It has no mechanics, laterality, difficulty, patterns or relationships. Those dimensions are therefore **not recorded** for all 89 exercises and are not scored here.

Baseline method: each exercise is counted once, in the group of its single primary muscle, using the 19 existing ids. The equipment class follows section 2 with one manual override: `lib-inverted-row` is counted as bodyweight, because its barbell is a fixed bar in a rack. Five groups with no existing id (rotator cuff, neck, hip flexors, deep hip rotators, shin and outer lower leg) have zero by construction.

| Group | Required | Baseline (primary) | Gap | Baseline involved as secondary | Class baseline (FW/M/C/S/B/KB/BW/Other) | Class gaps |
|---|---|---|---|---|---|---|
| Chest | 41 | 9 | 32 | 2 | 5/1/1/0/0/0/2/0 | Free wt 9, Mach 4, Cable 4, Smith 3, Band 3, KB 2, BW 7 |
| Upper back | 30 | 6 | 24 | 16 | 2/1/1/0/0/0/2/0 | Free wt 6, Mach 3, Cable 4, Smith 2, Band 3, KB 2, BW 4 |
| Lats | 28 | 7 | 21 | 8 | 1/1/1/0/1/0/3/0 | Free wt 4, Mach 4, Cable 4, Smith 1, Band 2, KB 2, BW 3 |
| Shoulders (deltoid) | 43 | 6 | 37 | 25 | 4/1/1/0/0/0/0/0 | Free wt 10, Mach 5, Cable 6, Smith 2, Band 4, KB 3, BW 5 |
| Rotator cuff | 12 | 0 | 12 | 0 | 0/0/0/0/0/0/0/0 | Free wt 3, Mach 1, Cable 3, Band 3, BW 2 |
| Neck | 8 | 0 | 8 | 0 | 0/0/0/0/0/0/0/0 | Free wt 1, Mach 2, Band 3, BW 2 |
| Biceps and brachialis | 28 | 5 | 23 | 10 | 4/0/1/0/0/0/0/0 | Free wt 4, Mach 3, Cable 5, Band 3, KB 2, BW 3 |
| Triceps | 30 | 5 | 25 | 10 | 2/1/1/0/0/0/1/0 | Free wt 6, Mach 3, Cable 5, Smith 2, Band 3, KB 2, BW 4 |
| Forearms and grip | 26 | 2 | 24 | 11 | 1/0/0/0/0/0/1/0 | Free wt 7, Cable 3, Band 2, KB 3, BW 3 |
| Glutes | 36 | 8 | 28 | 20 | 3/0/0/0/0/1/3/1 | Free wt 7, Mach 5, Cable 5, Smith 2, Band 4, KB 2, BW 4 |
| Abductors | 10 | 1 | 9 | 2 | 0/1/0/0/0/0/0/0 | Free wt 1, Mach 1, Cable 2, Band 3, BW 2 |
| Adductors | 11 | 1 | 10 | 6 | 0/1/0/0/0/0/0/0 | Free wt 1, Mach 1, Cable 2, Band 2, BW 4 |
| Hip flexors | 9 | 0 | 9 | 0 | 0/0/0/0/0/0/0/0 | Free wt 1, Mach 1, Cable 2, Band 2, BW 3 |
| Deep hip rotators | 6 | 0 | 6 | 0 | 0/0/0/0/0/0/0/0 | Cable 2, Band 2, BW 2 |
| Quadriceps | 42 | 17 | 25 | 9 | 9/3/0/0/0/0/4/1 | Free wt 5, Mach 5, Cable 2, Smith 4, Band 2, KB 4, BW 4 |
| Hamstrings | 22 | 5 | 17 | 11 | 2/2/0/0/0/0/1/0 | Free wt 4, Mach 2, Cable 2, Smith 2, Band 2, KB 3, BW 2 |
| Calves | 14 | 2 | 12 | 9 | 0/1/0/0/0/0/0/1 | Free wt 3, Mach 4, Smith 2, Band 1, KB 1, BW 2 |
| Shin and outer lower leg | 7 | 0 | 7 | 0 | 0/0/0/0/0/0/0/0 | Free wt 1, Mach 1, Band 3, BW 2 |
| Abs | 28 | 6 | 22 | 6 | 1/0/1/0/0/0/4/0 | Free wt 2, Mach 3, Cable 3, Band 2, KB 2, BW 8, Other 2 |
| Obliques | 24 | 2 | 22 | 7 | 0/0/1/0/0/0/1/0 | Free wt 3, Mach 2, Cable 4, Band 2, KB 2, BW 6, Other 3 |
| Lower back | 22 | 1 | 21 | 9 | 0/0/0/0/0/0/1/0 | Free wt 6, Mach 3, Cable 1, Smith 1, Band 2, KB 2, BW 5, Other 1 |

Reading the table: "Required" is the slot total from section 3. "Baseline" is the number of seed exercises with a primary target in the group. "Class gaps" lists the equipment classes that fall short, with the missing count. Classes marked N/A are not listed. The seed has no Smith machine, band-only, kettlebell-only or "other" entries in most groups.

Baseline in other dimensions:
- Conditioning: 6 seed exercises have primary `fullBody`; by category the seed has 8 `cardio`, 5 `fullBody` and 8 `mobility`. Patterns are not recorded.
- Mobility: the 8 mobility exercises touch 11 of the 21 coverage groups (abductors, abs, chest, glutes, hamstrings, lats, lowerBack, obliques, quadriceps, shoulders, upperBack). Ten groups (biceps, triceps, forearms, rotator cuff, neck, hip flexors, deep hip rotators, adductors, calves, shin and outer lower leg) have none.
- Equipment items actually used in the seed: `smithMachine` 0, `rings` 0, `medicineBall` 0, `kettlebell` 1, `resistanceBand` 1 (gap analysis, section 2).
- Raw size: 89 exercises. The slot totals across the 21 groups sum to 477 primary tags (some exercises count in two groups). That sum is informational. It is not an acceptance target.

## 10. Gap report format
The coverage tool produces one report per catalogue release and per tranche, as Markdown for people and JSON for tools.

**Row (one per group and dimension):**
| Field | Meaning |
|---|---|
| `tranche` | 5.1 to 5.7 |
| `group` | Group key or conditioning or mobility set |
| `dimension` | total, subTarget, mechanics, laterality, pattern, equipmentClass, difficulty, variationDepth, diversity, completeness |
| `item` | The measured item (for example `compound`, `horizontalPush`, `cable`, `pectoralisMajorClavicular`) |
| `required` | Minimum or cap (number, percentage band, or N/A) |
| `actual` | Count in this release |
| `gap` | required minus actual, never below zero (for a cap: excess) |
| `status` | `met`, `gap`, `notRecorded`, or `notApplicable` |
| `note` | Reason for N/A, or owner acceptance reference |

**Summary lines:** groups met and not met per tranche; dimensions not recorded; total open gaps; open gaps accepted by the owner (with references).

**Example from the baseline (illustrative):**
| Tranche | Group | Dimension | Item | Required | Actual | Gap | Status |
|---|---|---|---|---|---|---|---|
| 5.1 | Chest | total | primary count | 41 | 9 | 32 | gap |
| 5.1 | Chest | equipmentClass | smithMachine | 3 | 0 | 3 | gap |
| 5.1 | Chest | mechanics | compound | 24 | not recorded | n/a | notRecorded |
| 5.3 | Shoulders | subTarget | sideDelts | 12 | 1 | 11 | gap |
| 5.4 | Triceps | pattern | verticalPush | 4 | 2 | 2 | gap |

The report is a build artefact (published by CI), not a hand-edited document.

## 11. Open questions for the owner
1. **OQ-23 approval:** approve, change or reject the minimums in sections 3 to 7.
2. Mechanics for `cardio` and `mobility` exercises: the recommendation is to allow the field to be empty for these two categories and to exclude them from the mechanics check. The alternative is to force a value (`compound` for cardio, `isolation` or `compound` for stretches by joints involved).
3. Whether to include pelvic floor, neck and soft tissue release content at all.
4. Whether the 55 % and 30 % caps are right, and whether tranche minimums should be raised after the first pilot tranche.
5. Whether a pilot tranche (5.1 chest) should run first and the matrix be adjusted before the others.
