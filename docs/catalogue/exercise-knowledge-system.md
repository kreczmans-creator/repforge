# Exercise knowledge system (WP 8)

- Status: **implemented on branch, not reviewed, not accepted.** Content is drafted with AI assistance and awaits a named human editor; nothing here is published or complete under the owner's editorial rule.
- Date: 2026-11-07. Base: `claude/campaign-2026-11-07` (ancestor of aa59021; no WP 8 3b commits from the isolated branch `ccr-9fda2c32-wr163b`). Production schema stays v7; no v8 or migration code changed.
- Owner inputs: owner brief of 2026-11-07 (exercise knowledge system); D04 section 7 entries of 2026-11-05 (content policy) and 2026-11-07 (allocation; base branch; "the stage 3c catalogue release format is canonical; the knowledge system extends it and adds no competing exercise-reference format").
- Governance: `AGENTS.md`, `docs/governance/effort-points-and-progress-reporting.md`; effort section in `docs/delivery-record/WP8.md`.

## 1. What it does
Every exercise in the catalogue teaches the user: what it is, its muscles, equipment, difficulty and movement classification, starting position, numbered execution steps, breathing (and tempo where meaningful), coaching cues, common mistakes (fault, why it matters, fix), safety points, a visual, and links to easier, harder, other-equipment and comparable exercises that open the real RepForge exercise. It works offline. A custom exercise shows a clear "No instructions yet" state.

## 2. Relationship to the stage 3c release format (canonical)
There is one exercise-reference format: **catalogue release format 2** (`docs/catalogue/release-format-2.md`). The knowledge system:

| Concern | How it uses the 3c format |
|---|---|
| Identity | The stable exercise id of the release; no second id, no second catalogue |
| Classification, muscles, equipment, patterns | The release fields (release 2 values, unchanged in release 3) and the approved reference files for labels |
| Instruction content | The release `content` object; five kinds added to the controlled list by **specification revision 2** (section 12 of the spec) |
| Content provenance | New optional `contentProvenance` object (spec revision 2) |
| Media | The release `media` array with the spec revision 2 fields (purpose, caption, source, availability; array position = sequence) |
| Relationships | The release `relationships` (four stored kinds; regression derived) |
| Validation | The 3c parser and release validator (IC checks incl. IC-700) plus knowledge checks KS-101..KS-308 |
| CI | `tool/catalogue_gate.dart` validates release 3 against release 2 (0 errors) |

Release 2 is unchanged byte for byte. Release 3 (`app/assets/catalogue/releases/repforge-release-3.json`) is release 2 plus knowledge, at revision 3. The seed `app/assets/seed/exercise_library.json` is untouched (hash pinned in a test).

## 3. Architecture
| Layer | Code | Notes |
|---|---|---|
| Domain (pure Dart) | `app/lib/domain/exercise_knowledge/` | `ExerciseKnowledge`, `KnowledgeCatalogue.fromRelease`, `CommonMistake`, typed `ExerciseLink`s, `checkKnowledge` (KS codes), `KnowledgeMatrix` and report, port `ExerciseKnowledgeSource` with `KnowledgeFound`, `KnowledgeNotAuthored`, `KnowledgeUnavailable`. The only module outside `lib/domain/library` that imports it (architecture test updated) |
| Data adapter | `app/lib/data/catalogue/bundled_exercise_knowledge_source.dart` | Reads the release and the approved reference files from the app bundle once; read-only; never the network or the database |
| Wiring | `exerciseKnowledgeSourceProvider` in `app/lib/app/providers.dart`; `exerciseKnowledgeProvider` in `app/lib/features/training/application/exercise_knowledge_providers.dart` | |
| Presentation | `exercise_guidance.dart` (sections A to I), `exercise_illustration.dart` (original illustrations), `exercise_detail_screen.dart` (hosts the guidance) | Design-system tokens, dark and light, semantic labels, 48 dp targets, two-up visuals from 320 dp |

**Bundling (D-3c-3).** The release and reference files are data artefacts; registering them as Flutter assets is owner decision D-3c-3, still open. This work does **not** change `pubspec.yaml`. Until the owner decides, the adapter reports `KnowledgeUnavailable` in the running app and the detail screen shows "Exercise guidance is not included in this version of the app yet" above the existing details and history. Enabling it is a two-line `pubspec.yaml` change (`assets/catalogue/releases/`, `assets/catalogue/reference/`); a test pins that the catalogue is not bundled yet so the change is deliberate.

**Publication rule (KS-D9, review M-2).** The app shows **only editor-approved guidance** by default. Content with status `draftAwaitingEditor` is withheld (`applyPublicationPolicy`, state `KnowledgeAwaitingReview`): the screen says the guidance is written and waiting for review by a RepForge editor, and shows the existing details and history. Drafts appear only behind one switch, `showDraftExerciseGuidance` (build flag `--dart-define=REPFORGE_SHOW_DRAFT_GUIDANCE=true`), which defaults to off and carries the "Draft guidance" label when on. Bundling the catalogue therefore cannot publish drafts. Today all 89 exercises are drafts, so a default build shows none of their guidance.

**Off the UI thread (review L-6).** Production builds the catalogue (parse, checks, hash) with Flutter `compute`; the adapter keeps a plain in-place build for tests and tools.

## 4. Content model
Per exercise, in `content."en-GB"` of the release:

| Element (owner brief) | Release field |
|---|---|
| Description | `description` (1–2) |
| Starting position | `setup` (2–5) |
| Numbered execution | `execution` (3–6), shown numbered |
| Breathing | `breathing` (1–2) |
| Tempo (only where meaningful) | `tempo` (0 or 1); 60 of 89 exercises have one |
| Coaching cues | `cues` (2–4) |
| Common mistakes | `commonMistakes` ("Fault. Fix.", 2–4) + `mistakeEffects` (why, same count) |
| Safety | `safety` (1–3), plus a fixed "General exercise guidance, not medical advice" line on screen |
| Muscles, equipment, difficulty, movement classification | Exercise fields of the release (labels from approved reference data) |
| Variations and alternatives | `relationships` (families, progressions, alternatives) |
| Media references | `media` |
| Provenance | `contentProvenance` (content) and `provenance` (classification) |
| Completeness status | Computed (section 5), not stored |

Editorial rules applied: `editorial-guide.md` section 8 and IC-700 (10–200 characters an item, at most 20 words a sentence, imperative voice, no prescriptions, no medical or outcome claims, UK spelling). The gate reports 0 IC-700 errors; 85 IC-708 warnings remain (near-identical items across related exercises, such as "Keep your upper arms still" for curls) for the editor to review.

## 5. Completeness matrix rules
| Element | Rule | Complete when | Otherwise |
|---|---|---|---|
| Identity | required | id and `en-GB` name | missing |
| Description, starting position, execution, breathing, cues, safety | required | at least one item | missing |
| Primary muscles | required | at least one primary target | missing |
| Secondary muscles | where applicable | at least one secondary target | not applicable (none recorded) |
| Equipment | where applicable | at least one item | not applicable (bodyweight) |
| Difficulty | required | set | missing |
| Common mistakes | required | every mistake has fault, why and fix | partial, or missing |
| Visual | required | at least one available media item | placeholder (gap recorded) |
| Variations and alternatives | where applicable | at least one link to a catalogue exercise | missing (listed as a gap) |
| Media provenance | where applicable | every item has licence, attribution and source | not applicable without media; missing otherwise |

The report `docs/catalogue/content-completeness-2026-11-07.md` is generated by `app/tool/knowledge_report.dart`; `app/test/domain/exercise_knowledge/completeness_report_test.dart` recomputes it from the asset and fails on any difference.

## 6. Media model and visuals
Each media item: id, exercise (the containing record), kind (`image`, `illustration`, `animation`, `video`), purpose (`start`, `execution`, `finish`, `overview`), locator, sequence (array position), caption, attribution, source (`original` or `licensed`), licence, availability. The UI chooses the representation: built-in illustrations are drawn; `asset:` images use the bundle with a fallback; anything else degrades to a "not available offline" tile; no available media shows the labelled designed placeholder **"Illustration not yet available"**. External URLs are refused (KS-306): no mandatory external hosting.

**Original illustrations (10 exercises, 18 media items).** Side-view line figures drawn by a `CustomPainter` from pose data (`exercise_illustration.dart`): fixed segment lengths, joint angles solved from constraints and checked against the movement (for example deadlift: bar over the midfoot, hips above the knees, shoulders slightly ahead of the bar; push-up: one straight line from shoulder to ankle, toes on the floor, hands in the same place at the top and bottom; Romanian deadlift: about 24° knee bend, hips back, torso near horizontal, bar just below the knee; pull-up top: body leaning slightly back, elbows deeply bent, chin above the bar). Pose invariants are tests (hands fixed in the push-up, knee-bend limit in the Romanian deadlift, elbow angles, hands on the bar in the back squat, feet on the floor). Revised after the independent review of 2026-11-07 (H-1, H-2, M-3, L-1, L-2). Start and finish stages for the bodyweight squat, barbell back squat, conventional deadlift, Romanian deadlift, push-up, glute bridge, bodyweight lunge and pull-up; one hold position for the plank and the dead hang. Provenance: original RepForge, licence `proprietary (RepForge)`, no tracing of photos, video or third-party drawings. No new dependency: an SVG renderer was not added. 79 exercises show the placeholder and are listed in the report.

## 7. Offline
The adapter reads bundled bytes and keeps the parsed catalogue in memory; the illustrations are code. Tests run the adapter with network access disabled. A missing or invalid catalogue degrades to `KnowledgeUnavailable`; missing reference files only lose the labels (ids are shown).

## 8. Provenance and licensing
All text is original RepForge content drafted on 2026-11-07 with AI assistance (Claude) from general exercise knowledge; no website, app, book or video was copied or paraphrased, and Bodybuilding.com was not used. Each exercise records `authoredBy: "RepForge (AI-drafted)"`, `editor: null`, `status: "draftAwaitingEditor"` and the `draftingAssistance` note. By default the app does not show drafts (section 3, publication rule); with the switch on, it labels them "Draft guidance, written with AI assistance. It has not yet been reviewed by a RepForge editor." Counts: drafted 89, editor-approved 0, shown by default 0.

## 9. Owner decisions needed
| # | Decision | Why | Recommendation |
|---|---|---|---|
| KS-D1 | Accept the additive **specification revision 2** of format 2 (formatVersion stays 2), or require `formatVersion: 3` | The spec says a format change is a new formatVersion; revision 2 only adds optional keys and no format-2 file has been applied on a device. Section 12 of the spec is marked provisional until this decision | Accept revision 2 as additive |
| KS-D2 | **D-3c-3 bundling**: register `assets/catalogue/releases/` and `assets/catalogue/reference/` in `pubspec.yaml` | Without it the guidance is not visible in the app | Approve with D-3c-3 |
| KS-D3 | Relation of release 3 (all 89 exercises, drafts) to the stage 5 tranche releases and gates | Stage 5 plans one release per anatomical tranche after the 5.1 pilot | Treat release 3 as an enrichment of the existing 89 (population standards section 4 item 3), reviewed tranche by tranche |
| KS-D4 | Name the human editor(s) accountable for the 89 drafts, and the review workflow (population standards section 2) | Owner rule: nothing complete before a named editor approves | Name an editor; review in tranche order |
| KS-D5 | Dependency approval for an SVG or image renderer, or a licensed photography/video source | Only 10 exercises have visuals | Keep code-drawn originals; extend by tranche |
| KS-D6 | Legal review before first public release (D04, 2026-11-05) to cover AI-drafted text and original illustrations | Owner rule | Schedule with the credits screen |
| KS-D7 | `lib-run-400m` and `lib-outdoor-run`: keep as variation or merge (open IC-602 disposition) | Not linked here to avoid pre-empting the decision | Owner decides |
| KS-D9 | May labelled AI drafts be shown to users before a named editor approves them? | Owner editorial rule: nothing is complete or published before editor approval. The app now withholds drafts by default; one build switch shows them with a draft label | Keep the switch off for releases; use it only for internal review builds |
| KS-D8 | Accept that the release-2 muscle targets are shown in knowledge data while the v7 detail card keeps the user's stored muscles | Until stage 3d connects v8, two sources exist for muscles; the screen shows only the v7 one | Accept until 3d |

## 10. Known limitations
- Muscles on the detail screen come from the v7 exercise record (the user's data); the knowledge catalogue holds the release-2 targets, used by the completeness matrix.
- 15 exercises have no related catalogue exercise yet (listed in the report).
- 85 IC-708 near-identical warnings and 2 IC-311, 2 IC-508, 4 IC-602 warnings (as in release 2) remain for editorial disposition.
- Independent review of 2026-11-07: four High and six Medium findings fixed on this branch (H-1 to H-4, M-1 to M-6), Lows L-1, L-2, L-4 to L-6 fixed and L-3 recorded as editor notes in the completeness report; a re-check is outstanding.
- An approval-only release must raise the exercise revision (spec section 12.5); no check enforces it yet.
