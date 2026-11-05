# Equipment reference list — approved

- Status: **Approved by the owner 2026-11-05 (OQ-22 / OQ-23).** WP 8 stage 4 (documentation and reference data only). All 12 additions are approved; the single generic `machine` id is retained (a later split is a reference-data enhancement).
- Machine-readable source: `docs/catalogue/reference/equipment.json`. Id history: `reference/ledger.json`.
- Requirements: LIB-003, LIB-005; `docs/training-taxonomy.md` (21 ids).

## 1. Rules
1. The 21 existing ids are unchanged. Ids, labels and meaning stay as `docs/training-taxonomy.md` has them.
2. An exercise lists the items it needs. The list is empty when it needs none. Filtering by available equipment is unchanged: an exercise shows when every item it needs is available.
3. Each item has an **equipment class** for the coverage matrix: free weight, machine, cable, Smith machine, band, kettlebell, bodyweight, or other. Classes are not stored on exercises; the integrity tool derives them (see `coverage-matrix.md`, section 2).
4. Each item has a **default role**: `load` (supplies the resistance or the assistance), `support` (holds the body or an implement and adds no load), `cardio` (a cardio machine), or `implement` (a tool with its own load or movement, such as a sled or a rope).
5. **Per-exercise role rule (F21).** In one exercise an item is a `load` item if the resistance or assistance comes from it, and a `support` item if it only holds the body or another item. The default role applies unless the exercise record overrides it with `equipmentRoles` (a map from item id to `load` or `support`). Example: in an inverted row the barbell is fixed in a rack and the body is the load, so `equipmentRoles: {"barbell": "support"}`; the exercise is bodyweight. In a barbell row the barbell is `load`. An override is allowed only between `load` and `support` and needs a note.
6. A **support** item never changes the class. A dumbbell bench press is free weight; a bodyweight dip on dip bars is bodyweight; an ab wheel rollout and a stability-ball hamstring curl are bodyweight (the ball and the wheel are supports, aligned at revision 2).
7. The 12 additions are marked `approved`. Nothing is added to the app until stage 3 or the first catalogue release ships it.
8. Reference status: each item is `active` or `retired`. A retired item is never removed or reused (`reference/ledger.json`); active exercises must not use it.

## 2. Approved additions and why
12 additions approved on 2026-11-05, each needed to describe an exercise accurately or to name an item that the patterns already mention.

- `landmine`, `sled`, `plyoBox`, `suspensionTrainer`, `battleRopes`, `preacherBench`, `hyperextensionBench`, `abWheel`, `stabilityBall`: approved.
- `skiErg`, `stairClimber`: approved (F20), because the `ergometer` pattern names them.
- `foamRoller`: approved. Soft tissue release content is deferred by owner decision, so no coverage entry depends on it.

Four existing seed exercises are re-tagged in release 2: `lib-ab-wheel` (adds `abWheel`), `lib-sled-push` (`sled` instead of `plate`), `lib-preacher-curl` (adds `preacherBench`) and `lib-step-up` (`plyoBox` instead of `bench`, or keep `bench`). The mapping field `proposedEquipment` carries these.

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
| `landmine` | Landmine attachment | bodyweight | support | approved | Anchors one end of a barbell. Enables angled presses, rows and rotational work that no existing item represents. Tagged together with barbell or plate, which supply the load. Without it, a user without an anchor still sees these exercises. |
| `sled` | Sled | other | implement | approved | The seed tags the sled push as plate. A sled is a distinct item many gyms lack. Needed for push and drag patterns in conditioning. |
| `plyoBox` | Plyo box or step | bodyweight | support | approved | Needed for box jumps, step-ups and elevated work. The seed uses bench for step-ups; a box is the more accurate requirement. |
| `suspensionTrainer` | Suspension trainer | bodyweight | support | approved | Adjustable straps hung from an anchor (generic name; no brand). Supports inverted rows, push-up variants, fallouts and assisted single-leg work. |
| `battleRopes` | Battle ropes | other | implement | approved | Needed for rope conditioning patterns. |
| `preacherBench` | Preacher bench | bodyweight | support | approved | Angled arm pad for preacher curls. The seed tags preacher curl as ezBar and bench, which shows it to users who own a flat bench only. |
| `hyperextensionBench` | Back extension bench | bodyweight | support | approved | Roman chair or 45 degree bench. Required for back extensions and reverse hyperextensions, essential for Lower back coverage. |
| `abWheel` | Ab wheel | bodyweight | support | approved | The seed rollout lists no equipment, so it appears as bodyweight-only. The wheel is a required item. It adds no external load, so it is a support item and the exercise stays in the bodyweight class. |
| `stabilityBall` | Stability ball | bodyweight | support | approved | Needed for ball curls, rollouts and ball-supported core work. It adds no external load, so it is a support item and the exercise stays in the bodyweight class (a dumbbell held on the ball still gives free weight). |
| `skiErg` | Ski ergometer | other | cardio | approved | Approved 2026-11-05. Named by the `ergometer` pattern. |
| `stairClimber` | Stair climber | other | cardio | approved | Approved 2026-11-05. Stair-climbing machine or stepper. |
| `foamRoller` | Foam roller | other | implement | approved | Approved as one of the 12 additions. Soft tissue release content is deferred by owner decision (2026-11-05), so no coverage entry depends on this item. |

## 4. Candidates considered and not proposed
| Candidate | Why not proposed |
|---|---|
| Low parallel bars (`parallettes`) | Push-up and L-sit variations can be tagged without them; add only if the owner wants gymnastic content. |
| Glute-ham developer (`gluteHamDeveloper`) | Back extension bench covers the common cases; a separate item adds little. |
| Dip belt or weighted vest (`weightBelt`) | Weighted pull-ups and dips can be tagged plate or dumbbell; the logging type already records the added load. |
| Sandbag (`sandbag`) | Rare in gyms. Defer. |
| Air bike (`airBike`) | Folded into bike. |
| Branded suspension trainers (`trx`) | Brand names are not used; see suspensionTrainer. |
| Sliders or gliding discs (`sliders`) | Slider curls and body saws can be described with the stability ball or as bodyweight work; add a sliders item only if the owner wants them as a separate requirement (F20: slider curls removed from the knee-flexion pattern and the inventory). |

## 5. Equipment classes
| Class | Items | Counts for coverage when |
|---|---|---|
| freeWeight | barbell, ezBar, trapBar, dumbbell, plate | The load comes from one of these. |
| machine | machine | A selectorised or plate-loaded machine supplies the load or assistance. |
| cable | cable | A cable station supplies the load. |
| smithMachine | smithMachine | The Smith machine supplies the load. |
| band | resistanceBand | A band supplies the resistance or assistance. |
| kettlebell | kettlebell | A kettlebell supplies the load. |
| bodyweight | none, or only support items | No load item is listed after the per-exercise role rule is applied. Includes the support items bench, rack, bars, rings, landmine, plyoBox, suspensionTrainer, preacherBench, hyperextensionBench, abWheel and stabilityBall. |
| other | medicineBall, treadmill, bike, rower, elliptical, skippingRope, sled, battleRopes, skiErg, stairClimber, foamRoller | An implement or cardio machine is the main item. |

Class of an exercise: ignore items whose effective role is `support`. From the remaining items choose the first class in this order: Smith machine, cable, machine, kettlebell, band, free weight, other. With no remaining item the class is bodyweight.

## 6. Owner decisions (2026-11-05)
1. All 12 additions are approved, including `skiErg` and `stairClimber`.
2. `bike` covers upright, recumbent and air bikes.
3. One generic `machine` id is retained; splitting it later is a reference-data enhancement.
4. The per-exercise load/support role rule and the aligned classes of `abWheel` and `stabilityBall` are approved.
5. Sliders are not proposed (section 4).
