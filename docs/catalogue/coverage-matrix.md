# Coverage matrix and minimum targets (OQ-23) — proposed, revision 2

- Status: **Proposed — for owner approval.** Catalogue population (WP 8 stage 5) does not start until the owner approves these minimums. WP 8 stage 4 (documentation only).
- Requirements: owner decision 6 (structured coverage matrix is the formal acceptance mechanism for population; minimums per region before population; explicit gap report; raw count is not enough), LIB-001..LIB-005.
- Inputs: `reference/anatomy.json`, `reference/movement-patterns.json`, `reference/equipment.json`; baseline from `app/assets/seed/exercise_library.json` through `mapping-existing.json` (89 exercises, read only).
- **Source of every number: `reference/coverage.json`.** That file lists, per group, every slot with its patterns, its discriminator, its minimum and the enumerated intended entries that justify the minimum. This document is generated from it; no figure here is typed by hand. The minimums are measurable by CI from catalogue data alone.
- **Pilot and re-baselining (F07).** Tranche 5.1 (chest) is a **pilot**. All figures are proposals. After 5.1 an explicit re-baselining step re-derives the inventory, thresholds and bands from what the pilot showed; the owner approves the revised `coverage.json`; then 5.2 to 5.7 start (section 13, Q-C).

## 1. How the minimums are derived
The minimums are not a headcount target. They follow the anatomy and are enumerated.

1. **Which nodes need direct coverage.** Each L2 group in `anatomy.json` is a group of the inventory (the three lower-leg groups share one row). L4 nodes carry no minimum (F03).
2. **Slots.** A slot is one function of the group, defined by one or more movement patterns plus a **discriminator** that a machine can read: a sub-target at L2 or L3, a laterality, a set of equipment classes, or a named optional exercise attribute (section 3). Slots of one group can accept the same exercise (a single-arm flat press fits both the flat-press and the single-arm slot); the matching in section 2 assigns it to one, and an exercise fills at most one slot per group.
3. **Enumerated entries.** Each slot lists the intended entries by name, with their class, laterality and mechanics. An entry is listed only if it changes the implement, the line of pull, the arm or body position, or the side worked (the variation test in the editorial guide); superficial variants are not enumerated. **Slot minimum = the number of counted entries.** Entries marked optional are legitimate but never a minimum, which is how rare implements are handled (F07).
4. **Group minimum = sum of slot minimums.**
5. **Other dimensions come from the same entries.** Compound, isolation, bilateral and unilateral-or-alternating minimums, and each equipment-class minimum, are the counts of those values among the counted entries. A class with no counted entry has no minimum; nothing is forced (F07).
6. **Raw count never decides acceptance.** A group passes only when every slot is filled and every dimension passes. A group with enough exercises and one empty slot fails.

All figures are proposals for owner review.

## 2. Counting rules
1. An exercise counts toward a group when one of its **primary** targets is a node of the group or a descendant, **and its primary pattern (the first pattern) is a pattern of one of the group's slots** (F05). Secondary targets never count. Group figures can therefore overlap only when an exercise has primaries in two groups; the primaries-per-exercise metric (section 9) limits that.
2. An exercise fills **at most one slot per group**. Assignment of exercises to slots is a deterministic maximum bipartite matching (ties by id), so one exercise is never counted twice in a group.
3. `fullBody` never counts toward an anatomical group. Exercises of category `cardio` or `mobility` never count toward an anatomical group; they are measured separately by pattern and category in the conditioning and mobility sets (section 7).
4. Retired exercises, and user and imported exercises, never count.
5. **Equipment class of an exercise** follows `equipment.md` section 5: ignore items whose effective role is `support` (default role, or the per-exercise `equipmentRoles` override); from the rest choose the first class in the order Smith machine, cable, machine, kettlebell, band, free weight, other; with nothing left the class is bodyweight.
6. **Variation family.** A family is a canonical exercise plus the exercises reachable from it through `variationOf`.
7. **Compound** and **isolation** are the mechanics field. Unilateral counts the laterality values `unilateral` and `alternating`. For `cardio` and `mobility` the mechanics field is empty by default and not measured (open question Q-M).
8. **Difficulty** is the owner's definition (technical complexity, not load or fitness).
9. Counts are made on the shipped catalogue release; the tool reports the figures (see `quality-and-duplicates.md`).

## 3. Optional controlled exercise attributes (proposed)
Some slots need a fact that the existing fields do not record (the angle of a press, the arm position of a curl). The inventory proposes six optional, single-valued, controlled attributes. They are never required for an exercise, but a slot that uses one counts only exercises that record it.

| Attribute | Values | Used by slots |
|---|---|---|
| `angle` | flat, incline, decline | `chest.declinePress`, `chest.flatPress`, `chest.inclinePress` |
| `armPosition` | besideBody, behindBody, supportedInFront, overhead, abducted90 | `biceps.armBehindBody`, `biceps.armBesideBody`, `biceps.armSupported`, `rotatorCuff.externalRotationArmAbducted`, `rotatorCuff.externalRotationArmAtSide`, `triceps.overhead`, `triceps.pushdown` |
| `grip` | pronated, supinated, neutral | `biceps.neutralGrip`, `forearms.brachioradialis` |
| `bodyPosition` | standing, seated, lying, bentOver | `triceps.kickback`, `triceps.lying` |
| `kneePosition` | straight, bent | `calves.bentKnee`, `calves.straightKnee` |
| `stance` | standard, wide | duplicate check only |

**ADR-0008 implication.** ADR-0008 stores equipment, patterns, mechanics, laterality and difficulty as defined columns or child tables and rejected a generic attribute store. Six optional attributes are a small, controlled extension: either one optional column each, or one child table `exercise_attributes (exercise_id, attribute, value)` with a controlled value list. Both amend or clarify ADR-0008 and add a field to the release format. The owner decides (Q-A). If the owner declines, the attribute-discriminated slots become review checklist items and their minimums informational; no other number changes. The attributes also feed the near-duplicate check (`quality-and-duplicates.md`, IC-600), where a recorded difference clears a pair automatically.

## 4. Sub-targets without L4 minimums (F03)
No minimum depends on an L4 primary tag, and L4 tagging stays optional (editorial guide section 5). The needs that earlier drafts expressed as L4 primary minimums are now carried by slot discriminators:

| Need | Carried by |
|---|---|
| Clavicular head versus sternocostal head of the pectoralis major | `chest.inclinePress` (angle = incline) and `chest.flatPress`, `chest.declinePress` |
| Serratus anterior, pectoralis minor | `chest.serratus` (pattern `scapularProtraction`) |
| Upper, middle, lower trapezius, rhomboids | `upperBack.shrugs`, `upperBack.retraction`, `upperBack.depression`, rows |
| Front, side, rear delts | presses and `shoulders.frontRaise`; `shoulders.lateralRaise`, `shoulders.uprightRow`; the two rear-delt slots |
| Infraspinatus, teres minor, subscapularis, supraspinatus | `rotatorCuff.externalRotation*`, `rotatorCuff.internalRotation`, `rotatorCuff.supraspinatus` |
| Biceps long head, short head, brachialis | `biceps.armBehindBody`, `biceps.armSupported`, `biceps.neutralGrip` (arm position and grip, not heads) |
| Triceps long head | `triceps.overhead` (at least the number of overhead entries) |
| Wrist flexors, extensors, brachioradialis | `forearms.wristFlexion`, `forearms.wristExtension`, `forearms.brachioradialis` |
| Gluteus medius (L3) | `glutes.abduction` (sub-target `gluteusMedius` as primary) |
| Gastrocnemius, soleus | `calves.straightKnee`, `calves.bentKnee` (knee position) |
| Shin and outer lower-leg muscles | `lowerLeg.dorsiflexion`, `lowerLeg.inversionEversion` |

## 5. Inventory by group
Tranche order follows `population-standards.md`. Figures are generated from `coverage.json`. Entry names are intended exercises, not required names.


### Tranche 5.1

**Chest** (nodes: `chest`; **minimum 36** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: Pectoralis major has clavicular and sternocostal fibres, so presses at three angles and flys are needed; serratus anterior and pectoralis minor move the shoulder blade and need protraction work. Presses are discriminated by recorded angle, never by an L4 primary tag.

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `chest.flatPress` Flat press | `horizontalPush` | angle = flat; class in FW, M, C, S, B, KB | 6 | Barbell bench press; Dumbbell bench press; Machine chest press; Smith machine bench press; Cable chest press; Band chest press |
| `chest.inclinePress` Incline press (up to about 45 degrees) | `horizontalPush` | angle = incline; class in FW, M, C, S, B, KB | 5 | Incline barbell bench press; Incline dumbbell press; Incline machine press; Incline Smith machine press; Incline cable press |
| `chest.declinePress` Decline press | `horizontalPush` | angle = decline; class in FW, M, C, S, B, KB | 3 | Decline barbell bench press; Decline dumbbell press; Decline machine press |
| `chest.pushUp` Push-up family (bodyweight presses) | `horizontalPush` | class in BW | 6 | Push-up; Knee push-up; Incline push-up; Decline push-up; Archer push-up; Suspension trainer push-up |
| `chest.unilateralPress` Single-arm presses | `horizontalPush` | laterality = unilateral or alternating; class in FW, M, C, S, B, KB | 4 | Single-arm dumbbell bench press; Single-arm cable chest press; Single-arm machine chest press; Single-arm band press |
| `chest.flyFreeBodyweight` Flys with free weights or bodyweight | `shoulderHorizontalAdduction` | class in FW, BW | 3 | Flat dumbbell fly; Incline dumbbell fly; Suspension trainer fly |
| `chest.flyCable` Cable flys | `shoulderHorizontalAdduction` | class in C | 3 | Cable crossover (high pulleys); Low-to-high cable fly; Single-arm cable fly |
| `chest.flyMachineBand` Machine and band flys | `shoulderHorizontalAdduction` | class in M, B | 2 | Pec deck fly; Band chest fly |
| `chest.serratus` Shoulder blade protraction (serratus anterior, pectoralis minor) | `scapularProtraction` | none (pattern and group only) | 4 | Push-up plus; Scapular push-up; Cable serratus punch; Supine dumbbell serratus punch |

- Derived: compound 24, isolation 12; bilateral 28, unilateral or alternating 8; classes FW 10, M 5, C 7, S 2, B 3, BW 9; variation families with at least three variations: 5; caps: one family at most 10.8, one class at most 19.8.


### Tranche 5.2

**Upper back** (nodes: `upperBack`; **minimum 25** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: The trapezius works in three parts (elevation, retraction, depression) and the rhomboids retract. Rows load retraction, shrugs elevation, low-angle work the lower trapezius. Which row exercises carry an upper-back primary depends on the primary-target principle (Q-P); the row slots count whichever exercises the owner decision tags with an upper-back primary.

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `upperBack.rowsFreeWeight` Rows with free weights, Smith machine or kettlebell | `horizontalPull` | class in FW, S, KB | 4 | Barbell bent-over row; Pendlay row; Chest-supported dumbbell row; Smith machine bent-over row; (T-bar row (landmine), optional) |
| `upperBack.rowsMachineCable` Rows on machines and cables | `horizontalPull` | class in M, C | 3 | Wide-grip seated cable row; Chest-supported machine row; Machine high row |
| `upperBack.rowsBodyweightBand` Bodyweight and band rows | `horizontalPull` | class in BW, B | 4 | Inverted row; Feet-elevated inverted row; Suspension trainer row; Seated band row |
| `upperBack.rowsUnilateral` Single-arm rows | `horizontalPull` | laterality = unilateral or alternating | 3 | Single-arm chest-supported dumbbell row; Single-arm high cable row; Single-arm machine row |
| `upperBack.retraction` Retraction and mid-back isolation | `scapularRetraction` | none (pattern and group only) | 3 | Prone dumbbell T raise; Seated cable scapular retraction; Band scapular retraction |
| `upperBack.shrugs` Shrugs | `scapularElevation` | none (pattern and group only) | 5 | Barbell shrug; Dumbbell shrug; Trap bar shrug; Machine shrug; Cable shrug; (Smith machine shrug, optional) |
| `upperBack.depression` Depression and lower trapezius | `scapularDepression` | none (pattern and group only) | 3 | Scapular pull-up; Prone Y raise; Dip-bar scapular depression |

- Derived: compound 14, isolation 11; bilateral 22, unilateral or alternating 3; classes FW 8, M 4, C 4, S 1, B 2, BW 6; variation families with at least three variations: 3; caps: one family at most 7.5, one class at most 13.75.

**Lats** (nodes: `lats`; **minimum 21** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: The latissimus dorsi extends and adducts the arm. Vertical pulls load it through the full range, close-grip rows in a shorter range, and straight-arm work isolates shoulder extension.

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `lats.verticalBodyweightBand` Pull-ups and chin-ups (bodyweight and band-assisted) | `verticalPull` | class in BW, B | 5 | Pull-up; Chin-up; Neutral-grip pull-up; Wide-grip pull-up; Band-assisted pull-up |
| `lats.verticalMachineCable` Pulldowns and assisted pull-ups on machines and cables | `verticalPull` | class in M, C | 6 | Wide-grip lat pulldown; Close-grip neutral pulldown; Underhand lat pulldown; Machine-assisted pull-up; Plate-loaded pulldown machine; Single-arm cable pulldown |
| `lats.rowsFreeKettlebell` Lat-emphasis rows with free weights or a kettlebell | `horizontalPull` | class in FW, KB | 3 | One-arm dumbbell row; Underhand barbell row; Kettlebell one-arm row; (Meadows row (landmine), optional) |
| `lats.rowsCableMachine` Lat-emphasis rows on cables and machines | `horizontalPull` | class in C, M | 3 | Close-grip seated cable row; Single-arm cable row; Neutral-grip machine row |
| `lats.straightArm` Straight-arm pulldowns and pullovers | `shoulderExtension` | none (pattern and group only) | 4 | Straight-arm cable pulldown; Dumbbell pullover; Band straight-arm pulldown; Machine pullover |

- Derived: compound 17, isolation 4; bilateral 17, unilateral or alternating 4; classes FW 3, M 4, C 7, B 2, KB 1, BW 4; variation families with at least three variations: 3; caps: one family at most 6.3, one class at most 11.55.


### Tranche 5.3

**Shoulders (deltoid)** (nodes: `shoulders`; **minimum 35** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: The deltoid has three heads with different jobs: front (flexion, pressing), side (abduction), rear (extension, horizontal abduction). Each needs its own slot. Superficial variants (seat angle, hand rotation of a few degrees, tempo) are not enumerated: lateral and rear-delt slots list only entries that change the implement, the line of pull or the side worked.

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `shoulders.pressFreeWeight` Overhead presses with free weights | `verticalPush` | class in FW | 5 | Barbell overhead press; Seated dumbbell shoulder press; Arnold press; Barbell push press; Single-arm dumbbell overhead press |
| `shoulders.pressMachineSmithCable` Overhead presses on machine, Smith machine or cable | `verticalPush` | class in M, S, C | 3 | Machine shoulder press; Smith machine shoulder press; Single-arm cable overhead press |
| `shoulders.pressKettlebellBand` Kettlebell and band overhead presses | `verticalPush` | class in KB, B | 2 | Single-arm kettlebell overhead press; Band overhead press; (Bottoms-up kettlebell press, optional) |
| `shoulders.pressBodyweight` Bodyweight vertical presses | `verticalPush` | class in BW | 3 | Pike push-up; Feet-elevated pike push-up; Wall handstand push-up |
| `shoulders.lateralRaise` Lateral raises | `shoulderAbduction` | none (pattern and group only) | 6 | Dumbbell lateral raise; Cable lateral raise; Single-arm cable lateral raise; Machine lateral raise; Band lateral raise; Lean-away single-arm dumbbell lateral raise |
| `shoulders.uprightRow` Upright rows (decision rule R4) | `verticalPull` | none (pattern and group only) | 3 | Barbell upright row; Dumbbell upright row; Cable upright row |
| `shoulders.frontRaise` Front raises | `shoulderFlexion` | none (pattern and group only) | 4 | Dumbbell front raise; Plate front raise; Cable front raise; Band front raise |
| `shoulders.rearMachineCable` Rear-delt work on machines and cables | `shoulderHorizontalAbduction` | class in M, C | 4 | Reverse pec deck; Cable reverse fly; Single-arm cable reverse fly; Cable face pull |
| `shoulders.rearFreeBandBodyweight` Rear-delt work with free weights, bands or bodyweight | `shoulderHorizontalAbduction` | class in FW, B, BW | 5 | Bent-over dumbbell reverse fly; Chest-supported dumbbell reverse fly; Band pull-apart; Band face pull; Suspension trainer reverse fly |

- Derived: compound 16, isolation 19; bilateral 29, unilateral or alternating 6; classes FW 13, M 3, C 8, S 1, B 5, KB 1, BW 4; variation families with at least three variations: 5; caps: one family at most 10.5, one class at most 19.25.

**Rotator cuff** (nodes: `rotatorCuff`; **minimum 10** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: The four cuff muscles rotate and centre the humerus. Work is low load and single-joint: external rotation (infraspinatus, teres minor), internal rotation (subscapularis) and abduction (supraspinatus). No machine, Smith machine or kettlebell exercise is forced (F07).

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `rotatorCuff.externalRotationArmAtSide` External rotation, arm at the side | `shoulderExternalRotation` | armPosition = besideBody | 3 | Cable external rotation; Band external rotation; Side-lying dumbbell external rotation |
| `rotatorCuff.externalRotationArmAbducted` External rotation, arm at 90 degrees | `shoulderExternalRotation` | armPosition = abducted90 | 2 | Cable 90/90 external rotation; Prone dumbbell external rotation |
| `rotatorCuff.internalRotation` Internal rotation | `shoulderInternalRotation` | none (pattern and group only) | 3 | Cable internal rotation; Band internal rotation; Dumbbell internal rotation (lying) |
| `rotatorCuff.supraspinatus` Supraspinatus raises (scaption) | `shoulderAbduction` | none (pattern and group only) | 2 | Dumbbell scaption; Band scaption; (Cable scaption, optional) |

- Derived: compound 0, isolation 10; bilateral 2, unilateral or alternating 8; classes FW 4, C 3, B 3; variation families with at least three variations: 0; caps: one family at most 4, one class at most 5.5.

**Neck** (nodes: `regionNeck`; **minimum 10** exercises with a primary target in the group and a slot pattern) — *inclusion is an open owner question (Q-S)*

- Anatomical basis: Neck flexors, extensors, side flexors and rotators each need one low-load isolation pattern. Safety wording must be conservative. Inclusion of the neck is an open owner question (Q-S); no machine or cable entry is forced (F07).

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `neck.flexion` Neck flexion | `neckFlexion` | none (pattern and group only) | 3 | Lying neck flexion; Band neck flexion; Harness neck flexion |
| `neck.extension` Neck extension | `neckExtension` | none (pattern and group only) | 3 | Prone neck extension; Band neck extension; Harness neck extension |
| `neck.lateralFlexion` Neck side flexion | `neckLateralFlexion` | none (pattern and group only) | 2 | Side-lying neck side flexion; Band neck side flexion |
| `neck.rotation` Neck rotation | `neckRotation` | none (pattern and group only) | 2 | Manual-resistance neck rotation; Band neck rotation |

- Derived: compound 0, isolation 10; bilateral 6, unilateral or alternating 4; classes FW 2, B 4, BW 4; variation families with at least three variations: 0; caps: one family at most 4, one class at most 5.5.


### Tranche 5.4

**Biceps and brachialis** (nodes: `upperArmAnterior`; **minimum 17** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: The elbow flexors bend the elbow in different forearm positions: biceps (supinated), brachialis (any), brachioradialis (neutral and pronated; counted under Forearms). Slots are discriminated by the recorded arm position or grip, which is how the long and short biceps heads are covered without an L4 minimum. Only entries that change the arm position, grip, implement or side worked are listed (superficial-variant risk, F07).

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `biceps.armBesideBody` Curls with the arm beside the body | `elbowFlexion` | armPosition = besideBody | 7 | Barbell curl; EZ-bar curl; Dumbbell curl; Alternating dumbbell curl; Cable curl; Single-arm cable curl; Band curl |
| `biceps.armBehindBody` Curls with the arm behind the body | `elbowFlexion` | armPosition = behindBody | 2 | Incline dumbbell curl; Bayesian cable curl |
| `biceps.armSupported` Curls with the arm supported in front | `elbowFlexion` | armPosition = supportedInFront | 5 | EZ-bar preacher curl; Machine preacher curl; Single-arm dumbbell preacher curl; Cable preacher curl; Concentration curl; (Spider curl, optional) |
| `biceps.neutralGrip` Neutral-grip (hammer) curls | `elbowFlexion` | grip = neutral | 3 | Hammer curl; Rope hammer curl; Band hammer curl; (Cross-body hammer curl, optional); (Suspension trainer biceps curl, optional) |

- Derived: compound 0, isolation 17; bilateral 12, unilateral or alternating 5; classes FW 9, M 1, C 5, B 2; variation families with at least three variations: 2; caps: one family at most 5.1, one class at most 9.35.

**Triceps** (nodes: `upperArmPosterior`; **minimum 24** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: The triceps extend the elbow; the long head also crosses the shoulder, so overhead and neutral-arm positions load it differently. Overhead work is the discriminator for the long head ("at least n exercises with the arm overhead").

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `triceps.overhead` Extensions with the arm overhead | `elbowExtension` | armPosition = overhead | 5 | Overhead dumbbell triceps extension; EZ-bar overhead triceps extension; Overhead cable rope extension; Single-arm overhead dumbbell extension; Band overhead triceps extension |
| `triceps.pushdown` Pushdowns with the arm beside the body | `elbowExtension` | armPosition = besideBody | 5 | Rope pushdown; Straight-bar pushdown; Reverse-grip pushdown; Single-arm cable pushdown; Band pushdown |
| `triceps.lying` Lying extensions | `elbowExtension` | bodyPosition = lying | 3 | EZ-bar skull crusher; Dumbbell lying triceps extension; Cable lying triceps extension |
| `triceps.kickback` Kickbacks | `elbowExtension` | bodyPosition = bentOver | 3 | Dumbbell kickback; Cable kickback; Band kickback |
| `triceps.machine` Machine extension | `elbowExtension` | class in M | 1 | Machine triceps extension |
| `triceps.closeGripPress` Close-grip presses and push-ups | `horizontalPush` | none (pattern and group only) | 4 | Close-grip bench press; Neutral-grip dumbbell press; Close-grip push-up; Smith machine close-grip press |
| `triceps.dips` Dip variants | `verticalPush` | none (pattern and group only) | 3 | Parallel-bar dip; Bench dip; Machine-assisted dip |

- Derived: compound 7, isolation 17; bilateral 19, unilateral or alternating 5; classes FW 8, M 2, C 7, S 1, B 3, BW 3; variation families with at least three variations: 3; caps: one family at most 7.2, one class at most 13.2.

**Forearms and grip** (nodes: `forearms`; **minimum 19** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: Flexors and extensors of wrist and fingers, pronators and supinators, and brachioradialis. Grip holds use the finger flexors. Brachioradialis work is counted here, not under Biceps and brachialis.

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `forearms.wristFlexion` Wrist flexion | `wristFlexion` | none (pattern and group only) | 4 | Barbell wrist curl; Dumbbell wrist curl; Cable wrist curl; Band wrist curl |
| `forearms.wristExtension` Wrist extension | `wristExtension` | none (pattern and group only) | 4 | Reverse barbell wrist curl; Dumbbell reverse wrist curl; Cable reverse wrist curl; Band wrist extension |
| `forearms.brachioradialis` Pronated-grip elbow flexion (brachioradialis) | `elbowFlexion` | grip = pronated | 3 | Reverse barbell curl; Reverse cable curl; Zottman curl |
| `forearms.rotation` Forearm rotation | `forearmRotation` | none (pattern and group only) | 2 | Dumbbell forearm pronation and supination; Band forearm rotation |
| `forearms.gripHold` Grip holds | `gripHold` | none (pattern and group only) | 3 | Dead hang; Towel hang; Plate pinch hold |
| `forearms.carries` Carries with a forearm emphasis | `carryBilateral`, `carryUnilateral` | none (pattern and group only) | 3 | Farmer's carry (dumbbells); Suitcase carry; Kettlebell farmer's carry |

- Derived: compound 3, isolation 16; bilateral 10, unilateral or alternating 9; classes FW 10, C 3, B 3, KB 1, BW 2; variation families with at least three variations: 2; caps: one family at most 5.7, one class at most 10.45.


### Tranche 5.5

**Glutes** (nodes: `glutes`; **minimum 26** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: Gluteus maximus extends the hip; medius and minimus abduct and stabilise the pelvis. Hip extension slots are split by class, laterality and mechanics so that a bridge, a kickback and a reverse hyperextension each have their own slot (a single exercise fills one slot only). Hinge slots count exercises with a glutes primary; deadlift primaries depend on Q-P.

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `glutes.thrustLoaded` Loaded hip thrusts | `hipExtension` | class in FW, M, S, B; mechanics = compound | 5 | Barbell hip thrust; Dumbbell hip thrust; Smith machine hip thrust; Machine hip thrust; Banded hip thrust |
| `glutes.bridgeBodyweight` Bodyweight bridges and thrusts | `hipExtension` | class in BW; mechanics = compound | 4 | Glute bridge; Single-leg glute bridge; Single-leg hip thrust; Feet-elevated glute bridge |
| `glutes.kickback` Kickbacks (single-leg isolation) | `hipExtension` | mechanics = isolation; laterality = unilateral or alternating | 4 | Cable glute kickback; Machine glute kickback; Quadruped donkey kick; Band glute kickback |
| `glutes.reverseHyper` Reverse hyperextension (decision rule R5) | `hipExtension` | mechanics = isolation; laterality = bilateral | 2 | Reverse hyperextension (bench); Reverse hyperextension (machine) |
| `glutes.hinge` Hinges with a glutes primary | `hinge` | none (pattern and group only) | 4 | Conventional deadlift; Sumo deadlift; Cable pull-through; Kettlebell swing |
| `glutes.lunge` Lunges and steps with a glutes primary | `lunge` | none (pattern and group only) | 2 | High-box dumbbell step-up; Curtsy lunge |
| `glutes.abduction` Gluteus medius stability and abduction (bodyweight, side-lying, band) | `hipAbduction` | `gluteusMedius` as primary | 5 | Clamshell; Side-lying hip abduction; Fire hydrant; Banded lateral walk; Seated banded hip abduction |

- Derived: compound 15, isolation 11; bilateral 14, unilateral or alternating 12; classes FW 6, M 3, C 2, S 1, B 4, KB 1, BW 9; variation families with at least three variations: 5; caps: one family at most 7.8, one class at most 14.3.

**Abductors** (nodes: `abductors`; **minimum 3** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: Open-chain hip abduction against external resistance (machine, cable, standing band): primary abductors with gluteusMedius as secondary. Bodyweight and stability drills belong to the gluteusMedius slot of Glutes (functional double tag, editorial guide 5.7). No Smith machine or kettlebell entry exists.

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `abductors.hipAbduction` Open-chain hip abduction | `hipAbduction` | none (pattern and group only) | 3 | Machine hip abduction; Standing cable hip abduction; Standing band hip abduction |

- Derived: compound 0, isolation 3; bilateral 1, unilateral or alternating 2; classes M 1, C 1, B 1; variation families with at least three variations: 0; caps: one family at most 4, one class at most 4.

**Adductors** (nodes: `adductors`; **minimum 4** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: Hip adduction with the adductor muscles. Wide-stance compound lifts count only if tagged primary and their primary pattern is a slot pattern of this group (they are not).

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `adductors.hipAdduction` Hip adduction | `hipAdduction` | none (pattern and group only) | 4 | Machine hip adduction; Cable hip adduction; Copenhagen plank; Side-lying hip adduction |

- Derived: compound 0, isolation 4; bilateral 1, unilateral or alternating 3; classes M 1, C 1, BW 2; variation families with at least three variations: 1; caps: one family at most 4, one class at most 4.

**Hip flexors** (nodes: `hipFlexors`; **minimum 4** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: Iliopsoas lifts the thigh. Standing drives, cable and band work and supine marches give coverage. Hanging and lying leg raises with an abdominal primary count under Abs.

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `hipFlexors.hipFlexion` Hip flexion | `hipFlexion` | none (pattern and group only) | 4 | Standing cable hip flexion; Seated band knee raise; Supine psoas march; Standing knee drive |

- Derived: compound 0, isolation 4; bilateral 0, unilateral or alternating 4; classes C 1, B 1, BW 2; variation families with at least three variations: 1; caps: one family at most 4, one class at most 4.

**Deep hip rotators** (nodes: `hipExternalRotators`; **minimum 3** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: Small rotators behind the hip; light, controlled work. No cable entry is forced (F07).

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `hipExternalRotators.hipRotation` Hip rotation | `hipRotation` | none (pattern and group only) | 3 | Banded seated hip external rotation; 90/90 hip rotation; Prone hip external rotation; (Cable hip external rotation, optional) |

- Derived: compound 0, isolation 3; bilateral 0, unilateral or alternating 3; classes B 1, BW 2; variation families with at least three variations: 0; caps: one family at most 4, one class at most 4.

**Quadriceps** (nodes: `quadriceps`; **minimum 28** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: Four heads extend the knee; squats, lunges and extensions load them through different ranges. Rectus femoris also flexes the hip. Squat and lunge slots are split by implement class because the load path differs. No cable entry is forced (F07). The trap bar deadlift has a hinge primary pattern and so counts toward no quadriceps slot.

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `quadriceps.squatFreeWeight` Squats with free weights | `squat` | class in FW | 6 | Barbell back squat; Barbell front squat; Goblet squat; Barbell box squat; Zercher squat; Dumbbell squat |
| `quadriceps.squatMachineSmith` Squats and presses on machines | `squat` | class in M, S | 5 | Smith machine squat; Hack squat; Leg press; Single-leg press; Belt squat |
| `quadriceps.squatKettlebell` Kettlebell squats | `squat` | class in KB | 1 | Kettlebell goblet squat |
| `quadriceps.squatBodyweight` Bodyweight squats and holds | `squat` | class in BW | 3 | Bodyweight squat; Wall sit; Sissy squat |
| `quadriceps.lungeFreeWeight` Lunges and steps with free weights | `lunge` | class in FW | 4 | Dumbbell walking lunge; Dumbbell reverse lunge; Dumbbell Bulgarian split squat; Dumbbell step-up |
| `quadriceps.lungeBodyweight` Bodyweight lunges, steps and single-leg squats | `lunge` | class in BW | 5 | Bodyweight lunge; Bodyweight split squat; Bodyweight step-up; Skater squat; Pistol squat |
| `quadriceps.lungeSmith` Smith machine split stance | `lunge` | class in S | 1 | Smith machine split squat |
| `quadriceps.kneeExtension` Knee extension | `kneeExtension` | none (pattern and group only) | 3 | Machine leg extension; Single-leg machine leg extension; Reverse Nordic curl |

- Derived: compound 25, isolation 3; bilateral 16, unilateral or alternating 12; classes FW 10, M 6, S 2, KB 1, BW 9; variation families with at least three variations: 4; caps: one family at most 8.4, one class at most 15.4.

**Hamstrings** (nodes: `hamstrings`; **minimum 13** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: Hamstrings extend the hip and flex the knee. Hinges load the hip function; curls load the knee function. Knee-flexion variants differ by body position (seated, lying, standing, supported) and support, which gives fewer legitimate entries than elbow flexion (arm position and grip); the smaller figure is deliberate and reviewable (F07).

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `hamstrings.hinge` Hinges with a hamstring primary | `hinge` | none (pattern and group only) | 6 | Barbell Romanian deadlift; Dumbbell Romanian deadlift; Stiff-leg deadlift; Single-leg dumbbell Romanian deadlift; Smith machine Romanian deadlift; Kettlebell Romanian deadlift |
| `hamstrings.kneeFlexion` Knee flexion | `kneeFlexion` | none (pattern and group only) | 7 | Seated leg curl; Lying leg curl; Standing single-leg curl; Nordic hamstring curl; Stability ball leg curl; Suspension trainer hamstring curl; Band leg curl |

- Derived: compound 6, isolation 7; bilateral 11, unilateral or alternating 2; classes FW 4, M 3, S 1, B 1, KB 1, BW 3; variation families with at least three variations: 2; caps: one family at most 4, one class at most 7.15.

**Calves** (nodes: `calves`; **minimum 9** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: Gastrocnemius works best with a straight knee; soleus with a bent knee. The recorded knee position discriminates the two slots, so there is no L4 or L3 primary minimum.

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `calves.straightKnee` Calf raises with a straight knee | `plantarFlexion` | kneePosition = straight | 6 | Standing calf raise (machine); Smith machine calf raise; Single-leg dumbbell calf raise; Bodyweight calf raise on a step; Single-leg bodyweight calf raise; Leg press calf raise |
| `calves.bentKnee` Calf raises with a bent knee | `plantarFlexion` | kneePosition = bent | 3 | Seated calf raise (machine); Seated dumbbell calf raise; Bent-knee bodyweight calf raise |

- Derived: compound 0, isolation 9; bilateral 7, unilateral or alternating 2; classes FW 2, M 3, S 1, BW 3; variation families with at least three variations: 1; caps: one family at most 4, one class at most 4.95.

**Shin and outer lower leg** (nodes: `anteriorLowerLeg`, `lateralLowerLeg`, `deepPosteriorLowerLeg`; **minimum 4** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: Tibialis anterior, the fibularis muscles and tibialis posterior support the ankle. Light, single-joint work.

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `lowerLeg.dorsiflexion` Dorsiflexion | `dorsiflexion` | none (pattern and group only) | 2 | Wall tibialis raise; Band dorsiflexion |
| `lowerLeg.inversionEversion` Inversion and eversion | `ankleInversionEversion` | none (pattern and group only) | 2 | Band ankle eversion; Band ankle inversion |

- Derived: compound 0, isolation 4; bilateral 1, unilateral or alternating 3; classes B 3, BW 1; variation families with at least three variations: 0; caps: one family at most 4, one class at most 4.


### Tranche 5.6

**Abs** (nodes: `abs`; **minimum 20** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: Rectus abdominis flexes the trunk and resists extension; transversus abdominis braces. Bodyweight work is legitimate and common, so the bodyweight class is exempt from the class cap in this group.

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `abs.flexionBodyweight` Trunk flexion, bodyweight | `trunkFlexion` | class in BW | 6 | Crunch; Reverse crunch; Sit-up; V-up; Decline sit-up; Stability ball crunch |
| `abs.flexionLoaded` Trunk flexion, loaded | `trunkFlexion` | class in C, M, FW | 3 | Cable crunch; Machine crunch; Weighted crunch (plate) |
| `abs.antiExtension` Anti-extension (planks, rollouts, holds) | `antiExtension` | none (pattern and group only) | 7 | Plank; Weighted plank; Ab wheel rollout; Dead bug; Hollow body hold; Stability ball rollout; Suspension trainer fallout; (Barbell rollout, optional) |
| `abs.hipFlexionRaises` Leg and knee raises with an abdominal primary | `hipFlexion` | none (pattern and group only) | 4 | Hanging knee raise; Hanging leg raise; Lying leg raise; Captain's chair leg raise |

- Derived: compound 12, isolation 8; bilateral 19, unilateral or alternating 1; classes FW 2, M 1, C 1, BW 16; variation families with at least three variations: 3; caps: one family at most 6, one class at most 11; bodyweight exempt from the class cap.

**Obliques** (nodes: `obliques`; **minimum 14** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: Obliques rotate, side-flex and resist rotation and side flexion. Unilateral and alternating work is the norm; bodyweight is exempt from the class cap.

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `obliques.rotation` Rotation | `trunkRotation` | none (pattern and group only) | 5 | Cable high-to-low woodchop; Cable low-to-high woodchop; Russian twist; Machine rotary torso; Band woodchop |
| `obliques.lateralFlexion` Side bends | `trunkLateralFlexion` | none (pattern and group only) | 4 | Dumbbell side bend; Cable side bend; Roman chair side bend; Band side bend |
| `obliques.antiRotation` Anti-rotation | `antiRotation` | none (pattern and group only) | 3 | Cable Pallof press; Band Pallof press; Plank shoulder tap |
| `obliques.antiLateralFlexion` Anti-lateral flexion | `antiLateralFlexion` | none (pattern and group only) | 2 | Side plank; Weighted side plank; (Suitcase carry (obliques primary), optional) |

- Derived: compound 8, isolation 6; bilateral 0, unilateral or alternating 14; classes FW 2, M 1, C 4, B 3, BW 4; variation families with at least three variations: 2; caps: one family at most 4.2, one class at most 7.7; bodyweight exempt from the class cap.

**Lower back** (nodes: `lowerBack`; **minimum 8** exercises with a primary target in the group and a slot pattern)

- Anatomical basis: Erector spinae extend and brace the spine; quadratus lumborum resists side flexion; multifidus stiffens the spine. The reverse hyperextension counts under Glutes (rule R5). The earlier quadratus lumborum slot was removed as a forced entry (F07).

| Slot | Patterns | Discriminator | Min | Intended entries |
|---|---|---|---|---|
| `lowerBack.extension` Trunk extension | `trunkExtension` | none (pattern and group only) | 5 | Back extension (45 degree); Weighted back extension; Machine back extension; Superman; Stability ball back extension |
| `lowerBack.hinge` Hinges with a lower-back primary | `hinge` | none (pattern and group only) | 2 | Barbell good morning; Smith machine good morning |
| `lowerBack.stability` Spinal stability | `antiRotation` | none (pattern and group only) | 1 | Bird dog |

- Derived: compound 3, isolation 5; bilateral 7, unilateral or alternating 1; classes FW 2, M 1, S 1, BW 4; variation families with at least three variations: 1; caps: one family at most 4, one class at most 4.4; bodyweight exempt from the class cap.

## 6. Minimum targets per group (summary, derived)
Equipment columns: free weight, machine, cable, Smith machine, band, kettlebell, bodyweight, other. A number is the count of counted entries of that class; a dash means no minimum (no counted entry). Compound and isolation minimums are counted over the slot entries and add up to the slot total.

| Group | Tranche | Slot total | Compound | Isolation | Bilateral | Unilateral or alternating | FW | M | C | S | B | KB | BW | O | Families |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Chest | 5.1 | 36 | 24 | 12 | 28 | 8 | 10 | 5 | 7 | 2 | 3 | — | 9 | — | 5 |
| Upper back | 5.2 | 25 | 14 | 11 | 22 | 3 | 8 | 4 | 4 | 1 | 2 | — | 6 | — | 3 |
| Lats | 5.2 | 21 | 17 | 4 | 17 | 4 | 3 | 4 | 7 | — | 2 | 1 | 4 | — | 3 |
| Shoulders (deltoid) | 5.3 | 35 | 16 | 19 | 29 | 6 | 13 | 3 | 8 | 1 | 5 | 1 | 4 | — | 5 |
| Rotator cuff | 5.3 | 10 | — | 10 | 2 | 8 | 4 | — | 3 | — | 3 | — | — | — | 0 |
| Neck | 5.3 | 10 | — | 10 | 6 | 4 | 2 | — | — | — | 4 | — | 4 | — | 0 |
| Biceps and brachialis | 5.4 | 17 | — | 17 | 12 | 5 | 9 | 1 | 5 | — | 2 | — | — | — | 2 |
| Triceps | 5.4 | 24 | 7 | 17 | 19 | 5 | 8 | 2 | 7 | 1 | 3 | — | 3 | — | 3 |
| Forearms and grip | 5.4 | 19 | 3 | 16 | 10 | 9 | 10 | — | 3 | — | 3 | 1 | 2 | — | 2 |
| Glutes | 5.5 | 26 | 15 | 11 | 14 | 12 | 6 | 3 | 2 | 1 | 4 | 1 | 9 | — | 5 |
| Abductors | 5.5 | 3 | — | 3 | 1 | 2 | — | 1 | 1 | — | 1 | — | — | — | 0 |
| Adductors | 5.5 | 4 | — | 4 | 1 | 3 | — | 1 | 1 | — | — | — | 2 | — | 1 |
| Hip flexors | 5.5 | 4 | — | 4 | — | 4 | — | — | 1 | — | 1 | — | 2 | — | 1 |
| Deep hip rotators | 5.5 | 3 | — | 3 | — | 3 | — | — | — | — | 1 | — | 2 | — | 0 |
| Quadriceps | 5.5 | 28 | 25 | 3 | 16 | 12 | 10 | 6 | — | 2 | — | 1 | 9 | — | 4 |
| Hamstrings | 5.5 | 13 | 6 | 7 | 11 | 2 | 4 | 3 | — | 1 | 1 | 1 | 3 | — | 2 |
| Calves | 5.5 | 9 | — | 9 | 7 | 2 | 2 | 3 | — | 1 | — | — | 3 | — | 1 |
| Shin and outer lower leg | 5.5 | 4 | — | 4 | 1 | 3 | — | — | — | — | 3 | — | 1 | — | 0 |
| Abs | 5.6 | 20 | 12 | 8 | 19 | 1 | 2 | 1 | 1 | — | — | — | 16 | — | 3 |
| Obliques | 5.6 | 14 | 8 | 6 | — | 14 | 2 | 1 | 4 | — | 3 | — | 4 | — | 2 |
| Lower back | 5.6 | 8 | 3 | 5 | 7 | 1 | 2 | 1 | — | 1 | — | — | 4 | — | 1 |

The slot totals add up to **333** primary-tagged exercises across the 21 groups. That sum is informational. It is not an acceptance target, and the groups do not double count (each exercise has one primary group unless the primary-target principle, Q-P, gives it two). Earlier drafts summed to 477; the reduction comes from removing forced entries, from the pattern rule (section 2) and from enumerating only legitimate variants (F05, F07).

Asymmetry between elbow flexion and knee flexion (F07): Biceps and brachialis list 17 entries and Hamstrings 13 (of which 7 are knee flexion). Elbow flexion has two real discriminators, arm position and grip, which change the joint angles and the muscle emphasis; knee flexion varies by body position and support only. The remaining gap is deliberate and open to the reviewer; the 28 curls of the earlier draft were superficial variants and were removed.

## 7. Conditioning and mobility (tranche 5.7)
These sets are not anatomical groups. They are measured by pattern, not by muscle. Entries marked "needs" depend on a proposed equipment item; if the owner strikes the item, those entries leave the minimum.

| Set | Patterns | Min | Intended entries | Needs |
|---|---|---|---|---|
| `cardio.walkRun` Walking and running | `walkRun` | 6 | Walking; Incline treadmill walk; Treadmill run; Outdoor run; 400 m run; Interval run | — |
| `cardio.ergometer` Ergometer work | `ergometer` | 7 | Exercise bike; Interval cycling; Rowing machine; Interval rowing; Cross-trainer; Ski ergometer; Stair climber | `skiErg`, `stairClimber` |
| `cardio.skipping` Skipping | `skipping` | 3 | Skipping; Alternate-foot skipping; Double-under | — |
| `conditioning.sled` Sled push and pull | `sledPushPull` | 2 | Sled push; Sled drag | `sled` |
| `conditioning.crawl` Crawling | `crawl` | 3 | Bear crawl; Crab walk; Inchworm walk-out | — |
| `conditioning.wholeBody` Whole-body conditioning | `fullBodyConditioning` | 4 | Burpee; Mountain climber; Jumping jack; Battle rope wave | `battleRopes` |
| `power.verticalJump` Vertical jumps | `verticalJump` | 4 | Box jump; Jump squat; Tuck jump; Countermovement jump | `plyoBox` |
| `power.horizontalJump` Horizontal jumps | `horizontalJump` | 2 | Broad jump; Bounding | — |
| `power.lateralJump` Lateral jumps | `lateralJump` | 1 | Skater jump | — |
| `power.upperPlyometric` Upper-body plyometrics | `upperPlyometric` | 3 | Medicine ball slam; Medicine ball chest pass; Plyometric push-up | — |
| `power.explosiveLift` Explosive lifts | `explosiveLift` | 6 | Barbell power clean; Hang power clean; Dumbbell clean and press; Dumbbell snatch; Kettlebell clean; Barbell high pull | — |
| `mobility.static` Static stretches, one per coverage group (rule: one per coverage group, primary target in that group) | `staticStretch` | 21 | Doorway chest stretch (chest); Thread-the-needle stretch (upperBack); Child's pose (lats); Cross-body shoulder stretch (shoulders); Wall external rotation stretch (rotatorCuff); Neck side stretch (neck); Wall biceps stretch (biceps); Overhead triceps stretch (triceps); Wrist flexor stretch (forearms); Pigeon pose (glutes); Standing cross-leg side stretch (abductors); Butterfly stretch (adductors); Hip flexor stretch (hipFlexors); Supine figure-four stretch (hipExternalRotators); Standing quadriceps stretch (quadriceps); Hamstring stretch (hamstrings); Wall calf stretch (calves); Kneeling shin stretch (lowerLeg); Cobra stretch (abs); Standing side-reach stretch (obliques); Knees-to-chest stretch (lowerBack) | — |
| `mobility.dynamic` Dynamic mobility | `dynamicMobility` | 6 | World's greatest stretch; Arm circle; Band shoulder dislocate; Standing hip circle; Front-to-back leg swing; Side-to-side leg swing | — |
| `mobility.spinal` Spinal mobility | `spinalMobility` | 5 | Cat-cow; Thoracic spine extension; Open book thoracic rotation; Pelvic tilt; Gentle neck rotation | — |
| `mobility.softTissue` Soft tissue release (optional; conditional on foamRoller) | `softTissueRelease` | 0 | (Foam roll upper back, optional); (Foam roll quadriceps, optional); (Foam roll glutes, optional); (Foam roll calves, optional) | `foamRoller` |

Totals: conditioning and power sets 41; mobility sets 32. The cardio set is 16. The earlier minimums of 20 cardio, 20 fullBody and 60 mobility exercises were headcounts and were replaced by the enumerated sets. Carries are measured under Forearms (`forearms.carries`), not here. Mechanics for `cardio` and `mobility` exercises: Q-M. Soft tissue release has no minimum unless the owner approves foam rolling content.

## 8. Difficulty distribution
Difficulty uses the owner's definitions (`editorial-guide.md`, section 6).

| Scope | Beginner | Intermediate | Advanced |
|---|---|---|---|
| Each regional tranche (5.1 to 5.6) | 30 to 45 % | 40 to 55 % | 10 to 20 % |
| Tranche 5.7 conditioning | 30 to 45 % | 40 to 55 % | 10 to 20 % |
| Tranche 5.7 mobility | 50 to 70 % | 25 to 40 % | 0 to 10 % |
| Each group with a slot total of 20 or more | at least 20 % | at least 30 % | at least 5 % and at least 2 exercises |
| Each group with a slot total below 20 | at least 1 | at least 1 | optional; record the reason if none |

No system exercise may have an empty difficulty at tranche acceptance. The bands are proposals tuned in the pilot.

## 9. Variation depth, diversity and metrics
| Measure | Minimum, cap or metric |
|---|---|
| Variation families with a root and at least three variations, per group | the "Families" column of section 6 (derived: slots with at least four counted entries) |
| Flagship families with at least five variations | barbell bench press, barbell back squat, conventional deadlift, barbell overhead press, pull-up, barbell row, hip thrust, barbell biceps curl, triceps extension, lateral raise, plank, leg curl (a flagship needs enough slot entries to support it; the pilot confirms) |
| Progression chains of at least three steps | at least two per compound-heavy tranche (5.1, 5.2, 5.3, 5.5, 5.6), where a legitimate chain exists (push-up, squat, pull-up, plank). Stored as `progressionOf` only; the regression view is derived (F19) |
| Unilateral exercises with a bilateral counterpart that lack `unilateralCounterpartOf` | 0 |
| Exercises derived from a catalogue exercise that lack a `variationOf` link | 0 (IC-412 where the difference is recorded) |
| **Family cap (F06, chosen form)** | at most max(30 % of the group total, 4 exercises) in one family. Chosen because a percentage alone would cap small groups below a workable family size; the floor of 4 exercises is the smallest family that satisfies the three-variation rule |
| Equipment class cap | at most max(55 % of the group total, 4 exercises) in one class; bodyweight exempt in abs, obliques and lower back |
| Distinct primary patterns per group with more than one slot | at least the number of slot patterns that differ |
| **Primaries per exercise (F04), per tranche** | mean number of primary targets over the tranche's new exercises at most 1.25; at most 20 % of them with two or more primaries; three or more only with a reviewer note. The metric limits double counting and stops primaries being added to reach a minimum |
| Roles in functional double tags | one primary and one secondary, never two primaries (editorial guide 5.7) |

## 10. Whole-catalogue gates at tranche acceptance
1. 100 % of system exercises in the tranche have: at least one primary target, mechanics (not for cardio and mobility, Q-M), laterality, difficulty, at least one pattern, equipment (or an empty list on purpose), and the four instruction sections.
2. Zero integrity errors (`quality-and-duplicates.md`).
3. Every uncleared near-duplicate flag has a recorded disposition.
4. The gap report (section 12) shows no unmet requirement, or the owner has accepted each remaining gap in the accepted-gaps file (`quality-and-duplicates.md` section 5).


## 11. Current baseline from the 89-exercise seed (recomputed)
The seed has no recorded patterns, mechanics, laterality, difficulty, attributes or relationships. The baseline therefore uses the **proposed content** of `mapping-existing.json` (patterns, mechanics, laterality, difficulty, attributes and equipment roles are proposals; the baseline moves if the owner changes them).

Method (a throwaway script in the session scratchpad; not part of the repository): for each group, take the seed exercises of category other than cardio and mobility with a proposed **primary** target in the group and a primary pattern that is a slot pattern of the group, then fill slots by maximum matching on the discriminators using the proposed attributes. Class is the derived class (inverted row = bodyweight through its `equipmentRoles` override, so no manual override is needed any more). Secondary involvement is reported for information only and never counts.

| Group | Required | Baseline (counted) | Gap | Involved as secondary only (info) | Class baseline (FW/M/C/S/B/KB/BW/O) | Class gaps |
|---|---|---|---|---|---|---|
| Chest | 36 | 8 | 28 | 2 | 5/1/1/0/0/0/1/0 | FW 5, M 4, C 6, S 2, B 3, BW 8 |
| Upper back | 25 | 5 | 20 | 15 | 2/1/1/0/0/0/1/0 | FW 6, M 3, C 3, S 1, B 2, BW 5 |
| Lats | 21 | 6 | 15 | 6 | 1/1/1/0/1/0/2/0 | FW 2, M 3, C 6, B 1, KB 1, BW 2 |
| Shoulders (deltoid) | 35 | 5 | 30 | 22 | 3/1/1/0/0/0/0/0 | FW 10, M 2, C 7, S 1, B 5, KB 1, BW 4 |
| Rotator cuff | 10 | 0 | 10 | 0 | 0/0/0/0/0/0/0/0 | FW 4, C 3, B 3 |
| Neck | 10 | 0 | 10 | 0 | 0/0/0/0/0/0/0/0 | FW 2, B 4, BW 4 |
| Biceps and brachialis | 17 | 5 | 12 | 10 | 4/0/1/0/0/0/0/0 | FW 5, M 1, C 4, B 2 |
| Triceps | 24 | 5 | 19 | 10 | 2/1/1/0/0/0/1/0 | FW 6, M 1, C 6, S 1, B 3, BW 2 |
| Forearms and grip | 19 | 2 | 17 | 11 | 1/0/0/0/0/0/1/0 | FW 9, C 3, B 3, KB 1, BW 1 |
| Glutes | 26 | 5 | 21 | 18 | 3/0/0/0/0/1/1/0 | FW 3, M 3, C 2, S 1, B 4, BW 8 |
| Abductors | 3 | 1 | 2 | 1 | 0/1/0/0/0/0/0/0 | C 1, B 1 |
| Adductors | 4 | 1 | 3 | 6 | 0/1/0/0/0/0/0/0 | C 1, BW 2 |
| Hip flexors | 4 | 0 | 4 | 1 | 0/0/0/0/0/0/0/0 | C 1, B 1, BW 2 |
| Deep hip rotators | 3 | 0 | 3 | 0 | 0/0/0/0/0/0/0/0 | B 1, BW 2 |
| Quadriceps | 28 | 13 | 15 | 4 | 7/3/0/0/0/0/3/0 | FW 3, M 3, S 2, KB 1, BW 6 |
| Hamstrings | 13 | 4 | 9 | 8 | 2/2/0/0/0/0/0/0 | FW 2, M 1, S 1, B 1, KB 1, BW 3 |
| Calves | 9 | 1 | 8 | 4 | 0/1/0/0/0/0/0/0 | FW 2, M 2, S 1, BW 3 |
| Shin and outer lower leg | 4 | 0 | 4 | 0 | 0/0/0/0/0/0/0/0 | B 3, BW 1 |
| Abs | 20 | 6 | 14 | 5 | 1/0/1/0/0/0/4/0 | FW 1, M 1, BW 12 |
| Obliques | 14 | 2 | 12 | 6 | 0/0/1/0/0/0/1/0 | FW 2, M 1, C 3, B 3, BW 3 |
| Lower back | 8 | 0 | 8 | 7 | 0/0/0/0/0/0/0/0 | FW 2, M 1, S 1, BW 4 |

Total: 69 of 333 required slot fills are met by the seed (264 open). Groups with no seed exercise at all: Rotator cuff, Neck, Hip flexors, Deep hip rotators, Shin and outer lower leg, Lower back.

Reading the baseline:
- Seed exercises with a primary in a group but a primary pattern outside its slots are **not counted** (F05): `lib-trap-bar-deadlift` (primary quadriceps, pattern hinge), `lib-sled-push` (primary quadriceps, pattern `sledPushPull`) and `lib-clean-and-press` (primary frontDelts, pattern `explosiveLift`). The sled push and the clean and press are measured in the conditioning sets. The trap bar deadlift is counted nowhere and is a case for the pattern or primary review (flag D).
- The `lib-incline-walk` and the three runs have a muscle primary or `fullBody`, but are cardio and never count toward anatomical groups. Earlier drafts counted them (the previous baseline put 1 exercise in Lower back and 8 in Glutes by counting mobility and cardio rows).
- Slot fills depend on proposed attributes. Without the attribute proposal, the presses, curls, triceps, calf and leg-curl rows would show as `notRecorded`.

**Conditioning and mobility baseline** (by pattern, using the proposed patterns):

| Set | Required | Seed | Seed exercises |
|---|---|---|---|
| `cardio.walkRun` | 6 | 4 | lib-treadmill-run, lib-incline-walk, lib-run-400m, lib-outdoor-run |
| `cardio.ergometer` | 7 | 3 | lib-stationary-bike, lib-rowing-machine, lib-cross-trainer |
| `cardio.skipping` | 3 | 1 | lib-skipping |
| `conditioning.sled` | 2 | 1 | lib-sled-push |
| `conditioning.crawl` | 3 | 0 | — |
| `conditioning.wholeBody` | 4 | 1 | lib-burpee |
| `power.verticalJump` | 4 | 0 | — |
| `power.horizontalJump` | 2 | 0 | — |
| `power.lateralJump` | 1 | 0 | — |
| `power.upperPlyometric` | 3 | 0 | — |
| `power.explosiveLift` | 6 | 1 | lib-clean-and-press |
| `mobility.static` | 21 | 5 | chest, glutes, hamstrings, hipFlexors, lats |
| `mobility.dynamic` | 6 | 1 | lib-worlds-greatest-stretch |
| `mobility.spinal` | 5 | 2 | lib-cat-cow, lib-thoracic-extension |
| `mobility.softTissue` | 0 | 0 | — |

Equipment items actually used by the seed (proposed lists): `kettlebell` 1, `resistanceBand` 1, `smithMachine` 0, `rings` 0, `medicineBall` 0. Raw size: 89 exercises; raw size is not an acceptance measure.

## 12. Gap report format
The coverage tool produces one report per catalogue release and per tranche, as Markdown for people and JSON for tools.

**Row (one per group and dimension):**
| Field | Meaning |
|---|---|
| `tranche` | 5.1 to 5.7 |
| `group` | Group id or set id from `coverage.json` |
| `dimension` | slot, total, mechanics, laterality, equipmentClass, variationFamilies, difficulty, diversity, primariesPerExercise, completeness |
| `item` | The measured item (a slot id, `compound`, `cable`, ...) |
| `required` | Minimum or cap (number, percentage band, or N/A) |
| `actual` | Count in this release |
| `gap` | required minus actual, never below zero (for a cap: excess) |
| `status` | `met`, `gap`, `notRecorded`, `notApplicable` or `accepted` |
| `note` | Reason for N/A, or the accepted-gaps reference |

**Summary lines:** groups met and not met per tranche; dimensions not recorded; total open gaps; open gaps accepted by the owner (with references).

**Example from the baseline (illustrative):**
| Tranche | Group | Dimension | Item | Required | Actual | Gap | Status |
|---|---|---|---|---|---|---|---|
| 5.1 | Chest | slot | chest.flatPress | 6 | 3 | 3 | gap |
| 5.1 | Chest | slot | chest.inclinePress | 5 | 2 | 3 | gap |
| 5.1 | Chest | slot | chest.declinePress | 3 | 0 | 3 | gap |
| 5.1 | Chest | mechanics | compound | 24 | 6 | 18 | gap |
| 5.2 | Lats | slot | lats.straightArm | 4 | 0 | 4 | gap |

The report is a build artefact (published by CI), not a hand-edited document.

## 13. Open questions for the owner
1. **OQ-23 approval:** approve, change or reject the inventory in `coverage.json` and the figures derived from it.
2. **Q-C, pilot and re-baselining:** confirm that tranche 5.1 is a pilot and that the explicit re-baselining step (section 1) precedes 5.2 to 5.7.
3. **Q-A, exercise attributes:** approve the six optional controlled attributes of section 3 (an ADR-0008 clarification or amendment), or decline and accept informational minimums for the attribute-discriminated slots.
4. **Q-M, mechanics for cardio and mobility:** the proposal is to allow the field to be empty for these two categories and exclude them from the mechanics check. The alternative is to force a value. The checks use the empty default until the owner decides.
5. **Q-S, scope:** whether to include neck, pelvic floor and soft tissue release content at all. The neck group is in the inventory (10 entries) and is the first to remove if declined; pelvic floor has no entries; soft tissue release entries are optional.
6. **Q-P, effect on slots:** the row slots of Upper back and Lats, the hinge slots of Glutes, Hamstrings and Lower back, and the dip and chin-up slots depend on how the primary-target principle is answered. The inventory counts whichever exercises carry the primary in the group; the owner's answer may move entries between groups but not change the totals of the pattern-based slots.
7. Whether the family cap (30 % or 4) and class cap (55 % or 4) and the primaries-per-exercise thresholds are right; they are tuned in the pilot.
8. Equipment dependencies: `skiErg`, `stairClimber`, `sled`, `battleRopes`, `plyoBox`, `landmine`, `preacherBench`, `hyperextensionBench`, `suspensionTrainer`, `abWheel`, `stabilityBall`, `foamRoller` (see `equipment.md`). Entries that need an item the owner does not approve leave the minimum.

