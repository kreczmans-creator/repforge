# Equipment reference list — proposed

- Status: **Proposed — for owner approval.** WP 8 stage 4 (documentation and reference data only).
- Machine-readable source: `docs/catalogue/reference/equipment.json`.
- Requirements: LIB-003, LIB-005; `docs/training-taxonomy.md` (21 ids).

## 1. Rules
1. The 21 existing ids are unchanged. Ids, labels and meaning stay as `docs/training-taxonomy.md` has them.
2. An exercise lists the items it needs. The list is empty when it needs none. Filtering by available equipment is unchanged: an exercise shows when every item it needs is available.
3. Each item has an **equipment class** for the coverage matrix: free weight, machine, cable, Smith machine, band, kettlebell, bodyweight, or other. Classes are not stored on exercises; the integrity tool derives them (see `coverage-matrix.md`, section 2).
4. Each item has a **role**: `load` (adds external load), `support` (holds the body or an implement and adds no load), `cardio` (a cardio machine), or `implement` (a tool with its own load or movement).
5. A **support** item does not make an exercise an equipment-class exercise. A dumbbell bench press is free weight; a bodyweight dip on dip bars is bodyweight.
6. Proposed additions are marked `proposed`. One is `proposedConditional`. Nothing is added to the app until the owner approves and stage 3 or the first catalogue release ships it.

## 2. Proposed additions and why
Ten additions, each needed to describe an exercise accurately or to reach a coverage minimum.

- `landmine`, `sled`, `plyoBox`, `suspensionTrainer`, `battleRopes`, `preacherBench`, `hyperextensionBench`, `abWheel`, `stabilityBall`: proposed.
- `foamRoller`: proposed, conditional on approving soft tissue release content.

Four existing seed exercises would be re-tagged by a revision once the owner approves: `lib-ab-wheel` (adds `abWheel`), `lib-sled-push` (`sled` instead of `plate`), `lib-preacher-curl` (adds `preacherBench`) and `lib-step-up` (`plyoBox` instead of `bench`, or keep `bench`).

## 3. All items
| Id | Label | Class | Role | Status | Justification or note |
|---|---|---|---|---|---|
| `barbell` | Barbell | freeWeight | load | existing |  |
| `ezBar` | EZ bar | freeWeight | load | existing |  |
| `trapBar` | Trap bar | freeWeight | load | existing |  |
| `dumbbell` | Dumbbells | freeWeight | load | existing |  |
| `kettlebell` | Kettlebell | kettlebell | load | existing |  |
| `cable` | Cable station | cable | load | existing |  |
| `machine` | Machine (selectorised or plate-loaded) | machine | load | existing |  |
| `smithMachine` | Smith machine | smithMachine | load | existing |  |
| `bench` | Bench | bodyweight | support | existing | Flat or adjustable bench. A support item: it adds no external load. |
| `squatRack` | Squat rack | bodyweight | support | existing | Support item. |
| `pullUpBar` | Pull-up bar | bodyweight | support | existing | Support item. |
| `dipBars` | Dip bars | bodyweight | support | existing | Support item. |
| `resistanceBand` | Resistance band | band | load | existing | Covers loop bands, tube bands and mini bands. |
| `plate` | Weight plate | freeWeight | load | existing | Also used for weighted bodyweight work, such as plate-loaded planks. |
| `medicineBall` | Medicine ball | other | load | existing | Covers slam balls and wall balls. |
| `rings` | Gymnastic rings | bodyweight | support | existing | Support item. |
| `treadmill` | Treadmill | other | cardio | existing |  |
| `bike` | Exercise bike | other | cardio | existing | Covers upright, recumbent and air bikes unless the owner asks for a split. |
| `rower` | Rowing machine | other | cardio | existing |  |
| `elliptical` | Cross-trainer | other | cardio | existing |  |
| `skippingRope` | Skipping rope | other | implement | existing |  |
| `landmine` | Landmine attachment | bodyweight | support | proposed | Anchors one end of a barbell. Enables angled presses, rows and rotational work that no existing item represents. Tagged together with barbell or plate, which supply the load. Without it, a user without an anchor still sees these exercises. |
| `sled` | Sled | other | implement | proposed | The seed tags the sled push as plate. A sled is a distinct item many gyms lack. Needed for push and drag patterns in conditioning. |
| `plyoBox` | Plyo box or step | bodyweight | support | proposed | Needed for box jumps, step-ups and elevated work. The seed uses bench for step-ups; a box is the more accurate requirement. |
| `suspensionTrainer` | Suspension trainer | bodyweight | support | proposed | Adjustable straps hung from an anchor (generic name; no brand). Supports inverted rows, push-up variants, fallouts and assisted single-leg work. |
| `battleRopes` | Battle ropes | other | implement | proposed | Needed for rope conditioning patterns. |
| `preacherBench` | Preacher bench | bodyweight | support | proposed | Angled arm pad for preacher curls. The seed tags preacher curl as ezBar and bench, which shows it to users who own a flat bench only. |
| `hyperextensionBench` | Back extension bench | bodyweight | support | proposed | Roman chair or 45 degree bench. Required for back extensions and reverse hyperextensions, essential for Lower back coverage. |
| `abWheel` | Ab wheel | bodyweight | implement | proposed | The seed rollout lists no equipment, so it appears as bodyweight-only. The wheel is a required item. |
| `stabilityBall` | Stability ball | other | implement | proposed | Needed for ball curls, rollouts and ball-supported core work. |
| `foamRoller` | Foam roller | other | implement | proposedConditional | Only if the owner approves soft tissue release content (pattern softTissueRelease). Otherwise drop both. |

## 4. Candidates considered and not proposed
| Candidate | Why not proposed |
|---|---|
| Low parallel bars (`parallettes`) | Push-up and L-sit variations can be tagged without them; add only if the owner wants gymnastic content. |
| Glute-ham developer (`gluteHamDeveloper`) | Back extension bench covers the common cases; a separate item adds little. |
| Dip belt or weighted vest (`weightBelt`) | Weighted pull-ups and dips can be tagged plate or dumbbell; the logging type already records the added load. |
| Sandbag (`sandbag`) | Rare in gyms. Defer. |
| Ski ergometer (`skiErg`) | Cardio machine variety already met by five items. Candidate if the owner wants more conditioning options. |
| Stair climber (`stairClimber`) | As ski ergometer. |
| Air bike (`airBike`) | Folded into bike. |
| Branded suspension trainers (`trx`) | Brand names are not used; see suspensionTrainer. |

## 5. Equipment classes
| Class | Items | Counts for coverage when |
|---|---|---|
| freeWeight | barbell, ezBar, trapBar, dumbbell, plate | The load comes from one of these. |
| machine | machine | A selectorised or plate-loaded machine supplies the load. |
| cable | cable | A cable station supplies the load. |
| smithMachine | smithMachine | The Smith machine supplies the load. |
| band | resistanceBand | A band supplies the resistance or assistance. |
| kettlebell | kettlebell | A kettlebell supplies the load. |
| bodyweight | none, or only support items | No load item is listed. |
| other | medicineBall, cardio machines, skippingRope, sled, battleRopes, stabilityBall, foamRoller | An implement or cardio machine is the main item. |

## 6. Open points for the owner
1. Approve the ten additions, or strike any.
2. Confirm that `bike` covers upright, recumbent and air bikes.
3. Confirm whether to add a ski ergometer or stair climber later.
