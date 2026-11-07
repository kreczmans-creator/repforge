# D04 — Product Requirements Baseline

| Field | Value |
|---|---|
| Status | Draft |
| Date | 2026-10-31 |
| Source | Owner product vision (owner brief, 2026-10-31) |
| Purpose | Requirements catalogue for WP 1 onwards |

This catalogue describes the target product. It is NOT evidence that any feature currently exists. Nothing in this document should be read as a statement that a capability has been built, tested or released.

> Review note (architect, 2026-10-31): drafted by a delegated agent from the owner's product vision and reviewed against it. Priority counts are P1 Must 111, P2 Should 20, P3 Could 3. That P1 set is larger than a first usable release can carry; it should be read as "must exist before RepForge is called complete". The practical release scope is set by the roadmap in D06 (R0 after WP 6, R1 after WP 10). The owner should triage P1 items into those release points before WP 5 starts. All 18 open questions need owner answers; the ones gating WP 3–5 are OQ-01, OQ-02, OQ-07, OQ-14, OQ-17 and OQ-18.

## 2. Conventions

### 2.1 ID scheme

Each requirement has an ID of the form `PREFIX-NNN` (three digits, zero-padded, unique within the prefix, never reused once retired).

| Prefix | Domain |
|---|---|
| GEN | Non-functional and cross-cutting |
| NUT | Nutrition logging and food database |
| RCP | Recipes and meal planning |
| TRN | Strength training |
| BCM | Body composition and measurements |
| GOL | Goals and analytics |
| UXD | UX and design system |
| PLT | Platform integrations |
| DAT | Data, backup, sync and accounts |

### 2.2 Priority scale

| Priority | Meaning |
|---|---|
| P1 Must | Required for the first usable release |
| P2 Should | Expected soon after the first usable release; omission needs owner agreement |
| P3 Could / later | Desirable; scheduled only if capacity allows or deferred to a later release |

### 2.3 Status values

| Status | Meaning |
|---|---|
| Proposed | Written in this baseline; not yet agreed by the owner |
| Approved | Agreed by the owner as in scope |
| Implemented | Built and merged; not yet independently verified |
| Verified | Acceptance criteria demonstrated by recorded automated or manual verification |

All requirements in this baseline are **Proposed**. The Status column is therefore omitted from the tables below and will be added when requirements are first approved.

### 2.4 Mapping and verification rule

- Every requirement must map to at least one work package (WP). The default mapping is given by prefix in section 5; per-requirement mapping is to be refined when each WP is planned.
- Every requirement must have at least one automated or manual verification recorded before its status can become Verified. The acceptance criteria in this document are the basis for those verifications.
- Numeric targets described as "proposed target" are working figures for discussion. They are not agreed commitments until the owner approves them.
- Units are metric unless stated otherwise (kg, g, mg, kcal, cm, m, km, ml, l).

## 3. Non-functional and cross-cutting requirements (GEN)

| ID | Requirement | Acceptance criteria | Priority | Notes |
|---|---|---|---|---|
| GEN-001 | The app shall target Android and iOS from a single shared codebase. | (1) One repository produces both an Android build and an iOS build. (2) Platform-specific code is confined to platform adapter modules (see PLT); no feature module imports a platform API directly. | P1 Must | Framework choice is a WP1 decision, not set here. |
| GEN-002 | Routine food logging and workout recording shall work with no network connection. | (1) With the device in flight mode, a user can search the local food database, log a food, and complete and save a full workout. (2) No screen in these flows shows a blocking network error. | P1 Must | Offline-first is a vision constraint. |
| GEN-003 | Metric units shall be the default for mass, length and volume. | (1) On first run, weights display in kg or g, lengths in cm, volumes in ml. (2) No imperial unit is shown unless the user selects it. | P1 Must | Imperial support is an open question (OQ-02). |
| GEN-004 | The app shall convert between supported units using defined, tested rules, and shall store all quantities in canonical metric units independent of display unit. | (1) Conversion factors are held in one documented table. (2) 1 kg converts to 1000 g and 1 l to 1000 ml exactly. (3) Round-trip conversion of a stored value returns the original value to within 0.001 of the stored unit. (4) Changing the display unit does not alter any stored value; a weight entered as 100 lb (if imperial is supported) is stored as 45.359237 kg, not rounded to display precision. | P1 Must | Applies to nutrition, training and body measurements. |
| GEN-005 | Every nutritional value shall carry a data provenance label: verified, user-entered or estimated. | (1) No stored nutrient value exists without a provenance label. (2) The label is visible wherever the value is displayed or can be reached in one tap. | P1 Must | See NUT-018 to NUT-020. |
| GEN-006 | The app shall never fabricate nutritional, exercise or measurement data. | (1) When a value is unknown, it is stored as null and displayed as "not available". (2) No code path substitutes a default numeric value (such as 0) for a missing nutrient without marking it as estimated or missing. | P1 Must | Vision rule: do not invent nutritional information. |
| GEN-007 | The local database schema shall be changed only through versioned, ordered migrations, and a failed migration shall not destroy user data. | (1) Each schema change is a numbered migration with a stored version number. (2) Migrating from every released schema version to the current one succeeds in an automated test that checks row counts and sample values. (3) A backup copy is taken before a migration runs; if the migration fails, the app restores that copy, shows an error, and the original data is readable. | P1 Must | Links to DAT-007. |
| GEN-008 | The user shall be able to back up and export their data at any time. | (1) A backup and a JSON export can be started from settings in no more than 3 taps. (2) Both complete without network access. | P1 Must | Detail in DAT-003 to DAT-006. |
| GEN-009 | The app shall minimise collection and transmission of personal fitness data. | (1) With sync disabled, a network capture of a 10-minute scripted session shows no personal data leaving the device. (2) No third-party analytics or advertising SDK is included in the first release. | P1 Must | Telemetry policy is an open question (OQ-10). |
| GEN-010 | Secrets shall never be committed to the repository or bundled in the app. | (1) An automated secret scan runs on every commit and fails the build on a detected secret. (2) API keys are supplied at build time from the environment, not from source files. | P1 Must | Vision section 8. |
| GEN-011 | The app shall meet WCAG 2.2 level AA where applicable to native mobile. | (1) Text contrast is at least 4.5:1 for body text and 3:1 for large text and UI boundaries in both themes. (2) All core flows (log food, record workout, add measurement) can be completed using TalkBack on Android and VoiceOver on iOS. | P1 Must | Detail in UXD-004 and UXD-005. |
| GEN-012 | The app shall support light and dark themes. | (1) The app follows the system theme by default and offers a manual override. (2) Every screen renders without clipped, unreadable or invisible content in both themes. | P1 Must | See UXD-001. |
| GEN-013 | Food log entry shall be fast. Proposed target: a user can log a previously used food in under 10 seconds. | (1) In a timed manual test, logging a food from history or a saved meal takes under 10 seconds from opening the app, median of 10 attempts. (2) The flow takes no more than 4 taps from the home screen. | P1 Must | Proposed target. |
| GEN-014 | App cold start shall be fast on mid-range devices. Proposed target: under 2 seconds to an interactive home screen. | (1) On the agreed reference mid-range Android and iOS devices, median cold start over 10 launches is under 2 seconds. (2) The measurement method is documented. | P1 Must | Proposed target; reference devices to be chosen (OQ-11). |
| GEN-015 | The app shall not lose data when it is closed or killed unexpectedly. | (1) A food entry or set saved on screen is persisted before the confirmation is shown. (2) Force-stopping the app during an active workout and reopening it restores all sets already confirmed. | P1 Must | |
| GEN-016 | User-facing text shall be externalised so that further languages can be added. | (1) No user-visible string is hard-coded in UI code. (2) Dates, numbers and units format according to the device locale. | P2 Should | Languages in v1 are an open question (OQ-03). |

## 4. Functional requirements

Recipe management, recipe nutrition calculation, portion scaling, recipe favourites, meal planning and meal preparation (vision 5.1 and 5.2) are specified in RCP. NUT specifies how recipe and meal data enter the daily log.

### 4.1 Nutrition logging and food database (NUT)

| ID | Requirement | Acceptance criteria | Priority | Notes |
|---|---|---|---|---|
| NUT-001 | The app shall track daily energy intake in kcal. | (1) Given foods logged on one day with energy of 200, 350 and 125 kcal, the day total shows 675 kcal. (2) Foods logged on different calendar days (device local time) are not summed together. | P1 Must | Day boundary rule: local midnight, with a user-adjustable day start as P3. |
| NUT-002 | The app shall track protein, carbohydrate and fat in grams per logged food and per day. | (1) Given a food with 20 g protein per 100 g, logging 150 g records 30 g protein. (2) Day totals for each macronutrient equal the sum of the logged entries to 0.1 g. | P1 Must | |
| NUT-003 | The app shall track dietary fibre in grams per logged food and per day. | (1) Given a food with 6 g fibre per 100 g, logging 50 g records 3 g fibre. (2) Fibre is shown on the daily summary and is not silently included in or excluded from carbohydrate without a documented rule. | P1 Must | Carbohydrate convention (total vs available) is recorded in NUT-017 and an open question (OQ-14). |
| NUT-004 | Each food record shall hold nutrient values per a stated reference quantity (per 100 g or per 100 ml) and a list of serving sizes. | (1) A food cannot be saved without a reference basis of 100 g or 100 ml. (2) Nutrients for any logged quantity are computed as value per 100 units multiplied by quantity divided by 100. | P1 Must | Per-serving-only data from sources is converted on import, with provenance preserved. |
| NUT-005 | The app shall provide a local, searchable food database available offline. | (1) With network disabled, searching "banana" returns matching foods from the local database. (2) Each result shows name, energy per 100 g or 100 ml, and a provenance label. (3) Search ignores case and diacritics and matches partial words: "chick" returns "Chicken breast" and "creme" returns "Crème fraîche". | P1 Must | Source and licence unresolved (OQ-01). |
| NUT-006 | The user shall be able to find a food by scanning its barcode. | (1) Scanning a barcode present in the local database opens that food's log screen. (2) Scanning a barcode not found shows a "not found" state with options to search manually or create a custom food with the barcode pre-filled. | P1 Must | Camera and scanner abstraction in PLT-001 and PLT-002. Online lookup is an open question (OQ-07). |
| NUT-007 | The user shall be able to create a custom food. | (1) A custom food requires a name and energy per 100 g or 100 ml; protein, carbohydrate, fat and fibre are optional. (2) Saved fields left blank are stored as null, not 0. (3) The food appears in search immediately, offline. | P1 Must | Provenance is user-entered (NUT-018). |
| NUT-008 | The user shall be able to edit and delete a custom food without altering past log entries. | (1) After editing a custom food's protein from 10 g to 12 g per 100 g, entries logged before the edit still show the original values. (2) After deleting the food, past entries remain visible with the food's name. | P1 Must | Log entries hold a snapshot of nutrient values at time of logging. |
| NUT-009 | The user shall be able to define custom serving sizes for any food. | (1) A serving has a name (such as "1 slice"), and a gram or ml equivalent greater than 0. (2) Given a serving of 1 slice = 30 g and a food with 8 g protein per 100 g, logging 2 slices records 60 g food and 4.8 g protein. | P1 Must | |
| NUT-010 | The user shall be able to log a food by weight, volume, or serving count. | (1) Entering 150 g, 150 ml (for liquids) or 1.5 servings each produces the correct quantity in the stored canonical unit. (2) Volume entry is only offered for foods that have a density or ml-based reference. | P1 Must | |
| NUT-011 | The user shall be able to log foods to named meals (default: breakfast, lunch, dinner, snacks) and to rename or reorder those meals. | (1) A logged entry is shown under its chosen meal. (2) Renaming "Snacks" to "Pre-workout" changes the label on existing and new entries. | P1 Must | |
| NUT-012 | The user shall be able to edit the quantity of, move, copy and delete a logged entry. | (1) Changing 150 g to 200 g updates the day totals immediately. (2) Copying an entry to another date adds an identical entry to that date and leaves the original unchanged. | P1 Must | |
| NUT-013 | The user shall be able to save a set of logged foods as a saved meal and re-log it in one action. | (1) A saved meal with 3 foods, logged once, adds 3 entries with the saved quantities. (2) Editing the saved meal later does not alter entries already logged. | P1 Must | |
| NUT-014 | The app shall keep a food history and offer recent and frequent foods when logging. | (1) The log screen lists the 20 most recently logged distinct foods and the 20 most frequently logged in the last 90 days. (2) Selecting a history item pre-fills the last used quantity. | P1 Must | Supports the GEN-013 target. |
| NUT-015 | The app shall show a daily nutrition summary: energy, protein, carbohydrate, fat and fibre against targets where set. | (1) The summary shows each total with its target and remaining amount. (2) With no target set, totals are shown without a progress bar or remaining value. | P1 Must | Links to GOL-001 and GOL-002. |
| NUT-016 | The app shall show a weekly nutrition summary: daily average and per-day values for the same five measures. | (1) Over a 7-day period with entries on 5 days, the average is calculated over days with entries and the app states how many days were logged. (2) Days with no entries are shown as "not logged", not as 0. | P1 Must | Averaging basis is configurable as P3. |
| NUT-017 | Nutrition calculations shall follow a single, documented calculation specification. | (1) The specification defines the reference basis, rounding, carbohydrate convention, null handling and energy handling. (2) An automated test suite of at least 30 worked examples derived from the specification passes. | P1 Must | Specification to be written in WP5. |
| NUT-018 | Every food and every nutrient value shall display one of three provenance labels: verified, user-entered or estimated. Data entered or edited by the user shall never be labelled verified. | (1) A food from a vetted source shows "verified"; a custom food shows "user-entered"; a value derived by approximation shows "estimated". (2) Each label has a text form, not colour alone. (3) Editing any nutrient of a verified food creates a copy labelled user-entered and leaves the original unchanged; no user action sets a label to verified. | P1 Must | Definitions in GEN-005. |
| NUT-019 | Calculated totals shall carry the weakest provenance of their inputs. | (1) A day total built from verified and estimated entries is shown as containing estimated data. (2) The order of strength is verified, then user-entered, then estimated. | P1 Must | |
| NUT-020 | Estimated values shall only be created by a documented, user-visible action and shall be marked estimated. | (1) Estimation (such as "quick add calories only") requires the user to enter at least one value themselves. (2) The app never fills a missing nutrient from a guess without marking it estimated and showing how it was derived. | P1 Must | Supports "do not invent nutrition data". |
| NUT-021 | The app shall not invent nutrition data. | (1) A food with null fibre is displayed as "fibre: not available" and contributes nothing to the fibre total. (2) A day containing foods with missing nutrients displays a "some data missing" indicator on the affected totals. | P1 Must | Vision rule. |
| NUT-022 | The app shall convert between g, kg, mg, ml, l and (if supported) imperial units following the GEN-004 table, and allow the display unit to be set per food type. | (1) Entering 0.25 kg is stored and shown as 250 g in the food log. (2) Volume to mass conversion is only applied where the food has a stated density; otherwise the app asks for grams. | P1 Must | Imperial scope: OQ-02. |
| NUT-023 | Food records imported from external sources shall record their source and import date. | (1) Each imported food stores source name, source identifier and import date. (2) The source is visible in the food detail screen. | P1 Must | Needed for licence compliance. |

### 4.2 Recipes and meal planning (RCP)

| ID | Requirement | Acceptance criteria | Priority | Notes |
|---|---|---|---|---|
| RCP-001 | The user shall be able to create a recipe with a name, ingredients, number of portions and instructions. | (1) A recipe cannot be saved without a name, at least one ingredient and a portion count of 1 or more. (2) A saved recipe is available offline and appears in the recipe list. | P1 Must | |
| RCP-002 | Each ingredient shall reference a food from the food database (or a custom food) and a quantity in g, ml or a defined serving. | (1) Adding "chicken breast, 400 g" stores a reference to the food and the quantity 400 g. (2) An ingredient without a quantity is rejected. | P1 Must | |
| RCP-003 | Recipes shall support ordered preparation instructions and ordered cooking instructions as separate sections. | (1) The user can add, edit, reorder and delete steps in each section. (2) Both sections display in the recipe view, and an empty section is omitted. | P1 Must | |
| RCP-004 | Recipes shall store preparation time and cooking time in minutes. | (1) Both are optional integers from 0 to 1440. (2) The view shows total time as their sum. | P1 Must | |
| RCP-005 | Recipes shall store storage instructions, freezing suitability and reheating instructions. | (1) Storage and reheating are free text; freezing suitability is one of yes, no, unknown. (2) New recipes default to unknown for freezing suitability, not yes or no. | P2 Should | Do not imply a safety claim; see OQ-13. |
| RCP-006 | The app shall calculate recipe nutrition per portion from its ingredients. | (1) Given a recipe of 400 g chicken (20 g protein per 100 g) and 4 portions, protein per portion is 20 g. (2) Changing an ingredient quantity updates per-portion values immediately. | P1 Must | Uses the NUT-017 specification. |
| RCP-007 | Recipe nutrition shall state its provenance and flag missing data. | (1) A recipe containing one estimated ingredient is labelled as containing estimated data. (2) An ingredient with null fibre causes the recipe fibre value to show "incomplete", not a total presented as complete. | P1 Must | Follows NUT-019 and NUT-021. |
| RCP-008 | The number of portions and the size of one portion shall be editable. | (1) Changing portions from 4 to 5 changes per-portion nutrition to the total divided by 5. (2) The user may instead define a portion as a weight in g, and the portion count is derived. | P1 Must | |
| RCP-009 | The user shall be able to scale a recipe to a target number of portions or a target total weight. | (1) Scaling a recipe from 4 to 6 portions multiplies each ingredient quantity by 1.5 in the scaled view. (2) Scaling does not alter the saved recipe unless the user chooses "save as new" or "overwrite". | P1 Must | |
| RCP-010 | The user shall be able to record ingredient substitutions. | (1) An ingredient can have one or more alternative foods with quantities. (2) Selecting a substitution recalculates nutrition for that view and shows the difference in kcal per portion against the original. | P2 Should | |
| RCP-011 | The user shall be able to mark recipes as favourites and filter by favourites. | (1) Toggling favourite takes one tap on the recipe card. (2) The favourites filter lists only favourited recipes and survives app restart. | P1 Must | |
| RCP-012 | The user shall be able to log a recipe to the daily food log by portions or by weight. | (1) Logging 1.5 portions of a recipe with 400 kcal per portion adds 600 kcal. (2) The entry shows the recipe name and portion count, and the nutrient snapshot is stored with the entry. | P1 Must | |
| RCP-013 | Editing a recipe shall not alter past log entries. | (1) After a recipe's energy changes from 400 to 450 kcal per portion, entries logged earlier still show 400 kcal. (2) Entries retain a link to the recipe for navigation. | P1 Must | |
| RCP-014 | The user shall be able to create a meal plan assigning recipes, foods and saved meals to meals on dates. | (1) A planned item can be added to any meal on any date in the next 28 days. (2) The plan day shows planned energy and macros using the same calculations as the log. (3) Marking a planned item as eaten creates a log entry with the planned quantity, which the user can change before confirming. | P2 Should | |
| RCP-015 | The app shall support meal preparation: planning a batch of a recipe, recording the number of portions made, and tracking the portions remaining. | (1) Recording a batch of 6 portions creates a prep record with 6 portions remaining. (2) Logging a prepared portion reduces portions remaining by 1, and the count cannot go below 0. | P2 Should | Freezer and expiry tracking not included. |

### 4.3 Strength training (TRN)

| ID | Requirement | Acceptance criteria | Priority | Notes |
|---|---|---|---|---|
| TRN-001 | The data model shall support six exercise types: weighted, bodyweight, assisted, timed, distance-based and cardio. | (1) Each exercise has exactly one type. (2) A set of each type can be saved with only the fields relevant to that type, and no type requires both weight and reps. | P1 Must | Vision: do not assume weight × reps. |
| TRN-002 | A weighted set shall record weight in kg and repetitions. | (1) A set of 80 kg × 5 is stored as 80 kg, 5 reps. (2) Weight accepts increments of 0.25 kg and rejects negative values. | P1 Must | |
| TRN-003 | A bodyweight set shall record repetitions and optionally added load in kg. | (1) A set of 12 reps with no added load is valid. (2) A set of 8 reps with 10 kg added is stored with load 10 kg. | P1 Must | Body weight at the time may be linked from BCM for later analysis. |
| TRN-004 | An assisted set shall record repetitions and assistance in kg. | (1) A set of 6 reps with 20 kg assistance is stored as assistance 20 kg. (2) The assistance value is labelled as assistance, never shown as lifted load. | P1 Must | |
| TRN-005 | A timed set shall record duration in seconds, with optional added load in kg. | (1) A plank of 90 seconds is stored as 90 s. (2) Duration entry accepts mm:ss and stores seconds. | P1 Must | |
| TRN-006 | A distance-based set shall record distance in metres or kilometres, with optional duration. | (1) A 400 m entry is stored as 400 m. (2) Display switches to km at or above 1000 m and the stored value is unchanged. | P1 Must | |
| TRN-007 | A cardio entry shall record duration and optionally distance, average heart rate and energy expended. | (1) A 30-minute entry with no distance is valid. (2) Energy expended, if entered, is labelled user-entered or estimated and is not added to the nutrition energy balance automatically. | P2 Should | Health platform import is under PLT-005 and PLT-006. |
| TRN-008 | The app shall include an exercise library available offline. | (1) With network disabled, the library lists exercises with name, type, category, primary muscle group and equipment. (2) Library exercises are marked as supplied, and user changes create a custom copy. (3) Search matches name and aliases, ignoring case and diacritics. | P1 Must | Content source and licence: OQ-09. |
| TRN-009 | Exercises shall be classified by category (such as push, pull, legs, core, cardio, mobility). | (1) Each exercise has one category from a controlled list. (2) The library can be filtered by category. | P1 Must | Category list to be agreed. |
| TRN-010 | Exercises shall be classified by primary muscle group and optional secondary muscle groups. | (1) Each exercise has exactly one primary group from a controlled list. (2) Filtering by "quadriceps" returns exercises with it as primary or secondary, with primary listed first. | P1 Must | |
| TRN-011 | Exercises shall record required equipment. | (1) An exercise lists zero or more equipment items from a controlled list (bodyweight only is zero items). (2) The library can be filtered by available equipment. | P1 Must | |
| TRN-012 | The user shall be able to create, edit and archive custom exercises. | (1) A custom exercise requires a name, type, category and primary muscle group. (2) Archiving hides it from pickers but retains it in history. | P1 Must | |
| TRN-013 | The user shall be able to create a workout plan as an ordered list of exercises with target sets, repetition range (or duration or distance), and rest period. | (1) A plan exercise with 3 sets of 8 to 10 reps and 120 s rest is stored with those values. (2) Exercises can be reordered by drag or by move-up and move-down controls. | P1 Must | |
| TRN-014 | The user shall be able to define a training split as a set of named workouts arranged over a repeating cycle. | (1) A split named "Upper/Lower" with workouts Upper A, Lower A, Upper B, Lower B can be saved. (2) A cycle of 1 to 14 days can include rest days. | P2 Should | Templates are optional and, if offered, are editable. |
| TRN-015 | The user shall be able to schedule workouts on calendar dates, by weekday pattern or by split cycle. | (1) Scheduling "Upper A" on Mondays and Thursdays places it on each such date for the next 8 weeks. (2) A scheduled workout can be moved or skipped without altering the plan. | P2 Should | Reminders depend on PLT-007. |
| TRN-016 | The user shall be able to start a workout session from a plan, from a past session, or empty. | (1) Starting from a plan pre-fills exercises, targets, and the previous session's weights and reps for each exercise. (2) An empty session allows exercises to be added during the workout. | P1 Must | |
| TRN-017 | During a session the user shall be able to add, remove, replace and reorder exercises. | (1) Replacing an exercise keeps already-recorded sets with the original exercise. (2) Reordering changes the stored exercise order of the session. | P1 Must | |
| TRN-018 | The user shall be able to record sets with minimal interaction. | (1) A set is confirmed with no more than 2 taps when the pre-filled values are correct. (2) The numeric keyboard opens automatically on the weight field. | P1 Must | Links to UXD-008. |
| TRN-019 | The user shall be able to mark a set as warm-up, working or failure. | (1) Set type is stored per set. (2) Warm-up sets are excluded from volume and from personal records by default. | P2 Should | |
| TRN-020 | The user shall be able to record perceived exertion per set using RPE (1 to 10, steps of 0.5) or RIR (0 to 5, whole numbers). | (1) The user chooses RPE or RIR in settings, and the choice applies to new entries. (2) Values outside range are rejected, and existing entries keep the scale they were recorded in. | P1 Must | The scale is stored with the value to avoid mixing. Default scale: OQ-12. |
| TRN-021 | The app shall support rest periods per exercise and a rest timer. | (1) Confirming a set starts a countdown from the planned rest value (default 90 s, user-configurable). (2) The timer can be paused, extended by 15 s steps, and skipped. | P1 Must | |
| TRN-022 | The rest timer shall alert the user when it ends, including with the screen locked, where the platform allows. | (1) With the app in the foreground, a haptic or sound alert fires at 0 s. (2) With the app backgrounded, a local notification fires within 2 s of the end time on supported devices. | P2 Should | Depends on PLT-007, PLT-008 and OQ-05. If unsupported, the app shows the elapsed time on return. |
| TRN-023 | The user shall be able to add notes to a session and to each exercise within a session. | (1) Notes accept at least 2000 characters. (2) Notes appear in the session history and in the exercise history. | P1 Must | |
| TRN-024 | The user shall be able to edit and delete past sessions, exercises and sets. | (1) Editing a set recalculates volume and personal records that depend on it. (2) Deleting a session requires confirmation and can be undone for at least 10 seconds. | P1 Must | |
| TRN-025 | The app shall show exercise history: every recorded set for an exercise, grouped by session date. | (1) History for an exercise lists sets with date, weight, reps (or relevant fields) and exertion. (2) The history loads the most recent 20 sessions first and further sessions on scroll. | P1 Must | |
| TRN-026 | The app shall detect and record personal records (PRs) per exercise using type-appropriate definitions. | (1) For weighted exercises, a PR is recorded for the heaviest weight at each repetition count from 1 to 12. (2) For timed, distance-based and bodyweight exercises, the PR is respectively the longest duration, longest distance, and most repetitions. (3) Confirming a set of 82.5 kg × 5 where the previous best at 5 reps was 80 kg shows a PR indicator, and editing or deleting that set removes the PR if it is no longer the best. | P1 Must | Warm-up sets excluded (TRN-019). |
| TRN-027 | The app shall calculate training volume as the sum of weight × repetitions in kg for weighted working sets, and report it per exercise, per session, per muscle group and per week. | (1) Sets of 80 kg × 5 and 80 kg × 4 give a volume of 720 kg. (2) Bodyweight, assisted, timed and distance sets are excluded from kg volume and reported by their own measures (repetitions, seconds, metres). (3) Weekly volume per muscle group counts primary muscle volume in full and shows secondary attribution separately; weeks run Monday to Sunday unless the user changes the first day of the week. | P1 Must | Definition is a proposal; it is documented in the app help. Per-muscle attribution: OQ-19 (attributed set counts; primary full, secondary separate; not physiological measurements). |
| TRN-028 | The app shall provide progressive overload tracking per exercise. | (1) For a chosen exercise, a chart shows top-set weight, estimated 1RM (if applicable), and session volume over time. (2) The app states when a measure has increased, stayed level or decreased compared with the previous session of that exercise, without giving an instruction to the user. | P2 Should | Descriptive only; no coaching (GOL-011). |

### 4.4 Body composition and measurements (BCM)

| ID | Requirement | Acceptance criteria | Priority | Notes |
|---|---|---|---|---|
| BCM-001 | The user shall be able to record body weight in kg. | (1) Entry accepts values from 20.0 to 500.0 kg in steps of 0.1 kg and rejects values outside the range. (2) Each entry stores date, time and value; more than one entry per day is permitted. | P1 Must | |
| BCM-002 | The user shall be able to record neck, chest, waist and hip circumference in cm. | (1) Each accepts values from 10.0 to 300.0 cm in steps of 0.1 cm. (2) The user can record any subset of measurements in one entry, and omitted ones are stored as absent. | P1 Must | Measurement site definitions (such as waist at navel) shown as help text. |
| BCM-003 | Right and left thigh, calf, bicep and forearm circumferences shall be stored as separate values. | (1) Each of the eight limb measurements has its own field and its own history. (2) Entering right thigh only does not create or alter a left thigh value. | P1 Must | Stored individually even when charted together. |
| BCM-004 | Every measurement shall be dated, and the user shall be able to back-date, edit and delete entries. | (1) The date defaults to today and cannot be in the future. (2) Editing or deleting an entry updates charts and summaries immediately. (3) Each measurement type has a history list, newest first, available offline. | P1 Must | |
| BCM-005 | The app shall show trend charts per measurement over a selectable period (4 weeks, 12 weeks, 1 year, all). | (1) Right and left series for the same site can be shown on one chart as two distinct, labelled series. (2) Dates without data are shown as gaps; the app does not interpolate or invent values. | P1 Must | Chart rules in UXD-009. Gap rule decided 2026-11-05 (§7): readings up to and including 7 days apart may be joined; longer gaps break the line. |
| BCM-006 | The app shall show a weight trend line as a moving average alongside the raw entries. Method: 7-day moving average (decided 2026-11-05, §7). | (1) Raw entries remain visible as individual points. (2) With fewer than 3 entries in the window, no trend value is drawn for that window. | P1 Must | Method decided 2026-11-05 (§7, WP 10 D1): trailing 7-calendar-day average ending on each day with an entry; daily means first; a trend point needs at least three individual readings in the window. |
| BCM-007 | The user shall be able to compare measurements between two selected dates or periods. | (1) Given waist 90.0 cm on 2026-11-01 and 87.5 cm on 2026-12-01, the comparison shows -2.5 cm and -2.8 %. (2) If either date has no entry, the app offers the nearest entry on either side and states its date. | P1 Must | |
| BCM-008 | The app shall show a progress summary over a chosen period covering weight change and change in each measured site. | (1) The summary lists first value, latest value and difference for each type with at least two entries in the period. (2) Types with fewer than two entries are listed as "not enough data". | P1 Must | |
| BCM-009 | The user shall be able to export body weight and measurement data. | (1) Export produces CSV with one row per entry and columns for date, type, value and unit. (2) Export is also included in the full JSON export (DAT-005). | P1 Must | |

### 4.5 Goals and analytics (GOL)

| ID | Requirement | Acceptance criteria | Priority | Notes |
|---|---|---|---|---|
| GOL-001 | The user shall be able to set a daily calorie target in kcal. | (1) Target accepts whole numbers from 800 to 10,000 kcal. (2) The daily summary shows consumed, target and remaining kcal. | P1 Must | The target is entered by the user. Calculating a suggested target is not part of this requirement (OQ-13). |
| GOL-002 | The user shall be able to set macronutrient targets in grams for protein, carbohydrate, fat and fibre. | (1) Each target is optional, in g, from 0 to 1000. (2) The app shows the energy implied by protein, carbohydrate and fat targets (4, 4 and 9 kcal per g) and warns, without blocking, if it differs from the calorie target by more than 10 %. | P1 Must | |
| GOL-003 | The user shall be able to set a body weight goal with a target weight, direction and optional date. | (1) A goal of 80.0 kg from 85.0 kg shows 5.0 kg to go. (2) The app shows the latest weight and the trend value, and the goal progress uses the trend value. | P1 Must | |
| GOL-004 | The user shall be able to set goals for any body measurement. | (1) A waist goal of 85.0 cm is tracked against the latest waist entry. (2) Left and right limb goals can be set separately. | P2 Should | |
| GOL-005 | The user shall be able to set training goals: sessions per week, and a target for a chosen exercise (weight × reps, duration or distance). | (1) A goal of 3 sessions per week shows 2 of 3 after two completed sessions in the current week. (2) An exercise goal of 100 kg × 5 shows the best set so far against it. | P2 Should | |
| GOL-006 | The app shall record the date on which each target or goal was set or changed. | (1) Changing the calorie target on 2026-11-10 leaves earlier days' summaries evaluated against the earlier target. (2) The target history is viewable. | P1 Must | Prevents past analytics being rewritten. |
| GOL-007 | The app shall produce a weekly summary combining nutrition, training and body measurements. | (1) The summary shows days logged, average energy and protein, sessions completed against goal, total training volume, and weight change over the week. (2) Items without sufficient data are marked "not enough data" and not shown as zero. | P1 Must | Descriptive only. |
| GOL-008 | The app shall show progress indicators for each goal, with the basis of the figure visible. | (1) Each indicator shows current value, target value and percentage, with the date range used. (2) Indicators tap through to the underlying entries. | P1 Must | |
| GOL-009 | The app shall support historical comparisons between periods. | (1) The user can compare this week with last week, and this month with last month, for energy, protein, volume and weight. (2) A period with no data shows as not available. | P2 Should | |
| GOL-010 | The app shall provide a recomposition view showing body weight trend, waist trend and strength trend for chosen exercises on a shared time axis. | (1) The three series align to the same date axis. (2) The view states the number of data points behind each series. | P2 Should | Body recomposition is the primary objective. |
| GOL-011 | No automated coaching or AI-generated recommendations shall be shipped until the data-quality criteria in GOL-012 are met and the owner has approved release. | (1) The first release contains no feature that tells the user what to eat, lift or change in target. (2) A release checklist item confirms GOL-012 status before any recommendation feature is enabled. | P1 Must | Vision constraint. |
| GOL-012 | Data-quality criteria for enabling recommendations shall be defined and measurable. Proposed criteria: at least 28 days of data with food logged on at least 80 % of days; at least 90 % of logged energy from verified or user-entered values; weight entries on at least 3 days per week. | (1) The criteria are written, approved by the owner and implemented as a computed check. (2) The check returns a pass or fail with the reason for each criterion. | P2 Should | Figures are proposals; the owner must set them (OQ-15). |

### 4.6 UX and design system (UXD)

| ID | Requirement | Acceptance criteria | Priority | Notes |
|---|---|---|---|---|
| UXD-001 | Design tokens shall be defined before UI expansion: colour palette, typography, spacing, radius and elevation, each with light and dark values. | (1) Tokens are held in one source file used by all screens. (2) No screen uses a hard-coded colour, font size or spacing value outside the tokens (checked by lint). | P1 Must | Scheduled in WP2. |
| UXD-002 | A component library shall provide documented base components: buttons, inputs, lists, cards and panels, dialogs, chips, tabs and charts. | (1) Each component has documented variants, states and usage rules. (2) Each component renders in both themes in a reviewable catalogue. | P1 Must | Component hierarchy documented. |
| UXD-003 | Every data-driven screen shall define empty, loading and error states. | (1) Each state appears in the component catalogue for the screen. (2) An empty state offers the primary action (such as "Log your first meal"); an error state offers retry and does not show raw technical messages. | P1 Must | |
| UXD-004 | Interactive elements shall have touch targets of at least 48 × 48 dp on Android and 44 × 44 pt on iOS. | (1) An automated layout check finds no tappable element below the minimum. (2) Adjacent targets are separated by at least 8 dp or pt, or have non-overlapping hit areas. | P1 Must | |
| UXD-005 | All interactive and informative elements shall have screen-reader labels, and text shall scale with system font size. | (1) Every control has an accessibility label, role and state, verified by a TalkBack and a VoiceOver walkthrough of core flows. (2) At 200 % system font scale, core screens show no truncated primary content and no overlapping controls. | P1 Must | |
| UXD-006 | Navigation shall follow platform conventions with a consistent structure. Proposed: bottom navigation with up to 5 top-level destinations (for example Today, Nutrition, Train, Body, Progress). | (1) Every screen is reachable in 3 taps or fewer from the top level. (2) The system back gesture and button behave consistently and never exit the app from a nested screen. | P1 Must | Destination list to be agreed in WP2. |
| UXD-007 | Input conventions shall be consistent: numeric keypad for numbers, units shown beside values, and sensible defaults. | (1) Numeric fields open the numeric keypad and show the unit label. (2) Validation messages appear beside the field and state the accepted range. | P1 Must | |
| UXD-008 | Fast-logging flows shall be designed for minimal interaction: logging a repeated food, a saved meal, a set, and a body weight. | (1) A repeated food is logged in 4 taps or fewer from the home screen. (2) A set with pre-filled values is confirmed in 2 taps or fewer. (3) Body weight can be logged in 3 taps or fewer. | P1 Must | Supports GEN-013. |
| UXD-009 | Charts shall be readable and accessible. | (1) Series are distinguished by more than colour (shape, pattern or direct label). (2) Each chart offers a text summary or data table readable by a screen reader. (3) Axes show units, and charts remain legible at 320 dp width. | P1 Must | |

### 4.7 Platform integrations (PLT)

| ID | Requirement | Acceptance criteria | Priority | Notes |
|---|---|---|---|---|
| PLT-001 | Camera access shall be provided through a platform abstraction. | (1) Feature code calls only the abstraction interface. (2) A test double allows the dependent flows to be tested without a camera. | P1 Must | |
| PLT-002 | Barcode scanning shall be provided through a platform abstraction and shall read EAN-13, EAN-8, UPC-A and UPC-E. | (1) A printed EAN-13 code is recognised in under 3 seconds in normal indoor light on the reference devices. (2) The user can enter a barcode manually if scanning fails. | P1 Must | Success-rate target to be set (OQ-11). |
| PLT-003 | The app shall detect device capabilities at runtime: camera, barcode scanning, Health Connect or HealthKit availability, notification permission, background execution and secure storage. | (1) A single capability service reports each capability as available, unavailable or permission denied. (2) The result is available to any feature without calling platform APIs directly. | P1 Must | |
| PLT-004 | The app shall degrade gracefully when a capability is absent or permission is denied. | (1) With camera permission denied, barcode entry offers manual code entry and explains how to enable the permission. (2) With any single capability disabled in a test build, all other core flows remain usable. | P1 Must | |
| PLT-005 | The app shall integrate with Health Connect on Android, only with user permission per data type. | (1) Permissions are requested individually for each data type (such as weight, or exercise sessions) at the point of use. (2) If Health Connect is not installed, the integration is hidden or shows an install-or-unavailable state and nothing else is affected. | P3 Could / later | Read and write scope: OQ-16. |
| PLT-006 | The app shall integrate with HealthKit on iOS, only with user permission per data type. | (1) Permission is requested per data type at the point of use. (2) Revoking permission in system settings stops further reads and writes without error dialogs. | P3 Could / later | Same scope question as PLT-005. |
| PLT-007 | The app shall support local notifications for workout reminders and rest timer completion, off by default until the user opts in. | (1) Notification permission is requested only when the user enables a reminder. (2) Disabling a reminder cancels all scheduled notifications of that type. | P2 Should | OQ-05. |
| PLT-008 | The app shall use background tasks within platform limits for the rest timer, scheduled backup and (when enabled) sync. | (1) A scheduled backup runs at most once per day and reports failure in the app on next open. (2) The app does not rely on a background task for correctness; missed tasks are completed on next foreground. | P2 Should | |
| PLT-009 | Secrets and tokens shall be stored in platform secure storage (Android Keystore, iOS Keychain). | (1) Authentication tokens are never written to the app database, logs or plain files. (2) Removing the account deletes the stored tokens. | P1 Must | Relevant only once sync exists, but the abstraction is built first. |

### 4.8 Data, backup, sync and accounts (DAT)

| ID | Requirement | Acceptance criteria | Priority | Notes |
|---|---|---|---|---|
| DAT-001 | A local database on the device shall be the source of truth for all user data. | (1) All features read and write the local database only. (2) Uninstalling any cloud feature does not remove local data. | P1 Must | |
| DAT-002 | The data layer shall validate all input before persistence. | (1) Values outside defined ranges (for example negative weight, protein over 100 g per 100 g) are rejected with a message. (2) Foreign key and uniqueness constraints are enforced by the database, tested by attempting invalid writes. | P1 Must | |
| DAT-003 | The user shall be able to create a full backup file from within the app. | (1) The backup contains all user data and a format version. (2) The file can be saved to device storage or shared through the system share sheet, with no network required. | P1 Must | |
| DAT-004 | The user shall be able to restore from a backup file. | (1) Before applying, the app shows record counts and the backup date and asks for confirmation. (2) A corrupt or incompatible file is rejected without changing existing data. (3) After restoring a backup of a test dataset, row counts and checksums match the source. | P1 Must | Replace versus merge behaviour to be decided in WP3. |
| DAT-005 | The user shall be able to export all data as JSON. | (1) The export contains every domain with units and provenance labels. (2) The JSON validates against a published schema included in the repository. | P1 Must | |
| DAT-006 | The user shall be able to export data as CSV per domain (food log, recipes, workouts, body measurements). | (1) Each CSV has a header row, ISO 8601 dates and metric units in column names. (2) Opening the files in a spreadsheet shows no corrupted characters for names with diacritics (UTF-8). | P1 Must | |
| DAT-007 | The app shall handle database versions safely on upgrade and downgrade. | (1) Upgrading from each released schema version completes with data intact. (2) If the database is newer than the app supports, the app refuses to open it, preserves it and advises updating. | P1 Must | Supplements GEN-007. |
| DAT-008 | The app shall offer scheduled automatic local backups, off by default, retaining the most recent 5 copies. | (1) When enabled, a backup is created at the chosen interval. (2) The sixth backup replaces the oldest. | P2 Should | Storage location and retention: OQ-06. |
| DAT-009 | Authentication shall be required only when the user enables cloud sync. | (1) No sign-in screen is shown unless the user selects sync. (2) Signing out or disabling sync leaves all local data intact and usable. | P1 Must | Applies from the point sync exists. Sign-in methods: OQ-08. |
| DAT-010 | Cloud sync shall be optional, off by default, and transmit only the data the user has chosen to sync. | (1) With sync off, no sync requests are made. (2) Data in transit uses TLS 1.2 or later. (3) The settings screen lists exactly what is synced. | P3 Could / later | Provider and architecture: OQ-08. |
| DAT-011 | Sync shall resolve conflicts deterministically and without silent loss. | (1) Given the same record edited on two devices while offline, the result is the same on both devices after sync. (2) Where fields conflict, the later edit wins per field and the other value is retained in a recoverable conflict log. | P3 Could / later | Strategy (last-write-wins per field versus merge) to be confirmed. |
| DAT-012 | The user shall be able to delete all local data. | (1) A confirmation requires typing a word or holding a button. (2) After deletion, the app returns to first-run state and the database contains no user records. | P1 Must | |
| DAT-013 | When sync exists, the user shall be able to delete their account and all cloud-held data. | (1) Deletion is requested from within the app. (2) Cloud data is removed within a stated period (proposed: 30 days) and the app confirms completion. Local data remains unless the user also chooses to delete it. | P3 Could / later | Retention policy: OQ-06. |

## 5. Traceability stub

Prefix-level mapping of requirements to proposed work packages. Per-requirement mapping and verification references will be added when each work package is planned. Work package names and scope are proposals and are defined in the project plan, not here.

| Prefix | Domain | Proposed work packages | Requirements in baseline |
|---|---|---|---|
| GEN | Non-functional and cross-cutting | WP1 to WP3 | 16 |
| NUT | Nutrition logging and food database | WP5, WP6 | 23 |
| RCP | Recipes and meal planning | WP7 | 15 |
| TRN | Strength training | WP8, WP9 | 28 |
| BCM | Body composition and measurements | WP10 | 9 |
| GOL | Goals and analytics | WP11 | 12 |
| UXD | UX and design system | WP2 | 9 |
| PLT | Platform integrations | WP6, WP13 | 9 |
| DAT | Data, backup, sync and accounts | WP3, WP12 | 13 |
| | **Total** | | **134** |

## 6. Open questions

These questions need an owner decision. Until answered, the linked requirements stay Proposed.

| ID | Question | Why it matters | Affects |
|---|---|---|---|
| OQ-01 | Which food database will be used, and under what licence (open dataset, commercial licence, or user-built only)? Is redistribution inside the app permitted? | Determines coverage, whether data can be labelled verified, attribution duties and offline bundling size. | NUT-005, NUT-024, GEN-005 |
| OQ-02 | Is imperial unit support (lb, oz, in, fl oz) required in v1, or only metric? | Adds conversion, display and test scope across nutrition, training and body data. | GEN-004, NUT-022 |
| OQ-03 | Which markets and languages are in scope for v1 (for example UK English only)? | Affects food database choice, label conventions (such as energy in kJ), number formats and translation effort. | GEN-016, NUT-005 |
| OQ-04 | Do recipes need photos? If yes, are they stored only on the device and included in backup? | Affects storage size, backup size, camera and gallery permissions and sync cost. | RCP-001, DAT-003 |
| OQ-05 | Must the rest timer alert the user when the app is in the background or the screen is locked? | **Decided 2026-11-05** (§7): yes — background rest alerts are required where the platform allows, through opt-in local notifications (ADR-0007, accepted); on Android exact scheduling is offered (exact-alarm permission with an explanation) with inexact delivery as the fallback; iOS background delivery remains unverified until device evidence exists. | TRN-022, PLT-007, PLT-008 |
| OQ-06 | What is the retention policy for local backups, cloud data after account deletion, and deleted records (immediate purge or recoverable for a period)? | Drives privacy commitments, storage use and the deletion wording. | DAT-008, DAT-012, DAT-013 |
| OQ-07 | When a scanned barcode is not in the local database, may the app query an online source? If so, which, and is the barcode sent off the device? | Conflicts with offline-first and privacy minimisation unless handled as an explicit opt-in. | NUT-006, GEN-009 |
| OQ-08 | Is cloud sync intended at all, and if so which provider, which sign-in methods and which data is in scope? | Determines whether the sync, authentication and secure storage work packages are needed. | DAT-009 to DAT-011, PLT-009 |
| OQ-09 | What is the source and licence of the exercise library (own content, licensed dataset, or open source)? Are demonstration images or videos required? | Affects content creation effort, app size and licence compliance. | TRN-008, LIB-001..014 | **Decided 2026-11-05** (§7): original RepForge-authored content; compatible open datasets with provenance; no proprietary content; media deferred (WP 16e).
| OQ-10 | Is any crash reporting or usage analytics acceptable, and if so is it opt-in and which data may it contain? | Conflicts with data minimisation unless defined; affects the ability to find defects in the field. | GEN-009 |
| OQ-11 | Which devices and operating system versions are the reference for performance targets and minimum support (for example the oldest supported Android API level and iOS version)? What barcode scan success rate is acceptable? | The proposed performance targets cannot be verified without reference devices. | GEN-013, GEN-014, PLT-002 |
| OQ-12 | Should the default exertion scale be RPE or RIR, and may users switch? | Affects defaults, training copy and the meaning of stored values. | TRN-020 |
| OQ-13 | What health and safety positioning is required: disclaimers, minimum age, lower limits for calorie targets, and whether the app may suggest a calorie target or only accept the user's own? | Has legal and user-safety implications; also affects storage advice such as freezing and reheating guidance. | GOL-001, RCP-005 |
| OQ-14 | Which carbohydrate convention applies: total carbohydrate with fibre included, or available carbohydrate with fibre separate? How is energy from fibre treated? | Changes how every carbohydrate and energy figure is calculated and compared with product labels. | NUT-003, NUT-017 |
| OQ-15 | What data-quality thresholds must be met before any recommendation feature is considered, and who signs off? | The proposed figures (28 days, 80 % of days logged) are placeholders. | GOL-011, GOL-012 |
| OQ-16 | Should Health Connect and HealthKit integrations be read-only, or also write workouts, weight and nutrition back? | Write access widens the permission scope and the privacy review. | PLT-005, PLT-006 |
| OQ-17 | On restore, should the default be replace-all or merge? How are duplicates handled? | Affects data-loss risk and the complexity of the restore flow. | DAT-004 |
| OQ-18 | What are the day boundary and week start rules (local midnight, Monday start)? Should users be able to change them? | Affects every daily and weekly total and the consistency of comparisons. | NUT-001, NUT-016, TRN-028 |
| OQ-19 | How is training volume attributed when an exercise has several primary anatomical targets? | TRN-027 per-muscle volume and WP 11 reporting. **Decided and confirmed 2026-11-05** (§7): attributed set counts — primary muscle: full attribution of each recorded exercise set; secondary muscle: separately recorded attribution, excluded from primary totals; not physiological measurements of muscle stimulus. | TRN-027 |
| OQ-20 | Does TRN-010(1) ("exactly one primary group") still hold? | Conflicts with multiple primary targets. **Closed 2026-11-05** by WP 16 decision 3 (§7): one or more primary targets. | TRN-010 |
| OQ-21 | What counts as an "imported" exercise (versus system-supplied and user-created)? | Source separation and update rules. **Decided 2026-11-05** (§7): brought in by a user from an external file, application or user-controlled source; open datasets in the official catalogue are system content with provenance and licence. | LIB-011 |
| OQ-22 | Which anatomy nodes (L1–L4) and movement patterns form the controlled reference lists? | **APPROVED 2026-11-05** (§7): 126-node anatomy, 17 families and 62 patterns (79 entries), rules R1–R8, `docs/catalogue/`. | LIB-004, LIB-005 |
| OQ-23 | What are the minimum coverage targets per anatomical region? | **APPROVED 2026-11-05** (§7): 325 slot minimums in 21 groups plus 70 conditioning, power and mobility entries; 5.1 chest pilot then re-baselining and owner approval before 5.2–5.7. | LIB-001, LIB-002 |
| OQ-24 | WP 9 review M1: Android 14+ rest alerts usually inexact. | **Decided 2026-11-05** (§7): offer the exact-alarm permission with an explanation when rest alerts are enabled; inexact notifications remain the fallback. **Implemented 2026-11-05 in 0c35ef1** (independent review: no High/Medium; CI green incl. release build); device verification in the owner's device campaign. | TRN-022, PLT-007 |
| OQ-25 | WP 9 review M4: exercise history paging (TRN-025(2)). | **Decided 2026-11-05** (§7): allocated to WP 8 stage 6; recorded as a WP 9 limitation. | TRN-025 |

## 7. Amendments (owner decisions)

### 2026-11-04 — WP 5 acceptance decisions
- **Provenance labels: fourth category `crowdsourced` approved as a deviation** from GEN-005 / NUT-018 (which list verified, user-entered, estimated). It labels community-maintained data from Open Food Facts, which is neither verified by a curated source nor entered by this user. Order of strength for NUT-019 aggregate totals, weakest last: verified › crowdsourced › userEntered › estimated; a total carries the weakest label among its inputs (implementation: WP 5 closure, NUT-019).
- **NUT-018 part 3** ("editing a verified food creates a user-entered copy" per the original acceptance text) is retained with its original wording. It is not descoped and not assigned until its intended behaviour and owner are clarified by the owner.
- **Allocation of P1 nutrition items not delivered by WP 5**: NUT-017, NUT-019, NUT-022 → WP 5 closure; NUT-011 → WP 7; NUT-023 → WP 14. Recorded in D06.
- **NUT-021 interpretation**: an unknown nutrient value is stored and shown as unavailable, never as 0; a total built from inputs with unknown values states how many inputs were unknown.

### 2026-11-04 — WP 7 acceptance decisions
- **OQ-14 decided**: UK/EU convention — carbohydrate is available carbohydrate; fibre separate, never added or subtracted; energy as stated. Limitation accepted for US-labelled products (calculation specification §4).
- **Portion precision**: portion counts are stored to at least 0.01 (calculation specification §2.1 rev 1.3); gram/ml quantities stay at 0.1.
- **Allocation**: NUT-019 day-total provenance badge → WP 11; NUT-022 kg/l/imperial entry → new WP 15 (Nutrition entry units). Accepted WP 5 is not reopened.
- **Seed recipes**: imported with freezing "unknown" regardless of legacy flags; declared nutrition kept as estimated until every ingredient note is replaced by a linked ingredient.

### 2026-11-05 — NUT-017 approved
- **NUT-017** is satisfied by the approved calculation specification (`docs/nutrition-calculation-spec.md`, revision 1.3) and its 41 worked examples executed as tests.

### 2026-11-05 — Exercise library scope amendment (owner requirement)
- The exercise library shall be a comprehensive, extensible exercise reference and discovery system (breadth benchmark: historical bodybuilding and strength-training reference apps), not a minimal set for logging. Ten capabilities recorded as **LIB-001..LIB-010** (identifiers proposed) in `docs/exercise-library-expansion.md` §1, with the owner's architectural, content and acceptance requirements (anatomical coverage, diversity, classification quality, discoverability, extensibility, integrity over raw count). No built-in programmes or programme generation at this stage.
- WP 8 is not assumed to satisfy it: gap analysis and proposed WP 16 in `docs/exercise-library-expansion.md` (proposed, pending owner decisions §5). WP 9 scope unchanged.

### 2026-11-05 — WP 16 exercise library decisions (owner)
Full text: `docs/exercise-library-expansion.md` §5.
1. **Engineering Object** defined: first-class persistent domain entity with stable identity, defined type and schema, explicit source and provenance, validation and integrity constraints, creation and modification metadata, defined relationships, lifecycle-appropriate versioning, and persistence, query, backup and restore. Not every object needs its own history or table. Exercises are persistent entities.
2. **OQ-09 decided**: original RepForge-authored content; compatible openly licensed datasets allowed with recorded provenance; no Bodybuilding.com content (breadth benchmark only); multiple providers; commercial licensing deferred.
3. **Anatomy**: four levels (region, muscle group, anatomical muscle, subdivision or head); tag at the most meaningful defensible level; multiple primary and secondary targets; existing exercise ids and the 19 muscle-group ids preserved; qualitative classifications not presented as precise biomechanics. **TRN-010(1) amended**: "one or more primary targets" replaces "exactly one primary group" (OQ-20 closed by this decision).
4. **Difficulty**: beginner, intermediate, advanced as defined; technical complexity, not load or fitness.
5. **Relationships**: variation of, progression of, regression of, alternative to, unilateral counterpart; validated, directional where appropriate, no circular or invalid references; not programme functionality.
6. **Coverage**: structured coverage matrix is the formal WP 16c acceptance mechanism; regional minimums defined before population (OQ-23); explicit gap report; raw count insufficient.
7. **Languages**: English (UK) first; localisation without duplicate identities; translation deferred.
8. **Governance**: WP 16 separate; WP 8 not reopened or renumbered; WP 9 unchanged; WP 10/11 inspected before sequencing; unrelated work not blocked.
9. **Structure**: WP 16a–16e approved; schema v8 approved as target subject to architectural review.
10. **Additional**: separate system, user and imported exercises (LIB-011); catalogue updates never silently overwrite user customisations, idempotent import and update (LIB-012); provenance, validation, duplicate detection, integrity reporting (LIB-013); discovery by anatomy, equipment, pattern, classification, difficulty; future metrics, tempo, range of motion, execution guidance and recommendations accommodated but outside current acceptance.
- Owner retains approval of architectural decisions, work-package acceptance, merges and releases. WP 16a implementation awaits authorisation of `docs/wp16a-implementation-plan.md` (ADR-0008, ADR-0009 proposed).

### 2026-11-05 — Library expansion incorporated into WP 8 (owner; supersedes WP 16 governance)
- **WP 8 stays the active work package** and delivers the expanded library (LIB-001..014 and the library decisions above). **WP 16 is not created** as a delivery package; the earlier proposal is withdrawn.
- This supersedes library decision 8 (WP 16 separate; WP 8 not reopened) and re-organises decision 9: workstreams 16a–16e become **WP 8 stages 3 (architecture and reference data), 4 (catalogue tooling and quality assurance), 5 (anatomical catalogue population), 6 (search, discovery and exercise screens) and a deferred media workstream**. All other library decisions stand (Engineering Objects, OQ-09, anatomy, difficulty, relationships, coverage matrix, language, schema v8 target, additional requirements). No WP 8A–8E renumbering.
- Completed WP 8 work, identifiers, migrations and tests are preserved; the 89-exercise implementation is a foundation and does not satisfy the expanded requirements. Previously accepted work is not reopened. WP 9 is unchanged.
- Revised plan, the five-way distinction (implemented and verified; original criteria; expanded requirements; remaining work; final acceptance criteria) and sequencing: `docs/wp8-delivery-plan.md` (proposed; was `docs/wp16a-implementation-plan.md`). Implementation awaits owner review and authorisation.

### 2026-11-05 — WP 8 governance confirmed; OQ-19 and OQ-21 decided (owner)
- **WP 8 remains the active work package**; the expanded exercise library is WP 8 scope. **No WP 16 implementation is authorised**; the WP 16 proposal is superseded by the WP 8 scope decision and kept only as history. Its design, domain model, migration strategy, catalogue reconciliation and testing approach are retained as WP 8 internal stages (`docs/wp8-delivery-plan.md`). ADR-0008 and ADR-0009 keep their numbers and history and govern WP 8 stage 3 (still Proposed). WP 9 stage 3b continues independently. WP 10 may proceed independently, subject to schema version coordination. WP 11 keeps its dependency on the expanded anatomy and exercise taxonomy.
- **OQ-19 approved**: each primary muscle target receives the full recorded exercise-set volume. Secondary targets are reported separately and excluded from primary volume totals. These figures attribute recorded sets; they are not physiological volume measurements.
- **OQ-21 approved**: imported exercises are brought into RepForge by a user from an external file, application or user-controlled source. Open datasets incorporated into the official RepForge catalogue are system-provided content with recorded provenance and licensing.
- **Technical qualifications** for WP 8 stage 3: preserve all exercise ids, muscle-group ids and user data; demonstrate that the `exercises` table rebuild is preferable to an incremental migration; prove migration value equality across supported schema versions; preserve backup and restore compatibility; system catalogue updates never overwrite user customisations; retired exercises keep historical workout references; catalogue releases atomic, repeatable and auditable. Plan response: `docs/wp8-delivery-plan.md` §17.

### 2026-11-05 — WP 8 decisions approved; stage 4 authorised; stage 3 gated (owner)
**Approved**
1. **ADR-0008** (exercise domain model): architectural direction approved.
2. **ADR-0009** (catalogue provenance and updates): architectural direction approved.
3. **Muscle identifiers**: the 19 existing muscle-group ids are preserved and mapped into the approved hierarchy; `fullBody` is retained as a non-anatomical top-level classification.
4. **`exercises` table rebuild** approved, conditional on demonstrated complete value preservation, historical workout reference integrity, and justification against incremental migration.
5. **OQ-19**: each primary muscle target receives the full recorded exercise-set count; secondary muscles are reported separately and excluded from primary volume totals; these are set counts, not physiological volume measurements. *Clarification requested by the architect*: TRN-027(3) also reports kg volume per muscle group — does kg volume follow the same attribution, or is per-muscle reporting set counts only? Not assumed either way.
6. **OQ-21**: imported exercises are user-supplied from external files, applications or user-controlled sources; open datasets in the official catalogue are system-provided content with recorded provenance and licensing.
7. **Legacy invalid values** (WP 8 decision 3): never silently corrected or replaced; original preserved in quarantine; operational value cleared or retained according to field semantics; records and relationships preserved; **a migration report identifies every affected record** (the reporting surface is WP 8 stage 3 work; see TD-41).
8. **TRN-020** (WP 8 decision 4): RIR is an integer from 0 to 5 inclusive, enforced at the domain and persistence boundaries. The domain rule exists (WP 8 review fix M3); persistence enforcement (the v6 CHECK allows 0–10) is WP 8 stage 3 work, with out-of-range stored values handled by decision 7.
9. **Screen ownership** (WP 8 decision 5): WP 8 owns exercise library, taxonomy, discovery, exercise detail and favourites. WP 9 owns workout planning, workout execution, sessions, sets and rest timers. No unnecessary duplication.

**Stage 4 authorised now**, alongside WP 9: exercise editorial guide; anatomical coverage matrix; muscle reference data; movement-pattern reference data; catalogue population standards; provenance and licensing requirements; catalogue quality and duplicate-detection specifications. Restriction: no change to shared production code, database schemas or WP 9 implementation; outputs are reviewable documentation and reference data for use after stage 3.

**Stage 3 implementation gate**: not before (1) WP 9 stage 3b CI completes successfully, (2) Android and iOS build results are reviewed (core library desugaring with the supported Android build configuration in particular), (3) the emulator full-session test passes, (4) the independent WP 9 review is complete, (5) WP 9 delivery is formally accepted. Then the stage 3 plan returns for final authorisation.

Governance: WP 8 active and expanded; WP 16 withdrawn; WP 9 scope unchanged; accepted work not reopened.

### 2026-11-05 — WP 8 decisions confirmed; OQ-22 and OQ-23 review requirements (owner)
- **Confirmed**: ADR-0008 and ADR-0009; the 19 muscle-group ids and their mapping; `fullBody` as a non-anatomical top-level classification; OQ-19; OQ-21; legacy invalid-value handling; TRN-020 (RIR whole numbers 0–5); WP 8 owns the exercise library and discovery screens, WP 9 owns planning and session screens; stage 4 alongside WP 9.
- **OQ-19 terminology (confirmed)**: primary muscle — full attribution of each recorded exercise set; secondary muscle — separately recorded attribution, excluded from primary volume totals; these are **attributed set counts, not physiological measurements of muscle stimulus**. The distinction is shown in reporting and documentation. Where TRN-027(3) reports kg volume per muscle, it is the kg volume of the attributed sets, labelled the same way (architect's reading of "full attribution of each recorded exercise set"; correct if not intended).
- **Retired exercises**: never deleted; identifiers never reused; an automated integrity check verifies that every historical set (and plan) reference resolves to an existing exercise, retired ones included.
- **`exercises` rebuild**: conditional approval stands — the trial comparison against incremental migration, migration value-equality tests, backup compatibility and preservation of historical references are recorded as evidence **before sub-stage 3b is finalised**. The comparison may not be skipped.
- **OQ-22**: direction approved; the owner reviews the actual anatomy and movement-pattern lists (stable ids, display names, parents, definitions, inclusion and exclusion criteria, mapping to existing records) before they become controlled reference data.
- **OQ-23**: coverage minimums are proposed per anatomical region from the actual anatomical structure, covering compound, isolation, equipment diversity, movement patterns, unilateral and bilateral, difficulty distribution and meaningful variations; reviewed before stage 5. **No catalogue population before OQ-22 and OQ-23 are approved.**
- Sequencing unchanged: WP 9 stage 3b CI and independent review complete, and WP 9 formally accepted, before WP 8 stage 3 code; WP 10 independent with schema coordination; WP 11 follows the expanded taxonomy. WP 8 active and expanded; WP 16 withdrawn.

### 2026-11-05 — WP 8 stage 4 approved: OQ-22, OQ-23, ADR-0010 and related decisions (owner)
- **OQ-22 APPROVED**: the 126-node anatomy hierarchy; the movement-pattern taxonomy (17 families, 62 patterns, 79 entries); the 19 existing ids unchanged; the proposed classifications; rules R1–R8. Neck: include conventional gym exercises. Pelvic floor: excluded. Soft-tissue release: deferred.
- **Primary-muscle principle APPROVED**: primary targets are the muscles an exercise is designed and normally selected to train; other muscles making significant contributions are secondary. Applied consistently (rows, deadlifts, dips, chin-ups and other compound movements); disputed individual assignments are resolved in each tranche's content review; no additional primary target merely because a muscle contributes significantly.
- **ADR-0010 / Q-F APPROVED (Accepted)**: `fullBody` is a flagged, childless, non-anatomical L1 node; only the single primary of qualifying whole-body or conditioning exercises; never secondary; never with anatomical primaries; excluded from anatomical roll-ups, coverage and attributed muscle set counts; shown separately in reports, labelled non-anatomical; historical references preserved and listed in the migration report.
- **OQ-23 APPROVED**: 325 anatomical slot minimums across 21 groups (chest 36, shoulders 35, upper back 25, lats 20, quadriceps 28, glutes 25, triceps 24, forearms 19, abs 18, biceps and brachialis 17, hamstrings 13, obliques 13, rotator cuff 10, neck 10, calves 9, lower back 5, adductors 4, hip flexors 4, shin and outer lower leg 4, abductors 3, deep hip rotators 3); separate 70 conditioning, power and mobility minimums; one slot per exercise per group; primary targets determine coverage; no L4 minimums; optional superficial variations; class diversity cap; release-2 classifications; duplicate-detection thresholds; 5.1 chest pilot with mandatory re-baselining and explicit owner approval before 5.2–5.7; seed baseline 67/325 and 20/70 accepted. The framework is an acceptance mechanism, not a demand to add exercises to meet numbers; quality and meaningful variation take precedence.
- **Other decisions APPROVED**: all 12 equipment additions (including ski ergometer and stair climber); one generic `machine` id retained (a later split is a reference-data enhancement); equipment load/support rule; all seven optional controlled exercise attributes with their vocabulary and boundary rules (the attribute fallback is not required); cardio and mobility mechanics empty; content: original RepForge content remains the default; AI drafting assistance permitted and recorded in provenance; a named human editor is the accountable author; share-alike datasets excluded entirely; third-party datasets only with demonstrably compatible provenance and licensing; attribution on a credits screen; legal review before the first public release.
- **Deferred**: review items X1–X4 stay deferred to WP 8 stage 3a or the 5.1 pilot; stage 4 scope is not expanded.
- **Stage 5** is authorised in principle, gated: no bulk population before WP 8 stage 3 reference-data, integrity and migration tooling is implemented and verified; then the 5.1 pilot; then re-baselining and owner approval before 5.2–5.7.
- **WP 9** continues independently; M1 and M4 are open owner decisions (OQ-24, OQ-25). Workstreams and acceptance records stay separate.

### 2026-11-05 — WP 9 owner decisions (M1, M4, assumptions, ADR-0007)
- **M1 / OQ-24 approved**: when rest alerts are enabled, explain why exact-alarm access helps and offer the Android exact-alarm permission (existing `SCHEDULE_EXACT_ALARM`; no `USE_EXACT_ALARM` without separate technical and policy justification). If declined or not granted, inexact notifications remain the fallback. The setting reflects permission state and never implies precise timing when exact scheduling is unavailable. Denial, return from settings, revocation and re-enablement are handled. Notification permission is never a prerequisite for logging sets or using the timer. Requires implementation and verification before WP 9 acceptance.
- **M4 / OQ-25 approved**: exercise history paging (TRN-025(2)) is allocated to **WP 8 stage 6**; it is a recorded WP 9 limitation and is not delivered by WP 9.
- **WP 9 assumptions confirmed**: (1) personal records are calculated from recorded data, not stored; (2) schedule entries are date-specific; (3) the rest timer uses wall-clock time; (4) several entries of the same exercise are allowed in a session; (5) session, exercise and set notes have a 4,000-character limit; (6) the undo window is 12 seconds; (7) archived exercises are skipped when starting a workout; (8) weight entry is kg-only while OQ-02 is open — an interim constraint; **OQ-02 stays open**.
- **ADR-0007 approved** (Option 1, notification adapter). **OQ-05 decided**: background rest alerts are required where the platform allows, with Android exact scheduling offered and inexact fallback.
- WP 9 is **not accepted**: it remains delivered, awaiting acceptance, until M1 is implemented, verified and reviewed by the owner.

### 2026-11-05 — WP 10 owner decisions D1–D5
- **D1 — BCM-006 weight trend (method decided)**: trailing seven-calendar-day moving average ending on each day that has an entry; multiple readings on one day are averaged first, then the daily means are averaged; a trend point is shown only when the window holds **at least three individual readings** (not three distinct days); raw readings stay visible.
- **D2 — file output**: `share_plus` for exports and `file_selector` for choosing a restore file, behind a platform-neutral port (ADR-0011, accepted); package compatibility verified before implementation.
- **D3 — backup screen**: a minimal Settings screen using the existing `DriftBackupRepository`; backup date and record counts shown before restore confirmation; invalid or newer-format backups rejected without modifying existing data.
- **D4 — comparison**: periods are compared by their mean, with the number of readings shown for each period; for a selected date without an exact reading, the nearest earlier and later readings are shown with their actual dates and neither is silently substituted (the user chooses).
- **D5 — CSV**: columns `date, type, value, unit`; UTF-8; header row; one row per reading; date as ISO 8601 local date-time including the UTC offset.
- Authority: stages 1 and 2 continue with these decisions; stage 3 proceeds only after ADR-0011 and the file-output implementation have been reviewed; no schema migration unless evidence shows it is necessary; WP 9, PR #5 and `main` unchanged; WP 10 stays delivered-awaiting-acceptance until the owner accepts it.

### 2026-11-05 — WP 10 chart gap rule (BCM-005(2))
- **Option B approved**: readings separated by 7 days or less may be connected; gaps greater than 7 days must break the chart line. No missing reading is interpolated or fabricated; actual timestamps and values are preserved. A connection is a visual link between recorded observations, not continuous measurement.
- WP 10 stage 3a (11c4889) local gate, independent review and two re-checks accepted; CI is the verification gate for stage 3b.

### 2026-11-05 — WP 10 stage 3b architect decisions (owner may override)
Taken under owner decision D3 ("reject invalid or newer-format backups without modifying existing data"), as the safer reading:
- **Empty backups rejected**: a backup with no restorable records (empty or only unknown tables) is rejected at preview — "This backup contains no records. Nothing was changed." A restore never wipes all data; deleting all data, if ever wanted, would be its own explicit action.
- **Android restore picker unfiltered**: the picker does not filter by file type on Android (providers such as Drive or mail often report `.json` as `text/plain`); the backup validator remains the guard; iOS keeps the `public.json` filter.
- **CSV columns**: D5 (a `unit` column) supersedes DAT-006(1) "metric units in column names" for the body-measurements CSV.

### 2026-11-05 — WP 10 accepted (owner)
- **WP 10 ACCEPTED at bb5f788**; the delivery evidence and acceptance matrix in `docs/delivery-record/WP10.md` are accepted.
- **D3 decisions retained with clarification**: reject structurally empty or invalid backups, but do not reject a valid full backup merely because it contains zero measurement records; the Android restore picker needs no file-type filter and the restore validator remains authoritative. The implemented rule (reject only when no restorable row exists in any table) meets this; the brand-new-app export edge case is noted in the WP 10 record for owner confirmation.
- **OQ-18 and OQ-02 remain open.** Device-campaign and spreadsheet-compatibility checks remain deferred verification, not completed evidence.

### 2026-11-05 — Backup edge case confirmed (owner)
- The implemented behaviour is confirmed; no code change. A settings-only backup (valid data, zero measurement records) is accepted. A completely empty backup (every table present, no records anywhere) is rejected and cannot overwrite an existing database. WP 10 acceptance and closure at bb5f788 are unchanged; WP 10 is not reopened.
- WP 8 sequence confirmed: WP 9 acceptance review → authorisation of the stage 3 plan → stage 3a (domain model) → `exercises` rebuild trial and value-equality evidence before finalising 3b → migration, reference data and catalogue update. Stage 3 does not bypass the WP 9 acceptance gate or the agreed migration evidence.

### 2026-11-06 — WP 9 accepted; WP 8 stage 3 authorisation withheld pending plan correction (owner)
- **WP 9 ACCEPTED at 0c35ef1**, with the qualifications recorded in `docs/delivery-record/WP9.md` (Low findings N1a/N1b; M1-F1..F4 and real-device timing to the device campaign; assisted and cardio PR definitions as a requirements gap; exercise history paging to WP 8 stage 6; per-muscle and per-week volume screens as future delivery; rest alert lost on restart as a limitation; Google Play exact-alarm policy as a pre-release check). The exact-alarm flow is accepted as delivered, not as proof of identical behaviour across Android manufacturers.
- **WP 8 stage 3**: architectural direction, ADRs and technical decisions stand; implementation authorisation is withheld until `docs/wp8-delivery-plan.md` is corrected (§2/§14 approvals, schema v8 availability, §4 from the approved `anatomy.json`, §11 criteria) and re-reviewed. Retained requirements: report every affected legacy record; never silently correct invalid values; RIR 0–5 enforced in the database; deterministic, repeatable loading of the approved reference data with validation; retired exercises remain available to historical records; catalogue releases never overwrite user data; conditional table-rebuild approval subject to the comparison trial and migration evidence.
- Stage 4: previously authorised preparation continues; no stage 5 bulk population before stage 3 tooling is implemented and verified, the 5.1 pilot is reviewed, and the coverage matrix is approved.

### 2026-11-06 — WP 8 stage 3 authorised (owner)
- WP 8 delivery plan revision 3 (b63c4d9) **approved**; **stage 3 implementation authorised** (3a domain model; 3b schema v8, migration, repositories, backup format 3; 3c catalogue format, release reconciliation, integrity tooling; 3d WP 8/WP 9 integration; combined review and owner acceptance). Independent review and explicit gates at each sub-stage; implementation completion is not acceptance.
- Binding safeguards (plan §21): A — SQLite foreign-key sequence (no `PRAGMA foreign_keys` change inside a transaction; atomic migration; foreign-key check; enforcement restored and verified); B — 31-node migration bootstrap distinct from the complete approved catalogue (126 / 79 / 33), loaded deterministically without duplicates; C — TRN-020 per-scale database constraints from the authoritative text (RPE 1–10 in 0.5 steps; RIR integers 0–5; no RPE–RIR conversion invented).

### 2026-11-06 — WP 8 stage 3a decisions and acceptance; stage 3b authorised (owner)
- **X1 geometry cut points approved in principle**: bench angle 10°, arm position 20° and 135°, knee angle 10°; a bench tilted 5° head-down is flat. **X1 closes only when the exact inclusive/exclusive boundary texts are recorded** with no gaps or overlaps.
- **X2 IC-412**: the **narrow rule (19 pairs)** — the name-token gate is skipped only when a recorded attribute differs and the load items are equal; pairs documented; positive and negative tests.
- **X3**: wording "Machine back extensions in which the spine itself moves." approved.
- **IC-809**: `regionChest` relabelled **"Chest region"**; stable id and hierarchy unchanged.
- **ED-501**: a functional double-tag violation is an **error for system-supplied content**, never downgraded; user content may be handled differently but must not bypass fundamental domain integrity constraints.
- **Name normalisation**: full Unicode **NFKD** for comparison and duplicate-detection keys, covering Latin, Greek and full-width characters; no new dependency; display names never rewritten; consistent case handling; tests for accented, compatibility, Greek and full-width forms and for no false merges of distinct names.
- **OQ-19 roll-up**: when a primary and a secondary target of one exercise resolve to the same parent group, **only the primary credit is counted at that parent level**; the exercise's target assignments are unchanged (calculation rule only).
- **Release and version fields** for anatomy, movement-pattern and equipment records approved for stage 3c; no schema change in 3a.
- **Stage 3a technical delivery accepted at f2f9e9e**, subject to recording the final X1 boundary wording.
- **Stage 3b authorised**, beginning with the table-rebuild comparison trial (5,000 exercises, 100,000 sets; performance, integrity, crash recovery). Mandatory before the migration is finalised or committed: trial documented and returned to the owner; value equality; crash recovery; foreign-key integrity; migration from every supported schema; backup formats 1–3; independent review.

### 2026-11-06 — WP 8 stage 3b approach decisions; letter folds; X1 precedence (owner)
- **Comparison trial** (77b1d4c): the owner accepts it as evidence for the approach, not as acceptance of the migration.
- **`exercises`:** option A, table rebuild, is the canonical path. The owner rejects B3 if it leaves a definition different from a fresh install.
- **TRN-020:** rebuild `session_sets`; the table definition enforces the RPE and RIR rules. The migration keeps valid values. It reports and quarantines invalid legacy values and never silently rounds or corrects them.
- **Foreign keys:**
  - The migration checks the affected tables and relationships, including exercise and set references.
  - The test campaign adds a full `foreign_key_check` and `integrity_check`.
  - A whole-database check is not the only startup gate where unrelated existing damage could block access unnecessarily.
  - The report shows any broader failure separately and never ignores it silently.
- **No primary target:** block and report. No placeholder and no blanket legacy exception. The report lists every affected exercise id and its current data. Acceptance needs an explicit, reviewed disposition for every affected record.
- **Migration report:**
  - Minimum categories: migrated successfully; preserved unchanged; quarantined or unresolved; rejected or blocked; warnings requiring review.
  - Each record shows stable id, original value, field, reason and disposition. Counts reconcile.
  - The owner has not approved detailed labels.
- **Schema version 8:** the migration writes it inside its transaction. It becomes visible only after all work and checks succeed. A rollback leaves version 7.
- **Backup v3:**
  - A complete, self-consistent contract with user, reference and catalogue data, stable ids and relationships.
  - It states its format and schema version. Restore validates it before changing anything.
  - Restore is atomic and keeps the reference tables. It supports formats 1 to 3. A version 7 backup never fails part-way.
  - A settings-only backup stays valid; a structurally empty one stays invalid.
- **Versions 2 to 6:** frozen schemas and representative fixtures are required evidence. They prove each supported upgrade path, including the known version 5 to 6 incompatibility. Nobody rewrites them.
- **Device timing** is an acceptance condition. It uses representative Android and iOS devices, the bundled SQLite and realistic data. Records give device, OS, database size, elapsed time and outcome.
- **Implementation latitude:** the team chooses SQL and mechanics, subject to independent review.
  - It invents and weakens no domain rule, and keeps the accepted TRN-020 semantics.
  - It transforms no legacy value silently.
  - It documents every backup and restore assumption for owner approval.
- **Name keys:** fold `ø`→`o`, `đ`→`d`, `ł`→`l`, `æ`→`ae`, `œ`→`oe`, both cases, in comparison and duplicate keys only. Other letters stay distinct; no general transliteration.
- **X1:** the owner approves both precedence rules. Elbow and floor are no longer mandatory conditions; "typically" fits where they are descriptive. The exact thresholds and inclusive or exclusive wording must be visible in the decision record. The precedence rules must be unambiguous at boundary cases. X1 stays open until the owner signs off the table and boundary cases in `delivery-record/WP8.md`.
- **Stage 3b acceptance** needs:
  - evidence for upgrades from versions 1 to 6 and for backup formats 1 to 3;
  - recovery after a real process kill;
  - restore that keeps the reference tables;
  - device timing and independent review.
- **Migration:** stays unimplemented until the project resolves the remaining evidence and the disposition of all 303 records.

### 2026-11-06 — WP 8 stage 3b implementation authorised; disposition of exercises with no primary target (owner)
- **Implementation authorised:** build the v8 migration and its evidence on the branch. Schema version 8 appears only in isolated tests and migration fixtures.
  - The production schema version stays 7 until the owner explicitly accepts stage 3b.
  - This authorises implementation and testing, not release or production migration.
  - The migration stays behind the version 7 production gate. It does not ship active.
  - A passing test suite is not stage 3b acceptance.
- **Exercises with no primary target:** block each affected exercise individually. Never fail the whole migration or lock the user out.
  - Keep its stable id, original data and all historical references.
  - Mark it blocked: unavailable for normal selection and new workout planning.
  - Keep historical workout and session records readable and intact.
  - The migration report gives its id, original target state and reason.
  - Create no placeholder target and infer no anatomical target.
  - Provide a route to correct the record later without rewriting historical sessions.
  - This is a disposition for invalid legacy records, not a relaxed rule. New or imported system exercises still need a primary target.
  - Stage 3b acceptance verifies that blocked records cannot enter new workouts, while their history stays accessible and consistent.
- **CI:** CI on 77b1d4c does not substitute for CI on 52cbdef.
- **X1:** not signed off. The owner asked for the exact table, ordered checks and boundary inclusivity in the conversation.

### 2026-11-06 — X1 closed (owner)
- The owner signed off the X1 classification table and boundary cases in `delivery-record/WP8.md`.
- Bench −10° and +10° are flat; incline starts above +10°. A bench 5° head-down is flat.
- Knee 10° is straight; bent starts above 10°.
- An arm at exactly 20° is `besideBody`, behind the trunk included; `behindBody` starts above 20°.
- `supportedInFront` wins over every other valid arm value; invalid angles stay invalid. `behindBody` is checked before `overhead`.
- Values outside the valid ranges get no classification. The classifiers never clamp them.
- Authorised follow-up: align `coverage.json` and `coverage-matrix.md` with the approved wording and remove the superseded elbow conditions. Thresholds and classifier stay unchanged.
- The owner closes X1 against the current decision and implementation evidence. This is not stage 3b acceptance.

### 2026-11-06 — WP 8 stage 3b plan approved; report, restore, integrity, attributes, device timing (owner)
- **Plan:** the owner approved the staged plan (3b-1 to 3b-10) and the isolated version 8 schema.
  - 3b-2 defines the version 8 schema but never connects it to the app.
  - 3b-4 never repairs legacy data silently.
  - The production switch is a separate change that needs explicit owner authorisation after stage 3b acceptance.
- **Analyzer incident (ede7808, fixed in b22224e):** a process failure. The delivery record keeps the finding and the fix traceable. History stays unchanged.
- **Report detail:**
  - Each quarantined, blocked, rejected, changed or exceptional record gets its own row: stable id, field, original value, reason, disposition.
  - Clean records appear only as reconciled counts by table and outcome.
  - The report states records examined, migrated cleanly, preserved, blocked, quarantined and rejected. Counts reconcile to the input.
  - A secondary suppressed by the OQ-19 roll-up rule is normal handling, not a warning. Target assignments stay preserved.
- **Restore conflicts:** device wins for reference data.
  - Restore inserts missing reference rows from the backup and overwrites no existing device row.
  - The same stable id with conflicting immutable content is reported, and the restore fails atomically.
  - Restore merges migration report history and never replaces it. Stable event ids prevent duplicates on repeated restores. Each report keeps its provenance and timestamp.
- **3b check scope:** stage 3b verifies blocking and reporting at the domain, data and use-case layers.
  - Blocked exercises cannot be selected for new work through the use cases.
  - Workout and session history stays readable.
  - The report lists each blocked exercise with stable id and reason.
  - The correction route leaves historical sessions unchanged.
  - Screen checks, including Settings › Data, move to 3d or the production-switch campaign. Data-layer tests are not evidence that the UI is complete.
- **Damaged database at upgrade:** if `quick_check` fails before migration, the migration stops.
  - No version 8 migration, no version 8 written, no record changed or quarantined.
  - The app reports the integrity failure and shows the recovery and backup route.
  - The original database stays intact for diagnosis.
  - The app stays on its version 7 path where safe. It never promises normal operation on a damaged database.
- **Attributes and equipment roles:** version 8 includes them now.
  - Each single-valued, stable attribute is a typed column on the exercise.
  - Equipment roles sit on each exercise-to-equipment association.
  - Before 3b-2, ADR-0008 states each attribute's exact name, type, values, nullability and validation. A multi-valued or extensible attribute gets its own model.
  - Nothing is inferred or invented: the schema follows the approved catalogue contract.
- **Device timing:** one mid-range Android phone and one supported iPhone, with recorded specifications. This is platform evidence, not universal compatibility.
  - Data: 5,000 exercises, 100,000 sets, the full reference bootstrap, the 303 synthetic no-primary exercises, a representative report and user data.
  - At least three runs per device from an identical restored start. Record median and worst duration, model, OS, SQLite version, database size and outcome.
  - Include a normal run and a recovery or retry run.
  - The profile is a stress profile. Any material difference from the real production profile is recorded.
- **Structural identity:** the migrated version 8 schema must equal a fresh version 8 database structurally: tables, indexes, triggers, constraints and foreign keys.
- **Sub-stage authorisation:** 3b-1, 3b-3 and 3b-4 proceed. 3b-2 proceeds once ADR-0008 makes the attributes and equipment roles explicit. 3b-5 to 3b-9 are mandatory acceptance evidence. 3b-10 needs independent review, four green CI workflows, a complete record and owner acceptance.
- **Production schema** stays version 7 throughout.

### 2026-11-06 — ADR-0008 clarification approved; 3b-1 accepted as foundation (owner)
- **ADR-0008 clarification approved** with decisions on Q1 to Q16 (ADR-0008, section E). Key points:
  - The seven attribute value lists are schema contracts; a change needs a new schema version.
  - NULL means no recorded or applicable value; nothing infers a value or reads NULL as "not applicable".
  - Overrides only to `load` or `support`, never on `cardio` or `implement` items; the note is internal and required.
  - Default equipment roles are immutable. A changed meaning needs a new equipment id.
  - An exercise with unknown equipment is blocked individually and never becomes newly visible.
  - `equipment_json` is dropped after a successful copy. Quarantine keeps the original only where conversion is incomplete.
  - Equipment class and lifecycle wait for stage 3c.
  - Version 3 restore: device wins; an invalid value rejects the whole restore.
  - Custom copies copy equipment links, attributes and overrides as values.
- **3b-1 accepted** as the required historical test foundation. The fixtures stay immutable and the manifest hash check stays.
- **3b-3** continues independently. **3b-2** starts after the ADR-0008 commit, with a version 8 schema that reflects these decisions.
- Production stays at schema version 7, with no connection to the version 8 database. Stage 3b acceptance keeps all agreed gates.

### 2026-11-06 — WP 8 3b-3 complete; 3b-2 rules (owner)
- **3b-3 complete at 31f7652.** The delivery record keeps the independent review, both re-checks and the test evidence.
- Coverage (93.3 %) is supporting evidence only. It never replaces the migration acceptance tests.
- **3b-2 proceeds** under these rules:
  - Implement version 8 strictly against the approved ADR-0008 decisions.
  - Version 7 stays the immutable production baseline. No app connection, no production database change, no schema version advance.
  - Frozen v1–v7 snapshots, migration steps and locked manifests stay unchanged.
  - Ambiguities are never resolved silently. An assumption register records each: decision, sources, alternatives, recommendation, implications, and whether it blocks.
  - A choice that materially affects the schema, migration behaviour, data integrity or compatibility stops for owner approval.
  - Independent review checks every applicable ADR-0008 decision, v7 unchanged, frozen evidence intact, and schema comparison with reproducible tests.
- **Stage 3b overall is not accepted.** The remaining gates stay: migration and report, crash and process-kill tests, backup, blocked records, device timing, CI and independent review.

### 2026-11-06 — WP 8 3B-ACC-01 accelerated stage 3b campaign authorised (owner)
- **Authorised:** coordinated parallel workstreams WS1–WS6 (schema, migration engine, backup and restore, integrity and report, recovery and performance, domain and use cases). Agents may implement, integrate, test, review and commit isolated version 8 work in reviewable increments.
- **Not authorised:** production schema version 8, app connection to version 8, production migration rollout, stage 3b acceptance, or any domain-rule change without owner approval.
- **Hard constraints:** frozen fixtures and manifests immutable; all v1–v7 paths tested; fresh and migrated v8 schemas structurally identical; no silent deletion, inference, rounding or correction; material assumptions resolved through owner approval, never by inference.
- **Required behaviours:** the owner's scenario table (clean v7 migrates; failed integrity stays v7; no-primary and unknown-equipment exercises blocked individually; duplicate equipment ids reported; invalid TRN-020 values preserved and reported; restore conflicts rejected atomically; missing reference rows inserted only; crash leaves v7 or full v8; repeat migration writes nothing twice; v7 and settings-only backups restore; empty backups rejected).
- **Reviews:** A (schema and contracts), B (migration and compatibility), C (integrated release candidate). Reviewers inspect diffs and tests. High and Medium findings are fixed and re-checked; Low findings get a recorded disposition.
- **Never rushed:** v1–v7 compatibility on frozen fixtures; real process termination; real-device timing. Anything not completed stays outstanding, never "passed".
- **Handback:** the complete evidence package listed by the owner. Stage 3b stays unaccepted until the owner accepts it explicitly.

### 2026-11-06 — WP 8 3b-2 register R-01 to R-11 approved; 3b-4 authorised (owner)
- **R-01 Block key:** one row per exercise and blocking reason. Each reason is recorded and resolved independently. An exercise can have several active reasons. Resolving one reason never unblocks it while another stays active.
- **R-02:** a separate reason code `invalidEquipment`, distinct from `unknownEquipment`.
- **R-03:** the report gains the action `blocked`.
- **R-04 Reconciliation:** four mutually exclusive record outcomes sum to the records examined. Every examined record belongs to exactly one outcome. Warnings are additional counts. They may reference records in any outcome and never inflate the total.
- **R-05 Category codes:** five stored codes, persistent internal identifiers, never editable display text: `migrated` (migrated successfully), `preserved` (preserved unchanged), `quarantinedOrUnresolved` (quarantined or unresolved), `rejectedOrBlocked` (rejected or blocked), `warningForReview` (warnings requiring review). A later change needs an explicit compatibility decision. Display labels are decided separately.
- **R-06 Original values:** one JSON text encoding contract. It keeps SQL NULL, JSON null, strings and numbers distinct, and never collapses any of them into an empty string.
- **R-07 Event ids:** deterministic from run id, table, record id, field, position and rule. A resumed migration reuses its original run id. A genuinely new attempt gets a new run id.
- **R-08 Provenance:** structured: source device or backup, app version and merge time.
- **R-09 Bootstrap provider:** template values; attribution stays empty until stage 3c.
- **R-10 Release 1:** hash the exact bundled seed-file bytes with the project's established convention (SHA-256, lowercase hex). The release record states the algorithm and encoding. Nothing hashes a re-serialised form.
- **R-11 Secondary order:** contiguous and deterministic, as IC-309 requires. A removed or rejected entry leaves no gap.
- **3b-4 authorised** once these decisions are recorded. All earlier safeguards stay: production schema 7, atomic migration, invalid records kept and reported, blocked history kept, full reconciliation, crash recovery and backup compatibility, independent review. Stage 3b stays unaccepted.

### 2026-11-06 — WP 8 3b-2 register R-12, R-14, R-15, R-19 to R-24 decided; 3c deferrals (owner)
- **R-12 Foreign keys (mixed):**
  - Catalogue relationships get foreign keys: provider links, movement-pattern links and exercise-name records.
  - Exercise-owned child records with no independent lifecycle use `ON DELETE CASCADE`.
  - User exercise state gets no database key. IC-902 stays a reported check, like plan exercises.
  - A referenced catalogue record cannot be deleted. Exercise retirement never deletes workout or session history.
  - Tests cover cascades explicitly, including an exercise with several child records.
  - IC-902 names orphaned user-state records by stable id with actionable diagnostics. A missing key never permits ignoring an integrity failure.
- **R-20 Default-role immutability (application enforcement):** the release reconciler, backup restore validation and explicit conflict detection against the existing item enforce it. A conflicting role rejects the whole restore atomically. No trigger. Tests show that neither a later release nor a restore can silently change a default role.
- **R-14:** every system exercise needs a provider and a revision; a database constraint enforces it.
- **R-15:** `source` has no default; every insert states it.
- **R-22:** an override note may exist without an override.
- **R-23:** an existing device reference row wins silently during the version 8 migration.
- **R-24:** `archived` stays beside the retirement date; user archiving and catalogue retirement are distinct states.
- **R-19:** already resolved: overrides apply to load and support only, enforced in the domain.
- **Deferred to stage 3c (requirements, not forgotten):** R-13 release columns on anatomy, patterns and equipment; R-16 relationships table; R-17 content table and body-length rule; R-18 media table; R-21 reference lifecycle and creation times. They must not enter version 8 now, and the version 8 design must not prevent them later.
- **Device timing:** mandatory acceptance evidence. The harness may be completed now; real runs stay outstanding until performed on physical Android and iOS devices. Records give device model and hardware, OS version, SQLite version, database size and record counts, durations across repeated runs, outcome and errors.
- R-12 and R-20 may now be implemented. Stage 3b stays unaccepted.

### 2026-11-06 — WP 8 3b-7 backup decisions B-03, B-04, B-08, B-09; WS3 high finding (owner)
- **B-03:** keep the device's quarantine rows on a device-wins restore (option b). Quarantine records are part of the device's migration history. Restore inserts the backup's rows, renumbers colliding ids and rewrites the merged report links.
- **B-04:** the immutable reference field list implemented by WS3 is normative. Neither a restore nor a catalogue update may silently change reference identity or structural relationships.
- **B-08:** only user tables and user or imported exercises count as user data. A catalogue-only backup is never an instruction to wipe user data.
- **B-09:** a backup with unknown parts is rejected atomically. Nothing ignores unrecognised content silently.
- **WS3 H1 (release blocker):** every restored exercise is validated against database constraints and domain invariants. A system exercise without a valid primary target is rejected. Any failing exercise rejects the whole restore; no partial row, catalogue change or selectable invalid exercise survives. The malformed backups join the regression suite. Q15 applies to domain-invalid values, not only malformed SQL values.
- **WS3 closure evidence:** H1 fixed; four Medium findings resolved and independently re-checked; B-03 tested with migration-report links intact; B-04 documented and tested; B-08 and B-09 tested; existing equivalence, atomicity and device-wins evidence retained; full regression and four green CI workflows.
- Strong existing evidence does not offset the domain-validation defect. The Medium fixes are not accepted merely because the High issue is resolved. WS3 stays open until the corrected work passes independent review.
- B-01, B-02 and B-07 (with R-30) stay open.

### 2026-11-06 — WP 8 3b-7 B-15 (conditional) and B-16 decided (owner)
- **B-15 (accepted, conditional on the independent re-check):**
  - **Format 3:** full domain validation for every exercise. Catalogue completeness rules (author, description and similar) are excluded. A user exercise without a primary target is allowed only while explicitly blocked. No other domain rule is weakened.
  - **Formats 1 and 2:** the per-exercise migration blocking stays. A system exercise without a valid primary target is rejected. Rejection is not broadened to other legacy id-format violations without evidence that the migration cannot handle them safely.
  - **Condition:** the re-check must confirm that the migration itself does not introduce the same IC-101 problem. If it does, work stops and the inconsistency is resolved before B-15 is accepted.
- **B-16 (accepted limitation):** the single-outcome-per-table report contract stays. WS3 adds no complexity for it. The limitation is recorded and revisited with the 3d report screen.
- **WS3 closes only when:** B-15's migration id behaviour is verified; the conditional boundary is implemented and tested; B-16 is recorded; the final independent review confirms all fixes; the complete regression suite passes. The final WS3 report separates verified fixes, accepted limitations and outstanding risks, and never presents the work as complete while a criterion is unresolved.

### 2026-11-06 — WP 8 stage 3b decision baseline: 13 decisions approved; 3b effort allocation approved (owner)
- **R-30 / B-07 (option b):** release 1 is recorded only when the bundled file matches the exact known v7-era hash. An unknown or mismatched hash is reported and creates no record. Counts stay empty, never 0. Install-time provenance is explicit. Restored v7 backups follow the same rule.
- **B-01 (field-level ownership):** catalogue fields: device wins; user fields: backup wins. A different system/user classification between device and backup never rejects the whole restore by itself. The 12 identified combinations get explicit regression coverage; the ownership rules decide the outcome.
- **B-02:** a reused report event id with different content is an integrity violation; the whole restore is rejected atomically.
- **Unreadable data:** an exercise with unreadable secondary muscles, type, category or aliases is blocked individually. Restoration never makes hidden information newly visible.
- **C-1:** the report gains the action `corrected` and the trigger kind `userCorrection`.
- **R-C4:** one equipment correction clears both equipment block reasons. **R-C8:** retired exercises stay usable in new work and are excluded from discovery.
- **R-28:** invalid exertion pairs are cleared and quarantined. **R-31:** earlier damage is reported separately and never blocks. **R-32:** a crashed run keeps its run id, bound to the database file and app version. **R-33:** pre-v8 quarantine rows count as retained and are excluded from this run's quarantine total.
- **Block-row rule codes:** IC-204 (no primary target), ADR-0008-Q12 (unknown equipment), R-02 (invalid equipment).
- **3b effort allocation approved (4.50 points):** 3b-1 0.50, 3b-2 0.50, 3b-3 0.50, 3b-4 0.75, 3b-5 0.25, 3b-6 0.40, 3b-7 0.60, 3b-8 0.40, 3b-9 0.30, 3b-10 0.30. The 70/20/10 rule governs earned credit: 70 % commit, 20 % independent review, 10 % owner acceptance. A commit alone never earns review or acceptance credit. Approving a decision earns no credit.
- **Not acceptance of 3b.** 3b stays unaccepted until: all approved decisions are implemented; WS3 closes with its re-check passed; B-15 is resolved with evidence; device timing passes on both platforms; Review C passes; four CI workflows pass; the delivery records hold the complete evidence trail.
- These 13 decisions are not reopened without new contradictory evidence.

### 2026-11-07 — Train workspace redesign and exercise knowledge system: allocation (owner)
- **Integration baseline:** the clean release candidate (`claude/busy-hypatia-rhl3hu`, clean base aa59021). It holds accepted WP 15/WP 17 work and no WP 8 3b code.
- **Isolation:** branch `ccr-9fda2c32-wr163b` stays isolated. Nobody merges, cherry-picks or otherwise brings its 3b commits into the release candidate. OB-WP8-04 stays open until the owner decides.
- **Allocation:**
  - **Exercise knowledge system:** the WP 8 session, on a separate clean branch without 3b code (content architecture, instructions, media, catalogue population, offline support).
  - **Train dashboard redesign, filter-chip design-system correction, integration and regression testing:** the other (integration) session, on the release candidate.
- **Rules:**
  - The other session acknowledges the allocation before proceeding.
  - No duplicate implementation.
  - Independent review of all work.
  - No merge to main.
  - Source commit ancestry is checked before any release-candidate integration.
  - Four CI workflows rerun on the integrated commit.
- **Handover:** the WP 8 session pushes only to its own clean branch, never merges into the release candidate, and hands over commit SHAs, changed files, tests, review findings and outstanding work.

### 2026-11-07 — Exercise knowledge base branch; Train UX handover contingency (owner; supersedes the base in the entry above)
- **Base branch:** `claude/campaign-2026-11-07` is the exercise-knowledge baseline. The owner withdraws the earlier strict aa59021 base.
  - The handover demonstrates ancestry from aa59021 and shows no WP 8 3b commits or migration code.
  - The stage 3c catalogue release format is canonical. The knowledge system extends it and adds no competing exercise-reference format.
  - Compatibility with the existing catalogue and offline behaviour stays.
- **Train dashboard and filter-chip correction:** the WP 8 session prepares its locally started work as a reviewed commit series for handover, if the other session does not implement it.
  - The other session confirms implementation responsibility, or accepts the handover. It then reviews independently, integrates into its clean campaign branch, and runs regression and emulator tests.
  - The WP 8 session never merges into the release candidate itself. Started work is not discarded.
- **Push permission:** the WP 8 session may push independently reviewed exercise-knowledge work to `claude/exercise-knowledge-2026-11-07`, with:
  - no 3b ancestry or code;
  - complete test evidence;
  - the relationship to the 3c format documented;
  - no direct merge into the release candidate.
- **Responsibility matrix:**

  | Deliverable | Responsibility |
  |---|---|
  | Exercise knowledge architecture, content, imagery and instructions, offline references | WP 8 session |
  | Train dashboard and filter-chip correction | Other session, or the WP 8 session's reviewed handover |
  | Final integration | Campaign integration authority |
  | WP 8 3b | Isolated |
  | Merge to main | Owner approval required |

### 2026-11-07 — B-15 condition failed (re-check evidence); owner decision pending
Recorded by the WP 8 session from the re-check evidence. This entry states facts and the question put to the owner; it is **not** an owner decision.
- **The condition of B-15 (2026-11-06) is not met.** The re-check asked whether the migration itself introduces the IC-101 problem. It does:
  - Frozen fixtures v2–v5 hold the custom exercise `ex-bench` as a pre-v6 row with `is_custom` 0. The frozen v6 step maps it to supplied, and the v7 → v8 migration stores it as a **system** exercise (`source` system, provider `repforge`) with a non-catalogue id. That id fails IC-101 (catalogue id format).
  - On the migrated device the row is **selectable** (not blocked) and the migration report has **no entry** for it (no IC-101 entry anywhere in the run).
  - The same device's format 3 export is **rejected on another device** (IC-101, "Nothing was changed"); fixtures v1, v6 and v7 round-trip.
  - Evidence: Review C probes P1 and P4, re-run 2026-11-07 on 2ba5881 (`docs/delivery-record/WP8.md`, 3b-7 section).
- **Consequences:** B-15 stays **unaccepted**. WS3 (3b-7) stays **open**. The implemented boundary is unchanged: format 3 rejects IC-101; formats 1 and 2 keep the migration's blocking.
- **Options put to the owner:**
  - **(a)** Block such exercises at migration (a block reason for a non-catalogue system id). They are then not selectable, and they need a correction route (none exists for system exercises today: `docs/v8-library-use-cases.md` R-C9).
  - **(b)** Keep them as labelled legacy ids. The migration reports one `warningForReview` IC-101 entry per such exercise. A format 3 restore exempts IC-101 **only** when the backup's own report history holds that entry for that exercise.
  - **(c)** Accept that such devices have no cross-device format 3 restore (record as a limitation).
- **Recommendation (WP 8 session): (b).** It keeps the user's data usable, makes the migration report complete, and limits the exemption to rows the migration itself recorded.
- Nothing is implemented for (a), (b) or (c) until the owner decides.
