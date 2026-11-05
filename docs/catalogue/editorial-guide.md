# Editorial guide for the exercise catalogue — proposed

- Status: **Proposed — for owner approval.** WP 8 stage 4 (documentation only).
- Audience: editors who author or review system catalogue exercises (WP 8 stage 5) and the integrity tool that checks them.
- Requirements: LIB-001..LIB-007, LIB-013; owner decisions 2 (original content), 3 (anatomy), 4 (difficulty), 5 (relationships).
- Related: `anatomy.md`, `movement-patterns.md`, `equipment.md`, `quality-and-duplicates.md`, `provenance-and-licensing.md`.

## 1. Principles
1. **Original content.** Write every name, alias, classification and instruction yourself. Do not copy or closely paraphrase any website, app, book or video. Bodybuilding.com is a breadth benchmark only. See `provenance-and-licensing.md`.
2. **Plain language.** Active voice, short sentences, UK English.
3. **Defensible classification.** Tag what you can defend. When two reasonable editors would disagree, choose the less specific option and add a note for the reviewer.
4. **No precision claims.** The catalogue says which muscles an exercise loads and in what role. It does not say how much.
5. **No programming.** Entries describe how to perform an exercise. They do not prescribe sets, repetitions, loads or programmes.
6. **No medical claims.** Entries do not diagnose, treat, prevent or rehabilitate anything.

## 2. Naming
### 2.1 Canonical name
- Sentence case. Capitalise the first word and proper nouns only (Romanian, Bulgarian, Arnold).
- Use the traditional name when one exists and is unambiguous: Pull-up, Lat pulldown, Plank, Burpee.
- Otherwise build the name in this order, leaving out parts that do not apply:

  **laterality › position or angle › grip or stance › equipment › movement**

  Examples: *Single-arm cable lateral raise*; *Incline dumbbell press*; *Close-grip barbell bench press*; *Wide-grip lat pulldown*; *Seated cable row*; *Sumo deadlift*.
- Name the equipment when the movement exists with other equipment. Leave it out for a bodyweight movement unless the name would clash: *Squat* is ambiguous, so use *Bodyweight squat*.
- Use a single word for the implement as the seed does: *Barbell*, *Dumbbell*, *EZ bar*, *Cable*, *Machine*, *Smith machine*, *Kettlebell*, *Band*, *Landmine* (if approved), *Suspension* (if approved).
- Maximum 60 characters.

### 2.2 Style and spelling
- UK spelling: *programme*, *centre*, *metre*, *grey*, *tyre*. Units are metric: *400 m run*, *kg*.
- Hyphens as in the seed: *Push-up*, *Pull-up*, *Chin-up*, *Step-up*, *Single-arm*, *Close-grip*, *Bent-over*.
- No brand names, no model names, no hype words (*best*, *ultimate*, *killer*), no medical words.
- A name states the exercise; it does not describe the benefit.

### 2.3 Aliases
- Add the common alternative names, including common US names and abbreviations, so search finds them.
- At most six aliases. Each alias must be unique in the whole catalogue (not equal, after normalisation, to any other name or alias) and must refer to **this** exercise only.
- Do not add an alias that names a different exercise. *Stiff-leg deadlift* is not an alias of *Romanian deadlift*.
- Do not add a case, hyphen or plural variant of the name. The search normalises those.

| Canonical name (UK) | Typical aliases |
|---|---|
| Push-up | Press-up |
| Skipping | Jump rope, Rope skipping |
| Cross-trainer | Elliptical, Elliptical trainer |
| Exercise bike | Stationary bike |
| Back extension | Hyperextension |
| Romanian deadlift | RDL |
| Lying triceps extension | Skull crusher |
| Calf raise | Heel raise |
| Barbell bench press | Flat bench press, Bench press |
| Barbell overhead press | Standing press, Military press |
| Seated cable row | Low row |
| Dumbbell fly | Dumbbell flye, Dumbbell chest fly |
| Hip thrust | Glute thrust |

### 2.4 Identifiers
- System ids start with `lib-` followed by lower-case words joined by hyphens, ASCII only, at most 48 characters (for example `lib-cable-lateral-raise-single-arm`).
- Existing ids are kept even when a name is corrected. An id is never reused for a different exercise.

## 3. Legitimate variation versus superficial variation
A new entry must differ from every existing entry in **at least one** of these ways **and** that difference must change how the movement is done or what it demands:

| Dimension | Legitimate when | Example |
|---|---|---|
| Equipment | The implement changes the load path, stability demand or accessibility | Dumbbell press versus barbell press |
| Grip | Hand position changes joint angles or muscle emphasis | Close-grip versus wide-grip |
| Stance | Foot position changes joint angles or balance | Sumo versus conventional deadlift |
| Angle or position | Body or implement angle changes the movement | Incline versus flat press; seated versus standing |
| Range | A different start or end position changes demand | Deficit deadlift; partial range |
| Laterality | One limb works at a time | Single-arm row |

An entry is **not** a legitimate variation when it differs only by:
- tempo, pauses, repetition scheme, rest or intensity technique (these are ways to perform an exercise; future metadata may record tempo);
- the name, or a trivial change of hand angle (a few degrees) that no one would feel;
- machine brand or machine settings (seat height, pad position);
- the surface or place where it is done;
- a mixture of two exercises that adds no new demand and is better described by two entries.

**Test before adding an entry:**
1. Which of the six dimensions changes? If none, stop.
2. Would a trainee choose it for a reason the existing entry cannot meet (equipment they have, a joint angle, a progression step, balance demand, one side at a time)? If not, stop.
3. Does it have a canonical exercise to point to (`variationOf`)? If it is a new movement, it becomes a new canonical exercise.
4. Does the near-duplicate check (`quality-and-duplicates.md`, section 6) flag it? If yes, record a reason or merge.

## 4. Relationships
The five kinds, as in ADR-0008. Relationships describe the catalogue; they do not schedule or prescribe training. Each pair is stored once; the inverse is derived.

| Kind | Use when | Direction | Stored as |
|---|---|---|---|
| `variationOf` | The entry is the same movement as a canonical exercise, changed in equipment, grip, stance, angle, range or laterality | From the variation **to** the canonical exercise (the family root) | Directional, at most one per exercise |
| `progressionOf` | The entry is the next, more technically demanding step after another entry | From the harder entry **to** the easier one | Directional |
| `regressionOf` | The entry is an easier, more accessible version of another entry | From the easier entry **to** the harder one | Directional |
| `alternativeTo` | The entry loads the same target with a different movement, and a trainee could swap one for the other. It is not a variation | Symmetric | Stored once, ids in alphabetical order |
| `unilateralCounterpartOf` | One entry is the single-limb form of the other bilateral entry | Symmetric | Stored once, ids in alphabetical order |

### 4.1 How to choose
1. Same movement, one of the six dimensions changes: `variationOf` the family root.
2. A ladder of difficulty (for example wall push-up › incline push-up › push-up › decline push-up): choose `progressionOf` or `regressionOf`. Use `regressionOf` when you add the easier entry for an existing exercise and `progressionOf` when you add a harder one. Never store the same pair both ways.
3. Different movement, same target, interchangeable: `alternativeTo`.
4. A bilateral and a unilateral version of the same movement: `unilateralCounterpartOf`, in addition to `variationOf` when the unilateral one derives from the bilateral root.
5. A pair can carry more than one kind (for example `variationOf` and `unilateralCounterpartOf`), but not two kinds that mean the same thing.

### 4.2 Rules
- No self-reference, no duplicate, no inverse duplicate.
- `variationOf` forms a forest: every family has one canonical root with no `variationOf` of its own. A variation points to the root, not to another variation. Depth greater than 2 needs a reviewer note.
- `progressionOf` and `regressionOf` must not form a cycle.
- `alternativeTo` is not used between two members of the same family (the family already links them).
- `unilateralCounterpartOf` joins one bilateral and one unilateral or alternating entry.
- An active entry never links to a retired entry.
- Choose the **canonical root** as the most standard form: usually the barbell version of a barbell lift, the traditional form otherwise. The reviewer confirms each root.

## 5. Anatomical tagging
Use `anatomy.md`. Use `reference/anatomy.json` for ids.

1. **Most defensible level.** Tag the lowest level you can defend for this exercise. For a flat bench press, `pectoralisMajor` or `chest` is defensible; `pectoralisMajorClavicular` is not. For a lateral raise, `sideDelts`.
2. **Do not tag both a node and its ancestor or descendant.** Choose one. (Tagging `chest` and `pectoralisMajor` on the same exercise double-counts it.)
3. **Primary** means the muscle or muscles the exercise is designed to load, which do the main work through the main range. **Secondary** means a muscle that clearly assists or stabilises but is not the aim.
4. **Multiple primaries** are allowed when two muscle groups share the main work (for example chest and triceps in a close-grip press, only if you can defend it). Use one to three primaries. Do not promote a secondary to primary to make a coverage minimum. Adding a primary changes attributed set counts.
5. **Secondary list**: only muscles that clearly assist. Zero to six. Do not list every muscle that contracts.
6. **Heads and subdivisions** (L4): tag them only when the exercise design deliberately shifts the load (for example an overhead triceps extension for the long head) and the claim is a qualitative tendency. Otherwise tag the muscle (L3).
7. **Functional groups**: where a muscle has two functions, tag the muscle where it sits and also tag the group that names the function when it matters (for example `gluteusMedius` and `abductors` for a banded side step). See `anatomy.md` section 4.
8. **`fullBody`**: use only as a primary target, and only when no defensible anatomical subset exists (most cardio). Do not list it as secondary.
9. **No precision claims.** Write "tends to emphasise" in notes, never percentages, and never "isolates" or "only".
10. **Reporting wording.** Per-muscle figures in the app are *attributed set counts*: a primary muscle receives full attribution of each recorded exercise set; a secondary muscle receives separately recorded attribution that is excluded from primary totals. They are not physiological measurements of muscle stimulus.

## 6. Difficulty
Difficulty describes **technical complexity**, not load, volume or fitness (owner definitions).

| Level | Owner definition | Typical drivers |
|---|---|---|
| `beginner` | Simple movement, stable setup, straightforward execution | One main joint pattern; supported or guided path; low balance demand; little setup |
| `intermediate` | Moderate coordination, technique or control | Several joints coordinating; free implement; moderate balance or mobility demand; some setup steps |
| `advanced` | High technical demand, stability or complex execution | Fast or ballistic movement; high balance or mobility demand; complex timing; difficult setup |

Choose by the highest single driver. Do not raise a level because a lift is heavy, and do not lower it because it is easy for a strong person.

Worked examples:
| Exercise | Level | Reason |
|---|---|---|
| Machine chest press | beginner | Guided path, stable seat |
| Bodyweight squat | beginner | One pattern, no equipment |
| Lat pulldown | beginner | Guided path, simple setup |
| Plank | beginner | Static, one position |
| Barbell bench press | intermediate | Bar path, shoulder blade position and bracing |
| Barbell back squat | intermediate | Bar position, depth and bracing |
| Conventional deadlift | intermediate | Hinge pattern, bracing, set-up |
| Pull-up | intermediate | Shoulder blade control and bodyweight coordination |
| Bulgarian split squat | intermediate | Balance and range |
| Kettlebell swing | intermediate | Ballistic hinge timing |
| Snatch (barbell) | advanced | Fast, complex timing and mobility |
| Muscle-up | advanced | Transition and timing |
| Pistol squat | advanced | Balance and mobility on one leg |
| Handstand push-up | advanced | Inversion, balance, shoulder control |

## 7. Mechanics and laterality
### Mechanics
- `compound`: two or more joints produce the main work (squat, row, press, pull-up, face pull).
- `isolation`: one joint produces the main work (curl, lateral raise, leg extension, calf raise).
- Static holds follow the joints that bear the load: a plank is `compound`.
- Cardio and mobility entries: see the open question in `coverage-matrix.md`, section 11.

### Laterality
- `bilateral`: both limbs do the same job at the same time (barbell squat, lat pulldown).
- `unilateral`: one limb or side does the work while the other rests or supports (single-arm row), or the two limbs do different jobs (split squat, lunge, side plank).
- `alternating`: limbs take turns without a break in the set (alternating curl, walking lunge, running).

## 8. Instructions
Four sections for every system exercise, in `en-GB`.

| Section | Items | Purpose |
|---|---|---|
| `setup` | 2 to 5 | How to get into position |
| `execution` | 3 to 6 | How to perform one repetition or hold |
| `breathing` | 1 to 2 | When to breathe in and out |
| `commonMistakes` | 2 to 4 | Frequent faults, each with a short fix |

Rules for every item:
- 10 to 200 characters. One idea per item. Maximum 20 words per sentence.
- Imperative voice for setup and execution ("Set the bench...", "Press the bar..."). Present tense. Active voice.
- Use plain words: "elbow", not "humeral flexion".
- Name a body cue, not a number, where you can: "until your upper arm is level with the floor".
- No repetitions, sets, loads, percentages or programme advice.
- Breathing guidance is neutral and does not require breath-holding.
- **Safety wording.** Where a real hazard exists (bar over the face, heavy overhead lift, bar on the back), include one setup step: set the rack or safety arms, or use a spotter. Use "if" statements, not warnings that promise protection. Allowed: "Use safety arms set below your lowest point." Not allowed: "This prevents injury."
- **Not allowed:** claims to treat, heal, cure, rehabilitate, prevent or reduce pain or injury; claims about results ("builds bigger...", "burns fat"); the words *best*, *perfect*, *guaranteed*.
- Mistakes use the pattern: *Fault. Fix.* ("Shrugging the shoulder up. Keep the shoulder blade down.")
- Write from your own knowledge of performing the movement. Do not copy.

## 9. Fully worked example (catalogue release format 2 shape)
This entry shows the shape proposed in `docs/wp8-delivery-plan.md` section 7. It is an illustration for editors. Stage 3c fixes the final field names. The exercise is not in the catalogue; its text is original to this guide.

```json
{
  "id": "lib-cable-lateral-raise-single-arm",
  "revision": 1,
  "name": { "en-GB": "Single-arm cable lateral raise" },
  "aliases": { "en-GB": ["One-arm cable lateral raise", "Single-arm cable side raise"] },
  "loggingType": "weighted",
  "category": "push",
  "targets": [
    { "node": "sideDelts", "role": "primary" },
    { "node": "supraspinatus", "role": "secondary" },
    { "node": "trapeziusUpper", "role": "secondary" }
  ],
  "patterns": ["shoulderAbduction"],
  "equipment": ["cable"],
  "mechanics": "isolation",
  "laterality": "unilateral",
  "difficulty": "beginner",
  "relationships": [
    { "kind": "variationOf", "to": "lib-lateral-raise" }
  ],
  "content": {
    "en-GB": {
      "setup": [
        "Set the pulley to its lowest position and clip on a single handle.",
        "Stand side-on to the stack. Hold the handle in the hand furthest from it.",
        "Take one step away so the cable crosses in front of your thighs.",
        "Stand tall with soft knees. Rest your free hand on your hip."
      ],
      "execution": [
        "Start with the working arm just in front of your thigh and the elbow slightly bent.",
        "Raise the arm out to the side, leading with the elbow.",
        "Stop when your upper arm is about level with your shoulder.",
        "Lower the handle slowly to the start. Keep tension on the cable.",
        "Finish your repetitions on one side, then swap."
      ],
      "breathing": [
        "Breathe in at the bottom. Breathe out as you raise the arm."
      ],
      "commonMistakes": [
        "Shrugging the shoulder up. Keep the shoulder blade down and your neck long.",
        "Swinging the body to lift the handle. Use a lighter weight and keep your trunk still.",
        "Lifting the arm above shoulder height. Stop at about shoulder height.",
        "Leading with the wrist. Lead with the elbow."
      ]
    }
  },
  "media": [],
  "provenance": { "providerId": "repforge", "authoredBy": "editor-initials", "reviewedBy": "reviewer-initials" }
}
```

Why the choices were made:
- **Name.** Laterality, equipment, then the traditional movement name. UK spelling not at issue.
- **Targets.** `sideDelts` is the only primary: the movement is single-joint abduction. Supraspinatus starts the movement and the upper trapezius assists; both are clear assistants. No percentages.
- **Pattern.** One pattern, `shoulderAbduction`.
- **Equipment class.** Cable. No support item.
- **Mechanics, laterality, difficulty.** One joint (`isolation`); one arm at a time (`unilateral`); simple movement, guided by a cable path (`beginner`).
- **Relationship.** A variation of `lib-lateral-raise` (equipment and laterality). If a bilateral cable lateral raise is added to the catalogue, add `unilateralCounterpartOf` between the two.
- **Content.** Imperative, active voice, short sentences, no numbers of repetitions or loads, no medical claim, a fault and a fix for each mistake.

## 10. Editor's checklist (summary)
See `population-standards.md`, section 3, for the full definition of done.
- Name follows section 2; aliases unique.
- Variation passes the section 3 test.
- Targets, pattern, equipment, mechanics, laterality, difficulty complete.
- Relationships follow section 4.
- Four instruction sections follow section 8.
- Original text; provider and authorship recorded.
