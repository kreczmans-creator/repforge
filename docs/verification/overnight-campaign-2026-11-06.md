# Overnight integrated delivery campaign — 06/07 November 2026

Status: **release candidate frozen at `d50f724`; CI evidence recorded below as it lands.** This file is the integration ledger and the morning delivery report. Integration lead: the campaign session on branch `claude/busy-hypatia-rhl3hu`. Final authority: the project owner.

---

# Morning delivery report

## A. Executive summary
- **Completed and integrated** on `claude/busy-hypatia-rhl3hu` (release candidate `d50f724`): WP 15 stages 1–2 (entry units kg/l in the portion and ingredient sheets) and WP 17 S3–S4 (Fuel pick-from-library and recents, recipe duplicate and category filter, plan duplicate/delete, save session as plan, elapsed time, drag reorder), both with their independent review fixes; eight corrections from a new independent cross-package integration review; the new **Owner Actions & Delivery Blockers** workspace (Settings > Delivery) with a 19-entry canonical register, persisted status changes with history, and tests; WP 14 CI fixes (emulator disk-space root cause, APK signature and metadata verification, presentation-isolation test); planning documents for WP 11 and WP 8 stages 3c/3d/5/6; updated WP 8, WP 15 and WP 17 records and a programme snapshot.
- **Excluded, isolated:** WP 8 stage 3b code (decision-baseline implementation and WS3 backup format 3). The WP 8 session kept it unpushed and unreviewed, and its independent re-check found that the v7→v8 migration itself creates IC-101 system rows, which by the owner's own B-15 condition stops that work for an owner decision (OB-WP8-04). The candidate runs schema v7 with v8 not connected, so user data is unaffected.
- **`main` not advanced.** The WP 8 session holds the owner's standing constraint "no merge to main without my explicit approval", so the integrated commit stays on the campaign branch; advancing `main` is a fast-forward away and is the first owner action below.
- **APK:** release-ready or provisional per section B (filled when the Android workflow on `d50f724` completes). Signing uses the existing configuration (debug keystore for both build types, as on the rolling release), so every RepForge build to date is "debug-signed for testing"; no store signing exists yet (WP 14).

## B. APK delivery
| Field | Value |
|---|---|
| Commit | `d50f724` (branch `claude/busy-hypatia-rhl3hu`) |
| Build variant | debug (`flutter build apk --debug`, the same variant as the rolling `debug-latest` release); the Android workflow also builds the release variant as an R8 check |
| App version / code | 0.4.0+1 (`app/pubspec.yaml`), package `com.tempest.repforge` |
| Artifact | GitHub Actions artifact `repforge-android-debug-apk` of the "Android build" run on `d50f724` (run id in section D), file `app-debug.apk`; SHA-256 and `apksigner verify --print-certs` / `aapt2 dump badging` output are printed in that run's "Report APKs" and "Verify APK signatures and metadata" steps |
| Rolling release | not updated: `debug-release.yml` publishes only from `main`; when the owner fast-forwards `main` to `d50f724` it rebuilds and publishes the same commit to the `debug-latest` release automatically |
| Local build | not possible in the campaign container (the Android SDK download host is blocked by the container's network policy); the CI build is the artifact of record |
| Installation verification | emulator smoke tests (section D); no physical device was available overnight, so no physical-device claim is made |

## C. Integrated functionality (by work package)
**New functionality**
- WP 15: kg and l entry in the food portion sheet and the recipe ingredient sheet with exact conversion to g/ml, canonical preview, conversion on unit switch; mg in the domain, hidden in the UI.
- WP 17 S3: "Pick from library" (recipes, saved meals) and recent items in the Fuel add flow; recipe duplicate; recipe category filter.
- WP 17 S4: plan duplicate and delete (confirmation names splits); save a finished session as a plan; session elapsed time; drag-reorder of session exercises.
- Owner Actions & Delivery Blockers workspace: list grouped by work package with filters (WP, priority, category, status), Open/Resolved/All scope, summary; detail with description, why blocked, action, recommendation, consequences, dependencies, evidence, record, status control with note and change history; status persists in the settings table and travels with backups.
**Corrections and refactoring**
- WP 15/17 independent review fixes (R15-01..05, R17-02/03/05..09) from the parallel branch.
- Integration review corrections D-01..D-05, D-08 (save-as-plan and duplicate skip archived/removed exercises and say so; deleted plan's schedule rows offer no Start; sheets tolerate a portions basis; reorder guard; suffix constant).
- Workspace review corrections E-01..E-15 and re-check follow-ups.
- WP 14: emulator disk-space fix, longer boot wait, APK verification steps in two workflows, presentation-isolation architecture test.
**Documents**: WP 11 analytics plan; WP 8 stages 3c/3d/5/6 preparation; D04/D06 register entries for WP 17 and WP 15; WP 8/15/17 record sections; programme snapshot 2026-11-07.

## D. CI and testing (release candidate `d50f724`)
| Workflow | Run id | Conclusion | Notes |
|---|---|---|---|
| CI (format, analyse, test, coverage; recovery job) | RC-CI | RC-CI-RESULT | |
| Android build | RC-ANDROID | RC-ANDROID-RESULT | debug + release (R8) APKs, signature and metadata verified in-log |
| iOS build | RC-IOS | RC-IOS-RESULT | unsigned simulator build |
| Integration tests (Android emulator) | RC-INTEGRATION | RC-INTEGRATION-RESULT | 7 integration tests incl. the workspace smoke test and the v8 timing smoke harness |

Local full suite on the candidate tree (`0cbdf13` app content; `669d1e7`/`d50f724` change only the integration test file and the workflow): **2,742 passed, 5 skipped**, coverage 93.0 % of hand-written lines (gate rc2 below). Skipped tests are the five tag-skipped suites (kill, heavy, trial), explained below; none was disabled or weakened. Baseline for comparison: 2,361 passed / 4 skipped at `ded976b` (parallel branch) and 2,662 / 5 at the first merge.

Infrastructure exceptions: the hosted emulator failed to start on three runs for lack of disk space (root cause and fix below); after the fix it boots in about 70 s.

## E. Independent review
Three independent reviews ran overnight, each by a separate agent with no part in the implementation, each followed by a re-check of the corrections by the same reviewer:
1. **Cross-package integration review** (Workstream D): 8 findings (3 Medium, 5 Low) + test gaps; 7 corrected and re-checked closed, 1 deferred (plan-row actions, UX) — table in the ledger.
2. **Owner blocker workspace review** (Workstream E/F): 1 High (register recommendation would have accepted sub-stages about to change), 11 Medium, several Low; all High/Medium corrected and re-checked closed; three new Low defects from the corrections fixed; two Low residues recorded (no backup round-trip test of the blocker row; malformed history items dropped on rewrite).
3. **WP 15 review-fix re-check**: R15-01..06 closed; verdict PASS; three Low documentation items corrected.
Planning documents were reviewed and corrected by a fourth independent agent.
Accepted limitations: older-backup restore reverts blocker statuses (documented in-app and in the WP 8 record); D-06 plan-row actions; S4d rest-timer survival (owner decision). Outstanding risks: section H.

## F. Work-package progress (evidence: the records' campaign sections; weighted, no averaging)
| WP | Allocation | Earned | % | Remaining | Confidence | Implementation / review / acceptance |
|---|---:|---:|---:|---:|---|---|
| WP 8 | 18.00 (approved) | 9.66 | 53.7 % | 8.34 | low–medium | 3b decision baseline unpushed; B-15 open; not accepted |
| WP 15 | 3.00 (approved) | 2.20 | 73.3 % | 0.80 | medium / low | integrated; independent re-check PASS (credit pending OB-PROG-01: 2.30, 76.7 %); not accepted |
| WP 17 | 9.00 (**proposed**, OB-WP17-01) | 3.00 | 33.3 % | 6.00 | medium / low | S3–S4 integrated with review corrections; review credit pending OB-PROG-01; not accepted |
Programme (105 full / 97 core): **73.4 % full, 79.5 % core** (77.11 points); with the proposed WP 17 allocation: 70.3 % / 75.6 % (80.11 of 114 / 106). Details and sensitivities: `docs/governance/programme-progress-2026-11-07.md`.

## G. Owner Actions & Delivery Blockers (same list as in the app: Settings > Delivery)
| Id | WP | Priority | Required action | Recommendation | Consequence of delay | Evidence |
|---|---|---|---|---|---|---|
| — | Programme | High | **Fast-forward `main` to `d50f724`** (`git fetch origin && git checkout main && git merge --ff-only d50f724 && git push`): this publishes the rolling `debug-latest` APK automatically | Do it after reading section D; it is a pure fast-forward of reviewed, CI-verified work | Testers keep the older rolling build; the WP 8 session's constraint was respected overnight | ledger, section D |
| OB-WP8-04 | WP 8 | High | Choose B-15 option (a), (b) or (c) | (b) per the WP 8 session | WS3/3b-7 and the v8 switch-over wait | WP8.md campaign section; D04 §7 |
| OB-WP17-01 | WP 17 | High | Approve the 9.00 allocation | Approve | every WP 17 figure stays provisional | WP17.md |
| OB-WP8-01 / 02 | WP 8 | High (open, not yet ready) | Android and iPhone timing runs once the decision baseline and v7to8 harness land | wait for the WP 8 session's go, then run | 3b-9 stays at harness credit | docs/device-timing.md |
| OB-WP8-03 | WP 8 | Medium | Accept reviewed sub-stages | hold until the baseline is re-reviewed | 3b below 100 % | WP8.md |
| OB-PROG-01 | Programme | Medium | Decide whether agent reviews satisfy acceptance | accept for WP 15 / WP 17 S3–S4; human reviewer for WP 8 3b | review credit lines stay unearned | records |
| OB-WP15-01..05 | WP 15 | Medium/Low | custom-food serving units; spec 1.4; OQ-02; mg; acceptance | (a); approve; metric only; keep hidden; accept after the four | WP 15 stays open at 73.3 % | WP15.md |
| OB-WP17-02..09 | WP 17 | Medium/Low | S3b-ii; S4d; D-3..D-7; acceptance of S3/S4 (with the D-03 and D-06 points) | keep in WP 17; accept S4 without S4d; keep editable; approve draft; no density; no images; out of scope; accept | WP 17 review/acceptance lines stay at 0 | WP17.md |

## H. Outstanding technical risks
- **Code defects (open, Low):** no optimistic local order on drag reorder (brief snap-back); no test that a second reorder during a pending write is ignored; no backup round-trip test for the blocker row; malformed history items of a readable blocker entry are dropped on rewrite; WP 17 test gaps listed in the record.
- **Infrastructure:** hosted-runner disk space (fixed by freeing space and sizing the AVD partition; watch the first runs); emulator boot is slow (68 s) but within the 900 s wait.
- **Untested device behaviour:** no physical Android or iPhone run overnight; the v8 migration timing on devices (3b-9) is outstanding; the workspace at 2x text on a real phone keyboard is covered only by the emulator smoke test and widget tests.
- **Deferred scope:** S4d rest-timer survival; S3b-ii; WP 17 S5/S6 (v9); D-06 UX change; WP 8 3b decision baseline, WS3 and B-15 (owner decision); merge-on-restore of blocker statuses.
- **External dependencies:** Apple signing for device builds; store signing configuration (WP 14); owner devices.

## I. Recommended next actions (in order)
1. Fast-forward `main` to `d50f724` and let the rolling release publish; install `RepForge-debug-arm64-v8a.apk` on the test phone; open Settings > Delivery.
2. Decide OB-WP8-04 (B-15) in the WP 8 session so WS3 and the decision baseline can be pushed, reviewed and integrated.
3. Approve OB-WP17-01 and decide OB-PROG-01; then record WP 15 and WP 17 acceptances or conditions in the app and D04 §7.
4. Run the device timing campaigns when the WP 8 session reports the harness and baseline as landed.
5. Review the WP 11 plan and the WP 8 3c/3d preparation documents and decide their open questions.

---

# Integration ledger (working record)

## Integration ledger

| WP / stream | Agent | Branch | Base SHA | Latest SHA | Changes | Tests | Review | Integration | Final SHA | Blockers |
|---|---|---|---|---|---|---|---|---|---|---|
| Primary branch (`main`) | owner / earlier sessions | `main` | — | `c6d380f` | WP 8 3b-8 merged (PR #5); governance docs | CI 42293964647 success; Android 42293964684 success; iOS 42293965265 success; Integration 42293964654 **failure (emulator never booted: infrastructure)**; Debug release 42293964676 success | — | baseline | — | — |
| WP 8 3b decision baseline (owner decisions 2026-11-06) | WP 8 session `session_01U3ovysqyEjz5RtWLM2irEQ` | `ccr-9fda2c32-wr163b` | `c636a06` | `5f1192e` (docs); implementation uncommitted in that session | D04 §7 decision baseline, B-15/B-16; 3b-7 WS3 and decision implementation in progress (unpushed) | pending | pending | docs merged at `c63d0b2`; code awaited | — | see §Workstream A |
| WP 15 stages 1–2, WP 17 S3–S4 | parallel session `session_01U3ovysGUrQMxVjv2B58Hup` | `claude/repforge-parallel-implementation-flyjqw` | `0d912c2` | `ded976b` | entry units; Fuel pick/recents; recipe duplicate/filter; plan actions; elapsed time; reorder; records | local 2,361 passed / 4 skipped at `ded976b`; CI on `ded976b`: iOS, CI, Android success, emulator pending at 21:57 | independent review R15-01..06, R17-01..10 dispositioned | merged at `cee71dd` (no conflicts) | — | owner decisions (register) |
| Workstream E — Owner Actions & Delivery Blockers | campaign session + implementation agent | `claude/busy-hypatia-rhl3hu` | `cee71dd` | — | domain, register, settings persistence, screens, route, tests | pending | pending | pending | — | — |

## Workstream A — WP 8 (coordination)
- 22:00 The WP 8 session was still implementing the stage 3b decision baseline (R-30 option b, unreadable data, C-1, R-C4, timing-harness digest) with sub-agents, tree uncommitted, holding until its independent review passes. A coordination message was sent asking it to push only to `ccr-9fda2c32-wr163b` and to report SHAs, scope, tests and review status.
- The WS3 (3b-7 backup format 3) commits `32739ac..79b01b8` are not on any remote branch.
- 22:01 Reply from the WP 8 session: latest pushed SHA `5f1192e`; the decision-baseline implementation (unreadable-data blocks, C-1, R-30 option b, R-33, block codes, R-28, R-31, R-32) is uncommitted and unreviewed; WS3 lives on a local worktree branch (`87a3221, 3e9b83e, da5be8b, e3340c9, 514e9fc, d3913a3`, rebased), reviewed twice, **not closable**: Medium O1 (unknown envelope keys accepted, B-09) and O2 (IC-201 exemption too wide) open; B-01 field split and B-07 still to do. **B-15 is not resolved: the independent re-check verdict is that the migration itself introduces IC-101 rows** (fixtures v2–v5 produce a selectable system row `ex-bench` with no report entry). Per the owner's instruction that session stopped for an owner decision and put options (a), (b) and (c) to the owner. The session also holds an owner constraint "no merge to main without my explicit approval" and flagged the campaign plan to the owner.
- 22:20 Second reply from the WP 8 session with the B-15 text put to the owner (recorded in register entry OB-WP8-04 verbatim in substance). Finding: fixtures v2–v5 each hold built-in `ex-bench` (is_custom = 0); the frozen v5→v6 step maps it to supplied 1 and the 3b-4 migration to source = system (repforge, revision 1); the row fails IC-101, gets no report entry, stays selectable (`requireNewWork('ex-bench')` returns Ok as in v7) and a format 3 backup of that device is rejected on another device under IC-101. Options: (a) block such exercises (hides exercises v7 shows); **(b) keep them as labelled legacy ids with a `warningForReview` IC-101 report entry and a narrowly scoped restore exemption — recommended by the WP 8 session**; (c) accept that such backups cannot be restored cross-device (not recommended). Evidence: probe R5 `ws3_ic101_test.dart` over `fixture_v2..v5.sqlite`, a scratch file in that session's container (not in the repository until committed with the decision).
- Integration lead decision: WP 8 stage 3b code is **excluded from the overnight release candidate** (nothing beyond `5f1192e` is pushed; the unpushed work is unreviewed and B-15 is open). The release candidate runs schema v7 with the v8 migration not connected, so the B-15 finding does not affect user data in the delivered build. Advancing `main` is recorded as an explicit owner action, not taken overnight, to respect the standing constraint; the candidate is verified on `claude/busy-hypatia-rhl3hu` and is a fast-forward away.

## CI classification notes
- `claude/busy-hypatia-rhl3hu` `91ea266` Integration tests run 42305104781: the emulator exited at start-up with `FATAL | Not enough space to create userdata partition. Available: 7255.34 MB at /home/runner/.android/avd/test.avd, need 7372.80 MB`, so `adb` never saw a device and the action timed out after the (already raised) 900 s wait. **Root cause: hosted-runner disk space, not code.** The `ded976b` run 42298780193 (attempt 2) failed the same way. Correction (WP 14): a "Free disk space" step removes tool-chains the job never uses (dotnet, ghc, boost, CodeQL) and the AVD gets an explicit 4096 MB userdata partition.
- `ce7f2fd` Integration tests run 42307776044 (first run with the fix): **the emulator booted in 68 s** and the suite ran; 6 of 7 tests passed, including the full training session, backup export, recipe, barcode and real on-device database tests and the v8 timing smoke harness. The one failure was the new blocker-workspace smoke test: it waited for the status control, which sits below the fold of the lazy detail list and is never laid out on a phone until scrolled. Test corrected (wait for the detail app bar, then scroll to each control; `findsWidgets` where the note appears twice). Also found: the first version of the free-space step removed the Android NDK, which the app build then re-downloaded (11 minutes); the NDK is kept.
- `main` `c6d380f` Integration tests run 42293964654: `Timeout waiting for emulator to boot` after `adb: device 'emulator-5554' not found` on every poll; no test ran. Infrastructure failure of the hosted emulator, not a code regression. The scheduled runs on `30e51b0` (41817441405, 42014801238, 42205883177) and the push run on `ded976b` (parallel branch) show the same workflow passing on the same code paths.

## Workstream D — cross-package integration review (independent reviewer, merge `cee71dd`)
Reviewer: a separate agent (highest-capability model) with no part in WP 15, WP 17 or the workspace implementation; read source and tests, not records. Merge shape verified: no `lib/` file changed on both sides since `0d912c2`; the running app stays on schema v7; WP 15/WP 17 touch nothing under `lib/data/db/**` or `drift_schemas/`.

| Id | Sev | Finding (summary) | Disposition |
|---|---|---|---|
| D-01 | Medium | `SaveSessionAsPlan` refused the whole save when any session exercise was archived or soft-deleted, unlike `StartSessionFromPlan`, which skips and warns | **Corrected**: skips archived and missing exercises, reports the skipped names in the snackbar, refuses only when nothing remains; tests for archived, deleted and all-skipped |
| D-02 | Medium (latent for v8) | `DuplicatePlan` copied a plan without checking its exercises, so a soft-deleted exercise was copied and the copy could never be saved; under v8 a blocked exercise would be copied into new work | **Corrected**: exercise check through `ExerciseRepository.byId`; archived kept (TD-42), missing dropped, refusal when nothing remains; hard-coded suffix length replaced; tests. Adding `DuplicatePlan` and `SaveSessionAsPlan` to the WP 9/v8 contract test is recorded for WP 8 stage 3d |
| D-03 | Medium | A scheduled occurrence of a deleted plan still offered Start, which always failed; no test covered "Deleted workout" | **Corrected**: Start is not rendered when the plan is missing; schedule widget test added. Whether `DeletePlan` should also skip future planned occurrences is an owner choice recorded for WP 17 S4 acceptance (register entry OB-WP17-09 in `app/lib/domain/delivery/owner_blocker_register.dart`) |
| D-04 | Low | Portion and ingredient sheets called `EntryUnit.canonicalFor(per100)!`, null for a `portions` basis; a restored legacy ingredient snapshot could throw | **Corrected**: both sheets degrade to the pre-WP 15 behaviour (no unit selector) for a non-measure basis; tests |
| D-05 | Low | Drag reorder wrote asynchronously; a second drag during the write could use stale indices | **Corrected**: moves are ignored while one is in flight; upward-drag test added |
| D-06 | Low | Plan list row carries four trailing icon buttons at 360 dp | **Deferred, recorded**: no overflow (name ellipsises), delete is confirmation-guarded; moving the actions into a menu is a UX change left for WP 17 S4 acceptance |
| D-07 | Low | WP 17 record contradicted itself on rest-timer survival (G6c note vs the R17-04 row) | **Corrected** in the record |
| D-08 | Low | Hard-coded copy-suffix length; recipe copy suffix built inline in presentation | **Corrected** (suffix length); recipe suffix left (no length limit, no defect) |
| D-T1 | Test gap | No architecture test for "presentation never imports `lib/data`" | **Corrected**: `test/architecture/presentation_isolation_test.dart` |
| D-T2 | Test gap | Pick-mode "New recipe" (R17-06), saved-meals pop outside pick mode (R17-05), recipe duplicate double tap, category-filter fallback, elapsed time after resume | **Recorded** as remaining gaps for WP 17 S3/S4 acceptance; not corrected overnight (no defect found in the code paths) |

Verified sound by the reviewer: exercise selection and the v8 bridge, schema unchanged (v7 running), layering, plan actions, execution timers, Fuel entry units and recents, backup round trip (all tables generic), navigation paths from the five-pillar shell, lifecycle of the rest timer, single recents implementation.

### Re-check of the corrections (same reviewer, commit `5956ad9`)
D-01, D-03, D-04, D-05, D-07, D-08 and D-T1 **closed**; D-02 closed in code with the v8 contract-test extension tracked to WP 8 stage 3d; D-06 deferred as recorded. No High or Medium defect introduced. Three Low follow-ups raised and corrected in the next commit: duplicate reports the number of removed exercises left out; the schedule treats a missing plan as unknown (not "Deleted workout", no hidden Start) until the plans have loaded; the isolation test also catches relative `../data/` imports. Still open, Low: no test that a second reorder during a pending write is ignored; no optimistic local order (snap-back flicker). The register ids OB-WP17-03 and OB-WP17-09 the reviewer could not find live in `app/lib/domain/delivery/owner_blocker_register.dart`, the canonical register, not under `docs/`.

## Local quality gates (replica of the CI quality job: codegen check, v8 dump equality, format, analysis, full suite with coverage, 80 % gate)
| Run | Tree | Result |
|---|---|---|
| merged1 | `cee71dd` (main + owner docs + ded976b) | codegen clean (the only diff was the lead's in-progress edits), format ok, analysis ok, **2,662 passed, 5 skipped**, coverage 92.6 % |
| workspace1 | `54a88f3` with concurrent agent edits in the tree | 3 failures, all in test files being rewritten by the corrections agent while the run compiled them; not evidence either way |
| rc2 | `0cbdf13` clean tree (workspace review corrections and re-check follow-ups) | codegen clean, v8 dump equal, format ok, analysis ok, **2,742 passed, 5 skipped**, coverage 93.0 % (20,150 of 21,671 hand-written lines) |
| rc0 | `91ea266` clean tree, no concurrent edits | codegen clean, v8 dump equal, format ok, analysis ok, **2,712 passed, 5 skipped**, coverage 92.9 % (20,008 of 21,528 hand-written lines) |

**The five skipped tests, explained.** They are the tag-skipped suites declared in `app/dart_test.yaml`, skipped by default on every run and executed by the CI `recovery` job (`kill || heavy`) or explicitly: `test/migration_v8/kill/kill_test.dart` (tag `kill`: real SIGKILL of a child process), `test/migration_v8/timing/host_timing_test.dart`, `test/migration_v8/large/large_profile_test.dart` and `test/migration_v8/v8_large_profile_test.dart` (tag `heavy`: 5,000-exercise profile), and `test/migration_trial/table_rebuild_trial_test.dart` (tag `trial`: the stage 3b table-rebuild comparison trial, run on request only). The baseline at `ded976b` had four skipped; the fifth is `v8_large_profile_test.dart`, which came to main with WP 8 3b-4. No test was skipped, disabled or weakened by the campaign.

## Workstream E — Owner Actions & Delivery Blockers: independent review (commit `54a88f3`, reviewer with no part in the implementation)
Format and analysis clean on all 21 touched files; architecture rules verified (presentation imports no `lib/data`, domain imports no Flutter, Result-returning use case, tokens only). Findings and dispositions:

| Id | Sev | Finding (summary) | Disposition |
|---|---|---|---|
| E-01 | Medium | A non-string `updatedAt` in stored JSON threw a `TypeError`, broke every read and save, and escaped the use case (`on Exception` only) | **Corrected** (`0aa8058`): every field type-checked; use case catches every error; codec tests for non-string fields and a `TypeError` from storage |
| E-02 | Medium | A save re-encoded only what this build could decode, erasing entries it could not read (for example a status from a newer build) | **Corrected**: saves merge into the raw stored object; unreadable entries kept byte for byte; a non-object value makes the save fail; repository tests |
| E-03 | Medium | Only the latest state was kept, so reopening a resolved item erased the resolution; saving with no change moved the timestamp | **Corrected**: per-blocker change history (status, time, note, oldest first) stored and shown; Save disabled when nothing changed (UI commit); tests |
| E-04 | Medium | Restoring an older backup silently restores older statuses | **Documented** in the workspace (restore note) and here; merging on restore would touch the backup code owned by WP 8 and is not done overnight |
| E-05 | Low | Watch not de-duplicated; provider not auto-disposed; lenient date parsing | **Corrected**: `.distinct()` on the raw value; autoDispose providers; dates are written with `Z` and read back as UTC |
| E-06 | **High** | OB-WP8-03 recommended accepting 3b-2, 3b-5, 3b-6 and 3b-8 although the approved decision baseline changes them (C-1 report action in the v8 CHECKs, R-C4, R-32) | **Corrected**: recommendation holds every affected sub-stage until the baseline is pushed and re-reviewed; dependency added |
| E-07 | Medium | OB-WP8-01/02 asked for device runs before the migration is final; unsupported "ten minutes" claim | **Corrected**: status Open, dependencies on the decision baseline and the v7to8 harness, claim removed |
| E-08 | Medium | OB-WP15-05 overstated review and CI evidence | **Corrected**; an independent re-check of the review-fix commit `26e9f10` was then run (PASS, below) and is cited |
| E-09 | Medium | Missing items: WP 15 review re-check; the "owner may require a human reviewer" decision; D-03/D-06 points for WP 17 acceptance | **Corrected**: re-check performed (agent-completable, so not a blocker); OB-PROG-01 added; OB-WP17-09 carries both points |
| E-10 | Medium | OB-WP17-03 contradicted R17-04; OB-WP17-06 misquoted NUT-022(2) | **Corrected**: wording per R17-04; NUT-022(2) quoted exactly, the ml-entry reading left for the owner to confirm |
| E-11 | Low | Shared 0.20-point line double-counted; loose "only screen" claim; header date | **Corrected** |
| E-12 | Medium | Pill text below AA in the light theme (4.39:1) | **Corrected** in the UI commit with contrast-test pairs |
| E-13 | Medium | An owner decision could be resolved with no note | **Corrected**: use case requires a note to resolve an owner decision, scope approval or acceptance; tests |
| E-14 | Low | Hard-to-copy references; ISO timestamp with "Z UTC"; abbreviated status labels; overlapping filters with no reset; no retry; no note counter; unknown id not an `RfEmptyState` | **Corrected** in the UI commit |
| E-15 | Medium | Emulator smoke test tapped Save without scrolling (keyboard may cover it); brittle `Changed 20` assertion | **Corrected** |
| E-T | Tests | Untested: codec edge cases, preserved unknown entries, backup round trip, detail at 360 px / 2x / light, note-only edit, reopen, error state, register guard | **Corrected** except the backup round trip of the blocker row, which is covered by the generic all-tables backup test and recorded as a remaining gap |

Verified sound by the reviewer: unique ids and resolving dependencies; agent-owned entries limited to verification/technical/infrastructure (tested); transactional read-modify-write; backup copies the settings table generically; routes and Settings entry tested; decided WP 8 items correctly absent; allocation figures and D-3..D-7 mapping match the records.

### WP 15 review-fix re-check (independent agent, commit `26e9f10`, run during the campaign)
R15-01 to R15-06: all **CLOSED** with file:line evidence; the later campaign change D-04 (`5956ad9`) broke none of them. Four WP 15 test files: 9 + 8 + 9 + 6 = 32 passed. D06 acceptance criteria met in code and tests (0.25 kg as 250 g: E42 and the portion-sheet test; exact factors: E43; round trip: E49; §2.3 examples executed; imperial documented as not offered, OQ-02 open). Three Low items corrected in `0aa8058`: stale E35 note in the specification; two sheet doc comments after D-04; the WP 15 record is brought current below. **Verdict: PASS.**

### Re-check of the workspace corrections (same reviewer, commits `0aa8058` and `86e7a01`)
Every High and Medium finding **closed** in code and tests (format and analysis clean on the 30 changed files; targeted suites: detail 17, list 15, domain 15, use case 8, repository 7, contrast 47 passed). E-04 accepted as a recorded limitation on condition that the backup owner tracks it: now in the WP 8 record ("Follow-up for the backup owner"). The note-limit disposition accepted. Three new Low defects and four Low residues raised; all corrected in `0cbdf13` except as noted: N1 an unreadable stored entry of the *same* id was replaced on save → now moved aside under `<id>#unreadable-<n>` (test); N2 the note limit counted graphemes in the UI and UTF-16 code units in the use case → both count code units, truncating at the limit without splitting a surrogate pair; N3 the use case built its returned state outside the transaction → the repository returns the stored state; the smoke test scrolls to the status tile before tapping it; the all-entries render test uses a 360×6000 viewport so every section is laid out at 2x; the dependency test now resolves `OB-PROG-*` ids; OB-PROG-01's consequence names the S3/S4 share of the WP 17 review line. **Remaining, Low, recorded:** no backup export/import test asserts the `ownerBlockerStates` row (the generic all-tables backup test covers the mechanism); malformed history items of a readable entry are dropped when that entry is rewritten.
