# Movement patterns (OQ-22) — proposed

- Status: **Proposed — for owner approval.** WP 8 stage 4 (documentation and reference data only).
- Machine-readable source: `docs/catalogue/reference/movement-patterns.json` (format version 1).
- Requirements: LIB-002, LIB-005; ADR-0008 decision 4 (hierarchical, one or more per exercise, the first is primary).

## 1. Structure
Two levels: a **family** (no parent) and a **pattern** (parent is a family). An exercise carries one or more patterns. The first is its primary pattern; the rest describe secondary demands (for example a push-up is `horizontalPush` first and `antiExtension` second). Filtering by a family includes its patterns.

Each entry has an id (camelCase, stable, never reused), parent, sort order (step 10), en-GB label, definition, inclusion and exclusion criteria. A family also lists the existing categories it usually accompanies.

## 2. Rules for choosing a pattern
1. Choose the pattern that names the movement the exercise trains, not the muscle.
2. Joint movement patterns (for example `elbowFlexion`) apply when one joint moves against resistance. Compound patterns (for example `horizontalPull`) apply when several joints move together.
3. Stability patterns (`antiExtension` and others) apply when the trunk resists movement. They can be secondary patterns on any exercise.
4. Borderline cases follow the Includes and Excludes columns, the Note column and the decision rules R1 to R8 in section 4.

## 3. Relationship to the seven categories
Categories stay as the coarse, one-per-exercise label (TRN-009). Patterns do not replace them and no pattern is derived from a category.

| Category | Usual pattern families | Notes |
|---|---|---|
| `push` | Upper-body push; elbow (extension); shoulder joint (abduction, flexion, horizontal adduction) | Lateral raises and flys are `push` in the seed. |
| `pull` | Upper-body pull; elbow (flexion); scapular; shoulder joint (horizontal abduction, rotation); wrist and grip; neck movement | Curls and rear-delt work are `pull` in the seed. |
| `legs` | Lower-body compound; knee; hip; ankle and foot | Wall sit is `legs` with a squat pattern. |
| `core` | Trunk movement; trunk stability; carries; wrist and grip (hangs); hip (hanging leg raise) | Dead hang is `core` with `gripHold`; hanging leg raise is `core` with `hipFlexion`. |
| `fullBody` | Conditioning; power; mixed patterns | Compound lifts that span upper and lower body. |
| `cardio` | Conditioning (walking and running, ergometer, skipping) | Cardio entries are measured by time or distance. |
| `mobility` | Mobility and stretching | |

The integrity check warns when a category and a pattern family are not in this table. A warning is not an error: a farmer's carry can be `core` with `carryBilateral`, and a thruster can be `fullBody` with `squat`.

## 4. Decision rules for borderline movements (F12)
These rules settle movements that two patterns could claim. Each is proposed; the reviewer may change one, but a rule must not be left open because the checks and the coverage count use the primary pattern.

| Rule | Movement | Decision |
|---|---|---|
| R1 | Push press | `verticalPush` only. The leg dip assists a press that is still the main demand. `explosiveLift` is not added. |
| R2 | Incline press | Up to about 45 degrees `horizontalPush`; steeper angles `verticalPush`. |
| R3 | Thruster and other continuous two-phase movements | List the patterns in the order of the phases; the first is primary. Thruster: `squat`, then `verticalPush`. Clean and press: `explosiveLift`, then `verticalPush`. Thrusters are not `fullBodyConditioning`. |
| R4 | Upright row | `verticalPull` (hands travel vertically, elbows lead). Primary `sideDelts`, secondary `trapeziusUpper`. Not `shoulderAbduction` (compound) and not `scapularElevation` (that is the shrug). |
| R5 | Back extension, reverse hyperextension, superman | By the segment that moves. Torso moves on fixed legs (45 degree back extension, machine back extension) or both ends lift (superman): `trunkExtension`, primary `lowerBack`. Legs move on a fixed torso (reverse hyperextension): `hipExtension`, primary `glutes`. None of the three is `hinge`. |
| R6 | Hip thrust, glute bridge, kettlebell swing | Thrust and bridge are `hipExtension`, not `hinge`. A kettlebell swing is a ballistic `hinge`. `explosiveLift` is reserved for lifts that catch the load (cleans, snatches, high pulls). |
| R7 | Leg press, wall sit, step-up, trap bar deadlift | Leg press and wall sit are `squat`. Step-ups are `lunge`. Trap bar deadlift is `hinge` first, `squat` second. |
| R8 | Dips, pullovers, hanging leg raise, soft tissue release | Dips are `verticalPush`. Pullovers are `shoulderExtension`. Hanging leg raise is `hipFlexion` first, `trunkFlexion` second. Soft tissue release depends on the owner approving foam rolling content. |

Debatable and left for the owner: dips as vertical push (R8), leg press as squat (R7), upright row home (R4).

## 5. Mapping of existing exercises
Every existing exercise has a proposed pattern in `mapping-existing.md`. No existing exercise has a pattern today.

## 6. Entries
| Id | Name | Definition | Includes | Excludes | Note |
|---|---|---|---|---|---|
| **`lowerBodyCompound`** | **Lower-body compound** (family) | Multi-joint movements that bend and straighten the hips and knees under load. | Squat, hinge and lunge patterns. | Single-joint knee or hip work (Knee joint, Hip joint). | Usual categories: legs |
| &nbsp;&nbsp;`squat` | Squat | Knees and hips bend together with the trunk fairly upright and both feet loaded. | Barbell, goblet, hack and Smith squats; leg press; wall sit; sissy squat. | Split stances (Lunge); hip-dominant lifts (Hinge). | Leg press and wall sit are classed here: debatable. A thruster is a squat first and a vertical push second (decision rule R3). |
| &nbsp;&nbsp;`hinge` | Hinge | The hips travel back and forward with a near-neutral spine; knees bend only a little. | Deadlifts, Romanian deadlifts, good mornings, kettlebell swings, pull-throughs. | Squats; isolated hip thrusts (Hip extension); back extensions of any angle (Trunk extension). | Kettlebell swing is a ballistic hinge. |
| &nbsp;&nbsp;`lunge` | Lunge and split stance | One leg leads or carries most of the load while the other supports from behind or the side. | Lunges, split squats, step-ups, single-leg squats, skater squats. | Bilateral squats; single-leg hinges (Hinge). | Single-leg hinges are Hinge with unilateral laterality. |
| **`upperPush`** | **Upper-body push** (family) | Movements that press a load or the body away from the torso. | Horizontal and vertical push. | Single-joint elbow extension and fly movements. | Usual categories: push |
| &nbsp;&nbsp;`horizontalPush` | Horizontal push | Pressing along a line roughly level with the chest, including inclines up to about 45 degrees. | Bench and chest presses, push-ups, floor presses. | Overhead presses (Vertical push); flys (Shoulder horizontal adduction). | Incline angles above about 45 degrees count as vertical push. |
| &nbsp;&nbsp;`verticalPush` | Vertical push | Pressing overhead or steeply upwards, or pushing the body upwards against the hands. | Overhead presses, push presses (decision rule R1), pike push-ups, dips. | Flat presses (Horizontal push). | Dips are classed here: debatable. A push press stays here: the leg dip assists a press that is still the main demand. |
| **`upperPull`** | **Upper-body pull** (family) | Movements that pull a load or the body towards the torso. | Horizontal and vertical pull. | Single-joint elbow flexion and shoulder blade work. | Usual categories: pull |
| &nbsp;&nbsp;`horizontalPull` | Horizontal pull | Pulling the hands towards the torso along a roughly horizontal line. | Rows with any implement, inverted rows, seated cable rows. | Pulldowns and pull-ups (Vertical pull). |  |
| &nbsp;&nbsp;`verticalPull` | Vertical pull | Pulling the hands down towards the torso, pulling the body up towards the hands, or pulling a load up along the torso with the elbows leading. | Pull-ups, chin-ups, lat pulldowns; upright rows (decision rule R4). | Rows (Horizontal pull); straight-arm pulldowns (Shoulder extension); shrugs (Scapular elevation). | Upright rows are given this home at review (F12): the hands travel vertically and the elbows lead. Primary target sideDelts with trapeziusUpper as secondary. Owner may prefer a pattern of their own. |
| **`elbowJoint`** | **Elbow** (family) | Single-joint movements at the elbow. | Elbow flexion and extension. | Compound presses and pulls. | Usual categories: push, pull |
| &nbsp;&nbsp;`elbowFlexion` | Elbow flexion | Bending the elbow against resistance. | All curl variations. | Pull-ups and rows, which are compound pulls. |  |
| &nbsp;&nbsp;`elbowExtension` | Elbow extension | Straightening the elbow against resistance with the upper arm held in place. | Pushdowns, skull crushers, overhead extensions, kickbacks. | Presses (Horizontal or Vertical push). |  |
| **`shoulderJoint`** | **Shoulder joint** (family) | Single-joint movements of the arm at the shoulder. | Abduction, flexion, extension, horizontal movements and rotation. | Pressing and pulling. | Usual categories: push, pull |
| &nbsp;&nbsp;`shoulderAbduction` | Shoulder abduction | Raising the arm out to the side. | Lateral raises, cable lateral raises, scaption. | Upright rows, which are compound (Vertical pull). |  |
| &nbsp;&nbsp;`shoulderFlexion` | Shoulder flexion | Raising the arm forward and up. | Front raises, plate raises. | Overhead presses. |  |
| &nbsp;&nbsp;`shoulderExtension` | Shoulder extension | Pulling the straight arm down and back. | Straight-arm pulldowns, dumbbell pullovers. | Rows and pulldowns with bent elbows. | Pullover is classed here: debatable (it also trains chest). |
| &nbsp;&nbsp;`shoulderHorizontalAdduction` | Shoulder horizontal adduction | Bringing the arms together across the chest. | Chest flys, cable crossovers, pec deck. | Presses (Horizontal push). |  |
| &nbsp;&nbsp;`shoulderHorizontalAbduction` | Shoulder horizontal abduction | Moving the arms apart behind the line of the shoulders. | Reverse flys, face pulls, band pull-aparts. | Rows (Horizontal pull). |  |
| &nbsp;&nbsp;`shoulderExternalRotation` | Shoulder external rotation | Turning the upper arm outward. | Cable and band external rotations, side-lying rotations. | Face pulls, which are horizontal abduction first. |  |
| &nbsp;&nbsp;`shoulderInternalRotation` | Shoulder internal rotation | Turning the upper arm inward. | Cable and band internal rotations. | Pressing. |  |
| **`scapularMotion`** | **Shoulder blade** (family) | Movements of the shoulder blade on the ribcage. | Elevation, retraction, protraction, depression. | Arm movements at the shoulder joint. | Usual categories: pull |
| &nbsp;&nbsp;`scapularElevation` | Scapular elevation | Lifting the shoulder blades towards the ears. | Shrugs of every implement. | Rows; upright rows, whose elbow-led pull is classed as Vertical pull. |  |
| &nbsp;&nbsp;`scapularRetraction` | Scapular retraction | Drawing the shoulder blades together. | Scapular rows, prone Y-T-W, band retractions. | Full rows (Horizontal pull). |  |
| &nbsp;&nbsp;`scapularProtraction` | Scapular protraction | Pushing the shoulder blades forward around the ribcage. | Push-up plus, cable serratus punch. | Presses. |  |
| &nbsp;&nbsp;`scapularDepression` | Scapular depression | Pulling the shoulder blades down away from the ears. | Straight-arm scapular pulls, support holds on dip bars. | Dips. |  |
| **`kneeJoint`** | **Knee** (family) | Single-joint movements at the knee. | Knee extension and flexion. | Squats, lunges and hinges. | Usual categories: legs |
| &nbsp;&nbsp;`kneeExtension` | Knee extension | Straightening the knee against resistance with the hip fixed. | Leg extensions, band knee extensions, terminal knee extensions. | Squats and presses. |  |
| &nbsp;&nbsp;`kneeFlexion` | Knee flexion | Bending the knee against resistance with the hip fixed. | Leg curls, Nordic curls, stability-ball curls. | Romanian deadlifts (Hinge). | Slider curls are not listed: no sliders item is proposed (equipment.md section 4). |
| **`hipJoint`** | **Hip** (family) | Single-joint movements at the hip. | Extension, abduction, adduction, flexion, rotation. | Squats, lunges and hinges. | Usual categories: legs, core |
| &nbsp;&nbsp;`hipExtension` | Hip extension | Driving the thigh back with the knee and trunk largely fixed. | Hip thrusts, glute bridges, kickbacks, reverse hyperextensions. | Hinges (Hinge); back extensions where the torso moves on fixed legs (Trunk extension). | Reverse hyperextension is hip extension (legs move, torso fixed): decision rule R5. |
| &nbsp;&nbsp;`hipAbduction` | Hip abduction | Moving the leg out to the side. | Machine and cable abduction, side-lying raises, banded walks, clamshells. | Side planks (Anti-lateral flexion); squats with a band. |  |
| &nbsp;&nbsp;`hipAdduction` | Hip adduction | Moving the leg towards the midline. | Machine and cable adduction, Copenhagen plank, squeeze-ball work. | Wide-stance compound lifts, which are classed by their main pattern. |  |
| &nbsp;&nbsp;`hipFlexion` | Hip flexion | Lifting the thigh towards the trunk. | Hanging knee raises, hanging leg raises, standing cable knee drives, supine leg raises. | Crunches (Trunk flexion). | Hanging raises often pair hip flexion with trunk flexion. |
| &nbsp;&nbsp;`hipRotation` | Hip rotation | Turning the thigh in or out at the hip. | Seated and prone hip rotations, 90/90 transitions, banded external rotations. | Hinges and squats. |  |
| **`ankleFoot`** | **Ankle and foot** (family) | Single-joint movements at the ankle. | Plantar flexion, dorsiflexion, inversion and eversion. | Squats and lunges. | Usual categories: legs |
| &nbsp;&nbsp;`plantarFlexion` | Plantar flexion | Pointing the foot down, as in a calf raise. | Standing, seated, donkey and single-leg calf raises. | Jumps and skipping. |  |
| &nbsp;&nbsp;`dorsiflexion` | Dorsiflexion | Lifting the toes towards the shin. | Tibialis raises, banded dorsiflexion. | Plantar flexion. |  |
| &nbsp;&nbsp;`ankleInversionEversion` | Ankle inversion and eversion | Turning the sole inward or outward. | Banded inversion and eversion, side-lying foot raises. | Plantar flexion and dorsiflexion. |  |
| **`trunkMotion`** | **Trunk movement** (family) | Movements in which the trunk itself moves. | Flexion, extension, rotation and side flexion. | Bracing against movement (Trunk stability). | Usual categories: core |
| &nbsp;&nbsp;`trunkFlexion` | Trunk flexion | Curling the ribcage towards the pelvis. | Crunches, cable crunches, sit-ups, reverse crunches. | Leg raises that mainly flex the hip (Hip flexion). |  |
| &nbsp;&nbsp;`trunkExtension` | Trunk extension | Arching the spine or lifting the trunk against gravity. | Back extensions at any angle, supermans, loaded or machine back extensions. | Hip thrusts (Hip extension); hinges; reverse hyperextensions (Hip extension). | Decision rule R5: if the torso moves on fixed legs, or both ends lift (superman), it is trunk extension. If the legs move on a fixed torso, it is hip extension. |
| &nbsp;&nbsp;`trunkRotation` | Trunk rotation | Turning the ribcage relative to the pelvis against resistance. | Cable woodchops, Russian twists, rotational throws. | Anti-rotation holds. |  |
| &nbsp;&nbsp;`trunkLateralFlexion` | Trunk lateral flexion | Bending the trunk sideways against resistance. | Side bends, weighted side bends, hanging side tilts. | Side planks. |  |
| **`trunkStability`** | **Trunk stability** (family) | Exercises that resist unwanted trunk movement. | Anti-extension, anti-rotation, anti-lateral flexion. | Movements in which the trunk is the mover. | Usual categories: core |
| &nbsp;&nbsp;`antiExtension` | Anti-extension | Resisting arching of the lower back. | Planks, rollouts, dead bugs, body saws. | Crunches (Trunk flexion). |  |
| &nbsp;&nbsp;`antiRotation` | Anti-rotation | Resisting twisting of the trunk. | Pallof presses, bird dogs, single-arm planks. | Cable woodchops (Trunk rotation). |  |
| &nbsp;&nbsp;`antiLateralFlexion` | Anti-lateral flexion | Resisting sideways bending of the trunk. | Suitcase carries, side planks, single-arm overhead holds. | Side bends (Trunk lateral flexion). |  |
| **`carries`** | **Carries** (family) | Moving while holding a load. | Bilateral and unilateral carries. | Loaded movements without walking (see Locomotion). | Usual categories: core |
| &nbsp;&nbsp;`carryBilateral` | Bilateral carry | Walking with equal loads in both hands, on both shoulders or at the front. | Farmer's carries, front-rack carries, yoke carries. | Unilateral carries. |  |
| &nbsp;&nbsp;`carryUnilateral` | Unilateral carry | Walking with a load on one side or in one arm. | Suitcase carries, waiter's carries, offset carries. | Bilateral carries. |  |
| **`conditioning`** | **Conditioning and locomotion** (family) | Repeated movement that raises heart rate and trains work capacity. | Running, ergometers, skipping, sled work, crawling and whole-body circuits. | Strength lifts and plyometrics. | Usual categories: cardio, fullBody |
| &nbsp;&nbsp;`walkRun` | Walking and running | Moving on foot at any pace. | Treadmill and outdoor walking, running and sprinting; incline walking. | Sled work and cardio machines. |  |
| &nbsp;&nbsp;`ergometer` | Ergometer work | Continuous or interval work on a cardio machine. | Bike, rower, cross-trainer, ski ergometer, stair climber (the last two need the proposed equipment items `skiErg` and `stairClimber`). | Running on a treadmill (Walking and running), which is a locomotion pattern. |  |
| &nbsp;&nbsp;`skipping` | Skipping | Repeated small jumps over a rope. | Single, double and alternate-foot skipping. | Box jumps (Vertical jump). |  |
| &nbsp;&nbsp;`sledPushPull` | Sled push and pull | Moving a loaded sled by pushing or pulling. | Sled push, sled drag, backward drag. | Weighted carries. |  |
| &nbsp;&nbsp;`crawl` | Crawling | Moving on hands and feet or hands and knees. | Bear, crab and leopard crawls. | Sled work. |  |
| &nbsp;&nbsp;`fullBodyConditioning` | Whole-body conditioning | Multi-joint circuits and drills not covered by another conditioning pattern. | Burpees, battle ropes, mountain climbers, jumping jacks. | Olympic lift derivatives (Explosive lift); thrusters (Squat then Vertical push, decision rule R3). |  |
| **`power`** | **Power and plyometrics** (family) | Fast, forceful movements and jumps. | Jumps, upper-body plyometrics and explosive lifts. | Slow strength lifts. | Usual categories: fullBody |
| &nbsp;&nbsp;`verticalJump` | Vertical jump | Jumping upward and landing. | Box jumps, squat jumps, tuck jumps. | Skipping (Conditioning). |  |
| &nbsp;&nbsp;`horizontalJump` | Horizontal jump | Jumping forward or bounding. | Broad jumps, bounds, hurdle hops. | Vertical jumps. |  |
| &nbsp;&nbsp;`lateralJump` | Lateral jump | Jumping or bounding side to side. | Skater jumps, lateral box jumps. | Forward jumps. |  |
| &nbsp;&nbsp;`upperPlyometric` | Upper-body plyometric | Fast throws, slams and explosive push-ups. | Medicine ball slams and throws, clap push-ups. | Slow presses. |  |
| &nbsp;&nbsp;`explosiveLift` | Explosive lift | Fast lifts that finish with a hip and knee extension and catch the load. | Cleans, snatches, high pulls and their dumbbell or kettlebell forms. | Kettlebell swings (Hinge); push presses (Vertical push, decision rule R1). |  |
| **`wristGrip`** | **Wrist and grip** (family) | Movements and holds at the wrist and hand. | Wrist flexion and extension, forearm rotation, grip holds. | Elbow flexion. | Usual categories: pull, core |
| &nbsp;&nbsp;`wristFlexion` | Wrist flexion | Curling the hand towards the forearm. | Wrist curls, plate pinches with wrist movement. | Finger-only grip work (Grip hold). |  |
| &nbsp;&nbsp;`wristExtension` | Wrist extension | Lifting the back of the hand towards the forearm. | Reverse wrist curls. | Wrist flexion. |  |
| &nbsp;&nbsp;`forearmRotation` | Forearm rotation | Turning the palm up or down. | Pronation and supination with a dumbbell or bar. | Elbow flexion with a supinated grip. |  |
| &nbsp;&nbsp;`gripHold` | Grip hold | Holding a position or object with the hand muscles. | Dead hangs, plate pinches, towel hangs. | Carries (Carries). | Dead hang is classed here and has category core in the seed. |
| **`mobilityStretch`** | **Mobility and stretching** (family) | Work aimed at range of motion rather than load. | Static stretches, dynamic mobility, spinal mobility, soft tissue release. | Strength exercises done through a long range. | Usual categories: mobility |
| &nbsp;&nbsp;`staticStretch` | Static stretch | Holding a lengthened position for time. | Hamstring, hip flexor and chest stretches; child's pose. | Movement through range (Dynamic mobility). |  |
| &nbsp;&nbsp;`dynamicMobility` | Dynamic mobility | Moving through a joint range under control without load. | Leg swings, world's greatest stretch, arm circles. | Held stretches (Static stretch). |  |
| &nbsp;&nbsp;`spinalMobility` | Spinal mobility | Moving the spine through flexion, extension or rotation. | Cat-cow, thoracic extension, open-book rotation. | Loaded trunk flexion or extension (Trunk movement). |  |
| &nbsp;&nbsp;`softTissueRelease` | Soft tissue release | Self-applied pressure with a roller or ball. | Foam rolling, ball release. | Held stretches (Static stretch) and movement through range (Dynamic mobility). | Conditional on the owner approving foam rolling content (equipment `foamRoller`); otherwise drop this pattern. |
| **`neckMotion`** | **Neck movement** (family) | Movements of the head and neck. | Flexion, extension, side flexion and rotation. | Shoulder blade work. | Usual categories: pull |
| &nbsp;&nbsp;`neckFlexion` | Neck flexion | Nodding the head forward against resistance. | Harness, plate and manual-resistance flexion; chin tucks. | Neck extension, side flexion and rotation. |  |
| &nbsp;&nbsp;`neckExtension` | Neck extension | Tilting the head back against resistance. | Harness, plate and manual-resistance extension. | Neck flexion, side flexion and rotation. |  |
| &nbsp;&nbsp;`neckLateralFlexion` | Neck lateral flexion | Tilting the ear towards the shoulder against resistance. | Manual-resistance and band side flexion. | Neck flexion, extension and rotation. |  |
| &nbsp;&nbsp;`neckRotation` | Neck rotation | Turning the head to look over the shoulder against resistance. | Manual-resistance and band rotation (sternocleidomastoid and splenius). | Neck flexion, extension and side flexion. |  |
