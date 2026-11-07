# RepForge — Application Test and Acceptance Pack

**Document status:** `[ ] Draft  [x] In execution  [ ] Completed`  
**Application:** RepForge (Flutter), version `0.4.0+1` (`app/pubspec.yaml`)  
**Prepared:** 2026-11-07 from the repository records named in Part 10  
**Product Owner:** kreczmans-creator (repository owner)  
**Record location:** `docs/testing/REPFORGE-APPLICATION-ACCEPTANCE.md`

This document is the formal acceptance instrument for the RepForge application release. The Product Owner works through it, enters decisions and test outcomes, attaches evidence references, and saves the completed file in the repository. Nothing in it is pre-decided: every decision field is blank, every test outcome is unset, and every gate is open until the owner records otherwise.

## How to use this document

1. Work through the parts in order. Part 2 (decisions) comes before testing because several tests and gates depend on the scope the owner approves there.
2. Tick exactly one option per decision or outcome by replacing `[ ]` with `[x]`. Replace every `[enter …]` placeholder with your text, or with `n/a`.
3. Cite evidence by a stable reference: a commit hash, a GitHub Actions run id, a screenshot or log file committed under `docs/testing/evidence/`, or a record section. Do not cite a conversation.
4. Raise a defect for every FAIL in the Part 6 register and reference its id (`DEF-nnn`) from the test.
5. A gate in Part 7 may be marked **Satisfied** only when every item it depends on is PASS or has an approved deviation. A BLOCKED or NOT TESTED item leaves its gate **Open**.
6. Commit the completed document with a message that names the acceptance date. The commit is the acceptance record; the signature fields in Part 8 are the authorisation.

Vocabulary used throughout:

| Term | Meaning in this document |
|---|---|
| Implemented | Code is on the named commit and its tests pass. Says nothing about review or acceptance. |
| Reviewed | An independent review (separate agent or person, fresh context) exists with every High and Medium finding dispositioned. |
| Accepted | The Product Owner has recorded acceptance in this document or in the work-package record. |
| Proposed allocation | An effort-point figure a delivery agent proposed; it earns nothing until the owner approves it (governance standard `docs/governance/effort-points-and-progress-reporting.md`, section 5). |
| Earned | Points recorded against an approved allocation on the strength of evidence. |
| REQUIRES OWNER CONFIRMATION | The repository records do not establish the status; the owner must state it. |

**Accepting a work package is not accepting the release.** Accepting WP 8 stage 3b, WP 15 or WP 17 individually (Part 2) records that package's status only. The application release is accepted solely by the declaration in Part 8, after the gates in Part 7.

## Table of contents

- Part 1 — Authoritative position of the repository (facts, no decisions)
- Part 2 — Product Owner decision register (2A WP 8 stage 3b · 2B WP 15 · 2C WP 17 · 2D programme and release governance · 2E other open register items)
- Part 3 — Application testing programme (18 sections)
- Part 4 — Automated verification evidence (two separate baselines plus the integration branch)
- Part 5 — Physical-device testing record
- Part 6 — Defect, limitation and deviation register
- Part 7 — Final acceptance gates G1–G10
- Part 8 — Formal acceptance declaration
- Part 9 — Reconciliation: items that could not be verified, and conflicts between records
- Part 10 — Source records used

## Part 1 — Authoritative position of the repository

Facts established from the repository on 2026-11-07 (commands in Part 10). This part records; it decides nothing. Where the owner knows a different position, record it in Part 2D-4 (authoritative integration branch) rather than editing this part.

### 1.1 Branches and commits

| Item | Value | How established |
|---|---|---|
| Integration branch (campaign 2) | `claude/campaign-2026-11-07`, HEAD `28b67b3` (2026-11-07 03:34 UTC) | `git log -1 origin/claude/campaign-2026-11-07` |
| Release candidate | The head of `claude/campaign-2026-11-07` that carries the campaign-2 morning report; its `app/` tree is byte-identical to `d5af42c` (full local gate), `81b77ff` (CI, iOS, Integration green) and `b27ec18` (Android green). Every commit after `b27ec18` is documentation. | `git diff --stat b27ec18 28b67b3 -- app` is empty |
| Campaign-1 release candidate (preserved) | `aa59021` on `claude/busy-hypatia-rhl3hu` (branch head `391fe1b`, docs only) | `git merge-base --is-ancestor aa59021 28b67b3` holds |
| `main` | `c6d380f` = the owner's merge of pull request kreczmans-creator/repforge#5 (branch `ccr-9fda2c32-wr163b` at `c636a06`), 2026-11-06 21:06 | `git log -1 origin/main`; `c6d380f` is an ancestor of `28b67b3` (120 commits ahead), so a fast-forward of `main` is possible |
| WP 8 stage 3b session branch | `ccr-9fda2c32-wr163b`, HEAD `f3a12a4` (CI record), code commit `ac14711` | `git log -1 origin/ccr-9fda2c32-wr163b`; **not** an ancestor of the integration branch |
| WP 15 / WP 17 implementation branch (frozen) | `claude/repforge-parallel-implementation-flyjqw`, code HEAD `ded976b`, records HEAD `43aa667` | both are ancestors of the integration branch (`ded976b` merged at `cee71dd` in campaign 1; the records head `43aa667` merged at `6187c37` in campaign 2); neither is in `main` |
| Exercise-knowledge branch (WP 8 session, after the campaign freeze) | `claude/exercise-knowledge-2026-11-07`, HEAD `ffd6d14` (base `0df5d66`) | not integrated; listed in Part 2A-9 |
| Production schema | version 7 (`AppDatabase.schemaVersion`); the schema v8 definition and the v7→v8 migration exist in the isolated `lib/data/db/v8` zone and are not connected | `app/lib/data/db/app_database.dart`; architecture tests `test/architecture/schema_v8_isolation_test.dart`, `migration_isolation_test.dart` |

### 1.2 Two stage 3b code lines, kept distinct

| Line | Commits | Where it is | What it is |
|---|---|---|---|
| Earlier isolated schema v8 work | `2ba3997` (v8 definition), `e57834e` (v7→v8 migration), WP 8 branch up to `c636a06` (the commit `main` merged in pull request #5); the two documentation commits after it (`2cc7f91`, `5f1192e`: B-15 conditional acceptance text and the 2026-11-06 decision baseline) are in `aa59021` and the integration branch but not in `main` | code in `main`, `aa59021` and the integration branch | Isolated, not connected, not accepted. Its presence in `main` is **not** evidence that stage 3b is integrated or accepted (Part 9, C-1). |
| Later stage 3b implementation | `163ce4a` (decision baseline), `5e37008` (WS3 backup format 3), `38bdf6d` (3b-9 harness), `ac14711` (Review C fixes), `f3a12a4` (CI record) | only on `ccr-9fda2c32-wr163b` | Reviewed by that session; **not integrated** into the integration branch or `main`; stage 3b **not accepted** (WP 8 record, "Stage 3b status"). |

### 1.3 Implemented application functionality (integration branch, `28b67b3`)

Routes from `app/lib/app/router.dart`; features under `app/lib/features/`.

| Area | Screens / routes | Owning work packages |
|---|---|---|
| Dashboard | `/home` (today summary, latest weight, recent activity) | WP 4–6, WP 10 |
| Train | `/train`, plans (`/train/plans`, new, detail), splits (new, detail), schedule, session (`/train/session/:id`), history (list, detail), exercises (new, detail, edit, copy) | WP 7, WP 9, WP 17 S4 |
| Fuel | `/fuel`, search (pick mode), new food, barcode scan, week summary, saved meals (pick mode), recipes (list, new, detail, edit, pick mode), meal plan | WP 5, WP 15, WP 17 S3 |
| Track | `/track`, entry, unreadable records, progress, per-site (`/track/site/:site`), compare | WP 10 |
| Goals | `/goals`, edit per kind, history, weekly summary, period comparison, recomposition, training analytics (and `/goals/training/exercise/:id`) | WP 11 (stages A, B, C, D1, E, F non-muscle, G1 computation) |
| Settings | `/settings` (units, day start, week start, daily targets with implied-energy line), backup (`/settings/backup`: export/import, measurements CSV), owner actions (`/settings/owner-actions`, detail) | WP 4, WP 10, WP 14, campaign workspace |
| Gallery | `/gallery` (design-system gallery; development aid) | WP 2 |

Not implemented or not connected (do not test as if present): WP 11 D2 per-muscle figures; WP 17 S3b-ii frequent foods and quantity pre-fill; WP 17 S4d rest-timer survival across process death; WP 17 S5/S6 catalogue content, recipe tags and images; WP 15 custom-food serving-definition entry units; WP 12 accounts/sync; WP 13 health platforms; the v7→v8 migration (stage 3b); release signing (secrets not provisioned).

### 1.4 Existing test registers and validation records

| Record | Path |
|---|---|
| Campaign-2 morning report and ledger (release candidate, CI, APK, reviews) | `docs/verification/overnight-campaign-2026-11-07.md` |
| Campaign-1 morning report (release candidate `aa59021`, cross-package review D-01..D-08) | `docs/verification/overnight-campaign-2026-11-06.md` |
| Parallel-workstream assessment (WP 15 / WP 17 decisions D-1..D-7) | `docs/verification/parallel-workstream-assessment-2026-11-06.md` |
| Device checklist (WP 6) | `docs/verification/wp6-device-checklist.md` |
| Device timing procedure (WP 8 3b-9) | `docs/device-timing.md` |
| System check | `docs/verification/system-check-2026-11-03.md` |
| Delivery records | `docs/delivery-record/WP0.md` … `WP17.md` (WP 8, 11, 14, 15, 17 active) |
| Programme snapshots | `docs/governance/programme-progress-2026-11-07.md`, `-2026-11-07b.md` |
| Owner Actions register (canonical, in-app) | `app/lib/domain/delivery/owner_blocker_register.dart` (41 entries, all `open` or `awaitingOwner` at `28b67b3`) |
| Requirements baseline | `docs/wp0/D04-product-requirements-baseline.md`; roadmap `D06`; CI strategy `D07`; migration and recovery `D08` |

## Part 2 — Product Owner decision register

Every decision below is blank for the owner. "Recorded position" states what the repository records say as of 2026-11-07 (with the commit the statement was read at); it is context, not a choice. Where a record carries a recommendation, it is attributed to its author (a delivery or review agent) and is not the owner's. Where the records establish that a decision was already taken, the entry says so and asks only for confirmation of the evidence. Existing decision ids (B-15, R-34, C-10, D-3, OB-…) are preserved; this document adds its own ids `2A-n` … `2E-n` for cross-reference only.

Decision template fields: Reference · Description · Context and rationale (recorded position, evidence) · Options · Recommendation (if recorded) · Consequences · Owner's decision · Owner's rationale · Conditions / follow-up · Decision date · Resulting status.

---

### 2A — WP 8, stage 3b

Source branch for all 2A engineering facts: `ccr-9fda2c32-wr163b` at `f3a12a4` (records) and `ac14711` (code). None of these commits is in the integration branch or `main` (Part 1.2). Stage 3b acceptance conditions as the owner set them (D04 §7, 2026-11-06): all approved decisions implemented; WS3 closes with its re-check passed; B-15 resolved with evidence; device timing passes on both platforms; Review C passes; four CI workflows pass; records hold the evidence trail.

#### Decision 2A-1 — B-15: migrated pre-v6 custom exercise ids fail IC-101 (the 2026-11-06 condition failed)

**Reference:** B-15 (D04 §7 entries of 2026-11-06 and 2026-11-07; `docs/backup-format-3.md` register B-15, section 10; `docs/v8-library-use-cases.md` R-C9; WP 8 record "3b-7 … closure status"). Register entry OB-WP8-04.

**Description:** Choose how the v7→v8 migration treats pre-v6 custom exercises that became system rows with non-catalogue ids, so that WS3 (backup format 3) can close.

**Context and rationale (recorded position):** On 2026-11-06 the owner accepted B-15 conditionally: format 3 gets full domain validation per exercise; the condition was that the re-check must confirm the migration itself does not introduce the IC-101 problem, otherwise "work stops and the inconsistency is resolved before B-15 is accepted". The re-check (Review C probes P1 and P4, re-run 2026-11-07 on `2ba5881`) found that it does: frozen fixtures v2–v5 each hold `ex-bench` (pre-v6 custom, `is_custom` 0); the migration stores it as a **system** exercise (`source` system, provider `repforge`, name "Bench Press") with id `ex-bench`, which fails IC-101 (`lib-words-with-hyphens`, at most 48 characters). The row is selectable, the migration report has no entry for it, and the device's own format 3 export is rejected on a fresh device ("This backup conflicts with the data on this device: exercises ex-bench … (IC-101). Nothing was changed."). Fixtures v1, v6, v7 round-trip. The WS5 stress profile (`ex-0000`…) hits the same rejection. Caution: the B-15 options in `backup-format-3.md`'s register row are the older 2026-11-06 options (domain-rule scope); the options below are the 2026-11-07 ones from D04 §7. **The D04 entry states it was recorded by the WP 8 session and is not an owner decision.** Behaviour unchanged pending the decision; WS3 not closed; a test titled `B-15 (pending the owner)` pins the current behaviour.

**Options (as recorded in D04 §7, 2026-11-07):**
- [ ] **(a)** Block such exercises at migration (a block reason for a non-catalogue system id). They are then not selectable and need a correction route; none exists for system exercises today (R-C9).
- [ ] **(b)** Keep them as labelled legacy ids. The migration reports one `warningForReview` IC-101 entry per such exercise. A format 3 restore exempts IC-101 only when the backup's own report history holds that entry for that exercise.
- [ ] **(c)** Accept that such devices have no cross-device format 3 restore; record as a limitation.
- [ ] Request further investigation (state what).
- [ ] Defer decision.

**Recommendation (WP 8 session, not the owner):** (b): "It keeps the user's data usable, makes the migration report complete, and limits the exemption to rows the migration itself recorded." Nothing is implemented for (a), (b) or (c) until the owner decides.

**Consequences:** (a) blocks user data that was usable in v7 and needs a new correction route (R-C9) before release; (b) requires migration and restore code changes inside 3b-4 and 3b-7 (the record says the rework "falls inside 3b-7 and 3b-4"; no points change recorded) and a re-review; (c) leaves a class of users without cross-device restore and the stress profile unrestorable on a fresh device. Under every option the related B-01 field-ownership behaviour (12 of 63 golden-onto-migrated-device combinations rejected, enumerated in `golden_restore_v8_test.dart`) stays as decided. Until decided: WS3 stays open, 3b-7 review credit (0.12) and acceptance credit (0.06) stay withheld, stage 3b cannot be accepted, and OB-WP8-04 keeps every 3b commit out of the release candidate.

**Owner's decision:** `[enter]`  
**Owner's rationale:** `[enter]`  
**Conditions / follow-up:** `[enter]`  
**Decision date:** `[YYYY-MM-DD]`  
**Resulting status:** `[Proposed / Approved / Rejected / Deferred / Superseded]`

#### Decision 2A-2 — B-17: a device with tolerated foreign-key damage exports a backup that restores nowhere (Review C M-3)

**Reference:** B-17 (`docs/backup-format-3.md` register B-17 and section 11; WP 8 record 3b-10 finding M-3; relates to R-31 and B-12).

**Description:** Decide what a format 3 restore does with a backup whose source device carried pre-existing foreign-key damage that the migration tolerated (R-31).

**Context and rationale (recorded position):** R-31 (owner, 2026-11-06) says earlier damage is reported separately and never blocks the migration. B-12 says a backup with damaged declared relationships is rejected atomically. Together: a migrated device with tolerated damage exports a file every v8 restore refuses in phase 1a, the exporting device included ("such a user has no working backup until the damage is gone"). Evidence: reviewer probe P1 re-run 2026-11-07 with `fixture_v2_orphans`, `fixture_v5_orphans`, `fixture_v7_orphans`: each migrates and reports the damage; preview and restore are then refused with foreign-key details. Status: OPEN, owner decision requested 2026-11-07; behaviour unchanged (reject); the register marks it as blocking 3b-7 closure.

**Options (as recorded):**
- [ ] **(a)** Restore and report the damage as R-31 does (an integrity run on the restoring device), at least where the backup's own report history already records it as an R-31 finding.
- [ ] **(b)** Warn at export that the file will not restore anywhere, and say why.
- [ ] **(c)** Keep the current behaviour (reject).
- [ ] Request further investigation.
- [ ] Defer decision.

**Recommendation (WP 8 session register):** (a) limited to damage the backup's own history records as R-31 findings, else B-12; (b) as a minimum if (a) is not taken.

**Consequences:** (a) changes restore code and the B-12 contract for the recorded-damage case and needs tests and re-review inside 3b-7; (b) adds an export-time warning only, leaves the user without a working backup; (c) accepts a documented data-availability gap for users with pre-existing damage. Any choice other than (c) re-opens WS3 implementation before its re-check.

**Owner's decision:** `[enter]`  
**Owner's rationale:** `[enter]`  
**Conditions / follow-up:** `[enter]`  
**Decision date:** `[YYYY-MM-DD]`  
**Resulting status:** `[Proposed / Approved / Rejected / Deferred / Superseded]`

#### Decision 2A-3 — B-18: stress-profile backup exceeds the 50 MiB file-picker cap (Review C M-1)

**Reference:** B-18 (`docs/backup-format-3.md` register B-18 and section 11; WP 8 record 3b-10 M-1).

**Description:** Decide whether and when the production file-picker cap (`maxPickedFileBytes` = 52,428,800 bytes, `lib/domain/files/user_file_gateway.dart`, unchanged) is changed so that very large format 3 backups can be restored.

**Context and rationale (recorded position):** After the Review C fix round (`ac14711`) the stress profile (5,000 exercises, 100,000 sets) exports a compact format 3 file of 55,739,016 bytes (was 84,155,164 pretty-printed), still above the cap. Host-only figures (before → after the fix round): preview 17.1 s / 2,949 MB → 4.5 s / 646 MB; restore onto a fresh device 17.2 s / 2,988 MB → 4.5 s / 683 MB (rejected by IC-101); restore onto the same device 22.7 s / 2,998 MB → 6.8 s / 685 MB. The register states: "Record now; decide at the production switch (3d), with device evidence." Not a 3b decision by the record's own classification; listed here for completeness because it is open.

**Options (as recorded):**
- [ ] Raise the cap at the production switch (3d).
- [ ] Stream the import.
- [ ] Keep the cap and document the limit.
- [ ] Confirm the record's proposal: defer the decision to the production switch, with device evidence.
- [ ] Request further investigation.

**Recommendation (WP 8 session register):** defer to the production switch (3d) with device evidence.

**Consequences:** Raising the cap needs device memory evidence (Part 5) first; streaming is new work in 3d; keeping the cap means a documented ceiling on restorable backup size (LIM-007). None affects the current release (production writes format 2).

**Owner's decision:** `[enter]`  
**Owner's rationale:** `[enter]`  
**Conditions / follow-up:** `[enter]`  
**Decision date:** `[YYYY-MM-DD]`  
**Resulting status:** `[Proposed / Approved / Rejected / Deferred / Superseded]`

#### Decision 2A-4 — R-34: fate of the `seedExercisesVersion` setting after the migration (Review C L-4)

**Reference:** R-34 (`docs/schema-v8.md` register R-34; relates to R-10, R-30 option (b); `docs/backup-format-3.md` B-07; WP 8 record 3b-10 L-4).

**Description:** The delivery plan (§6 step 9) says the v7 setting `seedExercisesVersion` "is read once to decide whether release 1 was applied, then retired"; the implementation keeps it unchanged (R-30 option (b)). Decide which is correct.

**Context and rationale (recorded position):** `V7ToV8Migration._recordRelease1` reads the setting and never writes it; a restored v7 backup's setting decides release 1 the same way (B-07). No behaviour defect; a plan/code discrepancy. Status: "owner decision requested, or defer to 3c" (2026-11-07).

**Options (as recorded in `docs/schema-v8.md`):**
- [ ] **(a)** Keep the setting in v8 (implemented). Consequence: a v8 device keeps a v7 setting that nothing in v8 reads after the migration (dead data, no behaviour).
- [ ] **(b)** Retire it in the migration (delete or mark it after release 1 is decided). Consequence: changes the migrated database and the R-30 text; the restore must still read the backup's setting.
- [ ] **(c)** Retire it in stage 3c, once the reconciler owns the release log.
- [ ] Defer decision.

**Recommendation (register, author not named):** (c), or an explicit owner decision now.

**Consequences:** (b) re-opens 3b-4 evidence (digests change); (a) and (c) leave stage 3b unchanged.

**Owner's decision:** `[enter]`  
**Owner's rationale:** `[enter]`  
**Conditions / follow-up:** `[enter]`  
**Decision date:** `[YYYY-MM-DD]`  
**Resulting status:** `[Proposed / Approved / Rejected / Deferred / Superseded]`

#### Decision 2A-5 — C-10: setting an unreadable exercise type while a plan uses the exercise

**Reference:** C-10 (`docs/v8-library-use-cases.md` C-10, N-6; WP 8 record "Decision baseline implementation", review DB H1).

**Description:** Decide whether the correction `SetClassificationCorrection` may set the type of an exercise blocked for `invalidClassification` while a plan that is not deleted uses that exercise.

**Context and rationale (recorded position):** WP 9's `SaveCustomExercise` refuses a type change while a plan uses the exercise, and `validatePlanExercise(type:)` ties plan targets to type. The correction currently refuses (option (a)), "the most conservative option until the owner decides"; a test pins the refusal (`field: type`, nothing written; a deleted plan does not count).

**Options (as recorded):**
- [ ] **(a)** Refuse while any non-deleted plan uses the exercise (implemented). The user removes the exercise from its plans, corrects it, adds it again.
- [ ] **(b)** Allow when every entry of those plans passes `validatePlanExercise` with the new type; only inconsistent entries block.
- [ ] **(c)** Allow freely (the record says this is not recommended: a plan entry could contradict its exercise).
- [ ] Defer decision.

**Recommendation (register, author not named):** (b), "because the unreadable type is being established, not changed, and (b) keeps every plan entry valid."

**Consequences:** (b) needs a code change and tests in the decision-baseline code (`163ce4a` line) and re-review; (a) is in place; (c) weakens plan validity.

**Owner's decision:** `[enter]`  
**Owner's rationale:** `[enter]`  
**Conditions / follow-up:** `[enter]`  
**Decision date:** `[YYYY-MM-DD]`  
**Resulting status:** `[Proposed / Approved / Rejected / Deferred / Superseded]`

#### Decision 2A-6 — C-11: an unreadable type with mixed-type recorded sets cannot be corrected (owner-visible limitation)

**Reference:** C-11 (`docs/v8-library-use-cases.md` C-11, N-6; raised in re-check R1, 2026-11-06).

**Description:** Acknowledge or reject the limitation: if an exercise's type is unreadable and its recorded sets have several types, no type can be set; the exercise stays blocked and its history stays readable.

**Context and rationale (recorded position):** Cause: WP 9's set-type rule plus "never rewrite history". Frozen v7 data holds mixed-type sets (`ex-long`); "no real exercise with an unreadable type and recorded sets is expected". The record lists no options and no recommendation; it is raised with C-10 for the owner.

**Options:**
- [ ] Accept as a documented limitation (record in Part 6.5).
- [ ] Reject: require a correction route (new scope; state where it belongs).
- [ ] Request further investigation (e.g. frequency in real data).
- [ ] Defer decision.

**Recommendation:** none recorded.

**Consequences:** Accepting adds a limitation to the user-facing documentation of the v8 switch; rejecting adds scope to stage 3b or 3c and re-opens the WP 9 set-type rule.

**Owner's decision:** `[enter]`  
**Owner's rationale:** `[enter]`  
**Conditions / follow-up:** `[enter]`  
**Decision date:** `[YYYY-MM-DD]`  
**Resulting status:** `[Proposed / Approved / Rejected / Deferred / Superseded]`

#### Decision 2A-7 — F3: B-04 immutable-field list versus B-01 field ownership for `exercises.source` / `provider_id`

**Reference:** F3 (WS3 final review item F3; `docs/backup-format-3.md` B-01, B-04, section 10 "Outstanding risks"; WP 8 record 3b-7 closure bullet and blocker list).

**Description:** Confirm that the later owner decision B-01 (field-level ownership: every exercise column except user fields is a catalogue field where the device wins, reported as `retained`, never rejecting) supersedes the earlier B-04 immutable list for the columns `exercises.source` and `exercises.provider_id` (which B-04 made rejecting).

**Context and rationale (recorded position):** Implementation follows B-01: 11 reference fields on the B-04 list (13 before B-01); the two exercise columns no longer reject. The register asks for confirmation only; no options are recorded and no recommendation beyond "implemented per the later B-01". Related note F6 (restoring `archived`/`deleted_at` on a device-kept system exercise keeps the device's `updated_at`) is recorded, behaviour unchanged, to be settled with sync and 3d.

**Options:**
- [ ] Confirm: B-01 supersedes B-04 for `exercises.source` and `provider_id` (implemented behaviour stands).
- [ ] Reject: restore the B-04 rejection for these two columns (code change in 3b-7).
- [ ] Defer decision.

**Recommendation:** none recorded.

**Consequences:** Confirming closes F3 with no code change; rejecting re-opens WS3 implementation and the B-01 decision.

**Owner's decision:** `[enter]`  
**Owner's rationale:** `[enter]`  
**Conditions / follow-up:** `[enter]`  
**Decision date:** `[YYYY-MM-DD]`  
**Resulting status:** `[Proposed / Approved / Rejected / Deferred / Superseded]`

#### Decision 2A-8 — Confirmation of the Train/knowledge allocation relayed to the WP 8 session

**Reference:** `docs/wp0/D04-product-requirements-baseline.md` §7 on the WP 8 session branch (`ccr-9fda2c32-wr163b`), two owner-labelled entries: `516fac4` "2026-11-07 — Train workspace redesign and exercise knowledge system: allocation (owner)" and `d4a73fb` "Exercise knowledge base branch; Train UX handover contingency (owner; supersedes the base in the entry above)" (read at `f3a12a4`); campaign-2 report section H and ledger entries 01:57, 02:00 and 03:33 UTC (`docs/verification/overnight-campaign-2026-11-07.md`).

**Description:** Confirm or correct the owner allocation for the 7 November brief "Train workspace redesign and exercise knowledge system" as the WP 8 session relayed it.

**Context and rationale (recorded position):** The two D04 entries on the WP 8 session branch record, as owner decisions: exercise knowledge system → WP 8 session, on `claude/exercise-knowledge-2026-11-07`, base `claude/campaign-2026-11-07` (the earlier strict `aa59021` base withdrawn), no 3b ancestry or code, stage 3c release format canonical, complete test evidence, never merged directly into the release candidate; Train dashboard redesign and filter-chip design-system correction → "the other (integration) session, or the WP 8 session's reviewed handover"; final integration → the campaign integration authority; 3b isolated; merge to `main` only with owner approval; rules: acknowledgement before proceeding, no duplicate implementation, independent review, ancestry check, four workflows on the integrated commit. The integration session received these entries only through the WP 8 session's messages (the entries exist on that branch, not on the integration branch) and replied with choice (b): accept the handover for independent review and integration; it built none of it. Two statements in the first entry conflict with the records: it calls the release candidate "accepted WP 15/WP 17 work" (both are not accepted) and says it holds "no WP 8 3b code" (it holds the isolated earlier v8 work, Part 1.2) — Part 9, C-16. Status: recorded on the WP 8 branch as an owner decision; the owner confirms the evidence here.

**Options:**
- [ ] Confirm the allocation as recorded in `516fac4` and `d4a73fb` (evidence confirmed; the two D04 entries are to be carried onto the integration branch's D04).
- [ ] Confirm with corrections (state them; e.g. the "accepted WP 15/WP 17" wording).
- [ ] Reject the allocation (state the replacement).
- [ ] Defer.

**Recommendation:** none (not an engineering question).

**Consequences:** Until confirmed here, the exercise-knowledge branch (`ffd6d14`) and the Train dashboard series stay un-integrated and Decision 2A-10 cannot proceed; the D04 entries remain on the WP 8 branch only.

**Owner's decision:** `[enter]`  
**Owner's rationale:** `[enter]`  
**Conditions / follow-up:** `[enter]`  
**Decision date:** `[YYYY-MM-DD]`  
**Resulting status:** `[Proposed / Approved / Rejected / Deferred / Superseded]`

#### Decision 2A-9 — OB-WP8-04 and its relationship to the later stage 3b implementation

**Reference:** OB-WP8-04 (register, High, awaiting owner); D04 §7 2026-11-07 ("branch `ccr-9fda2c32-wr163b` stays isolated; nobody merges or cherry-picks its 3b commits into the release candidate; OB-WP8-04 stays open until the owner decides"); Part 1.2 of this document.

**Description:** Decide whether, and under which conditions, the later stage 3b implementation (`163ce4a`, `5e37008`, `38bdf6d`, `ac14711`, record `f3a12a4`) may be integrated into the integration branch, given that the earlier isolated v8 work (`2ba3997`, `e57834e`, up to `c636a06`) is already in `main` and the release candidate and is not connected.

**Context and rationale (recorded position):** OB-WP8-04 carries the B-15 decision (2A-1) as the gate. The later implementation is reviewed on its branch (Review C passed; `ac14711` has all four workflows green, Baseline A) but is **not accepted** and not integrated. The earlier work's presence in `main` is not evidence of integration or acceptance of the later work. The campaign-2 release candidate contains none of the later commits.

**Options:**
- [ ] Keep stage 3b isolated until B-15 (2A-1) is decided and implemented, WS3 closes, device timing passes (2A-11) and stage 3b is accepted (2A-12); only then integrate.
- [ ] Allow integration of the reviewed `ac14711` line into the integration branch now, as isolated and unconnected code (production stays schema 7), with B-15 still open — state the review and CI conditions.
- [ ] Request further investigation (e.g. an independent integration review of `ac14711` against the integration branch).
- [ ] Defer.

**Recommendation:** none recorded beyond the standing D04 rule (isolated until the owner decides).

**Consequences:** The first option keeps the release candidate free of the later 3b work and keeps two code lines diverging (merge cost grows); the second brings reviewed but unaccepted code into the candidate and requires the four workflows and an ancestry check on the merged commit; neither connects v8 to production.

**Owner's decision:** `[enter]`  
**Owner's rationale:** `[enter]`  
**Conditions / follow-up:** `[enter]`  
**Decision date:** `[YYYY-MM-DD]`  
**Resulting status:** `[Proposed / Approved / Rejected / Deferred / Superseded]`

#### Decision 2A-10 — Permission and disposition for the reviewed Train dashboard series

**Reference:** Campaign-2 ledger 03:33 UTC entry; WP 8 session message of 03:33 UTC ("The Train dashboard series is reviewed and its re-check is pending. It waits for the owner's permission to push to its own branch").

**Description:** Grant or refuse permission for the WP 8 session to push its Train dashboard and filter-chip series to its own branch, and set its disposition towards the release.

**Context and rationale (recorded position):** D04 entry `d4a73fb` (WP 8 branch) says the WP 8 session "prepares its locally started work as a reviewed commit series for handover, if the other session does not implement it" and grants push permission only for the exercise-knowledge branch; it does not name a branch for the Train series. No branch, commit or review record for the series exists in the repository; the WP 8 session reported at 03:33 UTC that the series is reviewed, its re-check pending, and that it waits for the owner's permission to push. Depends on Decision 2A-8. Status: **REQUIRES OWNER CONFIRMATION**.

**Options:**
- [ ] Permit the push to a dedicated branch; integration only after an independent review by the integration session, an ancestry check against the integration branch, and four green workflows on the merged commit; not part of this release candidate.
- [ ] Permit the push and include it in this release (re-opens Part 3 sections 2 and 5 and Part 4 baseline C).
- [ ] Refuse for now; keep it for the next campaign.
- [ ] Defer.

**Recommendation:** none.

**Consequences:** Including it in this release invalidates the current release-candidate evidence (new `app/` tree) and requires re-testing; excluding it leaves the Train landing screen as at `aa59021`.

**Owner's decision:** `[enter]`  
**Owner's rationale:** `[enter]`  
**Conditions / follow-up:** `[enter]`  
**Decision date:** `[YYYY-MM-DD]`  
**Resulting status:** `[Proposed / Approved / Rejected / Deferred / Superseded]`

#### Decision 2A-11 — Acceptance of the physical-device migration timing results (3b-9)

**Reference:** 3b-9 (D04 §7 "Device timing", 2026-11-06; `docs/device-timing.md`; harness `38bdf6d`); OB-WP8-01 (Android), OB-WP8-02 (iPhone); Part 5.3 of this document.

**Description:** Accept or reject the physical-device timing runs of the v7→v8 migration once they exist.

**Context and rationale (recorded position):** Requirement: one mid-range Android phone and one supported iPhone with recorded specifications; at least three normal runs from an identical restored start plus one recovery/retry run, profile mode, stress profile (5,000 exercises, 100,000 sets); record model, OS, SQLite version, database size, median and worst durations. **No device result exists in the repository.** Host figures (app-engine median about 8.4 s at `38bdf6d`, about 5.0 s after the Review C fixes) are not device evidence. Earned so far: harness 0.09 of 0.30; device runs 0.20 unearned.

**Options:**
- [ ] Accept the Android and iPhone results recorded in Part 5.3 as meeting the 3b-9 requirement.
- [ ] Accept Android only; iPhone outstanding (state why).
- [ ] Reject: runs do not meet the procedure (state the gap).
- [ ] Not yet possible: no runs exist (status stays Proposed).
- [ ] Defer: stage 3b is not under acceptance for this release (see 2A-9).

**Recommendation:** none; the record sets the procedure.

**Consequences:** Without accepted runs on both platforms stage 3b cannot be accepted (owner's 2026-11-06 condition).

**Owner's decision:** `[enter]`  
**Owner's rationale:** `[enter]`  
**Conditions / follow-up:** `[enter]`  
**Decision date:** `[YYYY-MM-DD]`  
**Resulting status:** `[Proposed / Approved / Rejected / Deferred / Superseded]`

#### Decision 2A-12 — Formal stage 3b acceptance decision

**Reference:** OB-WP8-03 (sub-stage acceptances 3b-2, 3b-4, 3b-5, 3b-6, 3b-8; register, awaiting owner); 3B-ACC-01; WP 8 record "Stage 3b status" and "Effort-point progress update (2026-11-07)" at `f3a12a4`.

**Description:** Accept or reject stage 3b as a whole, and record the sub-stage acceptances.

**Context and rationale (recorded position, `f3a12a4`, evidence baseline `2ba5881` plus the Review C fix round now committed as `ac14711`):**

| Sub-stage | Alloc. | Earned | Record status |
|---|---:|---:|---|
| 3b-1 frozen evidence | 0.50 | 0.50 | accepted as foundation |
| 3b-2 schema v8 | 0.50 | 0.45 | `2ba3997`; Review A + 2 re-checks; owner acceptance outstanding |
| 3b-3 historical steps | 0.50 | 0.50 | complete (owner) |
| 3b-4 v7→v8 migration | 0.75 | 0.675 | `e57834e`; Review B + 2 re-checks; decision baseline `163ce4a` reviewed; acceptance outstanding |
| 3b-5 all-paths test | 0.25 | 0.225 | acceptance outstanding |
| 3b-6 WS5 stress and kill suites | 0.40 | 0.36 | acceptance outstanding |
| 3b-7 backup format 3 (WS3) | 0.60 | 0.42 | merged `..5e37008`; **not closed** (B-15 failed, B-17 open); review 0.12 and acceptance 0.06 withheld |
| 3b-8 | 0.40 | 0.36 | `b644636..e50a047`; re-checked; acceptance outstanding |
| 3b-9 device timing | 0.30 | 0.09 | harness `38bdf6d`; device runs outstanding |
| 3b-10 Review C and fixes | 0.30 | 0.00 | Review C passed; fixes committed as `ac14711` after the record was written; four workflows green on `ac14711` (Baseline A); record not yet re-based |
| **Stage 3b** | **4.50** | **3.58** | **not accepted** |

WP 8 total at `f3a12a4`: 10.08 of 18.00 (56.0 %). Note for the owner: the record's effort section still describes the Review C fix round as uncommitted although `ac14711` committed it; no re-based figure exists (Part 9). Whether agent reviews satisfy the "independent review" conditions is Decision 2D-5 (OB-PROG-01).

**Options:**
- [ ] Accept stage 3b in full (requires 2A-1, 2A-2, 2A-7 decided and implemented, WS3 closed and re-checked, 2A-11 accepted on both platforms, four green workflows on the final 3b commit).
- [ ] Accept the reviewed sub-stages 3b-2, 3b-4, 3b-5, 3b-6, 3b-8 now (OB-WP8-03) and hold 3b-7, 3b-9, 3b-10.
- [ ] Reject / not yet: list the conditions still open.
- [ ] Defer.

**Recommendation:** none recorded (the WP 8 session reports status only).

**Consequences:** Sub-stage acceptance releases the withheld 10 % acceptance credit for those sub-stages (0.05 + 0.075 + 0.025 + 0.04 + 0.04); full acceptance is the gate for stage 3c formal start, 3d and the v8 switch-over.

**Owner's decision:** `[enter]`  
**Owner's rationale:** `[enter]`  
**Conditions / follow-up:** `[enter]`  
**Decision date:** `[YYYY-MM-DD]`  
**Resulting status:** `[Proposed / Approved / Rejected / Deferred / Superseded]`

#### 2A-13 — Other open WP 8 stage 3b items (confirmation requests; one line each)

| Id | Item (recorded position at `f3a12a4`) | Owner's answer | Date |
|---|---|---|---|
| B-05 | `acknowledged_at` merge: device wins; merged runs' provenance becomes `backup` with backup identity. Confirmation requested. | `[ ] Confirm  [ ] Change: …` | `[ ]` |
| B-06 | Report rule code for a device-wins difference: `D04-RESTORE-DEVICE-WINS`, action `retained`, category `warningForReview`. Confirmation requested. | `[ ] Confirm  [ ] Change: …` | `[ ]` |
| B-10 | Restore run provenance `backup`, `provenance_source` = `sha256:` of the backup text, `merged_at` = `generated_at` = restore time. Confirmation requested. | `[ ] Confirm  [ ] Change: …` | `[ ]` |
| B-11 | Unresolved references in restored data → separate integrity run `<run id>:integrity`, never blocking (with R-31). Confirmation requested. | `[ ] Confirm  [ ] Change: …` | `[ ]` |
| B-12 | Damaged declared relationships rejected atomically (interacts with B-17). No confirmation requested by the record; listed for completeness. | `[ ] Noted  [ ] Change: …` | `[ ]` |
| B-13 | Preview runs phase 1a only; the register marks it as a note for the production switch (3d), not a 3b decision. | `[ ] Noted  [ ] Change: …` | `[ ]` |
| R-C9 | How a blocked system exercise is cleared; tied to the B-15 choice; 3c requirement. | `[ ] Decide with 2A-1  [ ] Defer to 3c` | `[ ]` |
| 3B-ACC-01 | Acceptance scenario set for 3b (WS2, WS3, WS5). Covered by 2A-12. | — | — |

### 2B — WP 15, stages S1 / S2 (nutrition entry units)

Baseline labels follow Part 4 throughout this document: **Baseline B** = the frozen implementation branch (code `ded976b`, records `43aa667`); **Baseline C** = the integration branch (`28b67b3`; contains Baseline B plus the campaign-1 corrections and the review-fix re-check). (Baseline A is the WP 8 session branch, `ac14711`, and does not apply to WP 15 or WP 17.) Every acceptance option names its commit.

#### Decision 2B-1 — Confirmation of the earned allocation 2.20 / 3.00

**Reference:** `docs/delivery-record/WP15.md` "Effort-point breakdown and evidence reconciliation (2026-11-06)" (Baseline B, `43aa667`; same figure on Baseline C); governance standard §2 baseline row (WP 15: 40 %, 1.20, historical estimate); OB-PROG-01.

**Description:** Confirm that WP 15 has earned 2.20 of its approved 3.00 points (73.3 %), with 0.80 remaining, on the evidence recorded.

**Context and rationale (recorded position):**

| Row | Points | Earned | Record status |
|---|---:|---:|---|
| Stage 1 entry-unit domain | 0.90 | 0.90 | implemented `8f76f5c`; spec examples E42–E49 run as tests |
| Stage 2a portion sheet | 0.65 | 0.65 | implemented `353fcd8` |
| Stage 2b ingredient sheet | 0.65 | 0.65 | implemented `353fcd8` |
| Custom-food serving entry scope disposition / implementation | 0.25 | 0.00 | not implemented; owner disposition (2B-2) |
| Spec revision 1.4 approval and decisions (OQ-02, mg) | 0.20 | 0.00 | proposed, not approved (2E) |
| Independent review | 0.10 | 0.00 | review done by a separate agent (R15-01..06, ACCEPT WITH CONDITIONS); credit withheld pending OB-PROG-01 — the `43aa667` breakdown wording ("implementer-session review") is stale against its own review section (Part 9) |
| Owner acceptance | 0.25 | 0.00 | outstanding (2B-3) |
| **Total** | **3.00** | **2.20** | 73.3 % |

The governance baseline row (40 %, 1.20) is the historical estimate and is retained separately by the standard; it is not a conflict with 2.20. The integration-branch record shows a sensitivity of 2.30 (76.7 %) if OB-PROG-01 accepts agent reviews.

**Options:**
- [ ] Confirm 2.20 / 3.00 as earned.
- [x] Confirm 2.30 / 3.00 (adds the 0.10 review line because agent reviews suffice; requires Decision 2D-5 = accept).
- [ ] Set another figure (state the rows changed and why).
- [ ] Defer.

**Recommendation:** none beyond the record's figure.

**Consequences:** The programme roll-up uses the confirmed figure (Part 2D-7 sensitivity table).

**Owner's decision:** Option B as amended by 2B-2: WP 15 earned points are confirmed at 2.30, and the WP 15 total is reduced from 3.00 to 2.75 by the exclusion of the custom-food serving row, so the earned position is 2.30 / 2.75 (83.6 %).  
**Owner's rationale:** Consistent with Decision 2D-5 (agent reviews satisfy the independent-review criterion). The +0.10 is a governance adjustment releasing the review line, not an additional implementation achievement.  
**Conditions / follow-up:** Update the WP 15 record's breakdown (independent review 0.10 earned; custom-food row marked excluded; total 2.75), the governance standard §2 (WP 15 allocation 2.75 with the dated owner decision; programme total 104.75 full / 96.75 core, or as the owner restates the denominators), and the next programme snapshot.  
**Decision date:** 2026-11-07  
**Resulting status:** Approved

#### Decision 2B-2 — Custom-food serving-definition entry units (scope)

**Reference:** WP 15 record "Scope discrepancy kept visible (owner, 2026-11-06)" and "Open items"; OB-WP15-01; D06 WP 15 scope text; parallel-workstream assessment §12 S2.

**Description:** Decide whether the custom-food screen's serving-definition amounts (`custom_food_screen.dart`, keys `serving-amount-<i>`) must accept kg / l entry under NUT-022, as a stage 3, or are recorded as outside NUT-022's acceptance text.

**Context and rationale (recorded position):** D06's WP 15 scope names "food logging, portion sheets and recipe ingredients"; it does not name custom-food servings. The assessment's S2 plan listed `custom_food_screen.dart` as a target; stage 2 delivered the portion sheet (`portion-entry-unit`, `portion-canonical`) and the ingredient sheet (`ingredient-entry-unit`, `ingredient-canonical`) and left the custom-food screen unchanged ("small but not required by NUT-022's acceptance text; left for the owner to call"). The owner asked on 2026-11-06 that this "be resolved explicitly, not dropped". The 0.25-point row waits on this decision.

**Options:**
- [ ] **(a)** In scope: add the per-row entry unit on the custom-food screen as WP 15 stage 3 (implementation, tests, review) before WP 15 acceptance.
- [x] **(b)** Out of scope for NUT-022: record the exclusion in D04 §7; the 0.25 row is re-dispositioned (state how: earned as "decided" or removed with a total change, which needs a traceable owner decision under the standard).
- [ ] Defer to a later package (name it).

**Recommendation (register OB-WP15-01, delivery agent):** (a), add the per-row unit.

**Consequences:** (a) adds a small stage before acceptance and keeps the allocation at 3.00; (b) closes the discrepancy without code and changes how the 0.25 row is earned; deferral leaves WP 15 at 73.3 % with the row open.

**Owner's decision:** Option (b): the custom-food serving-definition amounts are explicitly excluded from WP 15 and from NUT-022's acceptance text.  
**Owner's rationale:** Scope discipline over superficial consistency across every screen; D06's WP 15 scope names food logging, portion sheets and recipe ingredients only.  
**Conditions / follow-up:** Record in D04 §7 and the WP 15 record: (1) explicit exclusion from WP 15; (2) the 0.25 "custom-food serving entry" row is re-dispositioned as excluded: no implementation credit is earned for it in WP 15; (3) the item may be allocated to a future work package. Owner's statement (2026-11-07): the excluded 0.25 row is retained in the WP 15 table for traceability, marked excluded; the WP 15 total is reduced from 3.00 to 2.75 (a traceable owner decision under the governance standard §6, to be recorded in the standard's §2 baseline note and D04 §7); earned position 2.30 / 2.75 = 83.6 %.  
**Decision date:** 2026-11-07  
**Resulting status:** Approved

#### Decision 2B-3 — Acceptance of the WP 15 implementation and its independent review

**Reference:** OB-WP15-05; WP 15 record "Independent review of stages 1–2 (2026-11-06)" (Baseline B record) and "Integration at the overnight campaign gate" with the separate-agent re-check of `26e9f10` (Baseline C record, verdict PASS); D06 WP 15 acceptance criteria.

**Description:** Accept or reject WP 15 stages 1 and 2 as implemented and reviewed, naming the baseline.

**Context and rationale (recorded position):** Implementation: stage 1 `8f76f5c`, stage 2 `353fcd8`, review fixes `26e9f10`, all on Baseline B and carried into Baseline C. Review (Baseline B record): separate fresh-context agent, verdict ACCEPT WITH CONDITIONS, no High; R15-01 (Medium, over-range amount message) corrected; R15-02..05 (Low) corrected; R15-06 (Low, API-only precision) recorded in spec E45, no code change. Re-check (Baseline C record): all six closed with file:line evidence; 32 tests in the four WP 15 files. CI: at `353fcd8` four workflows green (42273529731, 42273529821, 42273529701, 42273529969); at `ded976b` CI/Android/iOS green, emulator infrastructure-blocked (Baseline B); on the integration branch the emulator suite passed with the merged code (Baseline C). Local: 2,315 passed at `353fcd8`, 2,361 at `ded976b` (4 skipped). D06 acceptance also needs: spec revision 1.4 approved (2E-1), OQ-02 documented (2E-2), mg disposition (2E-3), and the custom-food scope (2B-2). The review's own caveat: "the owner may still require a human reviewer before acceptance" (2D-5).

**Options:**
- [x] Accept stages 1–2 on Baseline C (integration branch `28b67b3`), implementation and independent review, subject to the conditions listed below.
- [ ] Accept on Baseline B (frozen branch `ded976b`) only.
- [ ] Accept with conditions (state which of 2B-2, 2E-1, 2E-2, 2E-3, human review).
- [ ] Reject: remediation required (state it).
- [ ] Defer.

**Recommendation (register OB-WP15-05, delivery agent):** "Accept once the four decisions above are recorded" (the custom-food scope, spec revision 1.4, OQ-02 and mg).

**Consequences:** Acceptance releases the 0.25 acceptance row (and 0.10 review row if 2D-5 accepts agent reviews); WP 15 closes only when 2B-2 and the 2E decisions are also recorded.

**Owner's decision:** Option A: WP 15 stages 1 and 2 are accepted with conditions on Baseline C (integration branch, `app/` tree of `28b67b3`), implementation and independent review. The review verdict ACCEPT WITH CONDITIONS stands, with the six findings R15-01..R15-06 closed by the re-check.  
**Owner's rationale:** Independent review and re-check complete; the acceptance conditions are now recorded decisions.  
**Conditions / remaining remediation:** Acceptance is conditional on and references: specification revision 1.4 approved (2E-1); metric-only entry for v1 (2E-2); milligram entry hidden (2E-3); custom-food serving-definition amounts excluded from WP 15 (2B-2); earned allocation confirmed at 2.30 / 3.00 (2B-1). Record the acceptance in the WP 15 record and D04 §7; the acceptance row (0.25) is then earned, giving 2.55 / 2.75 with the excluded row retained for traceability and no other unearned line.  
**Decision date:** 2026-11-07  
**Resulting status:** Approved

### 2C — WP 17, stages S3 / S4 (Fuel and Train workflow completion)

Baseline labels as in Part 4 and 2B (Baseline B = `ded976b`; Baseline C = `28b67b3`). **Proposed allocation and earned credit are different things:** the 9.00 allocation is a proposal (R17-10, OB-WP17-01); the 3.00 "earned" in the records is implementation credit computed against that proposal and counts for nothing in the programme roll-up until the allocation is approved.

#### Decision 2C-1 — Approval or rejection of the proposed 9.00-point allocation

**Reference:** OB-WP17-01 (High, scope approval); WP 17 record "Effort points and progress" (Baseline B `43aa667`; Baseline C); governance standard §6; D06 WP 17 entry; parallel-workstream assessment D-1 (approved 2026-11-06: WP 17 created).

**Description:** Approve the proposed 9.00-point allocation with its stage table, set another figure, or reject it.

**Context and rationale (recorded position):** D-1 created WP 17 on 2026-11-06 and authorised S3 and S4 implementation before an allocation could be proposed. Proposal `b6510cd`: 9.00, sized relative to WP 7 (8) and WP 9 (9). Stage table (Baseline B record, exact): S3a 0.60; S3b-i 0.40; S3b-ii 0.20; S3c 0.40; S4a 0.50; S4b 0.60; S4c 0.50; S4d 0.30; S5 0.80; S6a 1.60; S6b 1.40; S6c 0.70; independent review 0.50; register/acceptance 0.50 = 9.00. Implementation credit so far: 3.00 (S3a, S3b-i, S3c, S4a, S4b, S4c). If approved, the programme denominator becomes 114 full / 106 core (snapshot figures: 80.66 / 114 = 70.8 %, 80.66 / 106 = 76.1 % in `programme-progress-2026-11-07b.md`; campaign 1 showed 70.3 % / 75.6 % on a different total earned — Part 9).

**Options:**
- [x] Approve 9.00 with the stage table as recorded.
- [ ] Approve a different total (state the figure and which rows change).
- [ ] Reject the allocation (WP 17 earns nothing until a new proposal).
- [ ] Defer.

**Recommendation (register OB-WP17-01, delivery agent):** approve 9.00.

**Consequences:** Until approved, every WP 17 percentage is provisional and the roll-up must show both denominators; approval makes the 3.00 implementation credit countable.

**Owner's decision:** Option A: the WP 17 allocation is 9.00 points with the stage table as recorded (S3a 0.60, S3b-i 0.40, S3b-ii 0.20, S3c 0.40, S4a 0.50, S4b 0.60, S4c 0.50, S4d 0.30, S5 0.80, S6a 1.60, S6b 1.40, S6c 0.70, independent review 0.50, register/acceptance 0.50).  
**Owner's rationale:** Sized against WP 7 (8) and WP 9 (9) and already split by stage with evidence lines.  
**Conditions / follow-up:** Record the approval in D04 §7 and the governance standard §2; the programme denominator becomes 114 full / 106 core; the 3.00 implementation credit now counts.  
**Decision date:** 2026-11-07  
**Resulting status:** Approved

#### Decision 2C-2 — S3b-ii scope (NUT-014 remainder)

**Reference:** OB-WP17-02; WP 17 record stage table rows S3b-i / S3b-ii; review R17-01.

**Description:** Confirm whether S3b-ii (20 most-frequent foods in 90 days; last-used quantity pre-fill; saved meals in recents, which needs a saved-meal id on log entries, schema v9) stays in WP 17.

**Context and rationale (recorded position):** Review R17-01 found the record over-claimed NUT-014; S3b was split into S3b-i (delivered: 10 most recent distinct foods and recipes; 0.40 earned) and S3b-ii (0.20, not started). Traceability now says "partially met". D04's integration-gate text must read "recents (subset of NUT-014)".

**Options:**
- [x] Keep S3b-ii in WP 17 as recorded (non-schema parts may proceed after the release; the saved-meal part waits for S6/v9).
- [ ] Move S3b-ii out of WP 17 (name the package; adjust the allocation with a traceable decision).
- [ ] Descope S3b-ii (NUT-014 stays "partially met").
- [ ] Defer.

**Recommendation (register OB-WP17-02):** keep it in WP 17; defer only the saved-meal part to S6.

**Consequences:** Affects the allocation total (2C-1) if moved or descoped; no effect on this release's code.

**Owner's decision:** Option A: S3b-ii stays in WP 17 at 0.20; the non-schema parts (frequent foods, last-used quantity pre-fill) may proceed after this release; the saved-meal part waits for S6 (schema v9).  
**Owner's rationale:** Keeps NUT-014's remainder traceable inside the package that owns it.  
**Conditions / follow-up:** none  
**Decision date:** 2026-11-07  
**Resulting status:** Approved

#### Decision 2C-3 — S4d scope (rest-timer survival across process death)

**Reference:** OB-WP17-03; WP 17 record S4d row; review R17-04; cross-package finding D-07 (record wording).

**Description:** Decide whether S4d is implemented before S4 acceptance or S4 is accepted without it.

**Context and rationale (recorded position):** Review R17-04 corrected the earlier rationale: the key-value `settings` table exists, so a typed accessor needs no schema change and is inside the branch's allowed paths; the deferral was the implementing agent's reading of its brief, not a constraint. Stays in S4 at 0.30, not started, no reallocation. The timer is wall-clock based and survives backgrounding but not process death. The `43aa667` record still carries the old G6c wording in one place (Part 9).

**Options:**
- [ ] Implement S4d before S4 acceptance (0.30 remains to earn; new review).
- [x] Accept S4 without S4d for this release; S4d stays allocated and open.
- [ ] Descope S4d (traceable allocation change).
- [ ] Defer.

**Recommendation (register OB-WP17-03):** accept S4 without it for this release.

**Consequences:** Implementing it changes the release candidate (re-test Part 3 section 5); accepting without it leaves a documented behaviour gap (DFR-004).

**Owner's decision:** Option B: S4 is accepted without S4d for this release; S4d remains allocated (0.30) and open in WP 17.  
**Owner's rationale:** The timer already survives backgrounding; implementing process-death survival now would re-open the release candidate.  
**Conditions / follow-up:** S4d recorded as DFR-004 (deferred functionality, allocated, open); no reallocation.  
**Decision date:** 2026-11-07  
**Resulting status:** Approved

#### Decisions 2C-4 — D-3, D-4, D-5, D-6 and D-7 (parallel-workstream assessment §14)

D-1 (create WP 17) and D-2 (schema changes deferred to v9 after v8 is connected and accepted) are recorded as **approved by the owner on 2026-11-06** in `docs/verification/parallel-workstream-assessment-2026-11-06.md` §14; they are not re-asked. The owner confirms the evidence here: `[ ] D-1 and D-2 evidence confirmed  [ ] Dispute: …`.

D-3 to D-7 have **no recorded decision**. Each maps to a register entry.

| Ref | Decision | Options (as raised) | Recommendation (register, delivery agent) | Owner's decision | Rationale / conditions | Date | Status |
|---|---|---|---|---|---|---|---|
| D-3 (OB-WP17-04) | Canonical seed recipes: editable or read-only | `[x] keep editable (WP 7 decision; "estimated until linked")  [ ] read-only with "copy to edit"  [ ] defer` | keep editable | Option A: keep editable | Consistent with the WP 7 decision | 2026-11-07 | Approved |
| D-4 (OB-WP17-05, Medium) | Workout catalogue content: approve the 30-plan draft (10 categories) limited to the 89 current exercises; name the reviewer | `[x] approve draft as release-1 content, 89 exercises only  [ ] approve with changes  [ ] hold (S5 stays held)  [ ] defer` | approve as release-1 content; second pass after WP 8 stage 5 | Option A: the 30-plan draft is approved as release-1 content limited to the 89 current exercises; a second pass follows WP 8 stage 5 | reviewer name: the Product Owner (kreczmans-creator). S5 may proceed; its 0.80 is earned on delivery and review | 2026-11-07 | Approved |
| D-5 density part (OB-WP17-06) — the imperial part is OQ-02, Decision 2E-2 | Whether a food may carry a density for volume↔mass conversion (NUT-022(2)) | `[x] no density in v1 (per-100 ml foods offer ml/l only; otherwise the app asks for grams)  [ ] allow density (new scope, v9)  [ ] defer` | no density in v1; revisit with the v9 allocation | Option A: no density in v1 | confirm that ml/l-only for per-100 ml foods is an acceptable reading of NUT-022(2): `[x] yes  [ ] no` | 2026-11-07 | Approved |
| D-6 (OB-WP17-07) | Recipe image (OQ-04): device-only storage and backup size | `[x] no images in v1  [ ] images, device-only, excluded from backup  [ ] images included in backup  [ ] defer` | no images in v1 | Option A: no recipe images in v1 | S6c image UI is descoped for v1; the S6c row stays allocated for tags and backup round-trip evidence until the owner restates it | 2026-11-07 | Approved |
| D-7 (OB-WP17-08) | CSV export of nutrition and training: new scope or not | `[x] out of scope for this release  [ ] in scope under its own allocation (name WP)  [ ] defer` | out of scope; reuse the WP 10 exporter later | Option A: out of scope for this release | May return later under its own allocation, reusing the WP 10 exporter | 2026-11-07 | Approved |

#### Decision 2C-5 — Specification revision 1.4 approval

Revision 1.4 of `docs/nutrition-calculation-spec.md` was proposed by WP 15 stage 1 and is also a WP 17 dependency (D-5). It is decided once, in **Decision 2E-1**; record the outcome here by reference: `[2E-1 status]`.

#### Decision 2C-6 — Cherry-pick of the cross-package corrections D-01 to D-08 onto the frozen implementation branch

**Reference:** WP 15 and WP 17 records at `43aa667` ("Integration status (2026-11-06, 22:30)"): the corrections "live on that branch and are **not** replayed here, to keep one integration line"; campaign-1 report `docs/verification/overnight-campaign-2026-11-06.md`, Workstream D table.

**Description:** Decide whether the corrections applied on the integration line are also cherry-picked onto the frozen branch `claude/repforge-parallel-implementation-flyjqw`.

**Context and rationale (recorded position):** Corrections on the integration branch: D-01 (Medium: `SaveSessionAsPlan` now skips archived/soft-deleted exercises and reports them instead of refusing the whole save — **this changes S4b behaviour after the independent review**; R17-03's archived-refusal test replaced), D-02 (Medium latent: `DuplicatePlan` checks exercises; follow-up `91ea266`), D-03 (Medium: scheduled occurrence of a deleted plan no longer offers Start; follow-up `91ea266`), D-04 (Low: sheets degrade for `portions` basis), D-05 (Low: drag-reorder guard), D-08 (Low: copy-suffix length), D-T1 (presentation-isolation test) — all in `5956ad9` (+ `91ea266`, `0aa8058`); D-06 deferred to S4 acceptance; D-07 record wording; D-T2 recorded test gaps. **No record in the repository recommends cherry-picking**; the only statement is the "not replayed" one (Part 9). The frozen branch therefore differs in behaviour from the release candidate for S4b (refuses on archived exercise vs skips and warns).

**Options:**
- [x] Do not cherry-pick: the frozen branch stays a historical record; acceptance of WP 15 / WP 17 names Baseline C (integration branch) as the behaviour accepted.
- [ ] Cherry-pick D-01..D-05, D-08, D-T1 (and follow-ups) onto the frozen branch so both lines match (needs CI on the frozen branch; emulator evidence there is infrastructure-blocked).
- [x] Delete or archive the frozen branch after acceptance on Baseline C. (Archive, not delete.)
- [ ] Defer.

**Recommendation:** none recorded.

**Consequences:** Not cherry-picking keeps one integration line (the records' stated reason) but means any acceptance on Baseline B accepts behaviour that is not in the release; cherry-picking costs CI time and re-review on a branch that is otherwise frozen.

**Owner's decision:** Option A, then option C: no cherry-pick; the frozen branch `claude/repforge-parallel-implementation-flyjqw` stays a historical record, and it is archived after Decision 2C-7 is recorded.  
**Owner's rationale:** One integration line; acceptance names Baseline C as the behaviour accepted.  
**Conditions / follow-up:** Archive (do not delete) the frozen branch once 2C-7 is recorded in the WP 17 record; keep its last commits `ded976b` / `43aa667` referenced from the records.  
**Decision date:** 2026-11-07  
**Resulting status:** Approved

#### Decision 2C-7 — Formal acceptance of the WP 17 S3 / S4 implementation and independent review

**Reference:** OB-WP17-09; WP 17 record "Independent review of S3 and S4 (2026-11-06)" (R17-01..R17-10, verdict "S3 ACCEPT WITH CONDITIONS; S4 ACCEPT WITH CONDITIONS", no High, 28 new tests); cross-package review D-01..D-08 (Baseline C); OB-PROG-01.

**Description:** Accept or reject S3 (Fuel add flow: library pick, recents subset, recipe duplicate/filter) and S4 (plan duplicate/delete, save session as plan, elapsed time and drag reorder) as implemented and reviewed, naming the baseline.

**Context and rationale (recorded position):** All ten review findings dispositioned (R17-01 record split; R17-02 code: save-as-plan derives from completed non-warm-up sets, "owner may override the rule"; R17-03 tests; R17-04 record; R17-05..R17-09 corrected; R17-10 allocation unapproved). Integration review on Baseline C added D-01..D-08 with the behaviour change noted above. Two points the register asks the owner to call with acceptance: (1) whether deleting a plan should also skip its future planned occurrences on the schedule (today they stay, labelled "Deleted workout", no Start); (2) whether the plan row keeps its four trailing actions or moves Duplicate, Delete and Archive into a menu (D-06, deferred). Evidence: Baseline B (CI at `ded976b` green except the emulator block) and Baseline C (emulator green on the candidate with the merged code). WP 17 stays at 3.00 earned of 9.00 (proposed) with review and acceptance lines at 0 until 2C-1 and 2D-5 are decided.

**Options:**
- [x] Accept S3 and S4 on Baseline C (integration branch `28b67b3`) — requires 2C-1 approved; state the answers to (1) and (2) and whether the R17-02 warm-up rule and the D-01 skip-and-warn behaviour are accepted design choices.
- [ ] Accept on Baseline B (frozen branch `ded976b`) only (note: differs from the release in S4b behaviour).
- [ ] Accept with conditions (list: S4d per 2C-3, D-06 menu follow-up, D-T2 test gaps, human review per 2D-5).
- [ ] Reject: remediation required (state it).
- [ ] Defer.

**Recommendation (register OB-WP17-09, delivery agent):** accept S3 and S4 after OB-WP17-01; treat the warm-up rule as an accepted design choice or override it; keep future occurrences of deleted plans as they are; move the row actions into a menu as a small follow-up.

**Consequences:** Acceptance releases the WP 17 acceptance line only after the allocation (2C-1) is approved; conditions recorded here flow to Part 6.6/6.8.

**Owner's decision:** Option A: WP 17 stages S3 and S4 are accepted on Baseline C (integration branch, `app/` tree of `28b67b3`), implementation and independent review (R17-01..R17-10 dispositioned; cross-package D-01..D-08 dispositioned), with the conditions below. The R17-02 warm-up rule in save-as-plan and the D-01 skip-and-warn behaviour on archived exercises are accepted as design choices.  
**Answer to (1) deleted-plan future occurrences:** No — retain the future scheduled occurrences as they are (labelled "Deleted workout", no Start).  
**Answer to (2) plan-row actions:** Move Duplicate, Delete and Archive into a menu as a small follow-up.  
**Owner's rationale:** Allocation approved (2C-1); review verdicts ACCEPT WITH CONDITIONS with all findings dispositioned; integration-branch corrections reviewed.  
**Conditions / follow-up:** S4d remains allocated and open (2C-3, DFR-004). D-06 (plan-row actions into a menu) is a small follow-up, not a condition of acceptance. D-T2 test gaps remain recorded for closure in a later stage. Record the acceptance in the WP 17 record and D04 §7; the review line (0.50 share for S3/S4) and the acceptance line become earnable per 2D-5.  
**Decision date:** 2026-11-07  
**Resulting status:** Approved

### 2D — Programme and release governance

#### Decision 2D-1 — OB-PROG-02: GitHub Actions allowance check

**Reference:** OB-PROG-02 (register, High); campaign-2 ledger "GitHub Actions stopped starting jobs (02:03 UTC)" and "02:31 UTC — Actions resumed".

**Description:** Check the account's Actions usage, billing and spending limit, and record the finding, so the next campaign is not interrupted and the register entry can be resolved.

**Context and rationale (recorded position):** Between 02:03 and 02:31 UTC on 2026-11-07 every workflow run on the campaign branch (push-triggered on `1259e75` and `3fb551a`, dispatch on `3a44733`) failed within seconds with no runner, no steps and no log; runs started normally again at 02:31 and the four dispatched workflows completed. The GitHub status page was not reachable from the campaign environment, so an incident was not ruled out. Cause unknown. The register entry text was written during the stop and still describes it as current.

**Options:**
- [ ] Checked: allowance and spending limit are adequate (record the figures); resolve OB-PROG-02 in the workspace.
- [x] Checked: limit reached or near; raised (record the change).
- [ ] Not checked yet.

**Recommendation:** none.

**Consequences:** An unchecked allowance risks a repeat during the next overnight campaign.

**Owner's decision:** Checked. The account's Actions spending limit was hit because the repository was private; the owner made the repository public, so hosted-runner minutes no longer count against the limit.  **Finding / figures:** spending limit reached (private-repository minutes); resolved by making the repository public, 2026-11-07.  
**Decision date:** 2026-11-07  
**Resulting status:** Approved

#### Decision 2D-2 — Outstanding register decisions from the campaign-2 report, section H

All 41 register entries are listed with their status in **2E**; the ones section H names are: OB-PROG-02 (2D-1); OB-WP11-01, -02, -03 (2E); OB-WP8-05..-11 (2E); OB-WP12-01, OB-WP13-01 (2E); OB-WP14-01..-09 (2E and 2D-6); standing items OB-WP8-01..-04 (2A), OB-WP15-* (2B, 2E), OB-WP17-* (2C), OB-PROG-01 (2D-5). The owner confirms that every section-H item has an entry in this document: `[ ] confirmed  [ ] missing: …`.

#### Decision 2D-3 — Release publication authorisation

**Reference:** Campaign-2 report section F (publication command); the owner's standing constraint "No merge to main without my explicit approval"; Part 7 gates; Part 8 declaration.

**Description:** Authorise, or not, the fast-forward of `main` to the accepted release candidate.

**Context and rationale (recorded position):** `origin/main` (`c6d380f`) and `aa59021` are ancestors of the candidate, so `git merge --ff-only origin/claude/campaign-2026-11-07` applies campaigns 1 and 2 together (120 commits at `28b67b3`). Nothing has been merged. The publication command is:

```bash
git fetch origin
git checkout main
git merge --ff-only origin/claude/campaign-2026-11-07
git push origin main
```

Pre-checks: `git merge-base --is-ancestor aa59021 origin/claude/campaign-2026-11-07 && git merge-base --is-ancestor origin/main origin/claude/campaign-2026-11-07` (both exit 0) and `git diff --stat b27ec18 origin/claude/campaign-2026-11-07 -- app` (empty).

**Options:**
- [ ] Authorise publication of the candidate named in Part 8 to `main` (only valid once Part 8 records ACCEPTED or ACCEPTED WITH CONDITIONS).
- [ ] Authorise publication of a different commit (state it and its evidence).
- [ ] Do not publish.
- [ ] Defer.

**Recommendation:** none.

**Consequences:** Publishing advances `main` by both campaigns; `debug-release.yml` then runs on `main` and creates the stable test certificate (LIM-002).

**Owner's decision:** `[enter]`  **Commit authorised:** `[full SHA]`  **Executed by / date:** `[enter]`  
**Resulting status:** `[Proposed / Approved / Rejected / Deferred / Superseded]`

#### Decision 2D-4 — Confirmation of the authoritative integration branch

**Reference:** Part 1.1; campaign-2 report section A; the WP 8 session's relay ("the owner named the release candidate as `claude/busy-hypatia-rhl3hu` and the base as `aa59021`"; later "claude/campaign-2026-11-07 is the approved base for exercise knowledge").

**Description:** Confirm which branch is the authoritative integration line going forward.

**Context and rationale (recorded position):** Campaign 2 created `claude/campaign-2026-11-07` from `aa59021` and integrated WP 14, WP 8 3c (pure domain), WP 11 and the register there; `claude/busy-hypatia-rhl3hu` is preserved at `391fe1b` (docs after `aa59021`) and will not move. D04 on the WP 8 branch (`516fac4`) first named `claude/busy-hypatia-rhl3hu` / `aa59021` as the integration baseline for the Train/knowledge work, then (`d4a73fb`) withdrew that base in favour of `claude/campaign-2026-11-07` as the exercise-knowledge baseline. Neither entry is on the integration branch. Status: **REQUIRES OWNER CONFIRMATION** for the integration line as a whole.

**Options:**
- [x] `claude/campaign-2026-11-07` is the authoritative integration branch (release candidate = its head carrying the campaign-2 report).
- [ ] `claude/busy-hypatia-rhl3hu` at `aa59021` remains the release candidate; campaign-2 work is held (state why).
- [ ] Another branch (name it).

**Recommendation:** none.

**Consequences:** Every acceptance in this document is recorded against the branch named here; Part 8 must name the same branch.

**Owner's decision:** Option A: `claude/campaign-2026-11-07` is the authoritative integration branch (head `ff7c68f` at the time of the decision; the `app/` tree is that of `b27ec18`).  
**Decision date:** 2026-11-07  
**Resulting status:** Approved

#### Decision 2D-5 — OB-PROG-01: whether agent reviews satisfy "independent review" for acceptance

**Reference:** OB-PROG-01 (register, Medium); WP 15 and WP 17 review sections ("the owner may still require a human reviewer before acceptance"); WP 8, WP 11, WP 14 reviews in campaign 2.

**Description:** Decide, per package, whether a separate-agent review with recorded dispositions satisfies the acceptance criteria' "independent review", or a named human reviewer must sign off.

**Context and rationale (recorded position):** Every review in the active packages was done by a separate agent with fresh context (WP 15 R15-*, WP 17 R17-* and D-*, WP 8 Reviews A/B/C, WP 11 domain and UI reviews, WP 14 review, register review). No decision says whether that is enough. The register recommendation (delivery agent): accept agent reviews for WP 15 and WP 17 S3/S4 and require a human reviewer only for WP 8 stage 3b (migration and user data).

**Options:**
- [ ] Agent reviews suffice for all active packages.
- [x] Agent reviews suffice except for WP 8 stage 3b (human reviewer required there).
- [ ] A named human reviewer must sign off everywhere (name: `[enter]`).
- [ ] Defer.

**Recommendation (register, delivery agent):** second option.

**Consequences:** Determines whether the 20 % review credit lines (WP 15 0.10; WP 17 0.50 for S3/S4/S6; WP 8 3b-7 0.12; WP 8 3c 0.17 sensitivity; WP 11 review lines) can be earned once recorded.

**Owner's decision:** Option B: separate-agent reviews with recorded dispositions satisfy the "independent review" acceptance criterion for every active package except WP 8 stage 3b, which needs a named human reviewer before acceptance.  
**Owner's rationale:** Stage 3b changes the migration and user data; the other packages have two-round agent reviews with recorded dispositions.  
**Decision date:** 2026-11-07  
**Resulting status:** Approved

#### Decision 2D-6 — Acceptance of the campaign-2 work packages discovered during repository inspection (WP 11, WP 14, WP 8 stage 3c pure domain, register)

**Reference:** `docs/delivery-record/WP11.md`, `WP14.md`, `WP8.md` ("Overnight programme acceleration campaign (2026-11-07) — stage 3c pure-domain stream"); OB-WP14-09; OB-WP11-01; OB-WP8-09, OB-WP8-10; campaign-2 report sections B and D.

**Description:** Record acceptance status for the work delivered and reviewed in campaign 2, which is in the release candidate.

**Context and rationale (recorded position):**

| Item | Implemented | Reviewed | Recorded earned | Owner acceptance |
|---|---|---|---|---|
| WP 14 release engineering (release.yml, signing config, cached test certificate with signer check, CHANGELOG, NUT-023 source line) | yes (`4d8ffdb`, `b27ec18`) | yes (0 High, 3 Medium fixed, re-check closed; `b27ec18` reviewed) | 1.45 / 3.00 | outstanding (OB-WP14-09) |
| WP 8 stage 3c pure domain (release format 2, parser/validator/hash/planner, release-2 data, catalogue gate; no runtime effect, no pubspec assets, no schema) | yes (`fea71c8`) | yes (1 High, 8 Medium fixed; re-check PASS) | 0 (sub-breakdown unapproved, OB-WP8-10; reviewer's view 0.58 + 0.17) | merge itself departs from D-3c-6's recommended wording; owner may reverse with `git revert -m 1 fea71c8` (OB-WP8-09) |
| WP 11 analytics (domain, application, UI for stages A, B, C, D1, E, F non-muscle, G1 computation) | yes (`d5af42c`) | yes (domain: 2 High, 3 Medium fixed over two rounds, final re-check PASS; UI: 6 Medium fixed, re-check PASS, Lows tracked LIM-006) | 0 (start and 7.0 breakdown unapproved, OB-WP11-01; reviewers' provisional view ≈ 2.75–3.50) | outstanding |
| Owner Actions register extension (22 entries; `BlockerWorkPackage` wp11–wp14) | yes (`b3be328`, `3fb551a`) | yes (0 High, 4 Medium fixed; re-check PASS) | n/a | n/a |

**Options (tick per row):**

| Item | Owner's decision | Conditions | Date | Status |
|---|---|---|---|---|
| WP 14 (OB-WP14-09) | `[ ] Accept delivered rows  [ ] Accept with conditions  [ ] Reject  [ ] Defer` | `[enter]` | `[ ]` | `[Proposed/…]` |
| WP 8 3c merge (OB-WP8-09) | `[ ] Confirm the merge  [ ] Reverse (`git revert -m 1 fea71c8`)  [ ] Defer` | `[enter]` | `[ ]` | `[Proposed/…]` |
| WP 8 3c sub-breakdown (OB-WP8-10) | `[x] Approve 2.00 split per preparation §3.11  [ ] Reject  [ ] Defer` | Approved: 3c-1 0.40, 3c-2 0.45, 3c-3 0.50, 3c-4 0.30, 3c-5 0.15, 3c-6 0.20. The reviewed 3c stream may now record 0.58 implemented + 0.17 reviewed (sensitivity in the snapshot becomes earned once the WP 8 record is updated). | 2026-11-07 | Approved |
| WP 11 start and breakdown (OB-WP11-01) | `[x] Approve 7.0 and the stage table; define bands for B, D1, F, G1  [ ] Approve with changes  [ ] Reject  [ ] Defer` | TRN-027/TRN-028 scope: both stay in WP 11; TRN-028 (estimated 1RM) is built last and is the first item to descope if points run short. Partial-credit bands for B, D1, F and G1: a stage's implementation credit is the share of its listed deliverables delivered (reviewed), per the plan §9 deliverable lists. WP 11 is authorised to start (retroactively covering the campaign-2 work). | 2026-11-07 | Approved |
| WP 11 delivered stages (acceptance) | `[ ] Accept A, B, C, D1, E, F (non-muscle), G1 computation as implemented and reviewed  [ ] Accept with conditions  [ ] Reject  [ ] Defer` | `[enter]` | `[ ]` | `[Proposed/…]` |

**Recommendation:** none recorded for acceptance; the register recommends approving the allocations (OB-WP8-10, OB-WP11-01).

**Consequences:** See the programme sensitivity table in `docs/governance/programme-progress-2026-11-07b.md`: WP 8 3c +0.75 and WP 11 roughly +2.75 to +3.50 become recordable only after the allocations are approved; recorded programme completion stays 77.66 / 105 = 74.0 % (80.1 % core) until then.

#### Decision 2D-7 — Confirmation that the Train/knowledge allocation has been acknowledged by the relevant session

**Reference:** Decision 2A-8; campaign-2 ledger 01:57, 02:00 and 03:33 UTC.

**Description:** Confirm that the integration session's acknowledgement (choice (b), handover for independent review; no duplicate implementation) is what the owner required of "the other session".

**Context:** The relayed rule was "The other session should acknowledge the same allocation before proceeding." The integration session acknowledged the allocation to the WP 8 session as unverified data and recorded it in the report for the owner to confirm; it did not acknowledge it to the owner directly because it had no channel to do so before this document.

**Options:** `[ ] Acknowledgement accepted as given  [ ] Owner requires a different acknowledgement: …  [ ] n/a (allocation not confirmed in 2A-8)`  
**Date:** `[YYYY-MM-DD]`  **Status:** `[Proposed / Approved / Rejected / Deferred / Superseded]`

### 2E — Other open owner decisions found in the register and records

These are genuine owner items with register entries that the sections above do not cover individually. Fill the decision column; where an item is decided elsewhere in this document, write the cross-reference.

#### Decision 2E-1 — Specification revision 1.4 (nutrition calculation spec §2.3 entry units, examples E42–E49)

**Reference:** OB-WP15-02; `docs/nutrition-calculation-spec.md` header and change history ("Revision 1.4 proposed (2026-11-06, WP 15 stage 1) … Revision 1.3 remains the approved text until the owner approves 1.4"); D04 §7 staged text.

**Context:** 1.4 adds §2.3 (an entry unit converts only to its own basis by exact factor, then the §2.1 0.1 g/ml store step; decimals 4 for kg and l, 1 for g/ml, 0 for mg; per-100 ml foods offer ml and l only; no density, hence no mass↔volume conversion) and examples E42–E49 executed as tests (`test/domain/nutrition_spec_examples_units_test.dart`); E45 carries the R15-06 API-precision note. No approved rule changed. Status on both baselines: **proposed**.

**Options:** `[x] Approve revision 1.4 as written  [ ] Approve with changes: …  [ ] Reject  [ ] Defer`  
**Recommendation (register OB-WP15-02):** approve.  
**Consequences:** Until approved, the implemented entry-unit behaviour is "proposed" and WP 15 cannot be accepted (2B-3); WP 17 D-5 depends on it.  
**Owner's decision:** Option A: revision 1.4 of `docs/nutrition-calculation-spec.md` is approved as written.  **Rationale:** The executable examples E42–E49 provide regression coverage without changing any approved rule.  **Date:** 2026-11-07  **Status:** Approved  
**Follow-up:** change the spec header and change-history row from "proposed" to "approved by the owner, 2026-11-07" (documentation change on the integration branch).

#### Decision 2E-2 — OQ-02: imperial entry units (lb, oz, fl oz)

**Reference:** OB-WP15-03; D04 OQ-02 (open); spec §2.3 ("imperial units are display-only … imperial entry is not offered"); assessment D-5 (imperial part).

**Context:** Imperial display factors exist (1 lb = 0.45359237 kg; 1 oz = 28.349523125 g; imperial fl oz = 28.4130625 ml); entry is metric only. D06 acceptance for WP 15 needs "the chosen imperial units documented".

**Options:** `[x] Metric entry only for v1; imperial entry recorded as a roadmap item (closes OQ-02 for WP 15)  [ ] Add imperial entry in WP 15 (name units; new stage)  [ ] Defer`  
**Recommendation (register OB-WP15-03):** metric only for v1.  
**Owner's decision:** Option A: metric entry only for v1; imperial display factors stay; imperial entry is a roadmap item. OQ-02 is closed for WP 15.  **Rationale:** Preserves GEN-003 consistency and avoids another implementation stage before acceptance.  **Date:** 2026-11-07  **Status:** Approved

#### Decision 2E-3 — Milligram entry availability

**Reference:** OB-WP15-04; WP 15 record stage 1 ("mg entry is implemented in the domain but not offered by default … Which screens, if any, offer mg is an owner decision"); spec E46 (250 mg → 0.3 g).

**Options:** `[x] Keep mg hidden (no screen offers it) until a finer store step is approved  [ ] Offer mg on: …  [ ] Defer`  
**Recommendation (register OB-WP15-04):** keep hidden.  
**Owner's decision:** Option A: milligram entry stays hidden on every screen until a finer store step is approved.  **Rationale:** Avoids presenting a precision the 0.1 g storage model cannot support.  **Date:** 2026-11-07  **Status:** Approved

#### 2E-4 — Register items decided elsewhere or still open (one line each)

| Register id | Title (short) | Priority | Where decided in this document | Owner's decision / cross-reference | Date |
|---|---|---|---|---|---|
| OB-WP8-01 | Android physical timing run (3b-9) | High | 2A-11 / Part 5.3 | `[ref]` | `[ ]` |
| OB-WP8-02 | iPhone physical timing run (3b-9) | High | 2A-11 / Part 5.3 | `[ref]` | `[ ]` |
| OB-WP8-03 | Acceptance of reviewed 3b sub-stages | Medium | 2A-12 | `[ref]` | `[ ]` |
| OB-WP8-04 | B-15 option (a)/(b)/(c) | High | 2A-1, 2A-9 | `[ref]` | `[ ]` |
| OB-WP8-05 | D-3c-1: where the deferred 3c schema (R-13/R-16/R-17/R-18/R-21) goes: (a) amend v8 before it is connected, (b) a later schema step | High | here | `[ ] (a)  [ ] (b)  [ ] defer` — no recommendation recorded; (a) re-opens 3b-2/3b-4 evidence, (b) competes with WP 17 S6a for v9 | `[ ]` |
| OB-WP8-06 | D-3c-2: confirm the five register choices incl. whether `releasedOn` is the R-21 reference-row time | Medium | here | `[ ] confirm  [ ] change: …  [ ] defer` | `[ ]` |
| OB-WP8-07 | D-3c-3: bundle the release and reference JSON as app assets | Medium | here | `[ ] bundle now  [ ] not until 3c-2  [ ] defer` | `[ ]` |
| OB-WP8-08 | D-3c-5: label kinds for the R-27 CHECK (register recommends anatomy, pattern, equipment, attribute value) | Low | here | `[ ] approve  [ ] change: …  [ ] defer` | `[ ]` |
| OB-WP8-09 | D-3c-6: confirm or reverse the merge of the pure-domain 3c stream `fea71c8` | Medium | 2D-6 | `[ref]` | `[ ]` |
| OB-WP8-10 | Approve the stage 3c sub-breakdown (2.00) | Medium | 2D-6 | Approved (2D-6) | 2026-11-07 |
| OB-WP8-11 | Confirm each `accepted-gaps.json` entry (6) as an owner decision | Low | here | `[ ] confirm all six  [ ] change: …  [ ] defer` | `[ ]` |
| OB-WP11-01 | WP 11 start, 7.0 breakdown, TRN-027/028 scope | Medium | 2D-6 | Approved (2D-6) | 2026-11-07 |
| OB-WP11-02 | GOL-012 thresholds (OQ-15): 28 days; food logged 80 % of days; 90 % of energy verified or user-entered; weight on 3 days/week; plus accepted energy provenances and weakest-7-day-block rule | Medium | here | `[ ] sign the proposed thresholds and rules  [ ] change: …  [ ] defer` — register recommends the proposed figures with a Settings status line | `[ ]` |
| OB-WP11-03 | Confirm or reverse WP 11 plan decisions 2–9, 11, 12 taken under delegated authority (3(a) adds a read-only method to closed WP 4; 11(a) adds the NUT-019 badge to closed WP 5 screens) | Medium | here | `[ ] confirm all  [ ] reverse: …  [ ] defer` | `[ ]` |
| OB-WP12-01 | Accounts, backup and sync backend (ADR-0012 options A/B/C; OQ-08 sign-in; TD-21, DAT-008 authorisations) | Low | here | `[ ] option A  [ ] B  [ ] C  [ ] defer` — ADR recommendation as recorded there | `[ ]` |
| OB-WP13-01 | Health platform integration scope, package and verification devices (ADR-0013) | Low | here | `[ ] approve scope: …  [ ] defer` | `[ ]` |
| OB-WP14-01 | Store signing secrets and `release` environment (deployment rule) | High | here | `[ ] provisioned (date)  [ ] not yet` | `[ ]` |
| OB-WP14-02 | First release version and tag | Medium | here | `[ ] version: … tag: …  [ ] defer` | `[ ]` |
| OB-WP14-03 | Store listings | Medium | here | `[ ] provided  [ ] defer` | `[ ]` |
| OB-WP14-04 | Beta distribution accounts (Play Console, Apple Developer, App Store Connect key) | Medium | here | `[ ] opened  [ ] defer` | `[ ]` |
| OB-WP14-05 | Opt-in crash reporting | Low | here | `[ ] yes: …  [ ] no  [ ] defer` | `[ ]` |
| OB-WP14-06 | Test-build certificate approach (cached debug keystore vs repository-secret keystore) | Medium | here / LIM-002 | `[ ] keep cache approach  [ ] secret keystore  [ ] defer` | `[ ]` |
| OB-WP14-07 | Run the device checklist on Android and iPhone | Medium | Part 5.2 | `[ref]` | `[ ]` |
| OB-WP14-08 | NUT-023 source schema (general form) | Low | here | `[ ] decide: …  [ ] defer` | `[ ]` |
| OB-WP14-09 | WP 14 acceptance | Medium | 2D-6 | `[ref]` | `[ ]` |
| OB-WP15-01 | Custom-food serving entry units | Medium | 2B-2 | Decided: excluded from WP 15 (2B-2 option b) | 2026-11-07 |
| OB-WP15-02 | Spec revision 1.4 | Medium | 2E-1 | Approved (2E-1) | 2026-11-07 |
| OB-WP15-03 | Imperial entry (OQ-02) | Medium | 2E-2 | Decided: metric only for v1 (2E-2) | 2026-11-07 |
| OB-WP15-04 | Milligram entry | Low | 2E-3 | Decided: hidden (2E-3) | 2026-11-07 |
| OB-WP15-05 | WP 15 acceptance | Medium | 2B-3 | Accepted with conditions on Baseline C (2B-3) | 2026-11-07 |
| OB-WP17-01 | 9.00 allocation | High | 2C-1 | Approved (2C-1) | 2026-11-07 |
| OB-WP17-02 | S3b-ii | Low | 2C-2 | Decided: stays in WP 17 (2C-2) | 2026-11-07 |
| OB-WP17-03 | S4d | Low | 2C-3 | Decided: S4 accepted without S4d; S4d allocated and open (2C-3) | 2026-11-07 |
| OB-WP17-04..08 | D-3..D-7 | Low/Medium | 2C-4 | All decided (2C-4): editable seed recipes; catalogue draft approved, reviewer the owner; no density; no images; CSV out of scope | 2026-11-07 |
| OB-WP17-09 | S3/S4 acceptance | Medium | 2C-7 | Accepted on Baseline C with conditions (2C-7) | 2026-11-07 |
| OB-PROG-01 | Agent reviews as acceptance | Medium | 2D-5 | Approved, option B (2D-5) | 2026-11-07 |
| OB-PROG-02 | Actions allowance | High | 2D-1 | Resolved: spending limit; repository made public (2D-1) | 2026-11-07 |

## Part 3 — Application testing programme

Application at the release candidate (`app/` tree of `28b67b3`, branch `claude/campaign-2026-11-07`), Flutter 3.47, production database schema v7. No results are recorded; every outcome is for the owner or a named tester to enter. **OPTIONAL rule:** a test marked OPTIONAL names the owner decision it depends on. Its code is in the release candidate, so run it and record the outcome; the outcome counts for release regression (G4) in every case, and for the named work package's acceptance only once that decision is approved. **CONDITIONAL rule:** a CONDITIONAL test needs equipment or accounts not yet provided; record BLOCKED with the reason until they are. The 3b-9 timing subsection in section 10 applies only when stage 3b is under acceptance (Part 2A) and needs the harness from the WP 8 branch.

### How to execute

Use a physical Android phone for sections 1 to 12 and 14 to 18 unless a test says otherwise; iOS tests (section 13 and the iOS parts of 17 and 18) are conditional on a signed iOS build, because CI only produces an unsigned simulator build and device signing is not configured (WP 14). Install the debug test build from the README, start from a fresh install unless a test names its own preconditions, and keep metric units (the default). Work through each test in order within a section; a test's Preconditions name any earlier test it needs. For every test: follow the steps, write what you saw in **Actual result**, tick exactly one **Outcome** box (PASS, FAIL, BLOCKED with the reason in Actual result, or NOT TESTED), attach evidence (a screenshot, log or CI run id) and enter a defect reference for every FAIL. Control names in backticks (for example `portion-log`) are the widget keys in the code and identify the control; the visible label is given where it is stable. A test marked **OPTIONAL** names the decision it depends on; run it and record the outcome (see the OPTIONAL rule above). Tests marked **CONDITIONAL** need equipment or accounts the owner has not yet provided; record BLOCKED until they exist. Test ids are T-section-number; requirement ids refer to `docs/wp0/D04-product-requirements-baseline.md`, calculation examples E01 to E49 to `docs/nutrition-calculation-spec.md`, and WP numbers to `docs/wp0/D06-work-package-roadmap.md`. Results are evidence for the owner's acceptance decisions; this document does not accept any work package.

#### Test session record (fill once per session)

| Item | Value |
|---|---|
| Tester / date | |
| Device (maker, model, RAM) | |
| OS and version | |
| Build (file name, commit, debug / profile / release) | |
| Network state | |
| Defect register used | |

### Contents

| # | Section | Tests | Optional |
|---|---|---|---|
| 1 | [Installation and startup](#s01) | 8 | 0 |
| 2 | [Navigation and application shell](#s02) | 8 | 0 |
| 3 | [Nutrition and food management](#s03) | 19 | 2 |
| 4 | [Recipes and serving quantities](#s04) | 14 | 1 |
| 5 | [Training and workout management](#s05) | 16 | 2 |
| 6 | [Progress tracking](#s06) | 11 | 0 |
| 7 | [Goals and planning](#s07) | 11 | 0 |
| 8 | [Body metrics](#s08) | 10 | 0 |
| 9 | [Data integrity and persistence](#s09) | 11 | 0 |
| 10 | [Schema migration and upgrade behaviour](#s10) | 11 | 4 |
| 11 | [Physical-device performance](#s11) | 9 | 0 |
| 12 | [Android verification](#s12) | 13 | 0 |
| 13 | [iOS verification](#s13) | 9 | 0 |
| 14 | [UI/UX and accessibility](#s14) | 10 | 0 |
| 15 | [Recovery and resilience](#s15) | 9 | 0 |
| 16 | [Regression testing](#s16) | 12 | 0 |
| 17 | [Cross-platform consistency](#s17) | 7 | 0 |
| 18 | [Release installation and final smoke testing](#s18) | 9 | 0 |
| | **Total** | **197** | **9** |

<a id="s01"></a>

### 1. Installation and startup

Android debug build from the rolling `debug-latest` release (README). Release (signed) installation is section 18; iOS is section 13.

#### Tests

##### T-01-01 — Download the Android test build and verify its checksum
- **Objective:** Confirm the published test APK is the file that CI built.
- **Traces to:** GEN-001, GEN-010 · WP 1, WP 14 · README / `debug-latest` release
- **Preconditions:** Android phone; a computer or the phone's browser; network on.
- **Steps:**
  1. Open the `debug-latest` release linked in README.md.
  2. Download `RepForge-debug-arm64-v8a.apk` (or `RepForge-debug-universal.apk` if unsure of the ABI) and the `SHA256SUMS` asset.
  3. Compute the SHA-256 of the downloaded APK and compare it with the line in `SHA256SUMS`.
- **Expected result:** Both files download; the computed SHA-256 equals the published value. The release page states that these are debug builds for testing.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-01-02 — Install the APK and first launch
- **Objective:** Confirm the app installs and reaches the Home screen.
- **Traces to:** GEN-001 · WP 1, WP 4 · `/home`
- **Preconditions:** No RepForge installed (or app data cleared). Unknown-source installs allowed for the installing app.
- **Steps:**
  1. Open the APK and accept the Android unknown-source warning.
  2. Install, then open RepForge.
  3. Note the time from tap to a usable Home screen (not a measurement; see T-11-01).
- **Expected result:** The app installs and opens on Home with the brand app bar, a Settings icon and five bottom tabs (Home, Train, Fuel, Track, Goals). No sign-in or account screen appears. No crash or error dialog.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-01-03 — First-run empty states
- **Objective:** Confirm a fresh install shows honest empty states and invents no data.
- **Traces to:** GEN-006, UXD-003 · WP 4 · `/home`
- **Preconditions:** Fresh install, nothing logged.
- **Steps:**
  1. On Home, look at the Fuel panel (`nutrition-empty`), the Training panel (`training-empty`), the Body panel (`latest-weight`, `weight-count`) and Recent activity (`activity-empty`).
  2. Open Fuel, Track and Goals (`goals-empty`) in turn.
- **Expected result:** Each panel shows an empty state, not a zero or a made-up value. Latest weight reads a dash (—). Fuel shows "Nothing logged.". Goals shows its empty state with the "Set a goal" actions.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-01-04 — First-run defaults
- **Objective:** Record the defaults a new user gets.
- **Traces to:** GEN-003, GEN-012, TRN-020 · WP 4 · `/settings`
- **Preconditions:** Fresh install.
- **Steps:**
  1. Tap the Settings icon (`open-settings`).
  2. Read Units (`units-choice`), Theme (`theme-choice`), Effort scale (`exertion-choice`), Week starts on (`week-start-choice`), default rest and the Rest timer notifications switch.
- **Expected result:** Units Metric; Effort scale RPE; Week starts on Monday; default rest 90 s; rest notifications off; no daily targets set; theme follows the system setting by default (GEN-012(1)). Known at 28b67b3: the code's default theme is Dark, so this expectation may not be met; record what is shown, and if it differs raise it against LIM-009 (Part 6.5) for the owner's disposition rather than waiving it here.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-01-05 — Start with no network
- **Objective:** Confirm the app starts and is usable offline.
- **Traces to:** GEN-002, DAT-001 · WP 4, WP 5 · `/home`
- **Preconditions:** Installed app. Put the phone in airplane mode.
- **Steps:**
  1. Force-stop RepForge.
  2. Open it with airplane mode on.
  3. Open every tab.
- **Expected result:** Home appears with no error. All five tabs open. No screen blocks on a missing network; seed recipes and the exercise library are present (see T-04-12 and T-05-01).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-01-06 — Update over an existing install keeps data
- **Objective:** Confirm a newer test build installs over an older one without losing data.
- **Traces to:** DAT-007, GEN-015 · WP 14 · README "Test-build certificate"
- **Preconditions:** An older `debug-latest` build installed with some data (a weight, a food entry). A newer APK downloaded.
- **Steps:**
  1. Note what is logged (weight, one food entry, one setting changed).
  2. Install the newer APK over the old one without uninstalling.
  3. Open the app and check the noted data.
- **Expected result:** Installation succeeds as an update and every noted item is present. If Android refuses (signature mismatch because the cached test certificate was evicted), record BLOCKED, back up first (T-09-03), uninstall once and use T-15-01.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-01-07 — Uninstall and reinstall
- **Objective:** Confirm local-first behaviour: removing the app removes its data and nothing is restored from a server.
- **Traces to:** GEN-009, DAT-001, DAT-009 · WP 3 · `/home`
- **Preconditions:** App installed with data. A backup file exported first (T-09-03).
- **Steps:**
  1. Uninstall RepForge.
  2. Reinstall the APK.
  3. Open the app and the Settings screen.
- **Expected result:** The app starts in first-run state, with no account prompt and no previously logged data. (Restoring the backup is T-15-01.)
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-01-08 — Developer build from source
- **Objective:** Confirm the README build instructions work.
- **Traces to:** GEN-001 · WP 1 · README "Build and test"
- **Preconditions:** Flutter 3.47.9 (`app/.fvmrc`); Android SDK with JDK 17+. Repository at the commit under test.
- **Steps:**
  1. From `app/` run: `flutter pub get --enforce-lockfile`.
  2. Run `dart run build_runner build --delete-conflicting-outputs`.
  3. Run `dart format .` and `flutter analyze --fatal-infos`.
  4. Run `flutter build apk --debug` and install the result.
- **Expected result:** All commands finish without error; analyze reports no issues; the built APK installs and opens on Home.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

<a id="s02"></a>

### 2. Navigation and application shell

Router: `app/lib/app/router.dart`. Five tabs (Home `/home`, Train `/train`, Fuel `/fuel`, Track `/track`, Goals `/goals`); Settings `/settings` is pushed from the app bar.

#### Tests

##### T-02-01 — The five tabs open their root screens
- **Objective:** Confirm each bottom-navigation tab leads to its documented root.
- **Traces to:** UXD-006 · WP 4 · `/home`, `/train`, `/fuel`, `/track`, `/goals`
- **Preconditions:** Fresh or populated install.
- **Steps:**
  1. Tap each tab in turn: `nav-home`, `nav-train`, `nav-fuel`, `nav-track`, `nav-goals`.
  2. For each, note the screen title and the highlighted tab.
- **Expected result:** Home shows the dashboard; Train shows the exercise library with Start empty workout, New exercise, Workouts, History and Schedule; Fuel shows the diary with Log food, Saved meals, Recipes and Meal plan; Track shows the measurements home; Goals shows goals and summaries. The selected tab is highlighted.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-02-02 — Each tab keeps its place
- **Objective:** Confirm switching tabs does not lose position inside a tab.
- **Traces to:** UXD-006 · WP 4 · tab shell
- **Preconditions:** Populated install.
- **Steps:**
  1. In Train open Workouts (`open-plans`).
  2. Switch to Fuel and open Recipes (`open-recipes`).
  3. Switch back to Train, then to Fuel.
- **Expected result:** Train returns to the Workouts list and Fuel returns to the Recipes list, as left.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-02-03 — Re-tapping the selected tab returns to its root
- **Objective:** Confirm the tab reset behaviour.
- **Traces to:** UXD-006 · WP 4 · tab shell
- **Preconditions:** As above.
- **Steps:**
  1. In Fuel, open Recipes.
  2. Tap the Fuel tab again.
- **Expected result:** Fuel returns to the diary root.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-02-04 — Settings reachable from every tab; back returns
- **Objective:** Confirm Settings opens from the app bar everywhere and Back returns to where the user was.
- **Traces to:** UXD-006 · WP 4 · `/settings`
- **Preconditions:** Populated install.
- **Steps:**
  1. On each of the five tabs tap the Settings icon (`open-settings`).
  2. Press the system Back button/gesture.
- **Expected result:** Settings opens each time (bottom bar hidden) and Back returns to the same tab and screen.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-02-05 — Back never exits from a nested screen
- **Objective:** Confirm system back behaves consistently.
- **Traces to:** UXD-006 · WP 4 · all pushed routes
- **Preconditions:** Populated install.
- **Steps:**
  1. Open Fuel > Recipes > a recipe > Edit; press Back until the diary.
  2. Open Train > Workouts > New workout; press Back.
  3. Open Goals > Training analytics; press Back.
  4. On Home press Back once.
- **Expected result:** Each Back moves up exactly one level. The app is left only from a tab root (Android Back on Home sends the app to the background/exits as the platform does).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-02-06 — Every screen is reachable in three taps from a tab root
- **Objective:** Check the navigation depth claim.
- **Traces to:** UXD-006(1) · WP 4, WP 5, WP 7, WP 9, WP 10, WP 11 · all routes in `router.dart`
- **Preconditions:** Populated install (at least one recipe, plan, session, reading and goal).
- **Steps:**
  1. Starting from the named tab root, count taps to reach each screen: Train: Workouts, History, Schedule, a split, an exercise detail; Fuel: Log food (`log-food`), Saved meals, Recipes, Meal plan, Weekly summary (`open-week`), Scan (`log-food` then `scan-barcode`); Track: Add measurements, Progress summary, Compare, one measurement type; Goals: each of Weekly summary, Compare periods, Training analytics, Recomposition, Target history, a goal editor; Settings: Backup and restore, Owner Actions.
- **Expected result:** Each screen is reachable in 3 taps or fewer from its tab root (Settings pages from the app bar). Record any that need more.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-02-07 — Home dashboard follows data changes
- **Objective:** Confirm the dashboard reflects new data without a restart.
- **Traces to:** NUT-015, BCM-001 · WP 4 · `/home`
- **Preconditions:** Fresh install.
- **Steps:**
  1. On Home note Latest weight and the Fuel panel.
  2. Track: log 83.2 kg (`log-weight`, `field-weight`, `save-measurements`).
  3. Settings: set calories 2100 and Save targets.
  4. Fuel: log a food (see T-03-01).
  5. Return to Home.
- **Expected result:** Home shows 83.2 for latest weight with an entry count of 1, and "570 of 2100" once T-03-01 food is logged. Nothing needed a restart.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-02-08 — Owner Actions workspace is reachable and records a status
- **Objective:** Confirm the in-app delivery workspace opens and keeps a status change.
- **Traces to:** n/a (delivery tooling) · WP 14 · `/settings/owner-actions`
- **Preconditions:** Any install.
- **Steps:**
  1. Settings > Owner Actions & Delivery Blockers (`open-owner-actions`); read the summary (`blockers-summary`).
  2. Use the filters (`blockers-filter-status`, `-priority`, `-wp`, `-category`) and Clear filters.
  3. Open `OB-WP8-01` (`blocker-row-OB-WP8-01`). Choose "In progress" (`blocker-status-choice`), type a note (`blocker-note-field`), tap Save (`blocker-save-status`).
  4. Force-stop and reopen; open the same item.
- **Expected result:** "Status saved" appears; after restart the status, note and a change-history entry ("Changed …") are still shown.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

<a id="s03"></a>

### 3. Nutrition and food management

Calculation reference: `docs/nutrition-calculation-spec.md` rev 1.3 (approved), examples E01–E41. Foods used: Oats 380 kcal, P 13, C 60, F 7, fibre 10 per 100 g; Bread 250 kcal, P 9, C 45, F 3, fibre 6 per 100 g with serving "1 slice = 35 g"; Chicken 120 kcal, P 20, C 0, F 2 per 100 g, fibre blank. Create these as custom foods (Fuel > Log food > New food). Not covered because no control exists in the code at 28b67b3: editing or deleting a custom food (NUT-008), copying an entry to another date (NUT-012(2)).

#### Tests

##### T-03-01 — Create a custom food and log 150 g (core calculation)
- **Objective:** Verify per-100 g scaling: 380 kcal per 100 g x 150 g = 570 kcal.
- **Traces to:** NUT-002, NUT-004, NUT-007, NUT-010, NUT-017 (E01) · WP 5 · `/fuel`, `/fuel/new-food`
- **Preconditions:** Fresh install.
- **Steps:**
  1. Fuel > Log food (`log-food`) > New food (`new-food`).
  2. Enter name `Test oats`, kcal 380, protein 13, carbs 60, fat 7 (`food-name`, `food-kcal`, `food-protein`, `food-carbs`, `food-fat`). Save (`food-save`).
  3. The portion sheet opens for the new food: choose Custom amount if needed and enter 150 (`portion-amount`). Check the preview (`portion-preview`).
  4. Tap Log (`portion-log`).
- **Expected result:** Preview and diary row show 570 kcal. Protein 19.5 g, carbs 90 g, fat 10.5 g (day tiles show whole numbers: P 20, C 90, F 11). Fibre was not entered and is shown as not available, not 0.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-03-02 — Daily target and remaining calories
- **Objective:** Verify the target comparison and persistence.
- **Traces to:** GOL-001, NUT-015 · WP 4, WP 5 · `/settings`, `/fuel`, `/home`
- **Preconditions:** T-03-01 done.
- **Steps:**
  1. Settings: enter 2100 in calories (`target-calories`), Save targets (`save-targets`); wait for "Targets saved".
  2. Open Fuel and Home.
  3. Force-stop and reopen.
- **Expected result:** Home shows "570 of 2100"; the Fuel calories tile reads "Calories left" with 1530. Both survive the restart.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-03-03 — Custom food validation limits
- **Objective:** Verify per-100 limits and unknown vs zero handling.
- **Traces to:** DAT-002, GEN-006, NUT-021 (E17–E21) · WP 5 · `/fuel/new-food`
- **Preconditions:** Fuel > Log food > New food.
- **Steps:**
  1. Try to save with: energy blank; energy 901; protein 101; fat -1.
  2. Save a food with name `Macro blank`, energy 300 and the macros left blank.
  3. Save a food with name `Zero protein`, energy 100, protein 0.
  4. Log 100 g of each and read the nutrient lines.
- **Expected result:** Each invalid value is refused with a message beside the field and nothing is saved. `Macro blank` saves; its macros show as not available (unknown). `Zero protein` shows protein 0 g (known zero).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-03-04 — Unknown nutrients stay unknown in totals
- **Objective:** Verify an unknown nutrient is never turned into 0 and the day total counts unknowns.
- **Traces to:** NUT-021, GEN-006 (E08, E10, E11) · WP 5 · `/fuel`
- **Preconditions:** Chicken created with fibre blank.
- **Steps:**
  1. Log 50 g of Chicken.
  2. Read the day tiles and the entry.
- **Expected result:** Entry shows 60 kcal and protein 10 g. Fibre for the day is shown as not available / unknown, never 0, and any "unknown" marker counts the entries that did not know it.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-03-05 — Amount validation and precision
- **Objective:** Verify amounts must be positive and are stored to 0.1.
- **Traces to:** DAT-002, NUT-010 (E04, E05) · WP 5 · portion sheet
- **Preconditions:** Oats exists.
- **Steps:**
  1. Open Oats; enter 0 as the amount and try to log.
  2. Enter 12.36 (the field may stop at one decimal) and log.
  3. Open the diary entry (`entry-<id>`) and read the amount.
- **Expected result:** 0 is refused with "Enter an amount greater than zero." The logged amount is never finer than 0.1 g (12.3 g or 12.4 g, never 12.36 g).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-03-06 — Named servings (slice arithmetic)
- **Objective:** Verify serving multiples convert to grams and scale.
- **Traces to:** NUT-009, NUT-010 (E06, E07) · WP 5 · `/fuel/new-food`, portion sheet
- **Preconditions:** None.
- **Steps:**
  1. Create `Bread`: 250 kcal, P 9, C 45, F 3, fibre 6 per 100 g; add a serving (`serving-label-0` = `slice`, `serving-amount-0` = 35).
  2. In the portion sheet choose the slice serving and enter 2 (`portion-servings`); log.
  3. Log a second entry of 1.5 slices.
- **Expected result:** 2 slices = 70 g = 175 kcal. 1.5 slices = 52.5 g = 131.25 kcal stored, displayed as 131.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-03-07 — Rename a meal
- **Objective:** Verify meal names can be renamed and apply to existing entries.
- **Traces to:** NUT-011 · WP 7 · `/settings`, `/fuel`
- **Preconditions:** At least one entry logged under Snacks.
- **Steps:**
  1. Settings > Meals: rename Snacks to `Pre-workout` (`meal-label-snack`); Save meal names (`save-meals`).
  2. Open Fuel; log a new food under the renamed meal (`portion-meal`).
- **Expected result:** "Meal names saved" appears. Existing and new entries are shown under "Pre-workout".
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-03-08 — Edit and delete a diary entry
- **Objective:** Verify edits update totals immediately.
- **Traces to:** NUT-012(1) · WP 5 · `/fuel`
- **Preconditions:** Oats 150 g logged (570 kcal).
- **Steps:**
  1. Tap the entry (`entry-<id>`), change the amount to 200 (`edit-amount`), Save changes (`edit-save`).
  2. Check totals on Fuel and Home.
  3. Open it again, change the meal (`edit-meal`), save.
  4. Open it and Delete entry (`edit-delete`).
- **Expected result:** At 200 g the entry and day total read 760 kcal at once (380 x 2). Moving the meal moves the row. After deletion totals return to 0 and Home agrees.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-03-09 — Saved meal: save once, log again, delete later
- **Objective:** Verify a saved meal logs its saved quantities and later changes do not alter old entries.
- **Traces to:** NUT-013 · WP 5 · `/fuel/saved-meals`
- **Preconditions:** Three foods logged today.
- **Steps:**
  1. On Fuel save the three logged items as a meal named `Breakfast set` (`save-meal-name`, `save-meal-confirm`).
  2. Fuel > Saved meals (`open-saved-meals`) > Log this meal (`log-meal-<id>`).
  3. Delete the saved meal (`delete-meal-<id>`).
- **Expected result:** Logging adds three new entries with the saved quantities. After deleting the saved meal all existing entries are unchanged.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-03-10 — Date navigation
- **Objective:** Verify the diary is per day and navigation is correct.
- **Traces to:** NUT-001 · WP 5 · `/fuel`
- **Preconditions:** Entries on today and yesterday.
- **Steps:**
  1. Tap Previous day (`day-previous`) and Next day (`day-next`).
  2. Tap Today (`day-today`).
  3. Log a food while viewing yesterday.
- **Expected result:** Each day shows only its own entries and totals; the label reads Today or the weekday and date. The yesterday log appears on yesterday and not on today.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-03-11 — Weekly nutrition summary and averages
- **Objective:** Verify averages count logged days only.
- **Traces to:** NUT-016, NUT-001 (E33, E34) · WP 5 · `/fuel/week`
- **Preconditions:** A food of 400 kcal per 100 g (create it). Current week with no other entries.
- **Steps:**
  1. Log 450 g (1800 kcal) on one day and 550 g (2200 kcal) on another day in the current week.
  2. Fuel > Weekly summary (`open-week`).
  3. Read `week-avg-kcal` and the days-logged figure.
- **Expected result:** Average energy is 2000 kcal; the five unlogged days are not counted. Macros that were not entered show as unknown ("N days unknown"), not 0.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-03-12 — Provenance labels and weakest-label totals
- **Objective:** Verify provenance is visible and a total carries the weakest label.
- **Traces to:** NUT-018, NUT-019, GEN-005 (E22–E24) · WP 5, WP 11 · `/fuel`, `/fuel/week`
- **Preconditions:** Custom foods exist (user-entered). Network on for one online food.
- **Steps:**
  1. Open a custom food in the portion sheet and read its provenance label.
  2. Log it with an Open Food Facts food (Log food > search `yoghurt` > log).
  3. Read the day total label (`day-total-provenance`) and the weekly one (`week-total-provenance`).
- **Expected result:** Custom foods are labelled user-entered and never verified. The day and week totals show the weakest label of the entries they include (user-entered here).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-03-13 — Online search and source line
- **Objective:** Verify Open Food Facts results, local caching and the source note.
- **Traces to:** NUT-005, NUT-023(2) · WP 5, WP 14 · `/fuel/search`
- **Preconditions:** Network on.
- **Steps:**
  1. Log food > type `greek yoghurt` in search (`food-query`).
  2. Open an online result and read the source line under the name.
  3. Log 100 g, reopen the same food from search.
- **Expected result:** Results appear under local and online sections. The unsaved result reads "Source: Open Food Facts · <code> · not saved yet"; after logging it reads "... imported <today's date>". The food now also appears in local results.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-03-14 — Search offline
- **Objective:** Verify local search and logging work without a network.
- **Traces to:** GEN-002, NUT-005 · WP 5 · `/fuel/search`
- **Preconditions:** A food already logged earlier. Airplane mode on.
- **Steps:**
  1. Log food > search the earlier food name.
  2. Log it again.
  3. Search for a name never used.
- **Expected result:** The cached food is listed at once and can be logged. The online section shows an offline state (`online-failure`) without blocking. An unknown name returns no local result and offers New food.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

#### OPTIONAL — Fuel add-flow additions (WP 17 S3)

Counts for WP 17 acceptance only if the owner approves the allocation (OB-WP17-01, Decision 2C-1) and puts S3 under acceptance (OB-WP17-09, 2C-7); run and record regardless (release regression). Frequent foods, last-quantity pre-fill and saved meals in recents (S3b-ii, OB-WP17-02) are not implemented and are not tested.

##### T-03-15 — OPTIONAL — Recent items in the add flow
- **Objective:** Verify the recents list.
- **Traces to:** NUT-014 (subset) · WP 17 S3b-i · `/fuel/search`
- **Preconditions:** OPTIONAL for WP 17 acceptance (OB-WP17-01, Decision 2C-1); the code is in the release candidate, so run it for release regression and record the outcome either way. At least 11 distinct foods/recipes logged.
- **Steps:**
  1. Open Log food with the query empty (`search-recent`).
  2. Log a different item, return to Log food.
- **Expected result:** At most 10 distinct foods and recipes, most recent first, the newly logged item on top; deleted items are absent.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-03-16 — OPTIONAL — Pick from library
- **Objective:** Verify recipes and saved meals can be logged from the add flow.
- **Traces to:** RCP-012 reuse · WP 17 S3a · `/fuel/search`
- **Preconditions:** OPTIONAL for WP 17 acceptance (OB-WP17-01, Decision 2C-1); the code is in the release candidate, so run it for release regression and record the outcome either way. One recipe and one saved meal exist.
- **Steps:**
  1. Log food > Pick from library > recipe (`search-pick-recipe`); choose a recipe, log 1 portion.
  2. Log food > Pick from library > saved meal (`search-pick-saved-meal`); Log this meal.
- **Expected result:** Each logs to the selected day and returns to Fuel; no duplicate entry is created.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

#### Entry units kg and l (WP 15 stages 1–2, implemented; spec revision 1.4 pending Decision 2E-1)

Implemented WP 15 scope; counts for WP 15 acceptance once specification revision 1.4 is approved (OB-WP15-02, Decision 2E-1) and WP 15 is put under acceptance (OB-WP15-05, 2B-3); run and record regardless. Not tested: custom-food serving entry units (OB-WP15-01), milligram entry (OB-WP15-04), imperial entry (OB-WP15-03).

##### T-03-17 — 0.25 kg is stored as 250 g
- **Objective:** Verify exact kg conversion on the portion sheet.
- **Traces to:** NUT-022(1), GEN-004 (E42, E43) · WP 15 · portion sheet
- **Preconditions:** Implemented in the candidate (WP 15 stages 1–2); run regardless of the pending specification approval (Decision 2E-1). Oats exists.
- **Steps:**
  1. Open Oats; Custom amount; choose kg (`portion-entry-unit`); enter 0.25.
  2. Read the helper (`portion-canonical`) and the preview; log.
  3. Switch the unit to g and back to kg before logging.
- **Expected result:** Helper reads "= 250 g"; preview 950 kcal (380 x 2.5); the entry shows 250 g. Switching converts the typed text (250 g and 0.25 kg). 1 kg gives exactly 1000 g.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-03-18 — Litres for a per-100 ml food and no mass/volume mixing
- **Objective:** Verify l conversion and that a ml food never offers g or kg.
- **Traces to:** NUT-022(2) (E47, E48) · WP 15 · portion sheet
- **Preconditions:** Implemented in the candidate (WP 15 stages 1–2); run regardless of the pending specification approval (Decision 2E-1). Create `Milk`: 64 kcal, P 3.4, C 4.8, F 3.6 per 100 ml.
- **Steps:**
  1. Open Milk; Custom amount; read the unit choices.
  2. Choose l, enter 0.5; log.
- **Expected result:** Only ml and l are offered. 0.5 l = 500 ml = 320 kcal, P 17, C 24, F 18; fibre unknown.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-03-19 — Ingredient quantity in kg
- **Objective:** Verify unit entry in a recipe ingredient.
- **Traces to:** NUT-022(1) · WP 15 · ingredient sheet
- **Preconditions:** Implemented in the candidate (WP 15 stages 1–2); run regardless of the pending specification approval (Decision 2E-1). A recipe being edited.
- **Steps:**
  1. Add ingredient (`add-ingredient`); pick Oats; choose kg (`ingredient-entry-unit`); enter 0.2; Save (`ingredient-save`).
- **Expected result:** The ingredient is stored and shown as 200 g (`ingredient-canonical` helper "= 200 g").
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

<a id="s04"></a>

### 4. Recipes and serving quantities

Reference: spec §9, examples E26–E32, E37–E41. 22 starter recipes are imported once at first launch from `assets/seed/legacy_recipes.json`, labelled estimated.

#### Tests

##### T-04-01 — Create a recipe and read per-portion nutrition
- **Objective:** Verify recipe nutrition is computed from ingredients: 200 g oats x 3.8 / 2 portions = 380 kcal per portion.
- **Traces to:** RCP-001, RCP-002, RCP-006 · WP 7 · `/fuel/recipes/new`
- **Preconditions:** Oats food exists (or create it from the picker).
- **Steps:**
  1. Fuel > Recipes (`open-recipes`) > New recipe (`new-recipe`).
  2. Name `IT stew` (`recipe-name-field`), portions 2 (`recipe-portions-field`).
  3. Add ingredient (`add-ingredient`) > Oats > 200 g > Save (`ingredient-save`).
  4. Save the recipe (`recipe-save`) and read the detail.
- **Expected result:** Detail shows 380 kcal, P 13 g, C 60 g, F 7 g per portion, with its provenance label.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-04-02 — Log 1.5 portions
- **Objective:** Verify portion logging: 380 x 1.5 = 570 kcal.
- **Traces to:** RCP-012 (E30) · WP 7 · recipe log sheet
- **Preconditions:** T-04-01 done.
- **Steps:**
  1. Open the recipe > Log (`recipe-log`).
  2. Press + once (`log-portions-inc`) to reach 1.5 and Log (`log-submit`).
  3. Open Fuel.
- **Expected result:** Snackbar "Logged 1.5 portions". Diary row: 570 kcal and "1.5 portions · P 20 · C 90 · F 11".
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-04-03 — Editing a recipe does not alter earlier entries
- **Objective:** Verify snapshots are immutable.
- **Traces to:** RCP-013, RCP-008 · WP 7 · `/fuel/recipes/<id>/edit`
- **Preconditions:** T-04-02 done.
- **Steps:**
  1. Recipe > Edit (`recipe-edit`); open ingredient 0 (`ingredient-0`); change 200 to 100 g; Save ingredient and Save recipe.
  2. Read the recipe detail.
  3. Return to the Fuel diary.
- **Expected result:** The recipe now shows 190 kcal per portion. The earlier diary entry still shows 570 kcal and "1.5 portions · P 20 · C 90 · F 11".
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-04-04 — Change the portion count
- **Objective:** Verify per-portion values follow the portion count only.
- **Traces to:** RCP-008(1) (E26, E27) · WP 7 · recipe editor
- **Preconditions:** Chicken exists.
- **Steps:**
  1. New recipe `Chicken only`: 400 g Chicken, 4 portions. Read protein per portion.
  2. Edit: set portions to 5. Read again.
- **Expected result:** Protein per portion is 20 g at 4 portions and 16 g at 5 portions; kcal per portion is 120 and 96.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-04-05 — Scale a recipe without changing it
- **Objective:** Verify scaling is a view unless saved.
- **Traces to:** RCP-009 (E31) · WP 7 · recipe detail
- **Preconditions:** `Chicken only` at 4 portions.
- **Steps:**
  1. Open it > Scale (`scale-open`); mode portions (`scale-mode`); target 6 (`scale-target`).
  2. Read the chicken quantity and protein per portion.
  3. Close (`scale-close`) and reopen the recipe.
  4. Scale again and choose Save as new (`scale-save-new`) or Overwrite (`scale-overwrite`, confirm `scale-overwrite-confirm`).
- **Expected result:** Scaled view shows Chicken 600 g (x1.5) with protein per portion still 20 g, and a scaled indicator (`scaled-indicator`). Closing leaves the saved recipe at 400 g / 4 portions. Save as new creates a second recipe; Overwrite changes the original only after confirmation.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-04-06 — Incomplete nutrition is flagged
- **Objective:** Verify unknown ingredient nutrients make the recipe value incomplete.
- **Traces to:** RCP-007, NUT-021 (E28) · WP 7 · recipe detail
- **Preconditions:** Oats (fibre 10) and Chicken (fibre blank) exist.
- **Steps:**
  1. New recipe: 100 g Oats + 100 g Chicken, 2 portions; save.
  2. Read per-portion values and the fibre line (`nutrition-note`).
  3. Log 1 portion and read the entry's fibre.
- **Expected result:** Per portion 250 kcal, P 16.5 g. Fibre shows a partial 5 g labelled incomplete. The logged entry's fibre is unknown (not 5, not 0).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-04-07 — Log by weight and portion weight
- **Objective:** Verify grams logging: total 1200 kcal, yield 1200 g, portion 300 g gives 4 portions; 450 g = 450 kcal.
- **Traces to:** RCP-008(2), RCP-012(2) (E32) · WP 7 · recipe editor, log sheet
- **Preconditions:** A food of 100 kcal per 100 g exists.
- **Steps:**
  1. New recipe `Weighed`: 1200 g of that food (1200 kcal), total weight 1200 (`recipe-total-weight-field`), portion weight 300 (`recipe-portion-weight-field`).
  2. Read the derived portions (`derived-portions`).
  3. Log > mode grams (`log-mode`) > 450 (`log-grams`) > Log.
- **Expected result:** Derived portions = 4. The entry is 450 kcal (1.5 portions).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-04-08 — Portion precision to two decimals
- **Objective:** Verify 1.25 portions is kept as 1.25.
- **Traces to:** NUT-017 §2.1 (E39) · WP 7 · recipe log sheet
- **Preconditions:** Custom food 400 kcal and protein 30 per 100 g. Recipe `Precise`: 100 g of it, 1 portion.
- **Steps:**
  1. Log > enter 1.25 in the portions field (`log-portions`) > Log.
  2. Read the diary row.
- **Expected result:** Row reads "1.25 portions", 500 kcal, protein 37.5 g (displayed 38); not 1.3 portions.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-04-09 — Favourites, search and filter
- **Objective:** Verify favourites and text search.
- **Traces to:** RCP-011 · WP 7 · `/fuel/recipes`
- **Preconditions:** At least three recipes.
- **Steps:**
  1. Mark one recipe favourite (`fav-<id>`).
  2. Switch on the favourites filter (`filter-favourites`).
  3. Search part of a name (`recipe-search`).
- **Expected result:** Only favourites are listed with the filter; search narrows by name; clearing both shows all.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-04-10 — Substitutions
- **Objective:** Verify an ingredient substitute changes the displayed values.
- **Traces to:** RCP-010 · WP 7 · recipe detail
- **Preconditions:** Recipe with an ingredient that has a substitute recorded.
- **Steps:**
  1. Open the recipe detail; for the ingredient choose a substitute (`sub-<id>-<n>`).
  2. Read the delta (`sub-delta`); choose Original again.
- **Expected result:** The kcal-per-portion difference is shown with a sign and returns to nothing on Original. If no recipe offers a substitute, record NOT TESTED with the reason.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-04-11 — Prepared batches
- **Objective:** Verify batch portions cannot go below zero.
- **Traces to:** RCP-015 (E41) · WP 7 · recipe detail
- **Preconditions:** A recipe exists.
- **Steps:**
  1. Record a batch of 2 portions (`record-batch`, `batch-portions`, `batch-submit`).
  2. Log from the batch: 0.75 portions (`log-batch-<id>`), then 1.25.
  3. Try to log more.
- **Expected result:** Left shows 1.25 after the first and 0 after the second (`batch-left-<id>`); a further log is refused or limited; it never goes negative. Deleting a batch asks for confirmation.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-04-12 — Starter recipes are present and estimated
- **Objective:** Verify seed recipes appear offline with the estimated label.
- **Traces to:** RCP-007(1), NUT-021 · WP 7 · `/fuel/recipes`
- **Preconditions:** Fresh install, airplane mode on.
- **Steps:**
  1. Fuel > Recipes.
  2. Open `Smoky Chicken Burrito Wrap`.
  3. Open it for editing and read `imported-note`.
- **Expected result:** 22 recipes are listed. The wrap shows declared per-portion values labelled estimated, ingredient lines as notes, fibre unknown.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-04-13 — Deleting a recipe keeps the diary
- **Objective:** Verify logged entries survive recipe deletion.
- **Traces to:** RCP-013 · WP 7 · recipe detail
- **Preconditions:** A recipe with a logged entry.
- **Steps:**
  1. Recipe > Delete (`recipe-delete`) > confirm (`recipe-delete-confirm`).
  2. Open Fuel and the entry.
- **Expected result:** The entry remains with its name and nutrients; its recipe link reads that the recipe is missing (`entry-recipe-missing`).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

#### OPTIONAL — Recipe duplicate and category filter (WP 17 S3c)

Counts for WP 17 acceptance only if the owner approves OB-WP17-01 (Decision 2C-1) and puts S3 under acceptance (OB-WP17-09, 2C-7); run and record regardless.

##### T-04-14 — OPTIONAL — Duplicate a recipe and filter by category
- **Objective:** Verify Duplicate creates a non-favourite copy and the category filter narrows the list.
- **Traces to:** RCP-011 extension · WP 17 S3c · recipe detail and list
- **Preconditions:** OPTIONAL for WP 17 acceptance (OB-WP17-01, Decision 2C-1); the code is in the release candidate, so run it for release regression and record the outcome either way. A favourite recipe with a category.
- **Steps:**
  1. Recipe > Duplicate (`recipe-duplicate`).
  2. In the list use the category chips (`recipe-category-filter`) with search and favourites.
- **Expected result:** A copy named "<name> (copy)" opens, not marked favourite. Category chips combine with search and favourites.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

<a id="s05"></a>

### 5. Training and workout management

Exercise library seed: `assets/seed/exercise_library.json` (89 exercises: 51 weighted, 13 bodyweight, 12 timed, 6 cardio, 4 distance, 3 assisted). Splits and scheduling are in section 7. Rest-timer notifications on a device are in section 12. Rest-timer survival after the process is killed (WP 17 S4d) is not implemented and is not tested.

#### Tests

##### T-05-01 — Browse, search and filter the exercise library
- **Objective:** Verify the offline library and its classification.
- **Traces to:** TRN-008, TRN-009, TRN-010, TRN-011 · WP 8 · `/train`
- **Preconditions:** Fresh install, airplane mode on.
- **Steps:**
  1. Open Train. Search `squat` (`exercise-search`); then search the alias `back squat`.
  2. Use a category chip (`filter-category-legs`), Muscle group (`filter-muscle`) and Equipment (`filter-equipment`); try Bodyweight only (`equipment-bodyweight-only`).
  3. Open `Barbell back squat` and read its category, primary and secondary muscles, equipment.
- **Expected result:** The library is present offline. Search finds `Barbell back squat` by name and by alias. Filters narrow the list and clear. Detail shows legs, quadriceps primary, secondary muscles and barbell/rack equipment.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-05-02 — All six exercise types exist
- **Objective:** Verify the data model covers every type.
- **Traces to:** TRN-001 · WP 8 · `/train/exercises/<id>`
- **Preconditions:** Seed library loaded.
- **Steps:**
  1. Open one exercise of each type and read its type: `Barbell back squat` (weighted), `Glute bridge` (bodyweight), `Assisted pull-up (machine)` (assisted), `Plank` (timed), `Sled push` (distance), `Treadmill run` (cardio).
- **Expected result:** Each opens and states the expected type.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-05-03 — Create, edit, archive and copy exercises
- **Objective:** Verify custom exercise management.
- **Traces to:** TRN-012 · WP 8 · `/train/exercises/new`, `/edit`, `/copy`
- **Preconditions:** None.
- **Steps:**
  1. Train > New exercise (`new-exercise`): name `My row` (`exercise-name-field`), type weighted (`type-weighted`), a category, a primary muscle (`primary-muscle`), Save (`exercise-save`).
  2. Open it > Edit (`exercise-edit`): rename; save.
  3. Archive it (`exercise-archive`); turn on Show archived (`show-archived`).
  4. Open `Barbell back squat` and make a copy (`copy-confirm`).
- **Expected result:** The exercise appears, is renamed, disappears from the default list when archived and reappears with Show archived. The copy is an editable custom exercise. Missing required fields show a message beside the field.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-05-04 — Build a workout plan
- **Objective:** Verify plan creation with targets.
- **Traces to:** TRN-013 · WP 9 · `/train/plans/new`
- **Preconditions:** None.
- **Steps:**
  1. Train > Workouts (`open-plans`) > New workout (`new-plan`).
  2. Name `IT leg day` (`plan-name-field`); Add exercise (`plan-add-exercise`) > `Barbell back squat`.
  3. Set sets 3, reps 5 to 5, load 60 kg, rest 60 s on the row.
  4. Save (`plan-save`).
- **Expected result:** The plan is listed with its exercise and prescription. Reordering with the move buttons (`plan-move-up-0`/`down`) changes the order. Invalid values (0 sets, reps min above max) are refused beside the field.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-05-05 — Record a session with one-tap sets, rest timer and PR
- **Objective:** Run the end-to-end training flow from the integration test as a manual script.
- **Traces to:** TRN-016, TRN-018, TRN-021, TRN-026 · WP 9 · `/train/plans`, `/train/session/<id>`
- **Preconditions:** T-05-04 done. Settings default rest 90 s.
- **Steps:**
  1. Workouts > Start on the plan (`plan-start-<id>`).
  2. The first set row is pre-filled 60 kg x 5. Tap Log set (`newset-log-<id>`) once.
  3. The rest panel appears (`rest-timer-panel`, `rest-remaining` about 1:00). Tap +15 s (`rest-extend`), then Skip (`rest-skip`).
  4. Log the same set again, skip rest.
  5. Finish (`finish-session`).
- **Expected result:** One tap logs the pre-filled set. The timer counts down from 60 s, +15 s adds 15 s, Skip hides the panel. The first set carries a personal-record badge (`pr-badge-<setId>`); the identical second set does not. Finish opens the summary (`detail-title` "IT leg day") and the workout is listed in History (`open-history`).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-05-06 — Session volume arithmetic and warm-ups
- **Objective:** Verify volume = sum of weight x reps for working sets: 80 x 5 + 80 x 4 = 720 kg, warm-ups excluded.
- **Traces to:** TRN-027, TRN-019 · WP 9, WP 11 · session screen, summary
- **Preconditions:** Empty workout started (`start-empty-session`) with `Barbell back squat` added.
- **Steps:**
  1. Log a warm-up set 40 kg x 10 (open `Type, effort, rest` details, set type warm-up).
  2. Log working sets 80 kg x 5 and 80 kg x 4.
  3. Read `session-volume`; finish; read `detail-volume`.
- **Expected result:** Volume reads 720 kg both during and after the session. The warm-up (400 kg) is not counted.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-05-07 — Set types and effort
- **Objective:** Verify warm-up/working/failure and RPE/RIR entry.
- **Traces to:** TRN-019, TRN-020 · WP 9 · set details
- **Preconditions:** Session in progress.
- **Steps:**
  1. Set the kind of a set to failure (`newset-kind-label-<id>`).
  2. Enter effort 8.5 under RPE; then 10.5 and 8.25.
  3. Settings > Effort scale (`exertion-choice`) > RIR; enter 2 and 5.5.
- **Expected result:** 8.5 (RPE) and 2 (RIR) are accepted. 10.5, 8.25 and 5.5 are refused with a message stating the range (RPE 1 to 10 in 0.5 steps; RIR 0 to 5).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-05-08 — Set fields for each exercise type
- **Objective:** Verify type-specific fields store and read back.
- **Traces to:** TRN-002 to TRN-007 · WP 8, WP 9 · session screen
- **Preconditions:** Empty workout.
- **Steps:**
  1. Add and log one set each: `Barbell back squat` 100 kg x 5; `Glute bridge` 15 reps (+ optional added load); `Assisted pull-up (machine)` 8 reps with 20 kg assistance; `Plank` 45 s; `Sled push` 20 m; `Treadmill run` 600 s, 2 km, 140 bpm.
  2. Finish and open the summary.
- **Expected result:** Each set shows only fields of its type and the values read back unchanged (load, reps, assistance, seconds, metres, duration/distance/heart rate).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-05-09 — Add, replace, remove and reorder session exercises
- **Objective:** Verify in-session exercise management.
- **Traces to:** TRN-017 · WP 9 · session screen
- **Preconditions:** Session with two exercises, one with a logged set.
- **Steps:**
  1. Add exercise (`add-exercise`).
  2. Entry menu (`entry-menu-<id>`) > Replace on the exercise with a set.
  3. Move an exercise with up/down (`entry-up-<id>`).
  4. Remove an exercise with no sets.
- **Expected result:** Replace keeps the already-logged set under the original exercise (`entry-removed-<id>` shown) and adds the new one. The order changes and survives leaving and reopening the session.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-05-10 — Session and set notes
- **Objective:** Verify notes at session and exercise level.
- **Traces to:** TRN-023 · WP 9 · session screen
- **Preconditions:** Session in progress.
- **Steps:**
  1. Edit the session note (`session-note-edit`); add an exercise note (`entry-menu-note-<id>`); add a set note (`set-note-<id>`).
  2. Finish and open the summary and History.
- **Expected result:** All notes are saved and shown in the summary and in History.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-05-11 — Edit sets in history and recompute
- **Objective:** Verify editing updates volume and records.
- **Traces to:** TRN-024(1) · WP 9 · `/train/history/<id>`
- **Preconditions:** A finished session with 80 x 5 and 80 x 4.
- **Steps:**
  1. History > open the session.
  2. Edit the 80 x 4 set (`set-edit-<id>`): change reps to 5; save (`editset-save`).
  3. Read the volume; open Goals > Training analytics.
- **Expected result:** Volume becomes 800 kg (80 x 5 x 2) in the summary and in training analytics.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-05-12 — Delete a session with undo
- **Objective:** Verify confirmation and the undo window.
- **Traces to:** TRN-024(2) · WP 9 · `/train/history/<id>`
- **Preconditions:** A finished session.
- **Steps:**
  1. Open the session and delete it, confirming.
  2. Within the undo window press Undo on the snackbar (`session-deleted-snackbar`).
  3. Delete again and let the snackbar close (about 12 s).
- **Expected result:** Delete asks for confirmation. Undo restores the session with all sets within 12 s (at least 10 s required). After it closes the session is gone from History and analytics.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-05-13 — Repeat a past workout
- **Objective:** Verify starting a session from history.
- **Traces to:** TRN-016 · WP 9 · `/train/history`
- **Preconditions:** A finished session.
- **Steps:**
  1. History > Repeat on a session (`history-repeat-<id>`).
- **Expected result:** A new session opens with the same exercises and last values pre-filled; the original is unchanged.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-05-14 — Unfinished session prompt
- **Objective:** Verify a workout left open is offered back.
- **Traces to:** GEN-015(2), TRN-016 · WP 9 · `/train`
- **Preconditions:** Session in progress with one logged set.
- **Steps:**
  1. Leave the session screen with Back without finishing.
  2. Tap Start empty workout.
- **Expected result:** A dialog (`unfinished-dialog`) offers Continue (`unfinished-continue`) or Start new (`unfinished-new`); Continue returns to the session with the set intact.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

#### OPTIONAL — Train workflow additions (WP 17 S4)

Counts for WP 17 acceptance only if the owner approves the allocation (OB-WP17-01, Decision 2C-1) and puts S4 under acceptance (OB-WP17-09, 2C-7); run and record regardless. Not tested: rest-timer survival after process death (S4d, OB-WP17-03).

##### T-05-15 — OPTIONAL — Plan duplicate, delete and save session as plan
- **Objective:** Verify plan actions leave sessions untouched.
- **Traces to:** TRN-013 · WP 17 S4a, S4b · `/train/plans`, session summary
- **Preconditions:** OPTIONAL for WP 17 acceptance (OB-WP17-01, Decision 2C-1); the code is in the release candidate, so run it for release regression and record the outcome either way. A plan and a finished session (2 working sets 80 x 5, one warm-up) exist.
- **Steps:**
  1. Duplicate the plan (`plan-duplicate-<id>`).
  2. On the session summary tap Save as plan (`detail-save-as-plan`).
  3. Delete the original plan (`plan-delete-<id>`), confirm.
  4. Open History.
- **Expected result:** The copy has a new name. The saved plan has one target set count and rep range from completed non-warm-up sets and carries no load. After deletion the session still exists with its sets.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-05-16 — OPTIONAL — Elapsed time and drag reorder
- **Objective:** Verify the session clock and reorder.
- **Traces to:** TRN-017(2) · WP 17 S4c · session screen
- **Preconditions:** OPTIONAL for WP 17 acceptance (OB-WP17-01, Decision 2C-1); the code is in the release candidate, so run it for release regression and record the outcome either way. Session with 3 exercises.
- **Steps:**
  1. Watch the elapsed display (`session-elapsed`) for 1 minute.
  2. Drag an exercise by its handle (`entry-drag-<id>`).
  3. Finish.
- **Expected result:** Elapsed time advances each second and is fixed at the end time after Finish. The new order is stored and shown after reopening.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

<a id="s06"></a>

### 6. Progress tracking

Charts and summaries on Track and Goals. Goal progress cards are in section 7. Per-muscle figures (WP 11 stage D2) are not implemented and are not tested. WP 11 stage breakdown is unapproved (OB-WP11-01); these tests verify implemented behaviour against D04 only.

#### Tests

##### T-06-01 — Weight chart with trend
- **Objective:** Verify raw points, 7-day trend and the text summary.
- **Traces to:** BCM-005, BCM-006, UXD-009 · WP 10 · `/track/site/weight`
- **Preconditions:** Fresh install.
- **Steps:**
  1. Log one weight; open Track > Weight (`site-weight`). Note the chart (`site-chart`).
  2. Log two more readings on different days (use `pick-date`); reopen.
  3. Read `chart-summary`.
- **Expected result:** With 1 reading: one point, no trend line. With fewer than 3 readings in the window no trend value is drawn. With 3 or more, raw points stay visible and a trend line appears. A text summary is shown.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-06-02 — Chart period selector and gaps
- **Objective:** Verify ranges and that gaps are not interpolated.
- **Traces to:** BCM-005 · WP 10 · `/track/site/weight`
- **Preconditions:** Readings on day 1 and day 20 only.
- **Steps:**
  1. Switch the period buttons (`period-weeks4`, `period-weeks12`, `period-year1`, `period-all`).
- **Expected result:** Each period changes the window. The days between the two readings are a gap; no values are invented.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-06-03 — Left and right on one chart
- **Objective:** Verify paired sites are distinct series.
- **Traces to:** BCM-005(1), BCM-003 · WP 10 · `/track/site/thighLeft`
- **Preconditions:** Left thigh 58 and right thigh 59.5 cm logged.
- **Steps:**
  1. Open the Left thigh chart and look for the right series.
  2. Check legend/labels.
- **Expected result:** Both sides are on one chart as two labelled series: left as circles with a solid line, right as diamonds with a dashed line.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-06-04 — Compare two dates
- **Objective:** Verify the change figure: 83.2 kg to 80.0 kg is -3.2 kg (about -3.8 %).
- **Traces to:** BCM-007 · WP 10 · `/track/compare`
- **Preconditions:** Weight 83.2 kg dated 14 days ago and 80.0 kg today.
- **Steps:**
  1. Track > Compare (`open-compare`); site weight (`compare-site`).
  2. Pick date A and date B (`compare-date-a`, `compare-date-b`).
  3. Read the change (`compare-change-abs`, `compare-change-pct`).
- **Expected result:** Both readings are shown; change -3.2 kg and about -3.8 %. Choosing a date with no reading explains the missing value and invents none.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-06-05 — Compare two periods
- **Objective:** Verify period means.
- **Traces to:** BCM-007 · WP 10 · `/track/compare?mode=periods`
- **Preconditions:** Several readings in two distinct weeks.
- **Steps:**
  1. Compare > mode Periods (`compare-mode`); choose period A and B (`compare-period-a`, `compare-period-b`).
  2. Read mean and count per period (`period-mean-<tag>`, `period-count-<tag>`).
- **Expected result:** Each period shows its mean and number of readings; the difference equals the later mean minus the earlier.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-06-06 — Progress summary over a period
- **Objective:** Verify weight change and per-site change.
- **Traces to:** BCM-008 · WP 10 · `/track/progress`
- **Preconditions:** Weight and waist readings in the last 12 weeks.
- **Steps:**
  1. Track > Progress summary (`open-progress`).
  2. Choose a period.
  3. Read weight and waist rows (`progress-weight`, `progress-waist`, `change-abs-waist`, `change-pct-waist`).
- **Expected result:** Sites with data show start, latest and change; sites without data show an explicit no-data state.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-06-07 — Training analytics: weekly volume and records
- **Objective:** Verify training totals match the logged sets.
- **Traces to:** TRN-027, TRN-028 · WP 11 · `/goals/training`
- **Preconditions:** Sessions logged this week (T-05-06: 80 x 5 + 80 x 4).
- **Steps:**
  1. Goals > Training analytics (`goals-open-training`).
  2. Read the current week (`training-weeks`) and records (`training-records`).
  3. Open the exercise (`training-exercise-<key>`).
- **Expected result:** Current-week volume reads 720 kg; warm-ups excluded; a bodyweight-only week reads 0 kg. Known Low N4 in the WP 11 record: bodyweight exercise rows may read "not enough data" on this screen; record it, do not fail the test for it. Exercise progress shows top-set and volume charts with text statements and all-time records.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-06-08 — Weekly summary
- **Objective:** Verify the combined week report.
- **Traces to:** GOL-007, NUT-016 · WP 11 · `/goals/weekly`
- **Preconditions:** Food, a session and weights logged in the week.
- **Steps:**
  1. Goals > Weekly summary (`goals-open-weekly`).
  2. Read nutrition (`weekly-nutrition`: days logged, average energy), training (`weekly-training`: sessions, sets, volume, reps, seconds, metres) and body (`weekly-body`: signed weight change).
  3. Step to the previous and next period (`weekly-period-prev`, `weekly-period-next`).
- **Expected result:** Figures agree with the diary, History and weight chart. The nutrition section is always shown; an empty week says so. The provenance label is visible (`weekly-provenance`).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-06-09 — Recomposition view
- **Objective:** Verify the three trends share a date axis.
- **Traces to:** GOL-010 · WP 11 · `/goals/recomposition`
- **Preconditions:** Weight, waist and one exercise with sets over several weeks.
- **Steps:**
  1. Goals > Recomposition (`goals-open-recomposition`).
  2. Choose the exercise (`recomposition-exercise-pick`) and range (`recomposition-range`: 4, 12, 26 weeks).
- **Expected result:** Weight, waist and strength charts are stacked on the same dates. Missing data is a gap or says not enough data.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-06-10 — Compare periods (goals)
- **Objective:** Verify the historical comparison and its notes.
- **Traces to:** GOL-009 · WP 11 · `/goals/compare`
- **Preconditions:** Data in two periods, the later one incomplete (current month).
- **Steps:**
  1. Goals > Compare periods (`goals-open-compare`).
  2. Read the table (`compare-table`) and notes (`compare-partial-note`, `compare-weight-note`).
- **Expected result:** Each measure shows earlier, later and difference or the reason it is unavailable. A partial later period is labelled partial.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-06-11 — No coaching text anywhere
- **Objective:** Verify no automated advice ships.
- **Traces to:** GOL-011, GEN-006 · WP 11 · all analytics screens
- **Preconditions:** Populated install.
- **Steps:**
  1. Read Goals, Weekly summary, Training analytics, Recomposition, Compare, Target history, Track Progress and the Settings screen, looking for recommendations, tips, "you should" or AI-generated advice.
- **Expected result:** Only descriptive figures and their basis appear; no advice or recommendation text.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

<a id="s07"></a>

### 7. Goals and planning

Goals editor: `/goals/edit/<kind>`; daily nutrition targets stay in Settings. Planning covers the Fuel meal plan and the Train split and schedule. The data-quality check for recommendations (GOL-012) has no screen and is not tested.

#### Tests

##### T-07-01 — Sessions-per-week goal, restart-proof
- **Objective:** Run the goals integration flow as a manual script.
- **Traces to:** GOL-005, GOL-008 · WP 11 · `/goals`
- **Preconditions:** Fresh install.
- **Steps:**
  1. Goals shows its empty state (`goals-empty`). Tap Sessions per week goal (`goal-set-sessionsPerWeek`).
  2. Enter 3 (`goal-target-field`) and Save (`goal-save`).
  3. Open Weekly summary (`goals-open-weekly`) and go back.
  4. Force-stop and reopen; open Goals.
- **Expected result:** The card reads "0 of 3 sessions" with "Goal saved" shown once. The weekly screen opens (`weekly-nutrition`). After restart the goal is still "0 of 3 sessions".
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-07-02 — Sessions goal progress arithmetic
- **Objective:** Verify 1 of 3 sessions is 33.3 %.
- **Traces to:** GOL-005, GOL-008 · WP 11 · `/goals`
- **Preconditions:** T-07-01 goal set.
- **Steps:**
  1. Finish one workout this week.
  2. Open Goals; read the card (`goal-statement-sessionsPerWeek`, `goal-percent-sessionsPerWeek`).
- **Expected result:** "1 of 3 sessions", 33.3 %, the week's date range shown, and tapping through lists the session.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-07-03 — Measurement goal with progress
- **Objective:** Verify progress from the baseline: waist 100 to target 90, now 95 is 50 %.
- **Traces to:** GOL-004, GOL-008 · WP 11 · `/goals/edit/measurement`
- **Preconditions:** Waist 100 cm logged dated 7 days ago (`pick-date`).
- **Steps:**
  1. Goals > Measurement goal (`goal-set-measurement`); site Waist (`goal-site-waist`); target 90; Save.
  2. Log waist 95 cm today.
  3. Open Goals and read the card.
- **Expected result:** Card shows current 95, target 90, 50 % and 5.0 to go, with its basis text (`goal-basis-<suffix>`) and date range.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-07-04 — Body weight goal
- **Objective:** Verify a weight goal with deadline and direction.
- **Traces to:** GOL-003 · WP 11 · `/goals/edit/bodyWeight`
- **Preconditions:** At least 3 weight readings.
- **Steps:**
  1. Goals > Body weight goal (`goal-set-bodyWeight`).
  2. Enter target 80 and deadline 2027-03-01 (`goal-date-field`); Save.
  3. Read the card; then Edit goal and change the target.
- **Expected result:** The card shows trend-based current weight, the target and deadline, the direction derived from the baseline and a basis line. Editing replaces the target.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-07-05 — Goal validation
- **Objective:** Verify bad input is refused.
- **Traces to:** GOL-003, GOL-005, DAT-002 · WP 11 · goal editor
- **Preconditions:** None.
- **Steps:**
  1. Sessions goal: enter 0, then 15.
  2. Weight goal: deadline `01/03/2027`, then `2027-02-30`, then a past date; target -5.
- **Expected result:** 0 and out-of-range values are refused with a message stating the range (sessions 1 to 14). Dates must be strict YYYY-MM-DD and real. Nothing is saved on error.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-07-06 — Clear a goal
- **Objective:** Verify clearing and that history keeps the record.
- **Traces to:** GOL-006 · WP 11 · goal editor
- **Preconditions:** A goal exists.
- **Steps:**
  1. Edit the goal > Clear (`goal-clear`) > Cancel, then Clear again > confirm (`goal-clear-confirm`).
  2. Goals > Target history (`goals-open-history`).
- **Expected result:** Cancel changes nothing. After confirming the goal card is gone and the history lists the period it was active, ending on the clearing day.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-07-07 — Daily nutrition targets and implied energy
- **Objective:** Verify macro targets and the energy they imply: 150 x 4 + 250 x 4 + 70 x 9 = 2230 kcal.
- **Traces to:** GOL-001, GOL-002 · WP 4 · `/settings`
- **Preconditions:** None.
- **Steps:**
  1. Settings: protein 150, carbs 250, fat 70, fibre 30, calories 1800 (`target-protein`, `target-carbs`, `target-fat`, `target-fibre`, `target-calories`).
  2. Read `implied-energy` and `implied-energy-warning`.
  3. Change calories to 2100.
  4. Clear the calories field and Save targets.
- **Expected result:** Implied energy reads 2230 kcal; at 1800 a warning appears (differs by more than 10 %); at 2100 (6 %) no warning. A cleared target is saved as no target and Home/Fuel show no remaining figure.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-07-08 — Target history keeps earlier targets
- **Objective:** Verify a changed target is dated and the earlier one is kept.
- **Traces to:** GOL-006 · WP 11 · `/goals/history`
- **Preconditions:** Calorie target set to 2100.
- **Steps:**
  1. Settings: change calories to 2300; Save.
  2. Goals > Target history; read the group for calories (`target-group-calories`) and periods (`target-period-<i>`).
- **Expected result:** Both targets are listed with the date each applied; the change date is recorded; a same-day replacement is listed as replaced.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-07-09 — Meal plan: add, mark eaten, prep list
- **Objective:** Verify planning a recipe, food and saved meal for a day and logging it as eaten.
- **Traces to:** RCP-014, RCP-015 · WP 7 · `/fuel/plan`
- **Preconditions:** One recipe, one food and one saved meal exist.
- **Steps:**
  1. Fuel > Meal plan (`open-plan`). Choose a future date (`plan-day-next`).
  2. Add a recipe (`plan-add-recipe`, `pick-recipe-<id>`, quantity `plan-quantity`), a food (`plan-add-food`) and a saved meal (`plan-add-saved-meal`) to Lunch (`plan-add-lunch`).
  3. Read the planned energy (`plan-kcal`) and the prep list (`plan-prep`).
  4. On today's plan mark an item eaten (`plan-eat-<id>`, `eaten-confirm`).
- **Expected result:** Planned energy equals the sum of the item energies. Marking eaten adds a diary entry with the planned quantity and the item shows as eaten (`plan-eaten-<id>`). Future days show a note (`plan-future-note`) and cannot be marked eaten.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-07-10 — Training split
- **Objective:** Verify a repeating cycle.
- **Traces to:** TRN-014 · WP 9 · `/train/splits/new`
- **Preconditions:** Two plans exist.
- **Steps:**
  1. Workouts > New split (`new-split`); name `Push Pull Rest` (`split-name-field`).
  2. Add days (`split-add-day`): plan A, plan B, rest (`split-option-rest`).
  3. Save (`split-save`); reopen from the list.
- **Expected result:** The cycle summary (`split-cycle-summary`) shows 3 days; the split is listed and editable; a split with no days is refused (`error-days`).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-07-11 — Schedule workouts
- **Objective:** Verify scheduling by date, weekday and split, and the schedule actions.
- **Traces to:** TRN-015 · WP 9 · `/train/schedule`
- **Preconditions:** A plan and a split exist.
- **Steps:**
  1. Train > Schedule (`open-schedule`); schedule the plan on a date (`sched-date`, `sched-plan-<id>`, `sched-confirm`).
  2. Schedule it on weekdays (`sched-weekday-1`, `sched-weekday-3`).
  3. Schedule the split from a date (`sched-split-<id>`).
  4. On an occurrence use Start (`schedule-start-<id>`), Skip (`schedule-skip-<id>`, confirm), Move (`schedule-move-<id>`) and Restore (`schedule-restore-<id>`).
- **Expected result:** Occurrences appear on the right dates. Start opens a session from the plan. Skip marks it skipped and Restore reverts it. A deleted plan reads "Deleted workout" and cannot be started.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

<a id="s08"></a>

### 8. Body metrics

Thirteen measurement types: weight (kg) and neck, chest, waist, hips, left/right thigh, calf, biceps, forearm (cm). Entry form `/track/entry`; type pages `/track/site/<type>`.

#### Tests

##### T-08-01 — Log a weight
- **Objective:** Verify the quickest weight logging and the Home reflection.
- **Traces to:** BCM-001, UXD-008(3) · WP 10 · `/track`, `/track/entry`
- **Preconditions:** Fresh install.
- **Steps:**
  1. Track > Log weight (`log-weight`) (the weight field is focused).
  2. Type 83.2 (`field-weight`) and Save (`save-measurements`).
  3. Count taps from the Track tab.
  4. Open Home.
- **Expected result:** Saved in 3 taps or fewer from Track (Log weight, type, Save). Track lists 83.2 kg and Home shows latest weight 83.2 with 1 entry. The weight field shows the numeric keypad and the unit kg beside it.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-08-02 — Log several measurements in one entry
- **Objective:** Verify partial entry of any subset.
- **Traces to:** BCM-001, BCM-002 · WP 10 · `/track/entry`
- **Preconditions:** None.
- **Steps:**
  1. Track > Add measurements (`add-measurements`).
  2. Enter weight 83.2, waist 85.5, neck 38 and a note (`note-input`); leave the rest blank; Save.
- **Expected result:** The confirmation names the number saved (3). Only entered types get a reading; blank types are not recorded as 0.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-08-03 — All thirteen types accept input; left and right are separate
- **Objective:** Verify every site exists and paired sites are distinct.
- **Traces to:** BCM-002, BCM-003 · WP 10 · `/track/entry`
- **Preconditions:** None.
- **Steps:**
  1. On the entry form check there is a field for each of the 13 types (`field-<name>`).
  2. Enter left thigh 58 and right thigh 59.5; Save.
  3. Open each thigh page (`site-thighLeft`, `site-thighRight`).
- **Expected result:** 13 fields with units kg/cm. Left shows 58, right 59.5; no shared value.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-08-04 — Input validation
- **Objective:** Verify range and format checks and a future date.
- **Traces to:** BCM-004(1), DAT-002, UXD-007(2) · WP 10 · `/track/entry`
- **Preconditions:** None.
- **Steps:**
  1. Enter weight -5, 0, 1000 and `abc`; try to Save.
  2. Enter waist 5 and 500.
  3. Open the date picker (`pick-date`) and try a future date.
- **Expected result:** Each invalid value is refused with a message beside the field stating the accepted range (`entry-error`). A future date cannot be chosen (`when-error` if forced). Nothing is saved.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-08-05 — Back-dated entry and history order
- **Objective:** Verify date and time can be set and history is newest first.
- **Traces to:** BCM-004 · WP 10 · `/track/site/weight`
- **Preconditions:** None.
- **Steps:**
  1. Add weight 84.0 dated 10 days ago (`pick-date`, `pick-time`).
  2. Add weight 83.0 dated today.
  3. Open Weight (`site-weight`) and read the history.
- **Expected result:** The history lists 83.0 above 84.0 with the chosen dates. It works with airplane mode on.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-08-06 — Edit and delete a reading
- **Objective:** Verify edits and deletions update views at once.
- **Traces to:** BCM-004(2) · WP 10 · `/track/site/weight`
- **Preconditions:** Three weight readings.
- **Steps:**
  1. Edit a reading (`edit-<id>`): change the value and note (`edit-value`, `edit-note`); Save (`edit-save`).
  2. Check the chart, Progress summary and Home.
  3. Delete a reading (`delete-<id>`): Cancel (`delete-cancel`) once, then Confirm (`delete-confirm`).
  4. Check the same views.
- **Expected result:** The edit shows in the history, chart, Progress and Home immediately. Delete asks for confirmation; Cancel keeps the reading; Confirm removes it and the views update.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-08-07 — Weight shown in pounds (display only)
- **Objective:** Verify the imperial display option: 83.2 kg is about 183.4 lb (1 lb = 0.45359237 kg).
- **Traces to:** GEN-003, GEN-004 (E35) · WP 4, WP 10 · `/settings`, `/track`
- **Preconditions:** Weight 83.2 kg logged.
- **Steps:**
  1. Settings > Units > Imperial (`units-choice`); read the note beneath.
  2. Open Track and Home.
  3. Switch back to Metric.
- **Expected result:** Weights read about 183.4 lb; the note says storage stays metric and entry stays in kg. Back on Metric the value is 83.2 kg again, unchanged.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-08-08 — Measurement help
- **Objective:** Verify guidance text for each type.
- **Traces to:** UXD-007 · WP 10 · `/track/entry`
- **Preconditions:** None.
- **Steps:**
  1. On the entry form open the help/info control of two types (`help-waist`, `info-waist`).
- **Expected result:** A short explanation of how to measure is shown and closes cleanly.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-08-09 — Export measurements as CSV
- **Objective:** Verify CSV content, name and spreadsheet opening.
- **Traces to:** BCM-009(1), DAT-006 · WP 10 · `/track` (`export-csv`)
- **Preconditions:** Weight 83.2 kg logged; a spreadsheet app available.
- **Steps:**
  1. Track > Export CSV (`export-csv`); choose a destination in the share sheet.
  2. Open the file in a spreadsheet and a text editor.
  3. From a type page use the single-type export (`export-site-csv`).
- **Expected result:** File name starts `repforge-measurements-` with the date and ends .csv; first line `date,type,value,unit`; a row ends `,Weight,83.2,kg`; dates ISO 8601. The spreadsheet shows four clean columns. The message does not claim "saved" when the platform only reports "shared" (`export-feedback`).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-08-10 — Unreadable readings
- **Objective:** Verify damaged stored readings are listed, not hidden.
- **Traces to:** GEN-006, BCM-004 · WP 10 · `/track/unreadable`
- **Preconditions:** Only possible if a restored backup contains a reading that cannot be shown; otherwise record NOT TESTED.
- **Steps:**
  1. If Track shows a notice (`unreadable-notice`), open it (`open-unreadable`).
  2. Delete one entry (`delete-<id>`).
- **Expected result:** The raw readings are listed and can be deleted; the other charts are unaffected.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

<a id="s09"></a>

### 9. Data integrity and persistence

Local SQLite is the source of truth; backup is JSON (`Settings > Backup and restore`, `/settings/backup`), format version 2, written with schema v7 data. Restore replaces all data. Not covered because no control exists in the code at 28b67b3: scheduled automatic backups (DAT-008), delete-all-data (DAT-012), per-domain CSV other than measurements (DAT-006).

#### Tests

##### T-09-01 — Everything survives a restart
- **Objective:** Verify each domain is persisted before confirmation and read back after a restart.
- **Traces to:** GEN-015(1), DAT-001 · WP 3, WP 4 · all domains
- **Preconditions:** Fresh install.
- **Steps:**
  1. Log a weight 77.7 with note `integration-test`; set calories 2345; log a food; save a recipe; save a plan; finish a session; set a goal; change Theme.
  2. Force-stop RepForge from Android settings.
  3. Reopen and check each item.
- **Expected result:** All items are present and unchanged, including "0 of 2345" on Home. Nothing needed to be saved separately.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-09-02 — Force-stop during a workout
- **Objective:** Verify confirmed sets survive a kill.
- **Traces to:** GEN-015(2) · WP 9 · `/train/session/<id>`
- **Preconditions:** Session started with 3 logged sets and a fourth unconfirmed.
- **Steps:**
  1. Force-stop the app mid-session.
  2. Reopen; choose Continue at the unfinished-session dialog.
- **Expected result:** The three confirmed sets are present; the unconfirmed row is not recorded; no set is duplicated.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-09-03 — Export a backup
- **Objective:** Verify the backup file is complete, local and shareable.
- **Traces to:** GEN-008, DAT-003, DAT-005 · WP 3, WP 10 · `/settings/backup`
- **Preconditions:** Populated install; airplane mode on.
- **Steps:**
  1. Settings > Backup and restore (`open-backup`) (2 taps from Settings, 3 from a tab).
  2. Tap Export backup (`export-backup`) and save to Files/Downloads.
  3. Open the file in a text viewer.
- **Expected result:** File name starts `repforge-backup-`; JSON contains `"app": "repforge"`, `formatVersion` 2, `schemaVersion` 7, `exportedAt` and a `tables` object with the logged data (for example 77.7). Works with no network. A status line (`backup-status`) confirms the outcome.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-09-04 — Restore round trip
- **Objective:** Verify export, change, restore returns exactly the exported state.
- **Traces to:** DAT-004(1), DAT-004(3), WP 3 acceptance · WP 3, WP 10 · `/settings/backup`
- **Preconditions:** Populated install; note row counts per domain (foods, entries, recipes, plans, sessions, readings, goals).
- **Steps:**
  1. Export backup A.
  2. Add a food entry, delete a reading, change a target.
  3. Restore backup A (`restore-backup`): read the dialog (`restore-date`, `restore-total`, `restore-count-<table>`, `restore-warning`) and confirm (`restore-confirm`).
  4. Compare every domain with the noted state.
- **Expected result:** The dialog shows the backup date and record counts and the warning that all data is replaced. After restore the counts and values equal state A; the later changes are gone.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-09-05 — Cancel a restore
- **Objective:** Verify cancelling changes nothing.
- **Traces to:** DAT-004(1) · WP 3 · `/settings/backup`
- **Preconditions:** Populated install and a backup file.
- **Steps:**
  1. Choose Restore, select the file, then Cancel (`restore-cancel`).
  2. Open Fuel, Track and Train.
- **Expected result:** All data is unchanged.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-09-06 — Reject corrupt or foreign backup files
- **Objective:** Verify bad files are rejected without altering data.
- **Traces to:** DAT-004(2), DAT-007(2) · WP 3, WP 10 · `/settings/backup`
- **Preconditions:** A good backup copied to a computer or file manager; text editor available.
- **Steps:**
  1. Make four copies: truncate one in the middle; change `"app"` to `"other"`; change `"formatVersion"` to 99; replace the whole content with `{}`.
  2. Try restoring each, and also a non-JSON file (a photo).
  3. Check app data after each attempt.
- **Expected result:** Each is refused with a plain message that ends "Nothing was changed." (no stack trace); the empty `{}` file cannot empty the device; all existing data remains.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-09-07 — Edits and deletes propagate everywhere
- **Objective:** Verify derived views follow source changes.
- **Traces to:** NUT-012, BCM-004, TRN-024, GOL-008 · WP 5, WP 10, WP 11 · multiple
- **Preconditions:** Populated install: a food entry, two weights, a session this week, a sessions goal 3.
- **Steps:**
  1. Change a food entry 150 g to 200 g; check Fuel, Home, Weekly summary (Fuel), Goals > Weekly summary.
  2. Edit a weight; check Track chart, Progress, Home, Compare, Recomposition.
  3. Delete the session; check History, Training analytics, Goals card, Weekly summary, Home activity.
  4. Delete a food entry; check the same nutrition views.
- **Expected result:** Every view that depends on the item changes at once and agrees with the source. For example the sessions goal returns to "0 of 3 sessions" and weekly volume to 0 kg.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-09-08 — Past entries are snapshots
- **Objective:** Verify later changes to recipes, saved meals or plans never rewrite history.
- **Traces to:** RCP-013, NUT-013(2), TRN-024 · WP 7, WP 9 · `/fuel`, `/train/history`
- **Preconditions:** A logged recipe entry, a logged saved-meal entry and a finished session from a plan.
- **Steps:**
  1. Edit the recipe ingredients; delete the saved meal; edit then delete the plan.
  2. Open the diary entries and the session in History.
- **Expected result:** Entry nutrients, quantities and the session sets are unchanged.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-09-09 — Special characters survive
- **Objective:** Verify diacritics, symbols and long text are stored and restored byte for byte.
- **Traces to:** DAT-006(2), DAT-001 · WP 3 · multiple
- **Preconditions:** None.
- **Steps:**
  1. Create a food `Crème brûlée – ł ü ñ 日本 “quoted”`, a recipe with the same name and a note of 500 characters, and an exercise `Žercice`.
  2. Restart; open each.
  3. Export a backup, restore it, open each again.
- **Expected result:** Names and notes display identically after restart and restore; none is truncated or replaced by question marks.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-09-10 — Double taps create one record
- **Objective:** Verify duplicate-submission prevention.
- **Traces to:** DAT-002, GEN-015 · WP 5, WP 9 · portion sheet, set row, entry form
- **Preconditions:** None.
- **Steps:**
  1. Double-tap Log in the portion sheet (`portion-log`).
  2. Double-tap Log set (`newset-log-<id>`).
  3. Double-tap Save measurements (`save-measurements`).
- **Expected result:** Exactly one diary entry, one set and one reading are created.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-09-11 — Settings persist
- **Objective:** Verify preferences survive a restart.
- **Traces to:** GEN-012, TRN-021, NUT-011 · WP 4 · `/settings`
- **Preconditions:** None.
- **Steps:**
  1. Change Theme, Effort scale, Week starts on (Sunday), default rest (120 s, Save), a meal name and the Units.
  2. Force-stop and reopen; open Settings.
- **Expected result:** Every choice is as set. The week summary uses Sunday as the first day.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

<a id="s10"></a>

### 10. Schema migration and upgrade behaviour

Production schema is **v7** (`AppDatabase.schemaVersion`). The v8 database and the v7 to v8 migration are isolated code (`app/lib/data/db/v8/`, `migration/v7_to_v8.dart`) and are not connected to the app, so this section covers the historical upgrade chain v1 to v7 and the on-device "migrates" integration flow. v7 to v8 belongs to WP 8 stage 3b acceptance (OPTIONAL subsection below). Tests marked "developer" need the Flutter toolchain in `app/`.

#### Tests

##### T-10-01 — Production schema version is 7 and v8 is not wired in
- **Objective:** Confirm the shipped database version.
- **Traces to:** GEN-007, DAT-007 · WP 3, WP 8 · `app/lib/data/db/app_database.dart`
- **Preconditions:** Repository at the commit under test (developer).
- **Steps:**
  1. Open `app/lib/data/db/app_database.dart` and read `schemaVersion`.
  2. Search `app/lib/main.dart`, `app/lib/app/` and `app/lib/data/db/open_database.dart` for imports of `db/v8` or `v7_to_v8`.
  3. Read `schemaVersion` in a freshly exported backup (T-09-03).
- **Expected result:** `schemaVersion` is 7; nothing outside tests/tooling imports the v8 database or migration; the backup states `schemaVersion` 7.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-10-02 — Historical chain v1 to v7 keeps data (automated)
- **Objective:** Run the migration test suites.
- **Traces to:** GEN-007, DAT-007(1) · WP 3, WP 5, WP 9 · `app/test/data/`
- **Preconditions:** Developer; `flutter pub get` done.
- **Steps:**
  1. From `app/` run `flutter test test/data/migration_test.dart test/data/migration_v6_test.dart test/data/drift_upgrade_behaviour_test.dart`.
  2. Read the test names in the output.
- **Expected result:** All pass. They include: v1 weight rows become measurements (site weight); v2 and v1 upgrade straight to v7; v3 to v4 keeps a food, a log entry and a saved-meal item; v4 to v5 keeps recipes with method becoming cook steps; each upgrade can run again after a crash before `user_version` is written; prep batches refuse negative portions.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-10-03 — Schema snapshots match the code (automated)
- **Objective:** Verify committed schema dumps v1 to v7 are consistent.
- **Traces to:** GEN-007 · WP 3 · `app/drift_schemas/`
- **Preconditions:** Developer.
- **Steps:**
  1. From `app/` run `flutter test test/data` and `dart run drift_dev schema dump lib/data/db/app_database.dart /tmp/rf_schema_check` (a scratch folder outside the repository).
  2. Compare the dump with `app/drift_schemas/drift_schema_v7.json` (for example `cmp`).
- **Expected result:** The suite passes and the dump equals `drift_schema_v7.json`.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-10-04 — Real on-device database opens, migrates and persists
- **Objective:** Run the eighth integration flow (real file database) as a manual script.
- **Traces to:** GEN-007, GEN-015, GOL-001 · WP 4, WP 10 · `/track`, `/settings`
- **Preconditions:** Android phone with a debug build; any data present (use a spare install).
- **Steps:**
  1. Track > Add measurements: weight 77.7 and note `integration-test`; Save.
  2. Settings: calories 2345; Save targets ("Targets saved").
  3. Force-stop, reopen. Home must read "0 of 2345".
  4. Clean up: clear the calories field and Save targets; Track > Weight > delete the `integration-test` reading and confirm.
- **Expected result:** The app opens the on-device database file, shows the reading and the target after a fresh connection, and the clean-up removes both. (The same flow runs as `integration_test/app_test.dart` test 8 with `flutter test integration_test -d <device>`.)
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-10-05 — Upgrade from an earlier test build with data
- **Objective:** Verify a real older build upgrades without loss.
- **Traces to:** DAT-007(1), GEN-007 · WP 3 to WP 10 · installed app
- **Preconditions:** An older APK whose schema version is known (record it; only v1 to v7 exist) and the current APK. If none is available record BLOCKED.
- **Steps:**
  1. Install the older build; create a weight, a food entry, a recipe, a session and a goal.
  2. Export a backup (T-09-03).
  3. Install the current build over it.
  4. Open every tab and compare.
- **Expected result:** The app opens without a database error; all items are present and the same as before; the exported backup of the new build has `schemaVersion` 7.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-10-06 — Backup from an older format restores
- **Objective:** Verify format 1 (schema v6 and earlier) files are still accepted.
- **Traces to:** DAT-004, DAT-007 · WP 3, WP 9 · `/settings/backup`
- **Preconditions:** A backup file with `formatVersion` 1 (produced by an older build, or hand-edited from a v2 file by changing the number to 1 and removing nothing). If none exists record BLOCKED.
- **Steps:**
  1. Restore the format 1 file and read the preview.
  2. Open Train and History.
- **Expected result:** The preview lists counts and the restore completes; data present in a format 1 file is shown; v7-only structures (set kinds, session entries) are empty or defaulted, not corrupt.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-10-07 — Reject a database from a newer app
- **Objective:** Verify an unsupported newer backup is refused.
- **Traces to:** DAT-007(2) · WP 3 · `/settings/backup`
- **Preconditions:** A copy of a backup with `formatVersion` set to 99.
- **Steps:**
  1. Try to restore it.
- **Expected result:** Refused with a message; "Nothing was changed."; existing data intact. (A downgrade of the installed app cannot be done by a normal Android install; not tested.)
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

#### OPTIONAL — Stage 3b v7 to v8 device timing (WP 8 3b-9)

Applies only when WP 8 stage 3b is under acceptance (Decisions 2A-9, 2A-11, 2A-12). Source: `docs/device-timing.md`, owner decision D04 §7 "Device timing" (2026-11-06), register entries OB-WP8-01 (Android) and OB-WP8-02 (iOS). Production stays v7. **Run these tests from a checkout of the WP 8 session branch `ccr-9fda2c32-wr163b` at `38bdf6d` or later (`ac14711`), where `integration_test/migration_v8_timing_test.dart` runs the registered v7→v8 migration (`ws5-timing/2`); at the release candidate `28b67b3` the same file still times the historical v5→v7 stand-in chain and asserts `standIn` true, so figures from the candidate are not 3b-9 evidence.** Record the harness commit in Part 5.3. Safety: the harness works in a cache subfolder and never opens `repforge.sqlite`, but it installs a profile build; back up the app first.

##### T-10-08 — OPTIONAL (WP 8 branch harness) — Android profile-mode timing run
- **Objective:** Time the migration on one mid-range Android phone, three or more normal runs plus a recovery run.
- **Traces to:** GEN-007, DAT-007 · WP 8 3b-9 · `app/tool/device_timing.sh`
- **Preconditions:** OPTIONAL — applies only when stage 3b is under acceptance; checkout at `38bdf6d` or later on `ccr-9fda2c32-wr163b`. Physical mid-range Android phone (no emulator); USB debugging; charged above 50 %, screen on, battery saver off; Flutter 3.47.9; `flutter pub get` in `app/`; app data backed up.
- **Steps:**
  1. Record the room temperature if unusual.
  2. From `app/` run `tool/device_timing.sh android <serial>` (use `V8_TIMING_REPS=5` for five runs; minimum 3).
  3. Wait for the run to end (up to an hour).
  4. Open `app/build/device_timing/android-<model>-<time>/` and copy `device.txt`, `report_data.json`, `result_from_log.json`, `drive.log`.
- **Expected result:** `outcome` is `pass`; every normal run and the retry end in the same state; the start digest equals the host reference (`hostReference.startMatches` true; with the WP 8 branch harness the v7 start digest is `v7 602dbcd0601b46b7` and the end digest `v8 7fc53371acfa16d7`; the candidate's stand-in digests `v5 e18285a1cb9d27d2` / `v7 cb68ca68ae2be071` indicate the wrong harness); `recovery.failure` is the injected failure only. Median and worst durations, database size before and after, SQLite version, model, SoC, RAM and Android release are recorded in the results template.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-10-09 — OPTIONAL (WP 8 branch harness) — Recovery and retry run
- **Objective:** Verify a failure at the last step rolls back and the retry succeeds.
- **Traces to:** GEN-007 · WP 8 3b-9 · timing report
- **Preconditions:** OPTIONAL — applies only when stage 3b is under acceptance. T-10-08 completed.
- **Steps:**
  1. In `report_data.json` read `recovery`: failed attempt time, rolled-back state check (previous version, integrity ok) and retry time and outcome.
- **Expected result:** The injected failure is reported once, the database is back at the previous version with integrity ok, the retry finishes and ends in the same state digest as the normal runs.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-10-10 — OPTIONAL (WP 8 branch harness) — iOS profile-mode timing run
- **Objective:** Time the migration on one supported iPhone.
- **Traces to:** GEN-007, DAT-007 · WP 8 3b-9 · `app/tool/device_timing.sh`
- **Preconditions:** OPTIONAL — applies only when stage 3b is under acceptance and the owner provides a signed setup (OB-WP8-02, OB-WP14-04). Mac with Xcode 15+; iPhone unlocked, trusted, developer mode; signing team set on Runner. Otherwise BLOCKED.
- **Steps:**
  1. Find the identifier with `xcrun devicectl list devices`.
  2. From `app/` run `tool/device_timing.sh ios <identifier>`.
  3. Check the marketing name, product type and iOS version in `device.txt` against Settings > General > About.
- **Expected result:** Same result files and pass criteria as T-10-08, for the iPhone.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-10-11 — OPTIONAL (WP 8 branch harness) — Complete the results template and the production-profile differences
- **Objective:** Record the evidence the owner needs.
- **Traces to:** GEN-007 · WP 8 3b-9 · `docs/device-timing.md` results template
- **Preconditions:** OPTIONAL — applies only when stage 3b is under acceptance. Result files from T-10-08 and/or T-10-10.
- **Steps:**
  1. Fill the template once per device: date and commit, model/SoC/RAM, OS, build mode (profile), whether the migration is v7 to v8 or the stand-in, SQLite version, record counts, digests and host equality, sizes, runs, median/worst, recovery run, outcome, errors, notes.
  2. State the material differences from the real production profile (the profile is a 5,000-exercise, 100,000-set stress profile).
- **Expected result:** A complete template per device with the migration stated honestly (stand-in figures are labelled as not 3b-9 evidence).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

<a id="s11"></a>

### 11. Physical-device performance

Run on the reference mid-range Android phone and, when available, a supported iPhone. Record device, OS, build mode and whether the build is debug, profile or release: figures from a debug build are indicative only (the distributed test builds are debug). Targets are those proposed in D04.

#### Tests

##### T-11-01 — Cold start median of 10
- **Objective:** Measure time to an interactive Home screen.
- **Traces to:** GEN-014 · WP 4 · `/home`
- **Preconditions:** Reference device; battery above 50 %; app installed with typical data.
- **Steps:**
  1. Method (write it in the evidence field): swipe the app away or force-stop; start a stopwatch or a 60 fps screen recording at the icon tap; stop when Home shows the Fuel and Body panels and a tab tap responds.
  2. Repeat 10 times; record each time and the median.
- **Expected result:** Median under 2 s (target proposed in GEN-014). Record build mode and the individual times.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-11-02 — Log a previously used food in under 10 seconds
- **Objective:** Measure fast food logging.
- **Traces to:** GEN-013, UXD-008(1) · WP 5 · `/fuel`
- **Preconditions:** A food logged before and a saved meal.
- **Steps:**
  1. From the launcher icon, open the app, log the earlier food (Fuel > Log food > recent/search result > Log) and stop at the diary row. Repeat 10 times.
  2. Repeat for a saved meal (Fuel > Saved meals > Log this meal).
  3. Count taps from Home.
- **Expected result:** Median under 10 s from opening the app, and no more than 4 taps from Home.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-11-03 — Confirm a pre-filled set in two taps
- **Objective:** Measure in-gym logging.
- **Traces to:** TRN-018, UXD-008(2) · WP 9 · session screen
- **Preconditions:** Session started from a plan.
- **Steps:**
  1. Count taps to log a set whose pre-filled values are correct. Check the weight field opens the numeric keypad when edited.
- **Expected result:** A correct pre-filled set is confirmed with one tap (no more than 2); the weight field opens the numeric keypad.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-11-04 — Barcode scan to portion sheet within 3 seconds
- **Objective:** Measure scan lookup time.
- **Traces to:** PLT-002, NUT-006 · WP 6 · `/fuel/scan`
- **Preconditions:** Camera device; network on; a printed EAN-13 in Open Food Facts (for example 3017624010701).
- **Steps:**
  1. Open Scan, hold the code in view, start timing when it is in focus; stop when the portion sheet opens. Repeat 5 times.
  2. Repeat once with the product already cached.
- **Expected result:** Found within 3 s per scan (PLT-002); cached products open faster.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-11-05 — Rest timer accuracy
- **Objective:** Verify the countdown matches a stopwatch.
- **Traces to:** TRN-021 · WP 9 · `rest-timer-panel`
- **Preconditions:** Plan with 60 s rest.
- **Steps:**
  1. Start a stopwatch with the set tap; compare with the on-screen time at 30 s and when it reaches zero.
  2. Repeat after +15 s.
- **Expected result:** Within 1 s of the stopwatch; +15 s adds 15 s.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-11-06 — Scrolling and screen transitions
- **Objective:** Check for visible stalls on large lists.
- **Traces to:** UXD-006 · WP 8 · `/train`, `/fuel/recipes`, `/train/history`
- **Preconditions:** Seed library (89 exercises), 22 starter recipes; if possible a history with 30 or more sessions (history-load-more).
- **Steps:**
  1. Fling-scroll the exercise library, the recipe list and History; load more history.
  2. Switch tabs quickly 20 times; open and close the Settings screen 10 times.
- **Expected result:** No freeze, blank frames or visible stutter; lists keep position; no crash.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-11-07 — Backup and restore duration
- **Objective:** Record how long a typical backup takes.
- **Traces to:** DAT-003, DAT-004 · WP 3, WP 10 · `/settings/backup`
- **Preconditions:** Populated install (about 200 diary entries, 30 sessions, 100 readings if available).
- **Steps:**
  1. Time Export backup from tap to the status line.
  2. Time Restore from confirm to completion.
- **Expected result:** Both finish without the screen freezing for more than a few seconds. D04 sets no target; record the times for the owner.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-11-08 — Thirty-minute usage soak
- **Objective:** Look for crashes, freezes and memory problems in normal use.
- **Traces to:** GEN-015 · WP 4 to WP 10 · all tabs
- **Preconditions:** Populated install.
- **Steps:**
  1. Use every tab for 30 minutes: log foods, record a short workout with rest timers, add measurements, open all Goals screens.
  2. Note device temperature, battery drop and any ANR dialog.
- **Expected result:** No crash, ANR, blank screen or data loss; the device does not overheat.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-11-09 — Rest timer in the background on battery
- **Objective:** Check background behaviour does not drain or kill the timer view.
- **Traces to:** TRN-021, PLT-008 · WP 9 · session screen
- **Preconditions:** Rest notifications enabled (T-12-11).
- **Steps:**
  1. Start a 90 s rest, lock the screen for 60 s, unlock.
- **Expected result:** The remaining time is correct on return (derived from the clock, not frozen).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

<a id="s12"></a>

### 12. Android verification

Physical Android phone. Record model, Android version and build commit for every run. Items 1 to 15 of `docs/verification/wp6-device-checklist.md` are reproduced in T-12-02 to T-12-10 (WP 6 acceptance and D05 V-01). Rest-timer notification behaviour is WP 9 device campaign item M1-F4. The release device checklist is owner action OB-WP14-07.

#### Tests

##### T-12-01 — Device and build record
- **Objective:** Record what was tested.
- **Traces to:** GEN-001 · WP 14 · n/a
- **Preconditions:** Phone, APK installed.
- **Steps:**
  1. Write down: manufacturer and model, Android version and API level, RAM, screen size, APK name, build commit, tester and date.
- **Expected result:** All fields filled in the evidence reference.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-12-02 — Scan permission flow
- **Objective:** Verify the camera rationale, denial and recovery. (WP 6 checklist rows 1 to 4 and 13)
- **Traces to:** PLT-001, PLT-004, NUT-006 · WP 6 · `/fuel/scan`
- **Preconditions:** Fresh install or cleared app data; camera present.
- **Steps:**
  1. Fuel > Log food: confirm Scan barcode (`scan-barcode`) is visible.
  2. Tap Scan: a rationale is shown before the system prompt (`scan-permission`).
  3. Deny the prompt: the screen explains the camera is needed, with Retry (`scan-retry`) and manual code entry (`scan-manual-input`).
  4. Retry and grant: live preview within 2 s.
  5. In system settings revoke the camera permission with Don't allow, reopen Scan.
- **Expected result:** Nothing crashes at any step. After permanent denial the screen says so and offers Open settings (`scan-open-settings`) and manual entry.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-12-03 — Scan EAN-13, EAN-8 and UPC-E
- **Objective:** Verify supported symbologies. (WP 6 rows 5 and 6)
- **Traces to:** PLT-002, NUT-006, NUT-010 · WP 6 · `/fuel/scan`
- **Preconditions:** Network on; printed EAN-13 3017624010701 plus an EAN-8 and a UPC-E product (note printed digits).
- **Steps:**
  1. Scan each code.
  2. In the portion sheet log 25 g of the EAN-13 product.
- **Expected result:** Each is found within 3 s with its name and per-100 values (record which resolved; TD-34). 25 g is logged with nutrients scaled from per-100 and Home total updated.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-12-04 — One detection per scan
- **Objective:** Verify duplicate lookups and entries are prevented. (row 7)
- **Traces to:** DAT-002 · WP 6 · `/fuel/scan`
- **Preconditions:** As above.
- **Steps:**
  1. Hold the same label in view after the first detection; log or cancel.
- **Expected result:** A single lookup, a single portion sheet and at most one diary entry.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-12-05 — Scan offline: cached and unknown products
- **Objective:** Verify offline behaviour. (rows 8 and 9)
- **Traces to:** GEN-002, PLT-004 · WP 6 · `/fuel/scan`
- **Preconditions:** A barcode scanned earlier is cached; a never-scanned barcode; airplane mode on.
- **Steps:**
  1. Scan the cached barcode.
  2. Scan the never-scanned barcode.
- **Expected result:** The cached product opens the portion sheet without network. The unknown one shows an Offline failure state (`scan-failed`) with Retry and Search manually (`scan-search-manually`); nothing is created or logged.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-12-06 — Scan a barcode Open Food Facts does not know
- **Objective:** Verify not-found handling. (row 10)
- **Traces to:** NUT-007, NUT-021 · WP 6 · `/fuel/scan`
- **Preconditions:** Network on.
- **Steps:**
  1. Scan an in-house label or type 2000000000008 in manual entry.
- **Expected result:** "Not found" state (`scan-not-found`) with Create custom food (`scan-create-food`, barcode pre-filled) and Search manually; nothing logged.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-12-07 — Manual barcode entry validation
- **Objective:** Verify input checks. (row 11)
- **Traces to:** DAT-002, UXD-007 · WP 6 · `/fuel/scan`
- **Preconditions:** Scan screen open.
- **Steps:**
  1. Type `12345` and submit (`scan-manual-submit`).
  2. Type `3017624010702` and submit.
- **Expected result:** First: "Enter 8, 12 or 13 digits." Second: "That barcode is not valid." No lookup is made for either.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-12-08 — Back during scanning and lookup
- **Objective:** Verify the scanner stops cleanly. (row 12)
- **Traces to:** PLT-001 · WP 6 · `/fuel/scan`
- **Preconditions:** As above.
- **Steps:**
  1. Press Back while the preview runs; again during a lookup (`scan-looking-up`).
- **Expected result:** The scanner stops, no entry is created and the diary is unchanged.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-12-09 — No camera hides the scan action
- **Objective:** Verify graceful degradation. (row 14)
- **Traces to:** PLT-003, PLT-004 · WP 6 · `/fuel/search`
- **Preconditions:** Emulator image without a camera, or camera disabled by policy.
- **Steps:**
  1. Fuel > Log food.
- **Expected result:** The Scan action is hidden and a one-line explanation (`scan-unavailable`) takes its place.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-12-10 — Airplane-mode logging (D05 V-01, six steps)
- **Objective:** Perform the owner-owned WP 5 verification. (row 15)
- **Traces to:** GEN-002, NUT-005 · WP 5, WP 6 · `/fuel/search`
- **Preconditions:** Android phone, network on, then off. Record model and version. Results are also entered in `docs/delivery-record/WP5.md` R6.
- **Steps:**
  1. Network on: Log food, search `greek yogurt`, log one portion; the entry appears and the food is cached.
  2. Airplane mode on: search the same name; the cached food is listed at once and the online section shows the offline state without blocking.
  3. Log the cached food again; second entry has correct nutrients and no spinner stays.
  4. Force-stop from recents, reopen offline, open Fuel; both entries and dashboard totals are as before.
  5. Airplane mode off, return to the app and navigate away and back; no duplicates or changed values.
  6. Delete the two test entries; diary and dashboard return to the earlier state.
- **Expected result:** All six steps pass. Any failure is a WP 5 defect.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-12-11 — Rest-timer notifications and exact alarms
- **Objective:** Verify the alert with the app in the background.
- **Traces to:** TRN-022, PLT-007, PLT-008 · WP 9 · `/settings`, session screen
- **Preconditions:** Android 13+ ideally; notifications not yet allowed for the app; a plan with 60 s rest.
- **Steps:**
  1. Settings: switch on Rest timer notifications (`rest-notifications-switch`); handle the system permission prompt. If offered, read the "Allow precise timing?" dialog (`exact-timing-dialog`) and choose Allow (`exact-timing-allow`) once and Not now (`exact-timing-not-now`) once.
  2. Start a session, log a set, press Home, lock the screen. Wait for the end of the rest.
  3. Repeat; return to the app before the end and confirm no notification arrives; use +15 s in the background and Skip.
  4. Deny the notification permission and revisit Settings.
- **Expected result:** A notification arrives at the end of the rest while backgrounded (exact when the exact-alarm permission is granted, possibly late when not); none arrives if you return first or Skip. When denied, Settings explains (`rest-notifications-denied`) and offers Open settings (`rest-alerts-open-settings`). Note the Android version and any OEM differences.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-12-12 — Share sheet, Files and restore picker
- **Objective:** Verify export and restore on Android.
- **Traces to:** DAT-003, DAT-004, BCM-009 · WP 10 · `/track`, `/settings/backup`
- **Preconditions:** Phone with a Files app and one other app that can receive a file (email or messaging).
- **Steps:**
  1. Export CSV and Export backup, once to Files/Downloads and once to the other app; once dismiss the share sheet.
  2. Restore: tap Restore backup, pick the file in the system picker.
  3. Open the saved CSV and backup in other apps.
- **Expected result:** Files are created with the expected names and open correctly. Dismissing shows a neutral message ("Share sheet closed."), never a false "saved". The picker returns the file and the restore preview appears.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-12-13 — Lifecycle: rotate, background, low-memory kill
- **Objective:** Verify state handling.
- **Traces to:** GEN-015 · WP 4 · all tabs
- **Preconditions:** Screen auto-rotate on; Developer options available.
- **Steps:**
  1. Rotate the phone on Home, Fuel, Track and the session screen.
  2. Open a half-filled food form, press Home for 5 minutes, return.
  3. Enable Developer options > Don't keep activities and repeat; also kill the app from recents with a session open.
- **Expected result:** Layouts adapt without clipped content; saved data is never lost; an unsaved form may be reset but nothing already saved is; the unfinished-session dialog appears after a kill.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

<a id="s13"></a>

### 13. iOS verification

CI builds iOS as an unsigned **simulator** build only (`ios.yml`); device and App Store signing are not configured (WP 14 owner action 4, register entry OB-WP14-04). No iOS test build is distributed. Every iOS **device** test is therefore conditional on the owner supplying a development-signed build and a device; without it record BLOCKED with the reason "no signed iOS build" and do not mark PASS. Simulator tests need a Mac with Xcode. Record device model, iOS version, build commit, tester and date.

#### Tests

##### T-13-01 — Simulator build and launch
- **Objective:** Confirm the iOS app builds and starts on a simulator.
- **Traces to:** GEN-001 · WP 1, WP 14 · README "Build and test"
- **Preconditions:** Mac with Xcode and Flutter 3.47.9; `flutter pub get --enforce-lockfile` and build_runner done in `app/`.
- **Steps:**
  1. Run `flutter build ios --simulator --no-codesign`.
  2. Install on an iPhone simulator and launch.
  3. Open the five tabs and Settings.
- **Expected result:** The build succeeds, the app opens on Home and all tabs work. A simulator has no camera, so the Scan action is hidden with its explanation (`scan-unavailable`).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-13-02 — Core flows on the simulator
- **Objective:** Run the calculation and persistence basics on iOS.
- **Traces to:** NUT-004, BCM-001, GEN-015 · WP 5, WP 10 · `/fuel`, `/track`
- **Preconditions:** T-13-01 done.
- **Steps:**
  1. Run T-03-01 (570 kcal) and T-08-01 (weight 83.2).
  2. Terminate the app from the simulator and relaunch.
- **Expected result:** Same figures as Android; data persists.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-13-03 — Install a signed build on an iPhone
- **Objective:** Confirm the device build installs.
- **Traces to:** GEN-001 · WP 14 · n/a
- **Preconditions:** CONDITIONAL on the owner supplying a development-signed build (or TestFlight build) and an iPhone with developer mode. Otherwise BLOCKED.
- **Steps:**
  1. Install the build; trust the developer profile if required.
  2. Launch.
- **Expected result:** The app installs and opens on Home with no account prompt.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-13-04 — Camera permission and scanning on iPhone
- **Objective:** Repeat the WP 6 checklist rows 1 to 13 (iOS column).
- **Traces to:** PLT-001, PLT-002, PLT-004, NUT-006 · WP 6 · `/fuel/scan`
- **Preconditions:** CONDITIONAL on T-13-03. Printed EAN-13 3017624010701, an EAN-8 and a UPC-E product; network on, then off.
- **Steps:**
  1. Run the steps of T-12-02 to T-12-08 on the iPhone, including the iOS "Don't Allow" path and the Open settings button.
  2. Record which of EAN-13, EAN-8 and UPC-E resolved.
- **Expected result:** Same expected results as the Android tests; a known EAN logs a correctly scaled entry. The rationale is shown before the system prompt. Row 14 and the V-01 step are Android-only.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-13-05 — Rest timer on iPhone
- **Objective:** Verify the documented iOS baseline.
- **Traces to:** TRN-021, TRN-022(1), PLT-007 · WP 9 · session screen
- **Preconditions:** CONDITIONAL on T-13-03.
- **Steps:**
  1. Settings: allow notifications for the rest timer. Start a 60 s rest and stay in the app.
  2. Repeat, switching to the Home screen and locking the phone.
- **Expected result:** In the foreground the alert fires at the end (haptic/sound). Background delivery is a documented limitation (foreground alert is the baseline); record exactly what happens when locked.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-13-06 — Export, share sheet and restore on iPhone
- **Objective:** Verify file hand-off.
- **Traces to:** DAT-003, DAT-004, BCM-009 · WP 10 · `/track`, `/settings/backup`
- **Preconditions:** CONDITIONAL on T-13-03. iPad also if available (popover).
- **Steps:**
  1. Export CSV and a backup to Files and to another app; dismiss the sheet once.
  2. Restore the backup through the Files picker.
- **Expected result:** Files are written with the expected names; dismissing shows a neutral message; restore preview and completion work. On iPad the share sheet opens as a popover and does not crash.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-13-07 — VoiceOver on core flows
- **Objective:** Verify screen-reader use on iOS.
- **Traces to:** GEN-011(2), UXD-005 · WP 2 · log food, record set, add measurement
- **Preconditions:** CONDITIONAL on T-13-03.
- **Steps:**
  1. Enable VoiceOver. Log a food, log a set, add a weight, using only VoiceOver gestures.
  2. Move through charts (`chart-summary`) and the bottom tabs.
- **Expected result:** Each control is announced with a meaningful name, role and state; the three flows complete; charts expose a text summary.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-13-08 — Safe areas, keyboard and navigation gestures
- **Objective:** Verify platform layout conventions.
- **Traces to:** UXD-004, UXD-006 · WP 2, WP 4 · all tabs
- **Preconditions:** CONDITIONAL on T-13-03 (or a simulator with a notch device for the layout part).
- **Steps:**
  1. Check Home, forms and the session screen on a notch/Dynamic Island iPhone in portrait and landscape.
  2. Use the edge-swipe back on pushed screens; open forms with the keyboard.
- **Expected result:** No content under the notch or home indicator; the keyboard does not hide the Save/Log buttons; edge-swipe goes back one level and never leaves the app from a nested screen.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-13-09 — Data persistence and iCloud exposure check
- **Objective:** Verify data survives and note how it is stored.
- **Traces to:** GEN-015, DAT-001 · WP 3 · `/home`
- **Preconditions:** CONDITIONAL on T-13-03.
- **Steps:**
  1. Log data, force-quit the app from the app switcher, reopen.
  2. Record whether Settings > iCloud lists RepForge data for backup (TD-21 is open).
- **Expected result:** Data persists after force-quit. Record the iCloud backup observation for the owner; it is not a pass criterion.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

<a id="s14"></a>

### 14. UI/UX and accessibility

Run on Android; repeat the TalkBack/VoiceOver items on iOS only when a signed build exists (section 13). Components and tokens are in `docs/design-system.md`.

#### Tests

##### T-14-01 — Light and dark themes on every screen
- **Objective:** Verify both themes render all content.
- **Traces to:** GEN-012, UXD-001 · WP 2 · all routes
- **Preconditions:** Populated install.
- **Steps:**
  1. Settings > Theme (`theme-choice`): choose Dark, then Light, then System (switch the phone between dark and light).
  2. In each, open: Home, Train, Exercise detail, Plans, Plan editor, Session, History, Fuel, Portion sheet, Recipes, Recipe detail/editor, Meal plan, Weekly (Fuel), Track, Entry form, Weight page, Compare, Progress, Goals, Goal editor, Training analytics, Recomposition, Settings, Backup.
- **Expected result:** Every screen is fully readable in both themes: no clipped, invisible or low-contrast text or controls. System follows the phone.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-14-02 — Contrast spot check
- **Objective:** Verify body text and boundaries are legible.
- **Traces to:** GEN-011(1) · WP 2 · multiple
- **Preconditions:** Phone at 50 % brightness.
- **Steps:**
  1. In both themes read body text, captions, disabled buttons, chart axes and input borders on Fuel, Track and Goals.
  2. Developer option: run `flutter test test/ui` and note the contrast test result.
- **Expected result:** Body text meets 4.5:1 and large text/boundaries 3:1 in both themes (the automated contrast test passes).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-14-03 — Touch targets
- **Objective:** Verify minimum 48 dp targets and spacing.
- **Traces to:** UXD-004 · WP 2 · all tabs
- **Preconditions:** Install Google's Accessibility Scanner or enable Developer options > Pointer location.
- **Steps:**
  1. Run the scanner on Home, Fuel, Portion sheet, Session screen, Track entry, Goals, Settings.
  2. Tap closely spaced controls (plan row buttons, +/- portions).
- **Expected result:** No target below 48 x 48 dp is reported; adjacent targets do not overlap; no accidental neighbour taps.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-14-04 — Large font size (200 %)
- **Objective:** Verify text scaling.
- **Traces to:** UXD-005(2) · WP 2 · core screens
- **Preconditions:** Android Settings > Font size and Display size at maximum.
- **Steps:**
  1. Open Home, Fuel diary, Portion sheet, Recipe detail, Session screen, Track entry, Goals, Settings.
- **Expected result:** Primary content is not truncated, controls do not overlap, nothing overflows (no striped overflow), and everything can be scrolled to.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-14-05 — TalkBack on the three core flows
- **Objective:** Verify screen-reader operation on Android.
- **Traces to:** GEN-011(2), UXD-005(1) · WP 2 · log food, record workout, add measurement
- **Preconditions:** TalkBack on.
- **Steps:**
  1. Log a food (create it, set the amount, Log).
  2. Start a workout from a plan and log a set; use Drag to reorder semantics ("Drag to reorder <name>").
  3. Add a weight.
  4. Open a chart and a goal card.
- **Expected result:** Every control has a label, role and state; flows complete without sight; a set with a personal record is announced as "Personal record"; charts read a text summary.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-14-06 — Empty, loading and error states
- **Objective:** Verify every data screen has an empty state offering the next action.
- **Traces to:** UXD-003 · WP 2, WP 4 · multiple
- **Preconditions:** Fresh install; airplane mode for error states.
- **Steps:**
  1. Open each and read the empty state: Home panels, Fuel diary, Saved meals (`saved-meals-empty`), Recipes (`recipes-empty` if all removed), Workouts (`plans-empty`), History (`history-empty`), Schedule (`schedule-empty`), Splits (`splits-empty`), Weekly summary (`week-empty`), Track (`measurements-empty`), a type page (`site-empty`), Progress (`progress-empty`), Goals (`goals-empty`), Target history (`target-history-empty`), Training analytics (`training-empty`).
  2. Trigger errors: online search offline; restore an invalid file.
- **Expected result:** Each empty state states what is missing and offers the primary action. Errors are plain language with Retry or a next step, never raw exception text.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-14-07 — Numeric keypad, units and validation placement
- **Objective:** Verify input conventions.
- **Traces to:** UXD-007 · WP 2 · forms
- **Preconditions:** None.
- **Steps:**
  1. Focus: weight, waist, food kcal/protein, portion amount, set load/reps, goal target, daily targets.
  2. Enter an out-of-range value in each.
- **Expected result:** Numeric fields open the numeric keypad and show their unit (kg, cm, g, kcal) beside the value; each error appears beside its field and states the accepted range.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-14-08 — Charts are accessible and legible
- **Objective:** Verify the chart rules.
- **Traces to:** UXD-009 · WP 2, WP 10, WP 11 · `/track/site/<type>`, `/goals/training`
- **Preconditions:** Left and right thigh readings; training data.
- **Steps:**
  1. Open the Left thigh chart: compare the two series.
  2. Read `chart-summary` and any data table.
  3. Check axis units and dates.
  4. Set Display size to large (about 320 dp width) and reopen.
- **Expected result:** Left (circles, solid line) and right (diamonds, dashed line) are distinguishable without colour. A text summary exists. Axes show units. The chart stays legible at narrow width.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-14-09 — Landscape, cutouts and keyboard
- **Objective:** Verify layout in landscape and with the keyboard open.
- **Traces to:** UXD-004 · WP 4 · forms, session screen
- **Preconditions:** Auto-rotate on.
- **Steps:**
  1. Rotate on Home, a long form and the session screen.
  2. Open the soft keyboard on the food form and the entry form.
- **Expected result:** No content under display cutouts; Save/Log buttons remain reachable with the keyboard open; no overflow.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-14-10 — Consistent patterns across features
- **Objective:** Verify consistent wording and behaviour of confirmations, snackbars and destructive actions.
- **Traces to:** UXD-002, UXD-008 · WP 2 · multiple
- **Preconditions:** Populated install.
- **Steps:**
  1. Delete one item in each area: diary entry, reading, saved meal, recipe, plan, session, goal.
  2. Note confirmation, cancel and result messages.
- **Expected result:** Destructive actions ask for confirmation with Cancel except where an Undo is offered (session); messages are short and consistent; Cancel never changes data.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

<a id="s15"></a>

### 15. Recovery and resilience

Disaster recovery and behaviour under interruption. Rest-timer state after process death is not implemented (WP 17 S4d deferred) and a lost rest alert after a device restart is a recorded limitation; neither is a pass criterion.

#### Tests

##### T-15-01 — Disaster recovery: uninstall and restore
- **Objective:** Verify a backup rebuilds the app on a clean install.
- **Traces to:** GEN-008, DAT-003, DAT-004 · WP 3, WP 10 · `/settings/backup`
- **Preconditions:** Populated install with all domains; note counts.
- **Steps:**
  1. Export a backup and copy it off the phone.
  2. Uninstall (or clear data) and reinstall.
  3. Copy the file back; Settings > Backup and restore > Restore; confirm.
  4. Compare every domain (foods, diary, recipes, plans, sessions, readings, goals, targets, preferences).
- **Expected result:** The app returns to the noted state. Record anything not restored (for example a preference) for the owner.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-15-02 — Offline use end to end
- **Objective:** Verify routine logging works without a network and recovers.
- **Traces to:** GEN-002 · WP 5, WP 9 · `/fuel`, `/train`
- **Preconditions:** Airplane mode on.
- **Steps:**
  1. Log a custom food, a recipe portion and a full short workout.
  2. Turn the network on and open Fuel search.
- **Expected result:** Everything saves offline; online search works again; no duplicate or changed entries.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-15-03 — Network lost during an online lookup
- **Objective:** Verify friendly failure and retry.
- **Traces to:** PLT-004, UXD-003(2) · WP 5, WP 6 · `/fuel/search`, `/fuel/scan`
- **Preconditions:** Network on.
- **Steps:**
  1. Start a search and switch to airplane mode immediately.
  2. Start a barcode lookup and do the same.
  3. Turn the network on and press Retry.
- **Expected result:** A plain failure message with Retry (`online-failure`, `scan-failed`); nothing is created; Retry succeeds when the network returns.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-15-04 — Unsaved-changes guard
- **Objective:** Verify leaving an edited form asks first.
- **Traces to:** TRN-012, TRN-013 · WP 8, WP 9 · plan, split and exercise editors
- **Preconditions:** None.
- **Steps:**
  1. Open New workout, type a name and add an exercise; press Back.
  2. Choose Keep editing (`keep-editing`), then Back again and Discard (`discard-changes`).
- **Expected result:** A dialog appears on Back; Keep editing returns to the form with edits; Discard leaves with nothing saved.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-15-05 — Lock, background and return during a workout
- **Objective:** Verify the session and rest timer survive screen lock.
- **Traces to:** TRN-021, GEN-015 · WP 9 · session screen
- **Preconditions:** Session in progress, rest timer running.
- **Steps:**
  1. Lock the screen for 60 s, unlock; switch to another app for 2 minutes and return.
- **Expected result:** The session and logged sets are intact; the remaining rest time reflects real elapsed time (or the over-time display, `rest-over-for`).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-15-06 — Permission revoked while the app is in the background
- **Objective:** Verify the app copes with a changed permission.
- **Traces to:** PLT-004, PLT-007 · WP 6, WP 9 · Settings, `/fuel/scan`
- **Preconditions:** Rest notifications on; camera allowed.
- **Steps:**
  1. Revoke notifications and camera in system settings while the app is in the background; return.
  2. Open Settings and Scan.
- **Expected result:** No crash; Settings explains notifications are blocked and offers Open settings; Scan shows the permission-denied state.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-15-07 — Share sheet dismissed and storage problems
- **Objective:** Verify export failure paths are neutral.
- **Traces to:** DAT-003 · WP 10 · `export-backup`, `export-csv`
- **Preconditions:** None.
- **Steps:**
  1. Start an export and dismiss the sheet.
  2. If possible export with almost no free storage.
- **Expected result:** A neutral message appears (never "saved" without evidence); the database is unaffected; a failure reads in plain language and can be retried.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-15-08 — Clock and time-zone change
- **Objective:** Verify no data is lost when the device date or zone changes.
- **Traces to:** GEN-015, DAT-001 · WP 5, WP 10 · `/fuel`, `/track`
- **Preconditions:** Entries logged on several days; Developer note OQ-18 (day boundary rules) is open.
- **Steps:**
  1. Change the phone time zone by +10 h (automatic zone off); reopen the app.
  2. Compare Fuel by day, Track history and Goals; restore the zone.
- **Expected result:** No entry disappears or duplicates; record any entry whose displayed day moved so the owner can judge against OQ-18.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-15-09 — Restore the same backup twice
- **Objective:** Verify restore is repeatable and does not duplicate rows.
- **Traces to:** DAT-004(3) · WP 3 · `/settings/backup`
- **Preconditions:** A backup file.
- **Steps:**
  1. Restore it; note counts; restore it again; compare counts.
- **Expected result:** Counts are identical after the second restore; no duplicates.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

<a id="s16"></a>

### 16. Regression testing

Run before every release candidate. T-16-01 to T-16-08 reproduce the eight flows of `app/integration_test/app_test.dart` as manual scripts (they run unattended in CI on an emulator; the manual versions use real input and real files). The CI results are the baseline: record the run ids.

#### Tests

##### T-16-01 — Flow 1: weight, targets and food logging
- **Objective:** Manual script of the in-memory flow.
- **Traces to:** BCM-001, GOL-001, NUT-002, NUT-010 · WP 4, WP 5, WP 10 · `/home`, `/track`, `/settings`, `/fuel`
- **Preconditions:** Fresh install.
- **Steps:**
  1. Home shows a dash for latest weight.
  2. Track: log 83.2 kg.
  3. Settings: calories 2100, Save targets.
  4. Fuel > Log food > New food: `Test oats` 380/13/60/7, Save; amount 150; Log.
  5. Force-stop and reopen; Home.
- **Expected result:** Diary shows `Test oats` 570 kcal; Home shows "570 of 2100" and 83.2.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-16-02 — Flow 2: goals
- **Objective:** Manual script of the goals flow.
- **Traces to:** GOL-005, GOL-007 · WP 11 · `/goals`
- **Preconditions:** Fresh install.
- **Steps:**
  1. Run T-07-01.
- **Expected result:** As T-07-01.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-16-03 — Flow 3: owner actions workspace
- **Objective:** Manual script of the delivery workspace flow.
- **Traces to:** n/a · WP 14 · `/settings/owner-actions`
- **Preconditions:** Any install.
- **Steps:**
  1. Run T-02-08.
- **Expected result:** As T-02-08.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-16-04 — Flow 4: CSV and backup export
- **Objective:** Manual script of the export flow.
- **Traces to:** BCM-009, DAT-003 · WP 10 · `/track`, `/settings/backup`
- **Preconditions:** Fresh install.
- **Steps:**
  1. Log 83.2 kg; Track > Export CSV; Settings > Backup and restore > Export backup.
- **Expected result:** CSV `repforge-measurements-<date>` with header `date,type,value,unit` and a row ending `,Weight,83.2,kg`; backup `repforge-backup-<date>` containing `"app": "repforge"` and 83.2; two exports in total.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-16-05 — Flow 5: recipe edited after logging
- **Objective:** Manual script of the RCP-013 flow.
- **Traces to:** RCP-013, RCP-006, RCP-012 · WP 7 · `/fuel/recipes`
- **Preconditions:** Fresh install.
- **Steps:**
  1. Run T-04-01 to T-04-03.
- **Expected result:** As those tests: 380 kcal per portion, 570 kcal logged, edited recipe 190 kcal per portion, the diary entry still 570 kcal and "1.5 portions · P 20 · C 90 · F 11".
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-16-06 — Flow 6: scan a known barcode and log it
- **Objective:** Manual script of the scanner flow using manual code entry (no camera needed).
- **Traces to:** NUT-006, PLT-002 · WP 6 · `/fuel/scan`
- **Preconditions:** Create custom food `Scan test spread` with barcode 3017624010701 (`food-barcode`) and 500 kcal per 100 g. Scan action available on the device.
- **Steps:**
  1. Fuel > Log food > Scan; type 3017624010701 in manual entry; submit.
  2. Log 25 g.
  3. Scan again with 2000000000008 (network on).
- **Expected result:** The first opens the portion sheet and logs 25 g = 125 kcal (one entry only). The second shows Not found with Create custom food and Search manually, and nothing is created or logged.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-16-07 — Flow 7: full training session
- **Objective:** Manual script of the workout flow.
- **Traces to:** TRN-016, TRN-018, TRN-021, TRN-026 · WP 9 · `/train`
- **Preconditions:** Rest notifications on.
- **Steps:**
  1. Run T-05-04 and T-05-05.
- **Expected result:** As those tests.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-16-08 — Flow 8: real database persistence
- **Objective:** Manual script of the on-device database flow.
- **Traces to:** GEN-007, GEN-015 · WP 4, WP 10 · `/home`
- **Preconditions:** Phone with a debug build.
- **Steps:**
  1. Run T-10-04.
- **Expected result:** As T-10-04.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-16-09 — Automated gates for the release candidate
- **Objective:** Record the machine evidence beside the manual runs.
- **Traces to:** GEN-007, NUT-017 · WP 14 · CI
- **Preconditions:** Commit under test.
- **Steps:**
  1. Open the four workflows for the commit: CI (format, analyse, tests, 80 % coverage gate, recovery job), Android build, iOS build, Integration tests (Android emulator).
  2. Locally run `flutter test` and `flutter analyze --fatal-infos` from `app/`.
  3. Record run ids and the test count (the figure at ded976b was 2361 passed, 4 skipped; compare, do not require equality).
- **Expected result:** All four workflows succeed for the commit; the local suite passes with no new failures; an emulator boot timeout without any test run is infrastructure, not a pass, and must be re-run.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-16-10 — Calculation spot checks (arithmetic panel)
- **Objective:** Re-verify the key numbers after any nutrition or training change.
- **Traces to:** NUT-017, TRN-027 · WP 5, WP 7, WP 9 · multiple
- **Preconditions:** Foods Oats and Bread and Chicken created.
- **Steps:**
  1. Check each: 380 kcal per 100 g x 150 g = 570 kcal; 2 slices of 35 g Bread = 70 g = 175 kcal; 1.5 slices = 131.25 kcal (shown 131); 50 g Chicken = 60 kcal, P 10; day of 200 + 350 + 125 kcal = 675 kcal; 200 g Oats /2 portions = 380 kcal each, x 1.5 = 570; 80 kg x 5 + 80 kg x 4 = 720 kg; waist 100 to 90 with 95 now = 50 %.
- **Expected result:** Every figure matches exactly (display rounds only for display).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-16-11 — Closed work packages behave as before
- **Objective:** Check accepted WP 7 and WP 9 behaviour is unchanged after later work (WP 17 acceptance criterion).
- **Traces to:** RCP-012, RCP-013, TRN-013, TRN-024 · WP 7, WP 9 · multiple
- **Preconditions:** Populated install.
- **Steps:**
  1. Run T-04-02, T-04-03, T-05-05, T-05-11 and T-05-12.
  2. Delete a plan and confirm its past sessions are unchanged.
- **Expected result:** All results equal those of the earlier runs; nothing recorded in history changes when definitions change.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-16-12 — Re-test of defects
- **Objective:** Confirm each fixed defect.
- **Traces to:** as per defect · any WP · as per defect
- **Preconditions:** A defect reference in an earlier test.
- **Steps:**
  1. Repeat the failed test exactly; run the neighbouring tests of the same screen; record the new build commit.
- **Expected result:** The failed test passes; neighbouring tests keep their earlier outcome.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

<a id="s17"></a>

### 17. Cross-platform consistency

Compares Android with iOS. Because iOS device builds are not available without signing, the simulator and Android emulator may be used as a proxy for logic and layout only; mark such runs "proxy" in the evidence field. Camera, notifications, share sheet and performance cannot be judged on a simulator.

#### Tests

##### T-17-01 — Same data, same figures
- **Objective:** Verify identical calculations on both platforms.
- **Traces to:** GEN-001, NUT-017 · WP 5, WP 7, WP 9 · `/fuel`, `/train`, `/goals`
- **Preconditions:** Both platforms freshly installed.
- **Steps:**
  1. On each platform run the arithmetic panel of T-16-10 and read the same screens.
- **Expected result:** Every figure is identical on Android and iOS.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-17-02 — Backup portability
- **Objective:** Verify a backup made on one platform restores on the other.
- **Traces to:** DAT-003, DAT-004, GEN-001 · WP 3 · `/settings/backup`
- **Preconditions:** Populated Android install and an iOS build (simulator allowed). Transfer the file by email or cloud drive.
- **Steps:**
  1. Export on Android; restore on iOS and compare counts and values.
  2. Export on iOS; restore on Android.
- **Expected result:** Both restores succeed with matching counts and values; special characters (T-09-09) survive.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-17-03 — Date, number and unit formatting
- **Objective:** Verify formatting follows the device locale consistently.
- **Traces to:** GEN-003, UXD-007 · WP 4 · multiple
- **Preconditions:** Both platforms; try English (UK) and a locale with a comma decimal separator.
- **Steps:**
  1. Read dates, weights and kcal on Home, Fuel, Track and the CSV.
  2. Enter 83,2 and 83.2 in the weight field.
- **Expected result:** Displays are consistent and readable. Record how each platform handles a comma decimal; CSV always uses ISO dates and a dot.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-17-04 — Navigation conventions
- **Objective:** Verify platform-native back handling and consistent structure.
- **Traces to:** UXD-006 · WP 4 · all tabs
- **Preconditions:** Both platforms.
- **Steps:**
  1. Compare back button/gesture and swipe-back, bottom bar behaviour and Settings access.
- **Expected result:** The same five tabs and the same screens in the same places; each platform's native back gesture goes up one level and does not exit from nested screens.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-17-05 — Theme and layout parity
- **Objective:** Verify both themes render equally.
- **Traces to:** GEN-012 · WP 2 · all tabs
- **Preconditions:** Both platforms.
- **Steps:**
  1. Capture Home, Fuel, Session and Track in Dark and Light on both.
- **Expected result:** No clipped content on either; differences are limited to native controls (pickers, share sheet).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-17-06 — Permission and platform capability handling
- **Objective:** Verify graceful degradation matches in intent.
- **Traces to:** PLT-003, PLT-004 · WP 6, WP 9 · `/fuel/scan`, `/settings`
- **Preconditions:** Device builds on both (CONDITIONAL on a signed iOS build).
- **Steps:**
  1. Deny camera, deny notifications on each; read the app's messages.
- **Expected result:** On both platforms the app explains, offers Open settings and keeps working; wording may differ with the platform dialogs.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-17-07 — Rest-timer alert parity (documented difference)
- **Objective:** Record the known platform difference.
- **Traces to:** TRN-022 · WP 9 · session screen
- **Preconditions:** Device builds (CONDITIONAL on a signed iOS build).
- **Steps:**
  1. Run a 60 s rest in the foreground and in the background on both.
- **Expected result:** Android alerts in the background (exact or inexact); iOS alerts in the foreground (documented baseline). Differences other than these are defects.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

<a id="s18"></a>

### 18. Release installation and final smoke testing

No release tag exists yet: `app/pubspec.yaml` is 0.4.0+1, `CHANGELOG.md` has only `[Unreleased]`, and signing secrets are not provisioned (WP 14, OB-WP14-01/02). Tests T-18-01 to T-18-06 apply when the owner cuts a release (`vX.Y.Z` tag, `release.yml`); until then record BLOCKED. iOS release artefacts do not exist (simulator only).

#### Tests

##### T-18-01 — Release preconditions agree
- **Objective:** Verify tag, version and changelog agree.
- **Traces to:** GEN-007 · WP 14 · `release.yml`, `CHANGELOG.md`, `app/pubspec.yaml`
- **Preconditions:** A tag `vX.Y.Z` has been pushed.
- **Steps:**
  1. Compare the tag without `v` with the `version:` name in `app/pubspec.yaml`.
  2. Check `CHANGELOG.md` has a non-empty `## [X.Y.Z]` heading and that the `[Unreleased]` entries moved under it.
  3. Check the build number (`+N`) is higher than the previous release.
- **Expected result:** All three agree; `+N` increased; the release workflow ran the verify job to green.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-18-02 — Release assets exist and are signed
- **Objective:** Verify the published artefacts.
- **Traces to:** GEN-010 · WP 14 · GitHub Release
- **Preconditions:** Release published.
- **Steps:**
  1. List the assets: signed APK, app bundle, SHA-256 sums.
  2. Run `apksigner verify --print-certs` on the APK and `jarsigner -verify -verbose -certs` on the AAB.
  3. Compare the APK SHA-256 with the sums file.
- **Expected result:** Signed with the owner's release certificate, not the Android debug certificate (CN=Android Debug); checksums match; the Release notes equal the changelog section; no keystore or secret is in the assets.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-18-03 — Install the release APK on a clean phone
- **Objective:** Verify installation and startup of the release build.
- **Traces to:** GEN-001 · WP 14 · `/home`
- **Preconditions:** Clean phone (or data cleared); release APK.
- **Steps:**
  1. Install and open the app.
  2. Look for debug-only items: the palette icon (`open-gallery`) in the app bar and a debug banner.
- **Expected result:** App opens on Home; no component gallery icon and no debug banner (release mode).
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-18-04 — Move from a debug test build to the release
- **Objective:** Verify the one-off uninstall path.
- **Traces to:** DAT-003, DAT-004, GEN-015 · WP 14 · README "Test-build certificate"
- **Preconditions:** A phone with the debug-latest build and data. The release build uses a different certificate, so Android refuses an in-place update.
- **Steps:**
  1. Export a backup and copy it off the phone.
  2. Confirm Android refuses to install over the debug build.
  3. Uninstall, install the release build, restore the backup.
- **Expected result:** Install over is refused as expected; after the uninstall and restore all data is back.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-18-05 — Version information
- **Objective:** Verify the installed version is the released one.
- **Traces to:** GEN-007 · WP 14 · Android app info
- **Preconditions:** Release build installed.
- **Steps:**
  1. Open Android Settings > Apps > RepForge > App info and read the version; compare with the tag.
- **Expected result:** Version name equals X.Y.Z and the build number is the incremented one.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-18-06 — Data-use check
- **Objective:** Verify the app contacts only the documented hosts.
- **Traces to:** GEN-009, GEN-010 · WP 5 · network
- **Preconditions:** Phone on a monitored network (router log or a proxy app); release build.
- **Steps:**
  1. Use the app for 15 minutes including food search and a barcode scan, workout and measurements.
  2. Review the contacted hosts.
- **Expected result:** Only `search.openfoodfacts.org` and `world.openfoodfacts.org` are contacted, only for food search and barcode lookup; no analytics, account or sync traffic.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-18-07 — Final smoke test (about 30 minutes)
- **Objective:** Walk the whole app once on the release candidate.
- **Traces to:** GEN-001 to GEN-015 · WP 4 to WP 11 · all tabs
- **Preconditions:** Fresh install of the release candidate.
- **Steps:**
  1. Home empty states (T-01-03).
  2. Set calories 2100; log 150 g of a 380 kcal food (570 kcal); Home shows "570 of 2100".
  3. Create a recipe and log 1.5 portions.
  4. Create a plan, run a 2-set session, finish; read History.
  5. Log weight 83.2 and waist; open the chart and Compare.
  6. Set a sessions goal 3; open Weekly summary.
  7. Export CSV and a backup.
  8. Force-stop, reopen: everything present.
  9. Restore the backup over the data.
  10. Switch theme Dark and Light.
- **Expected result:** Every step passes with no crash, wrong figure or lost data.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-18-08 — Final smoke test on iPhone
- **Objective:** The same smoke test on iOS.
- **Traces to:** GEN-001 · WP 14 · all tabs
- **Preconditions:** CONDITIONAL on the owner supplying a signed iOS build. Otherwise BLOCKED.
- **Steps:**
  1. Run T-18-07 on the iPhone.
- **Expected result:** As T-18-07.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

##### T-18-09 — Programme closure
- **Objective:** Confirm the test programme itself is complete and honest.
- **Traces to:** n/a · WP 14 · this document
- **Preconditions:** All sections attempted.
- **Steps:**
  1. Count outcomes per section (PASS, FAIL, BLOCKED, NOT TESTED).
  2. Check every FAIL has a defect reference and every BLOCKED has a stated reason (for example: no signed iOS build, no tag, no older APK).
  3. Check every OPTIONAL test has a recorded outcome and that its result is counted towards the named work package only where the owner approved the named decision.
- **Expected result:** A complete outcome table for the owner. Results are evidence for the owner's acceptance decisions; this document does not itself accept any work package.
- **Actual result:** `[enter]`
- **Outcome:** [ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED
- **Evidence reference:** `[screenshot / log / run id]`
- **Defect reference:** `[DEF-xxx or none]`

### Appendix A — Not tested by this programme

Each item is omitted because it is deferred, unapproved, not implemented, or outside the product at commit 28b67b3. Whether an omitted item is required for this release is the owner's decision: items with a D04 priority of Must that have no UI in the candidate are carried to Part 6.6 (DFR-010) for the owner's disposition; nothing here is decided.

| Item | Reason | Where recorded |
|---|---|---|
| Frequent foods, last-quantity pre-fill, saved meals in recents (WP 17 S3b-ii) | Not started; owner to confirm scope | WP17.md, OB-WP17-02 |
| Rest-timer survival across process death (WP 17 S4d) | Deferred, not implemented | WP17.md, OB-WP17-03 |
| Plan metadata, prebuilt catalogue, recipe tags and image (WP 17 S5, S6) | Held for schema v9 | WP17.md |
| Per-muscle analytics (WP 11 D2) | Waits for WP 8 stage 3d | WP11.md |
| Data-quality check for recommendations (GOL-012) | Thresholds unapproved (OQ-15); no screen | OB-WP11-02 |
| Custom-food serving entry units, milligram entry, imperial entry (WP 15) | Open owner decisions | OB-WP15-01, -03, -04 |
| User accounts, sync, account deletion (WP 12) | No approved backend; proposals only | wp12-wp13-owner-decisions-2026-11-07.md |
| Health Connect and HealthKit (WP 13) | No adapter exists | same |
| v7 to v8 migration on a device | Isolated, not connected; WP 8 stage 3b acceptance (OPTIONAL subsection of section 10) | schema-v8.md, device-timing.md |
| Scheduled automatic backup (DAT-008), delete all local data (DAT-012), CSV of food, recipes and workouts (DAT-006 beyond measurements) | No control found in the code | D04; CSV of nutrition and training is OB-WP17-08 |
| Edit or delete a custom food (NUT-008), copy an entry to another date (NUT-012(2)) | No control found in the code | D04 |
| Externalised text for further languages (GEN-016) | P2; not verified | D04 |
| Store listings, beta distribution, opt-in crash reporting | Owner decisions, not implemented | WP14.md |
| Imperial entry of lengths and weights | Display of weight only is implemented (T-08-07) | settings screen note |

### Appendix B — Requirement to test index

Requirement ids cited in the Traces line of a test, with the tests that verify them. A requirement not listed is not covered by this programme.

| Requirement | Tests |
|---|---|
| BCM-001 | T-02-07, T-08-01, T-08-02, T-13-02, T-16-01 |
| BCM-002 | T-08-02, T-08-03 |
| BCM-003 | T-06-03, T-08-03 |
| BCM-004 | T-08-04, T-08-05, T-08-06, T-08-10, T-09-07 |
| BCM-005 | T-06-01, T-06-02, T-06-03 |
| BCM-006 | T-06-01 |
| BCM-007 | T-06-04, T-06-05 |
| BCM-008 | T-06-06 |
| BCM-009 | T-08-09, T-12-12, T-13-06, T-16-04 |
| DAT-001 | T-01-05, T-01-07, T-09-01, T-09-09, T-13-09, T-15-08 |
| DAT-002 | T-03-03, T-03-05, T-07-05, T-08-04, T-09-10, T-12-04, T-12-07 |
| DAT-003 | T-09-03, T-11-07, T-12-12, T-13-06, T-15-01, T-15-07, T-16-04, T-17-02, T-18-04 |
| DAT-004 | T-09-04, T-09-05, T-09-06, T-10-06, T-11-07, T-12-12, T-13-06, T-15-01, T-15-09, T-17-02, T-18-04 |
| DAT-005 | T-09-03 |
| DAT-006 | T-08-09, T-09-09 |
| DAT-007 | T-01-06, T-09-06, T-10-01, T-10-02, T-10-05, T-10-06, T-10-07, T-10-08, T-10-10 |
| DAT-009 | T-01-07 |
| GEN-001 | T-01-01, T-01-02, T-01-08, T-12-01, T-13-01, T-13-03, T-17-01, T-17-02, T-18-03, T-18-07, T-18-08 |
| GEN-002 | T-01-05, T-03-14, T-12-05, T-12-10, T-15-02 |
| GEN-003 | T-01-04, T-08-07, T-17-03 |
| GEN-004 | T-03-17, T-08-07 |
| GEN-005 | T-03-12 |
| GEN-006 | T-01-03, T-03-03, T-03-04, T-06-11, T-08-10 |
| GEN-007 | T-10-01, T-10-02, T-10-03, T-10-04, T-10-05, T-10-08, T-10-09, T-10-10, T-10-11, T-16-08, T-16-09, T-18-01, T-18-05 |
| GEN-008 | T-09-03, T-15-01 |
| GEN-009 | T-01-07, T-18-06 |
| GEN-010 | T-01-01, T-18-02, T-18-06 |
| GEN-011 | T-13-07, T-14-02, T-14-05 |
| GEN-012 | T-01-04, T-09-11, T-14-01, T-17-05 |
| GEN-013 | T-11-02 |
| GEN-014 | T-11-01 |
| GEN-015 | T-01-06, T-05-14, T-09-01, T-09-02, T-09-10, T-10-04, T-11-08, T-12-13, T-13-02, T-13-09, T-15-05, T-15-08, T-16-08, T-18-04, T-18-07 |
| GOL-001 | T-03-02, T-07-07, T-10-04, T-16-01 |
| GOL-002 | T-07-07 |
| GOL-003 | T-07-04, T-07-05 |
| GOL-004 | T-07-03 |
| GOL-005 | T-07-01, T-07-02, T-07-05, T-16-02 |
| GOL-006 | T-07-06, T-07-08 |
| GOL-007 | T-06-08, T-16-02 |
| GOL-008 | T-07-01, T-07-02, T-07-03, T-09-07 |
| GOL-009 | T-06-10 |
| GOL-010 | T-06-09 |
| GOL-011 | T-06-11 |
| NUT-001 | T-03-10, T-03-11 |
| NUT-002 | T-03-01, T-16-01 |
| NUT-004 | T-03-01, T-13-02 |
| NUT-005 | T-03-13, T-03-14, T-12-10 |
| NUT-006 | T-11-04, T-12-02, T-12-03, T-13-04, T-16-06 |
| NUT-007 | T-03-01, T-12-06 |
| NUT-009 | T-03-06 |
| NUT-010 | T-03-01, T-03-05, T-03-06, T-12-03, T-16-01 |
| NUT-011 | T-03-07, T-09-11 |
| NUT-012 | T-03-08, T-09-07 |
| NUT-013 | T-03-09, T-09-08 |
| NUT-014 | T-03-15 |
| NUT-015 | T-02-07, T-03-02 |
| NUT-016 | T-03-11, T-06-08 |
| NUT-017 | T-03-01, T-04-08, T-16-09, T-16-10, T-17-01 |
| NUT-018 | T-03-12 |
| NUT-019 | T-03-12 |
| NUT-021 | T-03-03, T-03-04, T-04-06, T-04-12, T-12-06 |
| NUT-022 | T-03-17, T-03-18, T-03-19 |
| NUT-023 | T-03-13 |
| PLT-001 | T-12-02, T-12-08, T-13-04 |
| PLT-002 | T-11-04, T-12-03, T-13-04, T-16-06 |
| PLT-003 | T-12-09, T-17-06 |
| PLT-004 | T-12-02, T-12-05, T-12-09, T-13-04, T-15-03, T-15-06, T-17-06 |
| PLT-007 | T-12-11, T-13-05, T-15-06 |
| PLT-008 | T-11-09, T-12-11 |
| RCP-001 | T-04-01 |
| RCP-002 | T-04-01 |
| RCP-006 | T-04-01, T-16-05 |
| RCP-007 | T-04-06, T-04-12 |
| RCP-008 | T-04-03, T-04-04, T-04-07 |
| RCP-009 | T-04-05 |
| RCP-010 | T-04-10 |
| RCP-011 | T-04-09, T-04-14 |
| RCP-012 | T-03-16, T-04-02, T-04-07, T-16-05, T-16-11 |
| RCP-013 | T-04-03, T-04-13, T-09-08, T-16-05, T-16-11 |
| RCP-014 | T-07-09 |
| RCP-015 | T-04-11, T-07-09 |
| TRN-001 | T-05-02 |
| TRN-002 | T-05-08 |
| TRN-007 | T-05-08 |
| TRN-008 | T-05-01 |
| TRN-009 | T-05-01 |
| TRN-010 | T-05-01 |
| TRN-011 | T-05-01 |
| TRN-012 | T-05-03, T-15-04 |
| TRN-013 | T-05-04, T-05-15, T-15-04, T-16-11 |
| TRN-014 | T-07-10 |
| TRN-015 | T-07-11 |
| TRN-016 | T-05-05, T-05-13, T-05-14, T-16-07 |
| TRN-017 | T-05-09, T-05-16 |
| TRN-018 | T-05-05, T-11-03, T-16-07 |
| TRN-019 | T-05-06, T-05-07 |
| TRN-020 | T-01-04, T-05-07 |
| TRN-021 | T-05-05, T-09-11, T-11-05, T-11-09, T-13-05, T-15-05, T-16-07 |
| TRN-022 | T-12-11, T-13-05, T-17-07 |
| TRN-023 | T-05-10 |
| TRN-024 | T-05-11, T-05-12, T-09-07, T-09-08, T-16-11 |
| TRN-026 | T-05-05, T-16-07 |
| TRN-027 | T-05-06, T-06-07, T-16-10 |
| TRN-028 | T-06-07 |
| UXD-001 | T-14-01 |
| UXD-002 | T-14-10 |
| UXD-003 | T-01-03, T-14-06, T-15-03 |
| UXD-004 | T-13-08, T-14-03, T-14-09 |
| UXD-005 | T-13-07, T-14-04, T-14-05 |
| UXD-006 | T-02-01, T-02-02, T-02-03, T-02-04, T-02-05, T-02-06, T-11-06, T-13-08, T-17-04 |
| UXD-007 | T-08-04, T-08-08, T-12-07, T-14-07, T-17-03 |
| UXD-008 | T-08-01, T-11-02, T-11-03, T-14-10 |
| UXD-009 | T-06-01, T-14-08 |

## Part 4 — Automated verification evidence

Three separate evidence baselines exist. They are **not** combinable into one claim: no single commit carries all three sets of runs. "Verified" below means the preparer checked the run id against GitHub Actions on 2026-11-07 (workflow name, head commit, conclusion). The owner reviews each baseline and records the review in 4.4.

### 4.1 Baseline A — WP 8 stage 3b, commit `ac14711` (branch `ccr-9fda2c32-wr163b`; record commit `f3a12a4`)

| Workflow | Run id | Head commit | Conclusion | Verified against GitHub |
|---|---|---|---|---|
| CI (incl. recovery job) | 42338771180 | `ac14711` | success | yes (2026-11-07 04:30–04:46 UTC) |
| Android build (incl. R8 check) | 42338771148 | `ac14711` | success | yes |
| iOS build (simulator) | 42338771158 | `ac14711` | success | yes |
| Integration tests (Android emulator) | 42338771135 | `ac14711` | success | yes |

Local figures stated in the `ac14711` commit message (not independently re-run by the preparer): 2,781 tests, coverage 92.9 %, kill+heavy suites 221 passed, format and analyze exit 0, "production schema stays 7; v8 not connected". The CI record commit `f3a12a4` names the same four runs. **Scope of this evidence:** the WP 8 session branch only. `ac14711` is not an ancestor of the integration branch; green runs here say nothing about the integration branch.

### 4.2 Baseline B — WP 15 / WP 17 implementation branch, code HEAD `ded976b` (records HEAD `43aa667`)

| Workflow | Run id | Head commit | Conclusion | Verified against GitHub |
|---|---|---|---|---|
| CI (quality) | 42298780099 | `ded976b` | success | yes (2026-11-06 21:41–21:53 UTC) |
| Android build | 42298779979 | `ded976b` | success | yes |
| iOS build (simulator) | 42298779981 | `ded976b` | success | yes |
| Integration tests (Android emulator) | 42298780193 | `ded976b` | **infrastructure-blocked**: attempt 1 cancelled, attempt 2 failed before any test ran ("Timeout waiting for emulator to boot"); the records at `43aa667` classify this as runner infrastructure and record "no further re-runs" | yes (run exists with conclusion failure); no successful emulator run exists for this commit |

Local suite stated in the `ded976b` commit message and records: 2,361 passed, 4 skipped. **Scope of this evidence:** the frozen implementation branch. Its code was merged into the integration branch in campaign 1 (`cee71dd`) with cross-package corrections applied on the integration branch (Part 2C-7); the emulator suite later ran green on the integration branch (Baseline C), which covers the merged code but is not a run on `ded976b` itself.

### 4.3 Baseline C — Integration branch release candidate (`app/` tree = `d5af42c` = `81b77ff` = `b27ec18`)

| Workflow | Run id | Head commit | Conclusion | Notes |
|---|---|---|---|---|
| Local full gate (campaign lead) | — | `d5af42c` | pass | codegen clean; v8 schema dump equal; format and analyze clean; 3,220 passed, 5 tag-skipped; hand-written coverage 93.6 % (gate 80 %) |
| CI | 42329682815 | `81b77ff` | success | 3,220 passed, 5 tag-skipped; catalogue gate; coverage gate |
| iOS build (simulator) | 42329687813 | `81b77ff` | success | |
| Integration tests (Android emulator) | 42329690093 | `81b77ff` | success | 9 of 9: `app_test.dart` 8 (incl. the WP 11 goals smoke test) + `migration_v8_timing_test.dart` 1 (stand-in chain v5→v7, smoke profile; **not** a v7→v8 timing) |
| Android build | 42329685501 | `81b77ff` | failure (by design) | the new WP 14 signer check found AGP signing with a keystore other than the managed one |
| Android build | 42331651263 | `b27ec18` | success | workflow-only fix (pin `ANDROID_USER_HOME`); signer check passes; APK evidence below |
| Earlier dispatch attempts | 42327259844/880/899/894, 42327475492, 42327667641/800/976/680 | `1259e75`, `3a44733`, `3fb551a` | failure in seconds, no runner | GitHub Actions did not start jobs 02:03–02:31 UTC (OB-PROG-02); not code failures |

APK from run 42331651263 (artifact `repforge-android-debug-apk`, id 13558228357, retained until 2026-12-07): `app-debug.apk` 201,630,832 bytes, SHA-256 `e8768f7d086dc3502dc6e07f9507d31a7772014a95a62b04a18606375fb39ad9`; package `com.tempest.repforge`, versionName 0.4.0, versionCode 1, compileSdk 36, targetSdk 36; signer certificate SHA-256 `3642b6620a200003eff7963530415f3ae60b9a7d755bcc84283cbbbb55df8c50` (throwaway debug certificate of a cache-miss run: a device holding an earlier CI build must uninstall first). `release.yml` has never run; no signed release artefact exists.

### 4.4 Owner review of the automated evidence

| Baseline | Reviewed by owner | Accepted as evidence for | Notes |
|---|---|---|---|
| A (`ac14711`) | `[ ] yes  [ ] no` | `[ ] WP 8 stage 3b only  [ ] nothing` | `[enter]` |
| B (`ded976b`) | `[ ] yes  [ ] no` | `[ ] WP 15 and WP 17 implementation only  [ ] nothing` | emulator block: `[ ] accepted as infrastructure  [ ] re-run required` |
| C (release candidate) | `[ ] yes  [ ] no` | `[ ] the application release candidate  [ ] nothing` | `[enter]` |

Reviewer signature: `[name]`   Date: `[YYYY-MM-DD]`

## Part 5 — Physical-device testing record

Hosted-runner emulator runs are not physical-device evidence. The owner (or a named tester) records every physical run here. Each device row must name the build (commit, APK SHA-256 or signed build id).

### 5.1 Devices used

| Device id | Make / model | OS version | RAM / storage free | Build installed (commit, APK SHA-256) | Install method | Tester | Date |
|---|---|---|---|---|---|---|---|
| DEV-A1 | `[enter]` | `[enter]` | `[enter]` | `[enter]` | `[adb / sideload / TestFlight / Xcode]` | `[enter]` | `[YYYY-MM-DD]` |
| DEV-I1 | `[enter]` | `[enter]` | `[enter]` | `[enter]` | `[enter]` | `[enter]` | `[YYYY-MM-DD]` |
| `[add rows]` | | | | | | | |

### 5.2 Device checklist execution (WP 6 / WP 14)

The release device checklist is `docs/verification/wp6-device-checklist.md`; OB-WP14-07 asks for one Android and one iPhone run. Record the run here and keep the item-level results in Part 3 sections 11–13.

| Run | Device id | Checklist version (commit) | Items passed / failed / blocked | Evidence | Outcome |
|---|---|---|---|---|---|
| Android | `[DEV-..]` | `[commit]` | `[n / n / n]` | `[ref]` | `[ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED` |
| iPhone | `[DEV-..]` | `[commit]` | `[n / n / n]` | `[ref]` | `[ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED` |

### 5.3 WP 8 stage 3b-9 migration timing runs (only if stage 3b is under acceptance; OB-WP8-01, OB-WP8-02)

Procedure: `docs/device-timing.md`; harness `app/integration_test/migration_v8_timing_test.dart` at the WP 8 session's commit `38bdf6d` or later; required: at least three normal runs from an identical restored start plus one recovery/retry run, profile mode, with model, OS, SQLite version, database size, median and worst duration recorded. Emulator and host figures are not accepted.

| Platform | Device id | Harness commit | Profile | Run 1 ms | Run 2 ms | Run 3 ms | Recovery outcome | Median ms | Worst ms | DB size before/after | Result files | Outcome |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Android | `[DEV-..]` | `[commit]` | `[D04 §7 stress / smoke]` | `[ ]` | `[ ]` | `[ ]` | `[recovered / failed]` | `[ ]` | `[ ]` | `[ ]` | `[path]` | `[ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED` |
| iPhone | `[DEV-..]` | `[commit]` | `[ ]` | `[ ]` | `[ ]` | `[ ]` | `[ ]` | `[ ]` | `[ ]` | `[ ]` | `[path]` | `[ ] PASS  [ ] FAIL  [ ] BLOCKED  [ ] NOT TESTED` |

Owner acceptance of the timing results is Decision 2A-11.

## Part 6 — Defect, limitation and deviation register

Raise one row per item. Ids: `DEF-nnn` for defects, `LIM-nnn` for known limitations, `DFR-nnn` for deferred functionality, `BLK-nnn` for infrastructure-blocked verification, `DEV-nnn` for accepted deviations. **Data loss, data corruption and incorrect core calculations are Critical by default** and need an explicit owner disposition even when they are worked around.

Disposition vocabulary: `Fix before release` · `Fix after release (date)` · `Accept as limitation` · `Reject (not a defect)` · `Duplicate of …`.

### 6.1 Critical defects (data loss, data corruption, incorrect core calculation, crash on a core path)

| Id | Test id | Description | Found on (commit / device) | Owner | Disposition | Fix commit | Retest outcome | Evidence |
|---|---|---|---|---|---|---|---|---|
| DEF-001 | `[T-..]` | `[enter]` | `[enter]` | `[enter]` | `[enter]` | `[enter]` | `[ ] PASS  [ ] FAIL  [ ] NOT RETESTED` | `[ref]` |

### 6.2 High defects (a core flow blocked or wrong, with a workaround)

| Id | Test id | Description | Found on | Owner | Disposition | Fix commit | Retest outcome | Evidence |
|---|---|---|---|---|---|---|---|---|
| DEF-101 | `[T-..]` | `[enter]` | `[enter]` | `[enter]` | `[enter]` | `[enter]` | `[ ] PASS  [ ] FAIL  [ ] NOT RETESTED` | `[ref]` |

### 6.3 Medium defects

| Id | Test id | Description | Found on | Owner | Disposition | Fix commit | Retest outcome | Evidence |
|---|---|---|---|---|---|---|---|---|
| DEF-201 | `[T-..]` | `[enter]` | `[enter]` | `[enter]` | `[enter]` | `[enter]` | `[ ] PASS  [ ] FAIL  [ ] NOT RETESTED` | `[ref]` |

### 6.4 Low defects

| Id | Test id | Description | Found on | Owner | Disposition | Fix commit | Retest outcome | Evidence |
|---|---|---|---|---|---|---|---|---|
| DEF-301 | `[T-..]` | `[enter]` | `[enter]` | `[enter]` | `[enter]` | `[enter]` | `[ ] PASS  [ ] FAIL  [ ] NOT RETESTED` | `[ref]` |

### 6.5 Known limitations recorded in the repository (owner to disposition each)

These are documented in the records; none is dispositioned by the owner yet.

| Id | Limitation | Source record | Owner disposition | Date |
|---|---|---|---|---|
| LIM-001 | Fuel screen overflows at 360 px width with 2× text scale in rows from `4fc449f` (`fuel_screen.dart` ~67 and ~365; `rf_section_header.dart:19`). Pre-existing WP 5 defect found by the WP 11 UI review; not fixed. | campaign-2 report, section I | `[ ] Fix before release  [ ] Fix after release  [ ] Accept as limitation` | `[YYYY-MM-DD]` |
| LIM-002 | Test-build certificate: the debug APK of each cache-miss CI run carries a fresh certificate; a device must uninstall before installing a build with a different certificate. Stable certificate only after `debug-release.yml` runs on `main` and saves the cache; cache evicted after 7 days unused. | `docs/delivery-record/WP14.md` "Stable certificate", known limits (a)–(d) | `[ ] Accept as limitation  [ ] Change approach (OB-WP14-06)` | `[YYYY-MM-DD]` |
| LIM-003 | iOS: simulator builds only; no device signing, no TestFlight; iOS device testing needs a build signed by the owner's Apple Developer account. | `WP14.md` owner actions 4; `release.yml` ios job | `[ ] Accept for this release  [ ] Block release until signed` | `[YYYY-MM-DD]` |
| LIM-004 | Owner Actions workspace status changes are stored in the `settings` table and are replaced by a backup restore (older backup → older statuses). | `WP8.md` "Follow-up for the backup owner (E-04)" | `[ ] Accept as limitation  [ ] Fix (merge on restore)` | `[YYYY-MM-DD]` |
| LIM-005 | WP 11: deadlines saved by pre-release campaign builds were stored as local midnight (east-of-UTC shows one day early); nothing released, no migration. `latestBeforeStart` loads up to a year of one site's readings; `measurements.latest(site)` loads every row for a site (performance, pre-WP 11). | `docs/delivery-record/WP11.md` | `[ ] Accept as limitation  [ ] Fix before release` | `[YYYY-MM-DD]` |
| LIM-006 | WP 11 UI Lows open: silent failed refresh after a good load (N2); body-data "today" from the diary day between midnight and the day-start hour (N3); bodyweight exercise rows read "not enough data" on the training screen (N4); the advice-text guard scans Settings only inside the Daily targets card (must widen before G1). | `WP11.md` UI re-check | `[ ] Accept as limitation  [ ] Fix before release` | `[YYYY-MM-DD]` |
| LIM-007 | WP 8 3b (session branch only): B-18 — a stress-profile format 3 backup (55.7 MB compact) exceeds the 50 MiB file-picker cap (`maxPickedFileBytes`); registered for the production switch. | `docs/backup-format-3.md` B-18 (at `f3a12a4`) | see Decision 2A-3 | — |
| LIM-008 | Hosted emulator runner was shut down during a Gradle build twice (campaign 1 and run 42325613118); not reproduced locally. | campaign-2 report, section I | `[ ] Accept as limitation  [ ] Investigate` | `[YYYY-MM-DD]` |
| LIM-009 | Default theme is Dark in code, while GEN-012(1) says the system theme by default (observation from test T-01-04). | `app/lib` theme setup; D04 GEN-012 | `[ ] Accept as limitation  [ ] Fix before release  [ ] Not a requirement gap: …` | `[YYYY-MM-DD]` |
| `[add rows]` | | | | |

### 6.6 Deferred functionality (approved scope not delivered; owner to confirm deferral)

| Id | Item | Work package / decision | Owner disposition | Date |
|---|---|---|---|---|
| DFR-001 | WP 11 D2 per-muscle figures (waits for WP 8 stage 3d) | WP 11 plan §9 | `[ ] Deferred to next campaign  [ ] Descoped  [ ] Required for this release` | `[ ]` |
| DFR-002 | WP 11 G2 integration and acceptance (large-profile load test, accessibility pass, owner acceptance); WP 11 goals smoke test on a physical device | WP 11 plan §9 | `[ ] Deferred  [ ] Required for this release` | `[ ]` |
| DFR-003 | WP 17 S3b-ii frequent foods, last-used quantity pre-fill, saved meals in recents (NUT-014 remainder; needs a schema change, v9) | Decision 2C-2 | Deferred within WP 17 (2C-2) | 2026-11-07 |
| DFR-004 | WP 17 S4d rest-timer survival across process death | Decision 2C-3 | Deferred; allocated and open in WP 17 (2C-3) | 2026-11-07 |
| DFR-005 | WP 17 S5 catalogue content, S6 recipe tags/images/density, CSV export (OB-WP17-04..08) | Decisions 2C-4 | S5 content approved (may proceed); images, density and CSV out of v1 scope; tags remain with S6 (2C-4) | 2026-11-07 |
| DFR-006 | WP 15 stage 3 custom-food serving-definition entry units | Decision 2B-2 | Excluded from WP 15 (2B-2, option b); may be allocated to a future package | 2026-11-07 |
| DFR-007 | WP 8 stages 3c-2..3c-4 (reference-data loader, reconciler transaction, relationship/content/media tables), 3d, 5, 6 | WP 8 record; OB-WP8-05..11 | `[ ] Deferred  [ ] n/a` | `[ ]` |
| DFR-008 | WP 14: signed release via `release.yml`, beta pipeline, store listings, crash reporting (owner accounts and decisions) | OB-WP14-01..05 | `[ ] Deferred  [ ] Required for this release` | `[ ]` |
| DFR-009 | Train dashboard redesign, filter-chip correction, exercise knowledge system (relayed brief; `ffd6d14` not integrated) | Decisions 2A-8, 2A-10 | see 2A | — |
| DFR-010 | No UI found in the candidate for: editing or deleting a custom food (NUT-008); copying a diary entry to another date (NUT-012(2)); scheduled backup (DAT-008); delete-all-data (DAT-012); CSV export beyond measurements (DAT-006). Found while tracing tests (Part 3, Appendix A). **REQUIRES OWNER CONFIRMATION** whether each is approved scope for this release. | D04 ids as listed; Part 3 Appendix A | `[ ] Confirm deferred  [ ] Required for this release: …  [ ] Not in approved scope` | `[ ]` |
| `[add rows]` | | | | |

### 6.7 Infrastructure-blocked verification

| Id | Verification | Block | Workaround evidence | Owner disposition | Date |
|---|---|---|---|---|---|
| BLK-001 | Emulator integration suite on `ded976b` (WP 15 / WP 17 branch) | repeated emulator boot timeouts on hosted runners; "no further re-runs" recorded at `43aa667` | the same code merged into the integration branch passed the emulator suite in run 42329690093 (`81b77ff`) | `[ ] Accept workaround evidence  [ ] Require a run on the frozen branch` | `[ ]` |
| BLK-002 | WP 8 3b-9 physical-device timing (Android, iPhone) | no device available to the delivery agents | none (host/emulator figures are not accepted) | owner runs it (Part 5.3) | `[ ]` |
| BLK-003 | iOS device verification | no signed iOS build (no Apple Developer membership configured) | simulator builds green (iOS workflow) | see LIM-003 | `[ ]` |
| BLK-004 | `release.yml` end-to-end (signed artefacts) | signing secrets not provisioned (OB-WP14-01) | workflow YAML validated; verify job logic run locally | `[ ]` | `[ ]` |
| BLK-005 | GitHub status during the 02:03–02:31 UTC Actions stop | status page not reachable from the campaign environment | runs resumed at 02:31; cause unknown | see Decision 2D-1 | `[ ]` |
| `[add rows]` | | | | | |

### 6.8 Accepted deviations (owner-approved departures from requirements or process)

| Id | Deviation | From (requirement / standard) | Justification | Approved by | Date |
|---|---|---|---|---|---|
| DEV-001 | `[enter]` | `[enter]` | `[enter]` | `[name]` | `[YYYY-MM-DD]` |

## Part 7 — Final acceptance gates

A gate is **Satisfied** only when every item it depends on is complete; a gate with any BLOCKED or NOT TESTED dependency stays **Open** unless the owner records an approved deviation (Part 6.8) that covers the gap. Blocked or untested work is never represented as passed.

| Gate | Acceptance requirement | Depends on | Decision | Evidence reference | Date |
|---|---|---|---|---|---|
| G1 | Scope and allocation decisions resolved | Every decision in Part 2 that gates this release has a status other than Proposed: 2B-1, 2B-2, 2B-3, 2C-1, 2C-2, 2C-3, 2C-4, 2C-6, 2C-7, 2D-4, 2D-5, 2D-6, 2E-1, 2E-2, 2E-3. The stage 3b decisions (2A-1 to 2A-7, 2A-11, 2A-12) gate this release only if 2A-9 brings stage 3b into the candidate; 2A-8 and 2A-10 only if 2A-10 includes the Train series in this release. 2D-3 (publication) follows Part 8 and is excluded here. | `[ ] Satisfied  [ ] Open  [ ] Satisfied with deviation DEV-...` | `[ref]` | `[ ]` |
| G2 | Implementation and independent reviews accepted | Decisions 2B-3, 2C-7, 2D-6 (WP 11/WP 14 acceptance) recorded; OB-PROG-01 (2D-5) answered; 2A-12 only if 2A-9 brings stage 3b into the candidate | `[ ] Satisfied  [ ] Open  [ ] Satisfied with deviation DEV-...` | `[ref]` | `[ ]` |
| G3 | Automated verification evidence reviewed | Part 4.4 completed for baselines A, B, C | `[ ] Satisfied  [ ] Open  [ ] Satisfied with deviation DEV-...` | `[ref]` | `[ ]` |
| G4 | Functional application testing completed | Part 3 sections 1–8, 14, 16, 17 with no FAIL without a dispositioned defect and no NOT TESTED on in-scope tests | `[ ] Satisfied  [ ] Open  [ ] Satisfied with deviation DEV-...` | `[ref]` | `[ ]` |
| G5 | Data integrity and migration testing completed | Part 3 sections 9, 10, 15 complete; no open Critical defect | `[ ] Satisfied  [ ] Open  [ ] Satisfied with deviation DEV-...` | `[ref]` | `[ ]` |
| G6 | Physical-device testing completed | Part 5.1–5.2 complete on at least one Android device; Part 5.3 only if stage 3b is under acceptance | `[ ] Satisfied  [ ] Open  [ ] Satisfied with deviation DEV-...` | `[ref]` | `[ ]` |
| G7 | Android and iOS verification completed | Part 3 sections 12 and 13; LIM-003 dispositioned | `[ ] Satisfied  [ ] Open  [ ] Satisfied with deviation DEV-...` | `[ref]` | `[ ]` |
| G8 | Release-blocking defects resolved | Part 6.1 and 6.2 have no row with disposition "Fix before release" and retest ≠ PASS | `[ ] Satisfied  [ ] Open  [ ] Satisfied with deviation DEV-...` | `[ref]` | `[ ]` |
| G9 | Outstanding limitations formally dispositioned | Every row in Part 6.5, 6.6, 6.7 has an owner disposition and date | `[ ] Satisfied  [ ] Open  [ ] Satisfied with deviation DEV-...` | `[ref]` | `[ ]` |
| G10 | Product Owner acceptance recorded | Part 8 completed and signed (2D-3 may then be decided) | `[ ] Satisfied  [ ] Open` | `[ref]` | `[ ]` |

## Part 8 — Formal acceptance declaration

Select exactly one:

- [ ] **ACCEPTED** — all required gates G1–G10 satisfied.
- [ ] **ACCEPTED WITH CONDITIONS** — documented limitations and deviations explicitly approved (list below).
- [ ] **REJECTED** — remediation required (list the blocking defects and decisions below).
- [ ] **DEFERRED** — insufficient evidence or outstanding decisions (list what is missing below).

| Field | Value |
|---|---|
| Application version | `0.4.0+1` (confirm against `app/pubspec.yaml` at the release candidate): `[enter]` |
| Release candidate commit | `[full SHA of the head of claude/campaign-2026-11-07 being accepted]` |
| Integration branch | `[claude/campaign-2026-11-07 or as confirmed in Decision 2D-4]` |
| `app/` tree identity check | `git diff --stat b27ec18 <candidate> -- app` empty: `[ ] confirmed  [ ] not confirmed` |
| APK accepted (if any) | `[SHA-256 / artifact id / none]` |
| Acceptance date | `[YYYY-MM-DD]` |
| Product Owner | `[name]` |
| Outstanding conditions | `[enter, one per line, each with a DEF/LIM/DFR/DEV id and a due date]` |
| Supporting evidence | `[Part 4 baselines accepted; Part 3 summary counts PASS/FAIL/BLOCKED/NOT TESTED; Part 5 device ids; Part 6 register state]` |
| Decisions still Proposed at acceptance | `[list ids or "none"]` |

**Scope of this declaration.** This declaration accepts or rejects the RepForge application release as a whole, on the integration branch named above. It does not accept WP 8 stage 3b, WP 15 or WP 17 individually; those statuses are recorded in Part 2 and in their delivery records. Conversely, accepting any work package in Part 2 does not accept the release.

**Publication.** Publication to `main` is a separate authorisation (Decision 2D-3). No merge to `main` happens on the strength of this declaration alone.

### Signature / approval record

| Role | Name | Decision | Signature | Date |
|---|---|---|---|---|
| Product Owner | `[name]` | `[ACCEPTED / ACCEPTED WITH CONDITIONS / REJECTED / DEFERRED]` | `[signature or commit SHA of this file]` | `[YYYY-MM-DD]` |
| Witness / second reviewer (optional) | `[name]` | | | `[ ]` |

## Part 9 — Reconciliation: unverified items and conflicts between records

### 9.1 Decisions and statuses that could not be verified from the repository (marked REQUIRES OWNER CONFIRMATION in Part 2)

| Item | Why it could not be verified | Where to answer |
|---|---|---|
| The Train/knowledge allocation | Recorded as owner entries in D04 on the WP 8 branch only (`516fac4`, `d4a73fb`); not on the integration branch; the owner confirms the evidence | 2A-8, 2D-7 |
| Permission and status of the Train dashboard series | No branch, commit or review record in the repository | 2A-10 |
| The authoritative integration branch | D04 on the WP 8 branch names `aa59021` then `claude/campaign-2026-11-07` (for the exercise-knowledge base); no record on the integration branch states the authoritative line | 2D-4 |
| Whether the WP 8 session's statement "ac14711 … four green" is accepted as the stage-3b CI condition | Runs verified green (Part 4.1); the owner's acceptance condition names "four CI workflows pass" without naming a commit | 2A-12 |
| OB-PROG-02 cause | GitHub status page unreachable from the campaign environment; cause of the 02:03–02:31 stop unknown | 2D-1 |
| D-1 and D-2 "approved 2026-11-06" | Recorded in the assessment §14 by the delivery session; no separate owner signature artefact | 2C-4 confirmation line |
| B-15 2026-11-06 conditional acceptance, B-01, B-04, R-30, R-31 and the other 2026-11-06 decisions | Recorded in D04 §7 and the registers by the WP 8 session as owner decisions; not re-verified beyond the records | 2A entries cite them as recorded |

### 9.2 Conflicts between existing governance records (identified, not resolved)

| # | Conflict | Record A says | Record B says | Effect on this document |
|---|---|---|---|---|
| C-1 | Which 3b commits `main` holds | Campaign-2 report (`28b67b3`, section K and ledger): "`main` already holds the isolated 3b code up to `5f1192e`" | `git merge-base --is-ancestor`: `main` holds `2ba3997`, `e57834e` and the WP 8 branch up to `c636a06` (the PR #5 merge); `5f1192e` (two docs commits later: the 2026-11-06 decision baseline texts) is in the campaign branch, not in `main` | Part 1.2 uses the computed ancestry. The code content is the same (the two commits between `c636a06` and `5f1192e` are documentation); the report's wording overstates `main` by those two docs commits. |
| C-2 | Review C fix round commit state | WP 8 record at `f3a12a4` (effort section): fix round "in the working tree, uncommitted"; 3b-10 earns 0.00 | `ac14711` commits it; `f3a12a4` records four green runs on it | 2A-12 states both; effort figure (10.08 / 18.00) is not re-based. |
| C-3 | WP 15 review credit wording | WP 15 record at `43aa667`, breakdown row: "implementer-session review is recorded; independent reviewer sign-off remains outstanding" | Same record's review section: separate fresh-context agent, ACCEPT WITH CONDITIONS; campaign-1 re-check by a separate agent: PASS | 2B-1 treats the review as done and the credit as pending OB-PROG-01. |
| C-4 | Emulator run on `ded976b` | WP 15 / WP 17 records at `43aa667`: run 42298780193 attempt 1 cancelled, attempt 2 failed (boot timeout), "no further re-runs", emulator evidence "absent" | Campaign-1 report "CI classification notes": root cause runner disk space (same run id); one sentence says the push run on `ded976b` shows "the same workflow passing" | No passing emulator run exists for `ded976b`; Part 4.2 says infrastructure-blocked. The campaign-1 sentence is wrong. |
| C-5 | WP 15 CI evidence attribution | D06 WP 15 status and OB-WP15-05 (integration branch): "four CI workflows green at `353fcd8`" plus "review-fix commit `26e9f10` integrated" | `353fcd8` predates the review fixes; evidence for the fixes is `ded976b` (3 of 4) or the campaign candidates | Part 4.2 cites both commits with their own runs. |
| C-6 | Programme percentage with WP 17 | Campaign-1 report: 80.11 / 114 = 70.3 %, 80.11 / 106 = 75.6 % | `programme-progress-2026-11-07b.md`: 80.66 / 114 = 70.8 %, 80.66 / 106 = 76.1 % | Different total earned (77.11 vs 77.66 after WP 14's record); both state their snapshot; the later figure is current. |
| C-7 | S4b behaviour (save session as plan with an archived exercise) | Frozen branch `ded976b`: refuses the whole save (R17-03 test) | Integration branch: skips archived or soft-deleted exercises, reports "Saved without: …", refuses only if nothing remains (D-01, `5956ad9`; WP 17 record owner note "this changes S4b behaviour after the independent review") | 2C-6 and 2C-7 require the owner to name the baseline accepted. |
| C-8 | S4d deferral rationale | WP 17 record at `43aa667`, G6c note: "deferred to v9 … may not touch `lib/data/**`" | Same record's R17-04 row and the integration-branch record (D-07 rewrite): scope/effort deferral, no schema change needed | 2C-3 uses the corrected rationale. |
| C-9 | Cherry-pick of D-01..D-08 onto the frozen branch | No record recommends it; the WP 15 / WP 17 records say the corrections are "not replayed here, to keep one integration line" | — | 2C-6 asks the question as new, with no recorded recommendation. |
| C-10 | OB-PROG-02 text | Register entry: Actions "no longer starts jobs" (written during the stop) | Ledger: resumed at 02:31; cause unknown | 2D-1 asks for the allowance check and resolution. |
| C-11 | WP 15 progress baseline | Governance standard §2: WP 15 40 %, 1.20 (historical estimate) | Records: 2.20 / 73.3 % | Not a conflict under the standard (historical baselines retained separately); noted so the owner is not surprised. |
| C-12 | Finding numbering for the WP 17 rest-timer wording | WP 17 record (integration branch): "integration review finding 7" | Campaign-1 table: D-07 | Same item. |
| C-13 | WP 15 test-file counts | A after R15-04: "30 pass in the four WP 15 test files" | B re-check at `26e9f10`: 9 + 8 + 9 + 6 = 32; D-04 then added one test per sheet | Different commits; both correct for their commit. |
| C-15 | WP 8 earned figure | WP 8 record at `f3a12a4`: 10.08 / 18.00 (56.0 %), roll-up 77.53 / 105 = 73.8 % | `docs/governance/programme-progress-2026-11-07b.md` (integration branch): WP 8 at 9.66 (evidence baseline `e50a047`), roll-up 77.66 / 105 = 74.0 % | The snapshot predates the WP 8 branch's 3b-7 commit credit (+0.42) and is not re-based; neither figure includes stage 3c. The owner's confirmation in 2A-12 and 2D-6 fixes which figure the next snapshot uses. |
| C-16 | D04 entry `516fac4` (WP 8 branch) | "the clean release candidate … holds accepted WP 15/WP 17 work and no WP 8 3b code" | WP 15 and WP 17 are **not accepted** (their records; 2B-3, 2C-7); the candidate holds the isolated earlier v8 work (Part 1.2) | 2A-8 asks the owner to confirm with corrections. |
| C-14 | Record staleness at `f3a12a4` | Only two lines of the WP 8 record changed at `f3a12a4` (CI table); the rest still reads "working tree over 2ba5881" | — | 2A citations say "at `f3a12a4`, evidence baseline `2ba5881`". |

### 9.3 Externally supplied evidence references that the repository confirms

Run ids 42338771180, 42338771148, 42338771158, 42338771135 (all `ac14711`, success) and 42298780099, 42298779979, 42298779981 (all `ded976b`, success) match GitHub Actions; `f3a12a4` is the WP 8 CI record commit; `ded976b` / `43aa667` are the frozen branch's code and records heads; "2,361 passed, 4 skipped" matches the `ded976b` commit message; the emulator block on `ded976b` matches the records.

## Part 10 — Source records used

All read on 2026-11-07 from `/home/user/repforge` after `git fetch --all`. Branch heads: `origin/claude/campaign-2026-11-07` `28b67b3`; `origin/ccr-9fda2c32-wr163b` `f3a12a4`; `origin/claude/repforge-parallel-implementation-flyjqw` `43aa667`; `origin/claude/busy-hypatia-rhl3hu` `391fe1b`; `origin/claude/exercise-knowledge-2026-11-07` `ffd6d14`; `origin/main` `c6d380f`.

| Source | Read at | Used for |
|---|---|---|
| `docs/delivery-record/WP8.md` | `f3a12a4` (session branch) and `28b67b3` | 2A, 2D-6, Part 1 |
| `docs/wp0/D04-product-requirements-baseline.md` §7 | `f3a12a4` and `28b67b3` | B-15 options, 3b acceptance conditions, decision baseline |
| `docs/backup-format-3.md`, `docs/schema-v8.md`, `docs/v8-library-use-cases.md` | `f3a12a4` | B-15, B-17, B-18, R-34, C-10, C-11, F3, B-05..B-13, R-C9 |
| `docs/device-timing.md`; `app/integration_test/migration_v8_timing_test.dart` | `f3a12a4` / `28b67b3` | 3b-9, Part 5.3 |
| `docs/delivery-record/WP15.md`, `WP17.md` | `43aa667` and `28b67b3` | 2B, 2C, Part 4.2 |
| `docs/verification/parallel-workstream-assessment-2026-11-06.md` | `28b67b3` | D-1..D-7 |
| `docs/verification/overnight-campaign-2026-11-06.md` | `28b67b3` | D-01..D-08, D-T1/T2, campaign-1 candidate |
| `docs/verification/overnight-campaign-2026-11-07.md` | `28b67b3` | campaign-2 candidate, CI, APK, section H, relays |
| `docs/verification/pending-register-entries.md`, `wp6-device-checklist.md`, `system-check-2026-11-03.md` | `28b67b3` | registers, device checklist |
| `docs/nutrition-calculation-spec.md` | `28b67b3` | revision 1.4, OQ-02, mg, calculation checks |
| `docs/governance/effort-points-and-progress-reporting.md`, `programme-progress-2026-11-07.md`, `-2026-11-07b.md` | `28b67b3` | allocations, roll-up, sensitivities |
| `docs/wp0/D06-work-package-roadmap.md`, `D07-ci-cd-strategy.md`, `D08-migration-and-recovery-strategy.md` | `28b67b3` | scope, CI, migration tests |
| `docs/delivery-record/WP11.md`, `WP14.md`; `docs/wp11-analytics-plan.md`; `docs/wp8-stage-3c-3d-5-6-preparation.md`; `docs/adr/ADR-0012-*.md`, `ADR-0013-*.md`; `docs/verification/wp12-wp13-owner-decisions-2026-11-07.md` | `28b67b3` | 2D-6, 2E, limitations |
| `app/lib/domain/delivery/owner_blocker_register.dart` | `28b67b3` | 41 register entries and statuses (2E) |
| `app/lib/app/router.dart`; `app/lib/features/**`; `app/integration_test/app_test.dart`; `app/pubspec.yaml`; `README.md`; `CHANGELOG.md` | `28b67b3` | Part 1.3, Part 3 |
| GitHub Actions runs (via the GitHub API) | 2026-11-07 | Part 4 verification |

Commands used for ancestry: `git merge-base --is-ancestor <commit> <ref>`; for tree identity: `git diff --stat <a> <b> -- app`; for branch heads: `git log -1 <ref>`.

No application implementation code was changed while preparing this document; the only file added is this one.
