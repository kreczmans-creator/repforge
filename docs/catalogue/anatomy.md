# Anatomy hierarchy (OQ-22) — proposed

- Status: **Proposed — for owner approval.** Part of WP 8 stage 4 (documentation and reference data only). Nothing here is implemented. Stage 3 loads this list into the anatomy node table; stage 5 population tags exercises against it.
- Machine-readable source: `docs/catalogue/reference/anatomy.json` (format version 1).
- Requirements: LIB-001, LIB-004; owner decision 3 (four levels, most defensible level, multiple primary and secondary targets, 19 ids preserved, no precision claims); `docs/wp8-delivery-plan.md` section 4.

## 1. Levels and rules
| Level | Name | Example |
|---|---|---|
| L1 | Region | Shoulder (`regionShoulder`) |
| L2 | Muscle group | Shoulders (`shoulders`) |
| L3 | Anatomical muscle | Deltoid (`deltoid`) |
| L4 | Subdivision or head | Side delts (`sideDelts`) |

1. Every node has one id (camelCase), one parent (none at L1), a level equal to its parent's level plus one, a sibling sort order, an en-GB label, a definition, inclusion and exclusion criteria, and an optional note.
2. Ids are stable. An id is never reused or given a new meaning. A label can change without a migration.
3. `fullBody` is the only non-anatomical node. It is an L1 node with no children and is excluded from anatomical coverage. (ADR-0008 describes it as a "target kind"; the approved plan section 4 and the owner decision of 2026-11-05 make it an L1 node. This list follows the plan. The reviewer should confirm.)
4. A node has one parent. When a muscle has two functions, it sits where its anatomy puts it, and the other function appears as a note. This list does not model functional groups. See section 4.
5. Filtering by a node includes its descendants. Primary matches rank before secondary matches (TRN-010(2), unchanged).
6. The model is qualitative. It records primary and secondary involvement only. It stores no activation percentages and makes no claim of biomechanical precision.
7. Per-muscle figures that WP 9 reports are **attributed set counts**: a primary muscle receives full attribution of each recorded exercise set; a secondary muscle receives separately recorded attribution that is excluded from primary totals. They are not physiological measurements of muscle stimulus (OQ-19).

### Definition, inclusion and exclusion fields
- **Definition** says what the node is.
- **Includes** says what belongs under it, in terms of movements or tagged exercises.
- **Excludes** says what does not belong and, where it matters, where that thing sits instead. A muscle with two functions is classified once; the exclusion names its neighbour.

## 2. Mapping of the 19 existing muscle ids
Each existing id becomes a node at the level the plan sets. Stored values map one to one; no stored value changes. The mapping of every existing exercise is in `mapping-existing.md`.

| WP 8 id | Level | Parent | Label | What the node covers |
|---|---|---|---|---|
| `chest` | L2 | `regionChest` | Chest | Muscle group covering the pectorals and serratus anterior. |
| `frontDelts` | L4 | `deltoid` | Front delts | Anterior head of the deltoid. |
| `sideDelts` | L4 | `deltoid` | Side delts | Lateral head of the deltoid. |
| `rearDelts` | L4 | `deltoid` | Rear delts | Posterior head of the deltoid. |
| `triceps` | L3 | `upperArmPosterior` | Triceps | Triceps brachii with three heads. |
| `biceps` | L3 | `upperArmAnterior` | Biceps | Biceps brachii with two heads. |
| `forearms` | L2 | `regionArm` | Forearms | Muscles between elbow and wrist that move the wrist, fingers and forearm. |
| `upperBack` | L2 | `regionBack` | Upper back | Muscles between the neck and the mid-spine that move and stabilise the shoulder blades. |
| `lats` | L2 | `regionBack` | Lats | Muscle group of the latissimus dorsi and teres major. |
| `lowerBack` | L2 | `regionBack` | Lower back | Muscles that extend and stabilise the lumbar spine. |
| `abs` | L2 | `regionTrunk` | Abs | Front abdominal wall muscles. |
| `obliques` | L2 | `regionTrunk` | Obliques | Muscles on the sides of the abdomen. |
| `glutes` | L2 | `regionHip` | Glutes | Muscle group of the gluteus maximus, medius and minimus. |
| `abductors` | L2 | `regionHip` | Abductors | Muscles that move the thigh out to the side, as filed here. |
| `adductors` | L2 | `regionHip` | Adductors | Muscles on the inner thigh that pull the leg towards the midline. |
| `quadriceps` | L2 | `regionThigh` | Quadriceps | Four-headed muscle at the front of the thigh. |
| `hamstrings` | L2 | `regionThigh` | Hamstrings | Muscle group at the back of the thigh. |
| `calves` | L2 | `regionLowerLeg` | Calves | Muscles at the back of the lower leg that point the foot down. |
| `fullBody` | L1 | none (non-anatomical root) | Full body | Non-anatomical classification for conditioning and whole-body work. |

## 3. Node counts
| Region | L1 | L2 | L3 | L4 | Total |
|---|---|---|---|---|---|
| Neck | 1 | 3 | 6 | 0 | 10 |
| Shoulder | 1 | 2 | 5 | 3 | 11 |
| Chest | 1 | 1 | 3 | 2 | 7 |
| Back | 1 | 3 | 8 | 6 | 18 |
| Arm | 1 | 3 | 10 | 11 | 25 |
| Trunk | 1 | 3 | 4 | 0 | 8 |
| Hip and pelvis | 1 | 5 | 16 | 4 | 26 |
| Thigh | 1 | 2 | 7 | 2 | 12 |
| Lower leg and ankle | 1 | 4 | 8 | 2 | 15 |
| Full body | 1 | 0 | 0 | 0 | 1 |
| **All** | 10 | 26 | 67 | 30 | 133 |

Counts are for this proposal and will change if the owner adds or removes nodes.

## 4. Functional-group limitations (recorded, not modelled)
| Muscle | Filed under | Also acts as | Guidance |
|---|---|---|---|
| Gluteus medius, gluteus minimus | Glutes | Hip abductors | Tag the muscle itself, and tag `abductors` as well when the exercise is a hip abduction movement. |
| Tensor fasciae latae | Abductors | Hip flexor, internal rotator | `abductors` holds this one muscle; most abduction work loads gluteus medius too. |
| Rectus femoris | Quadriceps | Hip flexor | Tag `hipFlexors` as well for hip flexion work. |
| Sartorius | Hip flexors | Knee flexor, hip rotator | Anatomically in the anterior thigh. |
| Teres major | Lats | Shoulder stabiliser | Functionally closer to a shoulder muscle. |
| Brachioradialis | Forearms | Elbow flexor | Tag with `elbowFlexion` patterns. |
| Serratus anterior, pectoralis minor | Chest | Shoulder blade movers | Placed under Chest as the plan sets; scapular work. |
| Upper trapezius | Upper back | Neck extensor and side flexor | Tag neck groups as well for neck work. |
| Sternocleidomastoid | Neck flexors | Side flexor, rotator | Filed once. |
| Quadratus lumborum | Lower back | Trunk side flexor | Region Back; tranche 5.6 (trunk) covers it. |
| Adductor magnus (hamstring part) | Adductors | Hip extensor | Tag rarely. |
| Erector spinae (thoracic part) | Lower back | Upper-back extensor | Tag here; do not add a thoracic node. |

## 5. Classifications the reviewer should check
1. `fullBody` as an L1 node (plan and approved decision) versus ADR-0008 wording.
2. Gluteus medius and minimus under Glutes, with Abductors holding only tensor fasciae latae.
3. Rectus femoris under Quadriceps, and sartorius under Hip flexors although it lies in the thigh.
4. Serratus anterior and pectoralis minor under Chest (plan), although they move the shoulder blade.
5. Teres major under Lats (plan), although it works with the shoulder.
6. Tibialis anterior proposed as L3 under a new L2 `anteriorLowerLeg`; the plan sketched it as an L2 node. The new L2 gives the other shin, outer and deep calf muscles a parent.
7. Rotator cuff and Deep hip rotators as separate L2 groups (the plan names the first and hints the second).
8. `shoulders` (L2) has the deltoid as its only child; the rotator cuff is a sibling group under `regionShoulder`.
9. Levator scapulae under Upper back, although it is also a neck muscle.
10. Quadratus lumborum under Lower back (Region Back) rather than Trunk.
11. Pelvic floor under Trunk; it could sit under Hip and pelvis. It carries no coverage minimum.
12. Finger flexors and extensors modelled as L4 under the wrist muscles.
13. No split of the rhomboids, rectus abdominis, gluteus maximus or vastus medialis; the pectoralis major abdominal fibres sit inside the sternocostal head.
14. Adductor magnus split into adductor and hamstring parts (L4); contested in the literature, so tag rarely.
15. Neck, rotator cuff and Deep hip rotators are not in the 19 ids; exercises tagged only with the old ids cannot reach them until enriched.

## 6. Structures not modelled
Diaphragm, intercostals, intrinsic hand and foot muscles, plantaris, popliteus, facial and jaw muscles. Add them only if a catalogue exercise needs them.

## 7. Nodes
`*` marks one of the 19 preserved ids. Indentation follows level.

### Neck (`regionNeck`)

| Id | L | Name | Definition | Includes | Excludes | Note |
|---|---|---|---|---|---|---|
| `regionNeck` | 1 | Neck | The cervical region between the skull and the upper trunk. | Muscles whose main job is to flex, extend, tilt or rotate the head and neck. | Upper trapezius and levator scapulae (tagged under Upper back as scapular muscles). |  |
| `neckFlexors` | 2 | &nbsp;&nbsp;Neck flexors | Muscles at the front of the neck that bend the head and neck forward. | Sternocleidomastoid and deep neck flexors. | Muscles that lift the head backwards. |  |
| `sternocleidomastoid` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Sternocleidomastoid | Paired muscle running from behind the ear to the breastbone and collarbone. | Neck flexion (both sides), side flexion and rotation to the opposite side (one side). | Scalenes. | Also a lateral flexor and rotator; filed once under flexors. |
| `deepNeckFlexors` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Deep neck flexors | Longus colli and longus capitis, the deep muscles on the front of the cervical spine. | Chin-tuck movements and controlled neck flexion. | Sternocleidomastoid. |  |
| `neckExtensors` | 2 | &nbsp;&nbsp;Neck extensors | Muscles at the back of the neck that tilt the head back and hold it upright. | Splenius, semispinalis capitis and suboccipitals. | Upper trapezius (Upper back). |  |
| `splenius` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Splenius capitis and cervicis | Strap muscles on the back of the neck. | Neck extension and rotation to the same side. | Semispinalis capitis. |  |
| `semispinalisCapitis` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Semispinalis capitis | Thick column of muscle beside the cervical spine. | Neck extension. | Splenius. |  |
| `suboccipitals` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Suboccipital muscles | Small muscles at the base of the skull. | Fine head positioning and upper cervical extension. | Larger neck extensors. | Rarely a training target; kept so mobility entries can be tagged. |
| `neckLateralFlexors` | 2 | &nbsp;&nbsp;Neck side flexors | Muscles that tilt the head sideways. | Scalenes. | Sternocleidomastoid, which is filed under flexors. |  |
| `scalenes` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Scalenes | Anterior, middle and posterior scalene muscles on the side of the neck. | Neck side flexion and first-rib elevation. | Sternocleidomastoid. |  |

### Shoulder (`regionShoulder`)

| Id | L | Name | Definition | Includes | Excludes | Note |
|---|---|---|---|---|---|---|
| `regionShoulder` | 1 | Shoulder | The shoulder joint and the muscles that move or stabilise the arm at the shoulder. | Deltoid and rotator cuff. | Muscles that mainly move the shoulder blade (see Chest and Back) and the chest muscles that cross the shoulder. |  |
| `shoulders` | 2 | &nbsp;&nbsp;Shoulders | Muscle group of the deltoid, the main mover of the arm at the shoulder. | The deltoid and its three heads. | Rotator cuff (own group) and scapular muscles. |  |
| `deltoid` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Deltoid | The rounded shoulder muscle with front, side and rear fibres. | Shoulder flexion, abduction, extension and horizontal movement of the arm. | Rotator cuff. |  |
| `frontDelts` * | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Front delts | Anterior head of the deltoid. | Shoulder flexion and pressing overhead; assists in horizontal adduction. | Chest muscles that dominate flat pressing. | Anterior deltoid. Preserved WP 8 id (L4 head). |
| `sideDelts` * | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Side delts | Lateral head of the deltoid. | Shoulder abduction (raising the arm out to the side). | Supraspinatus, which starts abduction but sits in the rotator cuff. | Lateral deltoid. Preserved WP 8 id (L4 head). |
| `rearDelts` * | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Rear delts | Posterior head of the deltoid. | Shoulder extension and horizontal abduction (reverse fly). | Rhomboids and middle trapezius, which retract the shoulder blade. | Posterior deltoid. Preserved WP 8 id (L4 head). |
| `rotatorCuff` | 2 | &nbsp;&nbsp;Rotator cuff | Four small muscles that centre the head of the humerus in the shoulder socket. | Supraspinatus, infraspinatus, teres minor, subscapularis. | Deltoid and teres major. |  |
| `supraspinatus` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Supraspinatus | Cuff muscle above the shoulder blade spine. | Initiating shoulder abduction and stabilising the joint. | Side delts. |  |
| `infraspinatus` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Infraspinatus | Cuff muscle below the shoulder blade spine. | Shoulder external rotation. | Teres minor. |  |
| `teresMinor` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Teres minor | Small cuff muscle at the lower edge of the shoulder blade. | Shoulder external rotation. | Teres major (filed under Lats). |  |
| `subscapularis` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Subscapularis | Cuff muscle on the front of the shoulder blade. | Shoulder internal rotation. | Pectoralis major. |  |

### Chest (`regionChest`)

| Id | L | Name | Definition | Includes | Excludes | Note |
|---|---|---|---|---|---|---|
| `regionChest` | 1 | Chest | The front of the ribcage and the muscles that lie over it. | Pectoral muscles and serratus anterior. | Deltoid, which is a shoulder muscle. |  |
| `chest` * | 2 | &nbsp;&nbsp;Chest | Muscle group covering the pectorals and serratus anterior. | Pressing and fly movements that load the pectorals. | Deltoid and triceps. | Preserved WP 8 id (L2 group). |
| `pectoralisMajor` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Pectoralis major | Large fan-shaped muscle of the upper chest wall. | Horizontal adduction, shoulder flexion and internal rotation, pressing. | Pectoralis minor. |  |
| `pectoralisMajorClavicular` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Pectoralis major, clavicular head | Upper fibres attaching to the collarbone. | Incline pressing and shoulder flexion at the chest. | Sternocostal head. | Qualitative emphasis only; incline angles shift emphasis, they do not isolate it. |
| `pectoralisMajorSternocostal` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Pectoralis major, sternocostal head | Middle and lower fibres attaching to the breastbone and ribs. | Flat and decline pressing, dips and fly movements. Includes the abdominal fibres. | Clavicular head. | Abdominal fibres are not tagged separately. |
| `pectoralisMinor` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Pectoralis minor | Small muscle under pectoralis major, attaching to the shoulder blade. | Shoulder blade protraction and depression. | Pectoralis major. | Scapular function; placed under Chest as planned. |
| `serratusAnterior` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Serratus anterior | Muscle along the side of the ribcage attaching to the shoulder blade. | Shoulder blade protraction and upward rotation (push-up plus, overhead reach). | Rhomboids and trapezius. | Scapular function; placed under Chest as planned. |

### Back (`regionBack`)

| Id | L | Name | Definition | Includes | Excludes | Note |
|---|---|---|---|---|---|---|
| `regionBack` | 1 | Back | The posterior trunk from the base of the neck to the pelvis. | Muscles of the upper back, the lats and the lower back. | Rear deltoid (Shoulder) and neck muscles (Neck). |  |
| `upperBack` * | 2 | &nbsp;&nbsp;Upper back | Muscles between the neck and the mid-spine that move and stabilise the shoulder blades. | Trapezius, rhomboids and levator scapulae. | Lats, rear delts and spinal extensors. | Preserved WP 8 id (L2 group). Label in training taxonomy: Upper back (traps, rhomboids). |
| `trapezius` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Trapezius | Kite-shaped muscle from skull to mid-back, working in three parts. | Shoulder blade elevation, retraction, depression and upward rotation. | Rhomboids. |  |
| `trapeziusUpper` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Upper trapezius | Upper fibres running from neck to collarbone. | Shrugging and shoulder blade elevation. | Neck extensors. | Also extends and side-flexes the neck. |
| `trapeziusMiddle` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Middle trapezius | Horizontal fibres between spine and shoulder blade. | Shoulder blade retraction. | Rhomboids. |  |
| `trapeziusLower` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Lower trapezius | Lower fibres running down the mid-spine. | Shoulder blade depression and upward rotation. | Lats. |  |
| `rhomboids` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Rhomboids | Rhomboid major and minor beneath the trapezius. | Shoulder blade retraction and downward rotation. | Middle trapezius. | Major and minor are not tagged separately. |
| `levatorScapulae` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Levator scapulae | Muscle from the upper neck vertebrae to the shoulder blade. | Shoulder blade elevation. | Neck extensors. | Debatable: also a neck muscle; filed as a scapular muscle. |
| `lats` * | 2 | &nbsp;&nbsp;Lats | Muscle group of the latissimus dorsi and teres major. | Pulling the arm down and back, and pulling the body up. | Upper back and rear delts. | Preserved WP 8 id (L2 group). |
| `latissimusDorsi` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Latissimus dorsi | Broad muscle from the spine and pelvis to the upper arm. | Shoulder extension, adduction and internal rotation; vertical and horizontal pulling. | Teres major. |  |
| `teresMajor` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Teres major | Thick muscle below the shoulder blade that assists the lats. | Shoulder extension, adduction and internal rotation. | Teres minor (Rotator cuff). | Functionally a shoulder muscle; filed under Lats as planned. |
| `lowerBack` * | 2 | &nbsp;&nbsp;Lower back | Muscles that extend and stabilise the lumbar spine. | Erector spinae, quadratus lumborum and multifidus. | Glutes and hamstrings. | Preserved WP 8 id (L2 group). |
| `erectorSpinae` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Erector spinae | Three columns of muscle running along the spine. | Spinal extension and isometric bracing in hinges and carries. | Multifidus. | Thoracic portions also serve the upper back; tag here. |
| `iliocostalis` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Iliocostalis | Outer column of the erector spinae. | Spinal extension and side flexion. | Longissimus. |  |
| `longissimus` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Longissimus | Middle column of the erector spinae. | Spinal extension. | Spinalis. |  |
| `spinalis` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Spinalis | Inner column of the erector spinae. | Spinal extension. | Longissimus. |  |
| `quadratusLumborum` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Quadratus lumborum | Deep muscle linking the pelvis to the lowest rib. | Side flexion of the trunk and anti-lateral-flexion bracing. | Obliques. | Debatable: sits deep in the abdominal wall; filed under Lower back as planned. |
| `multifidus` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Multifidus | Short deep muscles along the vertebrae. | Fine control and stiffening of the spine. | Erector spinae. |  |

### Arm (`regionArm`)

| Id | L | Name | Definition | Includes | Excludes | Note |
|---|---|---|---|---|---|---|
| `regionArm` | 1 | Arm | The upper arm and forearm. | Elbow flexors and extensors and the muscles that move the forearm, wrist and fingers. | Deltoid (Shoulder). |  |
| `upperArmAnterior` | 2 | &nbsp;&nbsp;Upper arm, front | Muscles at the front of the upper arm that bend the elbow. | Biceps, brachialis, coracobrachialis. | Brachioradialis (Forearms). |  |
| `biceps` * | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Biceps | Biceps brachii with two heads. | Elbow flexion, forearm supination and shoulder flexion. | Brachialis. | Preserved WP 8 id (L3 muscle). |
| `bicepsLongHead` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Biceps, long head | Outer head crossing the top of the shoulder joint. | Curls with the arm behind or beside the body. | Short head. | Emphasis claims are qualitative. |
| `bicepsShortHead` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Biceps, short head | Inner head attaching to the shoulder blade. | Curls with the arm in front of the body. | Long head. | Emphasis claims are qualitative. |
| `brachialis` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Brachialis | Muscle under the biceps that bends the elbow in any forearm position. | Hammer and reverse curls. | Biceps and brachioradialis. |  |
| `coracobrachialis` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Coracobrachialis | Small muscle at the top of the inner upper arm. | Shoulder flexion and adduction. | Biceps. | Rarely a training target. |
| `upperArmPosterior` | 2 | &nbsp;&nbsp;Upper arm, back | Muscles at the back of the upper arm that straighten the elbow. | Triceps and anconeus. | Chest and deltoid. |  |
| `triceps` * | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Triceps | Triceps brachii with three heads. | Elbow extension and pressing. | Anconeus. | Preserved WP 8 id (L3 muscle). |
| `tricepsLongHead` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Triceps, long head | Head crossing the shoulder joint. | Overhead extensions. | Lateral and medial heads. | Emphasis claims are qualitative. |
| `tricepsLateralHead` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Triceps, lateral head | Outer head. | Heavy pressing and pushdowns. | Long and medial heads. |  |
| `tricepsMedialHead` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Triceps, medial head | Deep head beneath the other two. | Elbow extension at all angles. | Long and lateral heads. |  |
| `anconeus` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Anconeus | Small muscle at the back of the elbow. | Elbow extension and joint stability. | Triceps. | Rarely a training target. |
| `forearms` * | 2 | &nbsp;&nbsp;Forearms | Muscles between elbow and wrist that move the wrist, fingers and forearm. | Wrist flexors and extensors, brachioradialis, pronators, supinators. | Biceps, brachialis and triceps. | Preserved WP 8 id (L2 group). |
| `wristFlexors` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Wrist and finger flexors | Muscles on the palm side of the forearm. | Wrist flexion, gripping and holding. | Wrist extensors. |  |
| `flexorCarpiRadialis` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Flexor carpi radialis | Flexor on the thumb side of the forearm. | Wrist flexion and radial deviation. | Flexor carpi ulnaris. |  |
| `flexorCarpiUlnaris` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Flexor carpi ulnaris | Flexor on the little-finger side of the forearm. | Wrist flexion and ulnar deviation. | Flexor carpi radialis. |  |
| `fingerFlexors` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Finger flexors | Flexor digitorum superficialis and profundus. | Gripping, hanging and carrying. | Wrist-only flexors. | Cross the wrist; filed under wrist flexors. |
| `wristExtensors` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Wrist and finger extensors | Muscles on the back of the forearm. | Wrist extension and holding the wrist neutral under load. | Wrist flexors. |  |
| `extensorCarpiRadialis` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Extensor carpi radialis | Longus and brevis, on the thumb side. | Wrist extension and radial deviation. | Extensor carpi ulnaris. |  |
| `extensorCarpiUlnaris` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Extensor carpi ulnaris | Extensor on the little-finger side. | Wrist extension and ulnar deviation. | Extensor carpi radialis. |  |
| `fingerExtensors` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Finger extensors | Extensor digitorum and related muscles. | Opening the hand and finger extension. | Wrist-only extensors. |  |
| `brachioradialis` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Brachioradialis | Forearm muscle on the thumb side that bends the elbow. | Elbow flexion with a neutral or pronated forearm (reverse curl, hammer curl). | Brachialis. | Debatable: an elbow flexor placed under Forearms as planned. |
| `forearmPronators` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Forearm pronators | Pronator teres and pronator quadratus. | Turning the palm down. | Supinators. |  |
| `forearmSupinators` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Forearm supinators | Supinator muscle (the biceps also supinates). | Turning the palm up. | Pronators. |  |

### Trunk (`regionTrunk`)

| Id | L | Name | Definition | Includes | Excludes | Note |
|---|---|---|---|---|---|---|
| `regionTrunk` | 1 | Trunk | The abdominal wall and the deep muscles that brace the spine and pelvis. | Abdominals, obliques and pelvic floor. | Spinal extensors (Back, as Lower back). | Training tranche 5.6 also covers Lower back, whose region is Back. |
| `abs` * | 2 | &nbsp;&nbsp;Abs | Front abdominal wall muscles. | Rectus abdominis and transversus abdominis. | Obliques. | Preserved WP 8 id (L2 group). |
| `rectusAbdominis` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Rectus abdominis | Paired vertical muscle at the front of the abdomen. | Trunk flexion and resisting trunk extension. | Transversus abdominis. | Not split into upper and lower parts: a single muscle with segmental activity. |
| `transversusAbdominis` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Transversus abdominis | Deepest abdominal layer wrapping around the trunk. | Bracing and drawing in the abdominal wall. | Rectus abdominis. | Rarely a primary target; tag as secondary for bracing work. |
| `obliques` * | 2 | &nbsp;&nbsp;Obliques | Muscles on the sides of the abdomen. | External and internal oblique. | Quadratus lumborum. | Preserved WP 8 id (L2 group). |
| `externalOblique` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;External oblique | Outer oblique layer. | Trunk rotation to the opposite side, side flexion, flexion. | Internal oblique. |  |
| `internalOblique` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Internal oblique | Oblique layer under the external oblique. | Trunk rotation to the same side, side flexion. | External oblique. |  |
| `pelvicFloor` | 2 | &nbsp;&nbsp;Pelvic floor | Muscles that form the base of the pelvis. | Pelvic floor contraction and relaxation exercises. | Hip muscles. | Debatable: could sit under Hip and pelvis. Not covered by minimums; owner to decide whether to include it in the catalogue. |

### Hip and pelvis (`regionHip`)

| Id | L | Name | Definition | Includes | Excludes | Note |
|---|---|---|---|---|---|---|
| `regionHip` | 1 | Hip and pelvis | The hip joint and the muscles that move the thigh at the hip. | Glutes, hip abductors, adductors, hip flexors and deep hip rotators. | Quadriceps and hamstrings (Thigh). |  |
| `glutes` * | 2 | &nbsp;&nbsp;Glutes | Muscle group of the gluteus maximus, medius and minimus. | Hip extension, hip abduction, pelvic stability. | Tensor fasciae latae (Abductors) and deep rotators. | Preserved WP 8 id (L2 group). |
| `gluteusMaximus` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Gluteus maximus | Largest gluteal muscle. | Hip extension and external rotation (thrusts, bridges, hinges, squats). | Gluteus medius. | Upper and lower fibres are not tagged separately. |
| `gluteusMedius` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Gluteus medius | Fan-shaped muscle on the outer pelvis. | Hip abduction and single-leg pelvic stability. | Gluteus minimus. | Functionally a hip abductor but filed under Glutes: one parent per node. |
| `gluteusMinimus` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Gluteus minimus | Smallest gluteal muscle, under the medius. | Hip abduction and internal rotation. | Gluteus medius. | Functionally a hip abductor but filed under Glutes: one parent per node. |
| `abductors` * | 2 | &nbsp;&nbsp;Abductors | Muscles that move the thigh out to the side, as filed here. | Tensor fasciae latae and any exercise tagged as hip abduction at group level. | Gluteus medius and minimus (filed under Glutes). | Preserved WP 8 id (L2 group). Known limitation: most abduction work is done by gluteus medius and minimus; tag them as well when the exercise targets them. |
| `tensorFasciaeLatae` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Tensor fasciae latae | Small muscle at the front-outer hip feeding the iliotibial band. | Hip abduction, flexion and internal rotation. | Gluteus medius. |  |
| `adductors` * | 2 | &nbsp;&nbsp;Adductors | Muscles on the inner thigh that pull the leg towards the midline. | Adductor magnus, longus, brevis, gracilis and pectineus. | Hamstrings. | Preserved WP 8 id (L2 group). |
| `adductorMagnus` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Adductor magnus | Largest adductor with an adductor part and a hamstring part. | Hip adduction and, through its rear part, hip extension. | Adductor longus. |  |
| `adductorMagnusAdductor` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Adductor magnus, adductor part | Front part of adductor magnus. | Hip adduction. | Hamstring part. |  |
| `adductorMagnusHamstring` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Adductor magnus, hamstring part | Rear part of adductor magnus. | Hip extension in deep squats and hinges. | Adductor part. | Tag rarely; use only when the movement clearly loads deep hip extension. |
| `adductorLongus` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Adductor longus | Long, thin inner-thigh muscle. | Hip adduction and flexion. | Adductor brevis. |  |
| `adductorBrevis` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Adductor brevis | Short adductor beneath the longus. | Hip adduction. | Adductor longus. |  |
| `gracilis` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Gracilis | Thin strap muscle on the inner thigh. | Hip adduction and knee flexion. | Sartorius. |  |
| `pectineus` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Pectineus | Small muscle at the top of the inner thigh. | Hip adduction and flexion. | Iliopsoas. |  |
| `hipFlexors` | 2 | &nbsp;&nbsp;Hip flexors | Muscles that lift the thigh towards the trunk. | Iliopsoas and sartorius. Rectus femoris is filed under Quadriceps. | Abdominals. | Functional group; rectus femoris stays under Quadriceps (one parent per node). |
| `iliopsoas` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Iliopsoas | Psoas major and iliacus together. | Hip flexion and lumbar stabilisation. | Rectus abdominis. |  |
| `psoasMajor` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Psoas major | Muscle from the lumbar spine to the thigh. | Hip flexion. | Iliacus. |  |
| `iliacus` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Iliacus | Muscle lining the inside of the pelvis. | Hip flexion. | Psoas major. |  |
| `sartorius` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Sartorius | Long strap muscle across the front of the thigh. | Hip flexion, abduction and external rotation; knee flexion. | Quadriceps. | Debatable: lies in the anterior thigh but is filed with the hip flexors. |
| `hipExternalRotators` | 2 | &nbsp;&nbsp;Deep hip rotators | Small muscles behind the hip joint that turn the thigh outwards. | Piriformis, obturators, gemelli and quadratus femoris. | Gluteus maximus. |  |
| `piriformis` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Piriformis | Pear-shaped muscle from the sacrum to the thigh bone. | Hip external rotation. | Gluteus maximus. |  |
| `obturatorInternus` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Obturator internus | Deep rotator inside the pelvis. | Hip external rotation. | Obturator externus. |  |
| `obturatorExternus` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Obturator externus | Deep rotator on the outer pelvis. | Hip external rotation. | Obturator internus. |  |
| `gemelli` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Gemelli | Superior and inferior gemellus. | Hip external rotation. | Quadratus femoris. | Superior and inferior are not tagged separately. |
| `quadratusFemoris` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Quadratus femoris | Flat rotator below the gemelli. | Hip external rotation. | Gemelli. |  |

### Thigh (`regionThigh`)

| Id | L | Name | Definition | Includes | Excludes | Note |
|---|---|---|---|---|---|---|
| `regionThigh` | 1 | Thigh | The thigh between hip and knee. | Quadriceps and hamstrings. | Adductor group and hip flexors (Hip and pelvis). |  |
| `quadriceps` * | 2 | &nbsp;&nbsp;Quadriceps | Four-headed muscle at the front of the thigh. | Knee extension in squats, presses, lunges and extensions. | Hip flexors other than rectus femoris. | Preserved WP 8 id (L2 group). |
| `rectusFemoris` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Rectus femoris | Quadriceps head that crosses the hip. | Knee extension and hip flexion. | Vastus muscles. | Functions as a hip flexor but filed under Quadriceps. |
| `vastusLateralis` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Vastus lateralis | Outer quadriceps head. | Knee extension. | Vastus medialis. |  |
| `vastusMedialis` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Vastus medialis | Inner quadriceps head. | Knee extension, especially the last degrees. | Vastus lateralis. | The commonly used 'VMO' label is not modelled separately. |
| `vastusIntermedius` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Vastus intermedius | Deep quadriceps head under rectus femoris. | Knee extension. | Rectus femoris. |  |
| `hamstrings` * | 2 | &nbsp;&nbsp;Hamstrings | Muscle group at the back of the thigh. | Knee flexion and hip extension. | Gluteus maximus and adductor magnus. | Preserved WP 8 id (L2 group). |
| `bicepsFemoris` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Biceps femoris | Outer hamstring with two heads. | Knee flexion and hip extension. | Biceps brachii. |  |
| `bicepsFemorisLongHead` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Biceps femoris, long head | Head crossing hip and knee. | Hip extension and knee flexion. | Short head. |  |
| `bicepsFemorisShortHead` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Biceps femoris, short head | Head crossing the knee only. | Knee flexion, including when the hip is already extended. | Long head. |  |
| `semitendinosus` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Semitendinosus | Inner hamstring with a long tendon. | Knee flexion and hip extension. | Semimembranosus. |  |
| `semimembranosus` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Semimembranosus | Deep inner hamstring. | Knee flexion and hip extension. | Semitendinosus. |  |

### Lower leg and ankle (`regionLowerLeg`)

| Id | L | Name | Definition | Includes | Excludes | Note |
|---|---|---|---|---|---|---|
| `regionLowerLeg` | 1 | Lower leg and ankle | The lower leg between knee and ankle, including the muscles that move the ankle and foot. | Calf, shin and lateral lower-leg muscles. | Intrinsic foot muscles (not modelled). |  |
| `calves` * | 2 | &nbsp;&nbsp;Calves | Muscles at the back of the lower leg that point the foot down. | Gastrocnemius and soleus. | Tibialis posterior and toe flexors. | Preserved WP 8 id (L2 group). |
| `gastrocnemius` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Gastrocnemius | Two-headed calf muscle crossing knee and ankle. | Plantar flexion, strongest with the knee straight. | Soleus. |  |
| `gastrocnemiusMedialHead` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Gastrocnemius, medial head | Inner head of the calf muscle. | Plantar flexion with the knee straight. | Lateral head. | Heads are tagged only when an exercise deliberately changes foot position; qualitative. |
| `gastrocnemiusLateralHead` | 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Gastrocnemius, lateral head | Outer head of the calf muscle. | Plantar flexion with the knee straight. | Medial head. |  |
| `soleus` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Soleus | Flat calf muscle under the gastrocnemius. | Plantar flexion, strongest with the knee bent. | Gastrocnemius. |  |
| `anteriorLowerLeg` | 2 | &nbsp;&nbsp;Shin muscles | Front compartment of the lower leg. | Tibialis anterior and toe extensors. | Calves. |  |
| `tibialisAnterior` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Tibialis anterior | Muscle along the front of the shin. | Dorsiflexion and foot inversion. | Toe extensors. | The plan proposed this as an L2 node; here it is L3 under a new L2 compartment so related muscles have a parent. |
| `toeExtensors` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Toe extensors | Extensor digitorum longus and extensor hallucis longus. | Lifting the toes and assisting dorsiflexion. | Tibialis anterior. |  |
| `lateralLowerLeg` | 2 | &nbsp;&nbsp;Outer lower-leg muscles | Lateral compartment of the lower leg. | Fibularis (peroneal) muscles. | Calves. |  |
| `fibularisLongus` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Fibularis longus | Outer lower-leg muscle (peroneus longus). | Foot eversion and ankle stability. | Fibularis brevis. |  |
| `fibularisBrevis` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Fibularis brevis | Shorter outer lower-leg muscle (peroneus brevis). | Foot eversion. | Fibularis longus. |  |
| `deepPosteriorLowerLeg` | 2 | &nbsp;&nbsp;Deep calf muscles | Deep back compartment of the lower leg. | Tibialis posterior and toe flexors. | Gastrocnemius and soleus. |  |
| `tibialisPosterior` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Tibialis posterior | Deep muscle supporting the arch. | Foot inversion and arch support. | Toe flexors. |  |
| `toeFlexors` | 3 | &nbsp;&nbsp;&nbsp;&nbsp;Toe flexors | Flexor digitorum longus and flexor hallucis longus. | Curling the toes and push-off. | Tibialis posterior. |  |

### Full body (`fullBody`)

| Id | L | Name | Definition | Includes | Excludes | Note |
|---|---|---|---|---|---|---|
| `fullBody` * | 1 | Full body | Non-anatomical classification for conditioning and whole-body work. | Cardio and conditioning exercises with no defensible muscle subset. | Any anatomical muscle. The node has no children and is excluded from anatomical coverage. | Non-anatomical. ADR-0008 text calls fullBody a target kind; the approved plan (section 4) and D04 section 7 make it an L1 node. This list follows the plan. |

