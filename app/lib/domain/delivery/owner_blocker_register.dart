import 'package:repforge/domain/delivery/owner_blocker.dart';

// Canonical register of owner actions and genuine delivery blockers across
// WP 8, WP 11, WP 12, WP 13, WP 14, WP 15 and WP 17, reconciled against the
// delivery records named in each entry during the overnight integration
// campaigns of 2026-11-06/07 and 2026-11-07 (which added WP 11 to WP 14).
// Only items that need the owner, a physical device, an external verifier or
// an outside dependency are listed; work the delivery agents can finish by
// themselves is not. The statuses below are the state recorded in the
// delivery records; the owner's later changes are stored by
// `SettingsRepository.saveBlockerState` and never edit this file. A
// resolved entry stays here so the record remains auditable. Ids are
// stable and never reused.
/// Every owner action and genuine delivery blocker, in one place.
const List<OwnerBlocker> ownerBlockerRegister = [
  // ---------------------------------------------------------------- WP 8
  OwnerBlocker(
    id: 'OB-WP8-01',
    workPackage: BlockerWorkPackage.wp8,
    stage: '3b-9',
    reference: 'D04 §7 "Device timing" (2026-11-06); 3B-ACC-01',
    title: 'Android physical timing run of the v7 to v8 migration',
    description:
        'The v8 migration must be timed on one mid-range Android phone with '
        'recorded specifications: at least three normal runs from an '
        'identical restored start plus one recovery/retry run, in profile '
        'mode, with model, OS, SQLite version, database size, median and '
        'worst duration recorded.',
    category: BlockerCategory.physicalDeviceAction,
    priority: BlockerPriority.high,
    initialStatus: BlockerStatus.open,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'Profile-mode timing needs a physical device; emulator and host '
        'figures are not accepted as 3b-9 evidence. The agents have no '
        'device. Not yet ready for the owner: the migration under test '
        'still changes under the approved decision baseline (R-30, R-28, '
        'R-32, R-33), which is unpushed, and the device harness still runs '
        'the historical v5 to v7 stand-in. A run before both land would '
        'time the wrong migration and be invalidated.',
    actionRequired:
        'Connect the Android phone, run app/tool/device_timing.sh at the '
        'release commit as described in docs/device-timing.md, and return '
        'the result files.',
    recommendation:
        'Wait for the WP 8 session to report the decision baseline and the '
        'v7to8 harness as pushed and reviewed, then run it on the phone you '
        'use for RepForge testing, after backing up its data. The profile '
        'is a stress profile (5,000 exercises, 100,000 sets), so allow '
        'time for the profile build.',
    consequences:
        'Until both device runs exist, stage 3b-9 earns only its harness '
        'credit (0.10 of 0.30) and stage 3b cannot be accepted, which holds '
        'back 3c, 3d and the v8 switch-over.',
    dependencies: [
      'Decision baseline (R-30, R-28, R-32, R-33) pushed and reviewed',
      'Device harness switched from the stand-in to v7to8 (WP 8 session)',
    ],
    evidence: [
      BlockerEvidence('Device procedure', reference: 'docs/device-timing.md'),
      BlockerEvidence(
        'Harness',
        reference: 'app/integration_test/migration_v8_timing_test.dart',
      ),
      BlockerEvidence(
        'Host timing (not device evidence)',
        reference: 'WP8.md, 3b-4 "Host timing on the D04 v7 profile"',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP8.md',
  ),
  OwnerBlocker(
    id: 'OB-WP8-02',
    workPackage: BlockerWorkPackage.wp8,
    stage: '3b-9',
    reference: 'D04 §7 "Device timing" (2026-11-06); 3B-ACC-01',
    title: 'iPhone physical timing run of the v7 to v8 migration',
    description:
        'The same timing campaign as the Android run, on one supported '
        'iPhone, built from a Mac with Xcode and signed for the device.',
    category: BlockerCategory.physicalDeviceAction,
    priority: BlockerPriority.high,
    initialStatus: BlockerStatus.open,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'Needs a physical iPhone and an Apple-signed device build; CI only '
        'produces unsigned simulator builds (docs/wp0/D07-ci-cd-strategy.md). '
        'Same readiness condition as the Android run: the migration and '
        'the harness must be final first.',
    actionRequired:
        'On a Mac with Xcode and the iPhone connected, run '
        'app/tool/device_timing.sh per docs/device-timing.md and return the '
        'result files.',
    recommendation:
        'Do the Android run first; if the iPhone run has to wait, say so, '
        'and 3b-9 is reported as half-complete rather than deferred '
        'silently.',
    consequences:
        'Without the iPhone run the platform evidence required by the '
        'owner decision is incomplete and 3b stays unaccepted.',
    dependencies: ['OB-WP8-01 (same readiness conditions and harness)'],
    evidence: [
      BlockerEvidence('Device procedure', reference: 'docs/device-timing.md'),
      BlockerEvidence(
        'iOS signing constraint',
        reference: 'docs/wp0/D07-ci-cd-strategy.md',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP8.md',
  ),
  OwnerBlocker(
    id: 'OB-WP8-03',
    workPackage: BlockerWorkPackage.wp8,
    stage: '3b-2, 3b-4, 3b-5, 3b-6, 3b-8',
    reference: 'D04 §7 "3b effort allocation" (70/20/10 rule)',
    title: 'Owner acceptance of the reviewed stage 3b sub-stages',
    description:
        'Sub-stages 3b-2 (schema v8), 3b-4 (v7 to v8 migration), 3b-5 (all '
        'paths), 3b-6 (process-kill recovery) and 3b-8 (domain and use '
        'cases) are implemented and independently reviewed with re-checks. '
        'Each still carries its 10 % owner-acceptance credit unearned.',
    category: BlockerCategory.ownerAcceptance,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'Acceptance is reserved to the owner; agents may not record it.',
    actionRequired:
        'Read the sub-stage sections and review tables in the WP 8 record, '
        'then record acceptance (or conditions) in D04 §7 and the record.',
    recommendation:
        'Hold acceptance of every sub-stage the approved decision baseline '
        'changes until that implementation is pushed and re-reviewed: 3b-2 '
        '(C-1 adds the report action "corrected", which the v8 CHECK '
        'constraints must admit), 3b-4 (R-30, R-28, R-31, R-33), 3b-6 '
        '(R-32 crashed-run identity) and 3b-8 (C-1, R-C4, R-C8). Check '
        '3b-5 against R-30 before accepting it. Accepting now would accept '
        'work that is about to change.',
    consequences:
        'Deferral keeps 3b below 100 % and the WP 8 figure provisional; it '
        'does not block implementation work on 3c.',
    dependencies: [
      'Decision-baseline implementation pushed and re-reviewed (WP 8 session)',
      'OB-WP8-04',
    ],
    evidence: [
      BlockerEvidence(
        'WP 8 record sub-stage sections and effort table',
        reference: 'docs/delivery-record/WP8.md',
      ),
      BlockerEvidence('Review B and re-checks', reference: 'WP8.md, 3b-4'),
    ],
    deliveryRecord: 'docs/delivery-record/WP8.md',
  ),
  OwnerBlocker(
    id: 'OB-WP8-04',
    workPackage: BlockerWorkPackage.wp8,
    stage: '3b-7 / WS3',
    reference: 'B-15 (conditional acceptance, D04 §7 2026-11-06); IC-101',
    title:
        'B-15: the migration itself creates IC-101 system exercises; '
        'choose option (a), (b) or (c)',
    description:
        'B-15 was accepted on condition that an independent re-check '
        'confirmed the v7 to v8 migration does not create system exercises '
        'that fail IC-101 (system id format). The re-check (WP 8 session, '
        '2026-11-06 22:01) found that it does. Frozen fixtures v2, v3, v4 '
        'and v5 each hold one built-in exercise "ex-bench" (Bench Press, '
        'is_custom = 0). The frozen v5 to v6 step maps is_custom 0 to '
        'supplied 1, and the 3b-4 migration maps supplied 1 to source = '
        'system (provider repforge, revision 1). The resulting system row '
        'fails IC-101, the migration writes no report entry for it, and it '
        'stays selectable exactly as in v7. A device that migrated it '
        'cannot restore its own format 3 backup on another device: the '
        'restore rejects ex-bench under IC-101. Fixtures v1, v6 and v7 '
        'produce none. Real-data likelihood is probably rare, because no '
        'screen created exercises before schema 6.',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.high,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'The owner decision B-15 says that if the migration introduces the '
        'IC-101 problem, work stops and the inconsistency is resolved '
        'before B-15 is accepted. The WP 8 session stopped and put three '
        'options to the owner.',
    actionRequired:
        'Choose one and record it in D04 §7. (a) Block such exercises: the '
        'migration blocks every system exercise whose id fails IC-101. '
        '(b) Keep them as labelled legacy ids: the migration keeps the '
        'exercise exactly as v7 has it (selectable, id unchanged), records '
        'one report entry per such exercise (category warningForReview, '
        'rule IC-101), and a format 3 restore exempts IC-101 for such an '
        "exercise only when the backup's own report history holds that "
        'migration warning; every other id-format violation stays '
        'rejected; a test pins both migration and restore. (c) Accept that '
        'these backups cannot be restored on another device.',
    recommendation:
        'The WP 8 session recommends (b): the visible state equals v7, '
        'every affected record is reported, nothing is silent, and '
        'cross-device restore works. The integration lead takes no '
        'separate position.',
    consequences:
        "(a) hides exercises that v7 shows today, which breaks the owner's "
        '"no change in visibility" principle in the other direction. '
        '(c) keeps own-device restore working but cross-device restore of '
        'affected devices fails; not recommended. Until decided, WS3 '
        '(backup format 3) cannot close, 3b-7 earns nothing, stage 3b '
        'stays unaccepted and the v8 switch-over waits. The released app '
        'is unaffected: it runs schema v7 and the v8 migration is not '
        'connected.',
    dependencies: [
      'WP 8 session push of the WS3 branch (87a3221..d3913a3)',
      'WP 8 session push of the decision-baseline implementation',
    ],
    evidence: [
      BlockerEvidence(
        'Owner decision B-15 / B-16',
        reference: 'D04 §7, 2026-11-06 "3b-7 B-15 (conditional) and B-16"',
      ),
      BlockerEvidence(
        'Re-check probe R5 (WS3 independent re-check; scratch file in the '
        'WP 8 session, to be recorded in WP8.md with the decision)',
        reference: 'ws3_ic101_test.dart over fixtures fixture_v2..v5.sqlite',
      ),
      BlockerEvidence(
        'Campaign ledger, Workstream A (22:01 and 22:20 reports)',
        reference: 'docs/verification/overnight-campaign-2026-11-06.md',
      ),
      BlockerEvidence(
        'WS3 review findings H1, M1 to M4; O1, O2 open',
        reference: 'WP8.md, "3b-7 review and owner decisions"',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP8.md',
  ),
  OwnerBlocker(
    id: 'OB-WP8-05',
    workPackage: BlockerWorkPackage.wp8,
    stage: '3c',
    reference:
        'D-3c-1; R-13, R-16, R-17, R-18, R-21 (preparation §3.6, 2026-11-07)',
    title:
        'D-3c-1: where the deferred R-13/R-16/R-17/R-18/R-21 schema goes '
        '(amend v8 or add a later step)',
    description:
        'The owner deferred R-13, R-16, R-17, R-18 and R-21 to stage 3c on '
        '2026-11-06 with the wording "they must not enter version 8 now". '
        'Option (a) amends the v8 definition before v8 is connected; option '
        '(b) adds a later schema step. (a) re-opens tables_v8.dart, '
        'drift_schema_v8.json, the generated v8 shapes, from7To8 and backup '
        'format 3. (b) uses the next free version, which WP 17 S6a also '
        'wants.',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.high,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'The meaning of "now" is the owner wording. If it means not during '
        '3b, (a) is open and re-opens the 3b-2 and 3b-4 evidence; if it '
        'means not in v8 at all, only (b) is possible. The preparation '
        'document makes no recommendation ahead of the owner.',
    actionRequired:
        'Clarify the wording, then choose (a) amend the v8 definition '
        'before v8 is connected, or (b) add a later schema step; record it '
        'in D04 §7.',
    recommendation:
        'No recommendation is recorded in the source. It notes that the '
        'cost of adding a CHECK later (R-27) favours (a), and that WP 17 '
        'S6a competing for the next version favours settling this before '
        'v8 is connected. Choosing (a) keeps v9 for WP 17.',
    consequences:
        'Until decided, 3c-2 (reference-data loader) and 3c-4 '
        '(relationships, content, media tables) cannot start. Choosing (b) '
        'makes 3c and WP 17 S6a compete for v9.',
    dependencies: [
      'OB-WP8-04 (stage 3b gate)',
      'WP 17 S6a schema version claim',
    ],
    evidence: [
      BlockerEvidence(
        'Decision table',
        reference: 'docs/wp8-stage-3c-3d-5-6-preparation.md §3.6, §3.7',
      ),
      BlockerEvidence('Deferred items', reference: 'docs/schema-v8.md §3'),
    ],
    deliveryRecord: 'docs/delivery-record/WP8.md',
  ),
  OwnerBlocker(
    id: 'OB-WP8-06',
    workPackage: BlockerWorkPackage.wp8,
    stage: '3c',
    reference: 'D-3c-2; R-13, R-16, R-17, R-18, R-21 (preparation §3.5, §3.6)',
    title:
        'D-3c-2: confirm the five register choices, including whether '
        'releasedOn becomes the reference-row time (R-21)',
    description:
        'Each of R-13 (release columns nullable), R-16 (four stored '
        'relationship kinds, CASCADE), R-17 (length(body) BETWEEN 10 AND '
        '200), R-18 (NOT NULL, CASCADE) and R-21 (lifecycle columns and '
        'release-derived times) carries a recorded recommendation awaiting '
        'confirmation. For R-21 the release file carries releasedOn; '
        'whether it becomes the creation and update time of reference rows '
        'is pending this decision.',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'The register items were owner decisions deferred to 3c; the '
        'recommendations are not decisions until confirmed.',
    actionRequired:
        'Accept or change the recorded choice for each of R-13, R-16, '
        'R-17, R-18 and R-21 (in particular releasedOn versus device '
        'timestamps).',
    recommendation:
        'The preparation document recommends accepting the recorded '
        'recommendations. For R-21 the register records lifecycle columns '
        'with release-derived times, because device timestamps would break '
        'byte-identical loading.',
    consequences:
        'Until confirmed, the domain model still stamps parsed exercises '
        'with releasedOn but the stored form of R-21 is undecided, and '
        '3c-2 and 3c-4 cannot be finalised. Device timestamps would break '
        'byte-identical reference loading.',
    dependencies: ['OB-WP8-05'],
    evidence: [
      BlockerEvidence(
        'Register table',
        reference: 'docs/wp8-stage-3c-3d-5-6-preparation.md §3.5, §3.6',
      ),
      BlockerEvidence(
        'releasedOn wording',
        reference: 'docs/catalogue/release-format-2.md (field table)',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP8.md',
  ),
  OwnerBlocker(
    id: 'OB-WP8-07',
    workPackage: BlockerWorkPackage.wp8,
    stage: '3c',
    reference: 'D-3c-3 (preparation §3.6); plan sections 2 and 19',
    title:
        'D-3c-3: bundle the release and reference JSON as app assets '
        '(app/assets/catalogue/)',
    description:
        'The app bundles only assets/seed/. Plan sections 2 and 19 say '
        'stage 3 loads the approved docs/catalogue/reference/ files, but '
        'the app cannot read docs/. The files are copied to '
        'app/assets/catalogue/ as validated data; they are not yet listed '
        'in the pubspec (the entries were removed on review).',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'Bundling adds files to the shipped app and a CI byte-equality '
        'obligation; the campaign did not bundle ahead of the decision.',
    actionRequired: 'Approve or change how the approved JSON reaches the app.',
    recommendation:
        'The source recommends copying the files into app/assets/catalogue/ '
        'and adding a CI byte-equality check against '
        'docs/catalogue/reference/.',
    consequences:
        'Until approved, the reference-data loader and the release 2 '
        'loading have no bundled input and nothing is registered in the '
        'pubspec.',
    dependencies: ['OB-WP8-05'],
    evidence: [
      BlockerEvidence(
        'Decision table',
        reference: 'docs/wp8-stage-3c-3d-5-6-preparation.md §3.6',
      ),
      BlockerEvidence(
        'Review finding M1 and pubspec removal',
        reference: 'WP8.md, stage 3c pure-domain stream',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP8.md',
  ),
  OwnerBlocker(
    id: 'OB-WP8-08',
    workPackage: BlockerWorkPackage.wp8,
    stage: '3c',
    reference: 'D-3c-5; R-27 (preparation §3.5, §3.6)',
    title: 'D-3c-5: approve the label kinds for the R-27 CHECK',
    description:
        'R-27 adds a CHECK on reference_labels.kind and locale once the '
        'label kinds are approved. The register recommendation is four '
        'kinds: anatomy, pattern, equipment and attribute value.',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.low,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'The kinds fix a stored vocabulary; the CHECK cannot be written '
        'before they are approved.',
    actionRequired: 'Approve or change the list of label kinds.',
    recommendation:
        'The source records the register recommendation: anatomy, '
        'pattern, equipment, attribute value.',
    consequences:
        'Until approved, no CHECK list can be written. If v8 is amended '
        '(OB-WP8-05 option a), the CHECK must be in the v8 definition '
        'before release; adding it later needs a schema change.',
    dependencies: ['OB-WP8-05'],
    evidence: [
      BlockerEvidence(
        'Decision table',
        reference: 'docs/wp8-stage-3c-3d-5-6-preparation.md §3.5, §3.6',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP8.md',
  ),
  OwnerBlocker(
    id: 'OB-WP8-09',
    workPackage: BlockerWorkPackage.wp8,
    stage: '3c',
    reference: 'D-3c-6 (preparation §3.6); merge fea71c8 (2026-11-07 campaign)',
    title:
        'D-3c-6: confirm or reverse the merge of the pure-domain 3c stream '
        '(fea71c8)',
    description:
        'D-3c-6 recommended allowing pure-domain and specification work '
        'only, with no merge to the campaign branch before the 3b gate. '
        'The campaign lead merged the stream (fea71c8) because the mandate '
        'asked for the work and the merge has no runtime effect: no '
        'migration, schema, v8 connection, bundled asset or call site.',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'The merge departed from the recommended wording of D-3c-6, so '
        'only the owner can confirm it or have it reversed.',
    actionRequired:
        'Confirm the merge stays, or reverse it (the record gives '
        'git revert -m 1 fea71c8).',
    recommendation:
        'The record states the facts and the revert command and takes no '
        'position; the choice is the owner.',
    consequences:
        'Confirming keeps the stream and its 0.58 implemented points as a '
        'sensitivity; reversing removes the code from the campaign branch '
        'and the work is redone later. Either way stage 3b is untouched.',
    dependencies: ['OB-WP8-04'],
    evidence: [
      BlockerEvidence(
        'Campaign section',
        reference:
            'WP8.md, "Overnight programme acceleration campaign (2026-11-07) '
            '— stage 3c pure-domain stream"',
      ),
      BlockerEvidence(
        'Decision table',
        reference: 'docs/wp8-stage-3c-3d-5-6-preparation.md §3.6',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP8.md',
  ),
  // --------------------------------------------------------------- WP 11
  OwnerBlocker(
    id: 'OB-WP11-01',
    workPackage: BlockerWorkPackage.wp11,
    stage: 'Start and stage breakdown',
    reference:
        'WP 11 plan §10 decision 1, §9 (2026-11-06, reviewed 2026-11-07)',
    title:
        'Approve the WP 11 stage breakdown (7.0 points) and settle the '
        'TRN-027/TRN-028/NUT-019 scope',
    description:
        'The plan proposes a stage breakdown summing to 7.00 points '
        '(A 0.75, B 1.00, C 0.75, D1 1.00, D2 0.50, E 1.00, F 1.00, G1 '
        '0.50, G2 0.50). NUT-019 is allocated in D06; the TRN-027 screens '
        'and TRN-028 are only "proposed" in the WP 9 record, so the 7.0 '
        'baseline may not cover them. Options: (a) approve as written, '
        'TRN-028 built last and dropped if points run short; (b) order an '
        'estimate review that may raise the total; (c) remove TRN-028 '
        'from WP 11.',
    category: BlockerCategory.scopeApproval,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'The plan is a proposal and the stage breakdown and any change to '
        'scope or total points need a traceable owner decision. The '
        'campaign mandate authorised work to start; it did not approve the '
        'breakdown or settle the TRN-027/028 scope question.',
    actionRequired:
        'Choose (a), (b) or (c) and approve or change the section 9 '
        'breakdown; state the choice in D04 section 7.',
    recommendation:
        'The plan recommends (a), with D2 and TRN-028 marked as the first '
        'items to descope.',
    consequences:
        'Without approval the WP 11 sub-allocations stay proposed and the '
        'earned-point reporting cannot rely on them. (b) may raise the '
        'total and the programme denominators; (c) drops TRN-028 from the '
        'package.',
    dependencies: ['WP 8 stage 3d for stage D2 (per-muscle figures)'],
    evidence: [
      BlockerEvidence(
        'Plan, decision 1 and stage table',
        reference: 'docs/wp11-analytics-plan.md §9, §10',
      ),
      BlockerEvidence(
        'Campaign status of WP 11',
        reference: 'docs/verification/overnight-campaign-2026-11-07.md',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP11.md',
  ),
  OwnerBlocker(
    id: 'OB-WP11-02',
    workPackage: BlockerWorkPackage.wp11,
    stage: 'G1',
    reference: 'WP 11 plan §10 decision 10; GOL-012, OQ-15',
    title:
        'Sign the GOL-012 data-quality thresholds (OQ-15) and the '
        'reviewer-raised provenance and regularity choices',
    description:
        'Proposed thresholds: 28 days of data, food logged on 80 % of '
        'days, 90 % of energy verified or user-entered, weight on 3 days '
        'per week. Result shown (a) in a developer or Settings status '
        'line, or (b) not shown. The independent reviewer raised two '
        'further choices: (1) which energy provenances count as "verified '
        'or user-entered": the pure computation currently excludes '
        'crowdsourced and counts user-entered, which reverses the '
        'strength order of nutrition calculation spec §8; (2) whether '
        'weigh-in regularity is judged by the weakest 7-day block or by an '
        'average. Note that "days of data" is measured as the span from '
        'the earliest record.',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'The plan states the owner must sign the figures; the thresholds '
        'are proposals. The provenance set and the regularity rule decide '
        'what a pass means and are product choices, not engineering ones.',
    actionRequired:
        'Sign or change each threshold; choose where the result shows; '
        'choose the counted provenances; choose weakest-block or average '
        'for weigh-in regularity; confirm the span-from-earliest-record '
        'measure of days of data.',
    recommendation:
        'The plan recommends keeping the proposed thresholds, showing the '
        'result in a Settings status line and shipping no recommendation '
        'feature. The source states no recommendation for the two '
        'reviewer-raised choices.',
    consequences:
        'Until signed, stage G1 (0.50 points) keeps the proposed '
        'thresholds and cannot be accepted, and GOL-011 forbids any '
        'coaching or recommendations. Different provenance or regularity '
        'rules change which datasets pass the check.',
    dependencies: ['OB-WP11-01'],
    evidence: [
      BlockerEvidence(
        'Plan, decision 10 and GOL-012 row',
        reference: 'docs/wp11-analytics-plan.md §2, §10',
      ),
      BlockerEvidence(
        'Independent review of the WP 11 domain',
        reference: 'docs/verification/overnight-campaign-2026-11-07.md',
      ),
      BlockerEvidence(
        'Provenance strength order',
        reference: 'docs/nutrition-calculation-spec.md §8',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP11.md',
  ),
  // --------------------------------------------------------------- WP 12
  OwnerBlocker(
    id: 'OB-WP12-01',
    workPackage: BlockerWorkPackage.wp12,
    stage: 'Decision (before stage 1)',
    reference: 'OQ-08, OQ-06, DAT-009 to DAT-013, ADR-0012',
    title:
        'Decide whether RepForge has accounts and cloud sync, and who '
        'runs the backend',
    description:
        'WP 12 is optional. The owner must choose between no accounts '
        'with file backup only, an own backend with a RepForge sync '
        'protocol, or a third-party sync service. The choice sets the '
        'privacy policy, account deletion, conflict policy, cost and test '
        'plan.',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.low,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'A backend, a privacy policy and a budget are product and legal '
        'decisions. The delivery agents cannot choose them. D06 lists '
        '"owner decision" and "privacy policy" as dependencies. Code '
        'beyond the existing sync columns and backup would be a '
        'stub with no working implementation.',
    actionRequired:
        'Read ADR-0012, choose option A, B or C, and record the choice in '
        'the ADR Decision section and in D04 section 7 (answering OQ-08).',
    recommendation:
        'The ADR proposes option A (no accounts in v1; file backup only), '
        'with a revisit trigger: a named multi-device need, a stable '
        'schema after v9, a budget and a legal reviewer.',
    consequences:
        'A closes WP 12 as not pursued and keeps GEN-009 true. B or C '
        'needs a new effort allocation, a legal review, a schema '
        'migration and a sync test harness before any code. Deferral '
        'changes nothing in the core programme.',
    dependencies: [
      'OQ-06 retention policy',
      'For B or C, a budget and a legal reviewer',
      'WP 8 v8 and WP 17 v9 schema acceptance',
    ],
    evidence: [
      BlockerEvidence(
        'ADR proposal',
        reference: 'docs/adr/ADR-0012-accounts-backup-and-sync-backend.md',
      ),
      BlockerEvidence(
        'Sync columns',
        reference: 'app/lib/data/db/tables.dart lines 3 to 9',
      ),
      BlockerEvidence(
        'Backup format 2',
        reference: 'app/lib/data/repositories/drift_backup_repository.dart',
      ),
      BlockerEvidence(
        'Requirements',
        reference: 'D04 DAT-009 to DAT-013, GEN-009, OQ-08',
      ),
      BlockerEvidence('Roadmap entry', reference: 'D06 "WP 12"'),
      BlockerEvidence(
        'Summary',
        reference: 'docs/verification/wp12-wp13-owner-decisions-2026-11-07.md',
      ),
    ],
    deliveryRecord: 'docs/adr/ADR-0012-accounts-backup-and-sync-backend.md',
  ),
  // --------------------------------------------------------------- WP 13
  OwnerBlocker(
    id: 'OB-WP13-01',
    workPackage: BlockerWorkPackage.wp13,
    stage: 'Decision (before stage 1)',
    reference: 'OQ-16, PLT-005, PLT-006, ADR-0013',
    title:
        'Decide health integration scope and package, and provide devices '
        'for verification',
    description:
        'WP 13 is optional. The owner must decide whether Health Connect '
        'and HealthKit are read only or also write (OQ-16), approve a '
        'package or native route after the standards section 4 checks, '
        'and supply the devices and the Apple Developer account for the '
        'device matrix.',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.low,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'Scope and the privacy review are owner decisions. Acceptance '
        'needs real devices, a signed iOS build and store-policy checks, '
        'which the delivery agents cannot do (D07 section 3). A port '
        'without a verified adapter would be a stub with no working '
        'implementation (standards '
        'section 10).',
    actionRequired:
        'Read ADR-0013, decide the scope for stage 1 and stage 2, approve '
        'or reject the package route, and say when devices and accounts '
        'are available. After approval, an agent runs the standards '
        'section 4 checks and the owner runs the device checklist.',
    recommendation:
        'The ADR proposes stage 1 as weight read plus workout summary '
        'write, and stage 2 as nutrition write after stage 1 passes on '
        'devices. It prefers the health package if it passes the checks, '
        'otherwise own platform channels, and starting when devices and '
        'the Apple membership are ready.',
    consequences:
        'Deferral keeps WP 13 at 0 earned points and changes nothing in '
        'the core programme. Approval adds a dependency or native code, a '
        'schema migration for imported weight, and native manifest and '
        'entitlement changes, each recorded in D03.',
    dependencies: [
      'Owner devices (Android and iPhone)',
      'Apple Developer Program membership',
      'Standards section 4 checks on the chosen package',
      'Schema sequencing after WP 8 v8 and WP 17 v9',
    ],
    evidence: [
      BlockerEvidence(
        'ADR proposal',
        reference: 'docs/adr/ADR-0013-health-platform-integration.md',
      ),
      BlockerEvidence(
        'Adapter rule',
        reference: 'app/test/architecture/plugin_isolation_test.dart',
      ),
      BlockerEvidence('Existing adapters', reference: 'app/lib/data/platform/'),
      BlockerEvidence(
        'Requirements',
        reference: 'D04 PLT-003 to PLT-006, OQ-16',
      ),
      BlockerEvidence(
        'Limits of CI',
        reference: 'D07 section 3; D03 section 2.5',
      ),
      BlockerEvidence('Roadmap entry', reference: 'D06 "WP 13"'),
      BlockerEvidence(
        'Summary',
        reference: 'docs/verification/wp12-wp13-owner-decisions-2026-11-07.md',
      ),
    ],
    deliveryRecord: 'docs/adr/ADR-0013-health-platform-integration.md',
  ),
  // --------------------------------------------------------------- WP 14
  OwnerBlocker(
    id: 'OB-WP14-01',
    workPackage: BlockerWorkPackage.wp14,
    stage: 'Signing',
    reference: 'WP14.md, Owner actions: Owner action 1',
    title: 'Store signing secrets and release environment',
    description:
        'Generate the Android upload keystore offline and provision the '
        'release environment: ANDROID_KEYSTORE (base64), '
        'ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_PASSWORD and '
        'ANDROID_KEY_ALIAS, with a required reviewer on the release '
        'environment. Also decide on Play App Signing so the upload key can '
        'be rotated.',
    category: BlockerCategory.externalInfrastructure,
    priority: BlockerPriority.high,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'Secrets and keystores are owner-held and must never be committed '
        '(engineering standards section 9). Until they exist release.yml '
        'fails at its first android step by design.',
    actionRequired:
        'Create the keystore offline, set the four secrets in the '
        'repository release environment, add a required reviewer, and '
        'decide on Play App Signing. Deployment rules: if the release '
        'environment is limited to v* tags, the manual workflow_dispatch '
        'path from a branch is refused (allow the dispatch branch, or use '
        'tags only); an environment that does not exist yet is created '
        'automatically without a reviewer, so create it deliberately '
        '(review finding L4).',
    recommendation:
        'The record states the actions and the deployment-rule caveats and '
        'gives no recommendation on Play App Signing.',
    consequences:
        'Without the secrets the signed-release deliverable (0.20 points) '
        'stays unearned and the D06 acceptance (a tagged release produces '
        'signed artefacts) cannot be met.',
    evidence: [
      BlockerEvidence(
        'Owner actions list',
        reference: 'docs/delivery-record/WP14.md, "Owner actions" item 1',
      ),
      BlockerEvidence(
        'Progress table and blockers',
        reference: 'docs/delivery-record/WP14.md, "Effort points and progress"',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP14.md',
  ),
  OwnerBlocker(
    id: 'OB-WP14-02',
    workPackage: BlockerWorkPackage.wp14,
    stage: 'First release',
    reference: 'WP14.md, Owner actions: Owner action 2',
    title: 'Decide the first release version and tag it',
    description:
        'Decide the first version (0.4.0 as in pubspec, or another), move '
        'the [Unreleased] changelog entries under a dated version heading, '
        'bump app/pubspec.yaml in the same commit, and tag vX.Y.Z. The '
        'build number +N is the Android versionCode and must increase for '
        'Google Play. A debug-latest tester will reinstall once when moving '
        'to the signed release (different certificate).',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'The version is a product decision and the tag triggers a release; '
        'the agents invented no version (CHANGELOG.md states no tag has '
        'been cut).',
    actionRequired:
        'Choose the version, make the changelog and pubspec commit (name '
        'and +N build number), and push the tag; confirm the one-time '
        'reinstall for debug-latest testers.',
    recommendation: 'The record gives no recommendation on the version number.',
    consequences:
        'No tag means release.yml is never exercised and the verification '
        'run needed for acceptance cannot happen.',
    dependencies: ['OB-WP14-01'],
    evidence: [
      BlockerEvidence(
        'Owner actions list',
        reference: 'docs/delivery-record/WP14.md, "Owner actions" item 2',
      ),
      BlockerEvidence(
        'Progress table and blockers',
        reference: 'docs/delivery-record/WP14.md, "Effort points and progress"',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP14.md',
  ),
  OwnerBlocker(
    id: 'OB-WP14-03',
    workPackage: BlockerWorkPackage.wp14,
    stage: 'Store listings',
    reference: 'WP14.md, Owner actions: Owner action 3',
    title: 'Provide or approve the store listings',
    description:
        'Provide or approve names, descriptions, screenshots, privacy '
        'policy and data-safety and age-rating answers for Google Play and '
        'the App Store.',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'Listing content and legal answers (privacy policy, data safety, '
        'age rating) are the owner own content and statements.',
    actionRequired:
        'Supply or approve the listing text, screenshots, privacy policy '
        'and the data-safety and age-rating answers for both stores.',
    recommendation: 'The record gives no recommendation.',
    consequences:
        'The store listing deliverable (0.15 points) cannot be done and no '
        'store submission is possible.',
    evidence: [
      BlockerEvidence(
        'Owner actions list',
        reference: 'docs/delivery-record/WP14.md, "Owner actions" item 3',
      ),
      BlockerEvidence(
        'Progress table and blockers',
        reference: 'docs/delivery-record/WP14.md, "Effort points and progress"',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP14.md',
  ),
  OwnerBlocker(
    id: 'OB-WP14-04',
    workPackage: BlockerWorkPackage.wp14,
    stage: 'Beta accounts',
    reference: 'WP14.md, Owner actions: Owner action 4',
    title: 'Open the beta distribution accounts',
    description:
        'Google Play Console (internal testing track) and the Apple '
        'Developer Program with TestFlight; for iOS signing, the App Store '
        'Connect API key secrets APP_STORE_CONNECT_KEY_ID, _ISSUER_ID and '
        '_KEY_P8 per D07 section 2.4.',
    category: BlockerCategory.externalInfrastructure,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'Accounts, memberships and API keys belong to the owner. iOS stays '
        'simulator-only without an Apple Developer Program membership.',
    actionRequired:
        'Create or provide the Play Console and Apple Developer accounts '
        'and set the App Store Connect key secrets.',
    recommendation: 'The record gives no recommendation.',
    consequences:
        'The beta distribution pipeline (0.20 points) cannot be built or '
        'exercised; iOS remains simulator-only.',
    evidence: [
      BlockerEvidence(
        'Owner actions list',
        reference: 'docs/delivery-record/WP14.md, "Owner actions" item 4',
      ),
      BlockerEvidence(
        'Progress table and blockers',
        reference: 'docs/delivery-record/WP14.md, "Effort points and progress"',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP14.md',
  ),
  OwnerBlocker(
    id: 'OB-WP14-05',
    workPackage: BlockerWorkPackage.wp14,
    stage: 'Crash reporting',
    reference: 'WP14.md, Owner actions: Owner action 5',
    title: 'Decide on opt-in crash reporting',
    description:
        'Decide whether to add opt-in crash reporting at all, which '
        'provider, and what data it may send, given the local-first posture '
        '(ADR-0005).',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.low,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'Sending any data off the device is a privacy and product decision '
        'the agents cannot make.',
    actionRequired:
        'Decide whether to add crash reporting; if yes, name the provider '
        'and the data allowed.',
    recommendation: 'The record gives no recommendation.',
    consequences:
        'If not wanted, the adapter and settings switch (0.10 points) are '
        'dropped or rescoped; if wanted, they wait for the provider choice.',
    evidence: [
      BlockerEvidence(
        'Owner actions list',
        reference: 'docs/delivery-record/WP14.md, "Owner actions" item 5',
      ),
      BlockerEvidence(
        'Progress table and blockers',
        reference: 'docs/delivery-record/WP14.md, "Effort points and progress"',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP14.md',
  ),
  OwnerBlocker(
    id: 'OB-WP14-06',
    workPackage: BlockerWorkPackage.wp14,
    stage: 'Test certificate',
    reference: 'WP14.md, Owner actions: Owner action 6',
    title: 'Approve the test-build certificate approach',
    description:
        'Confirm the cache-based debug keystore is acceptable, or provide a '
        'keystore as a repository secret instead; accept that testers '
        'uninstall once after the first run (back up data), and again if '
        'the cache entry is evicted.',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'The choice trades a stable certificate against owner-held secrets '
        'and tester inconvenience; the first CI run of the cache steps has '
        'not happened.',
    actionRequired:
        'Choose the cache-based debug keystore or provide a keystore '
        'secret, and accept the one-time uninstall by testers.',
    recommendation: 'The record gives no recommendation.',
    consequences:
        'Until chosen, two CI builds may keep different certificates and '
        'cannot be installed over each other.',
    evidence: [
      BlockerEvidence(
        'Owner actions list',
        reference: 'docs/delivery-record/WP14.md, "Owner actions" item 6',
      ),
      BlockerEvidence(
        'Progress table and blockers',
        reference: 'docs/delivery-record/WP14.md, "Effort points and progress"',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP14.md',
  ),
  OwnerBlocker(
    id: 'OB-WP14-07',
    workPackage: BlockerWorkPackage.wp14,
    stage: 'Device checklist',
    reference: 'WP14.md, Owner actions: Owner action 7',
    title: 'Run the release device checklist on Android and iPhone',
    description:
        'Run the release device checklist on an Android phone and an iPhone '
        'when it is written. It also carries the open WP 6 camera items and '
        'the D05 V-01 airplane-mode check.',
    category: BlockerCategory.physicalDeviceAction,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'Device checks need physical devices (D07 section 3). The checklist '
        'itself is not yet written.',
    actionRequired:
        'When the checklist exists, run it on one Android phone and one '
        'iPhone and return the results.',
    recommendation: 'The record gives no recommendation.',
    consequences:
        'The device-run deliverable (0.10 points) stays unearned and the WP '
        '6 camera items stay open.',
    dependencies: ['Release device checklist written (WP 14 engineering item)'],
    evidence: [
      BlockerEvidence(
        'Owner actions list',
        reference: 'docs/delivery-record/WP14.md, "Owner actions" item 7',
      ),
      BlockerEvidence(
        'Progress table and blockers',
        reference: 'docs/delivery-record/WP14.md, "Effort points and progress"',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP14.md',
  ),
  OwnerBlocker(
    id: 'OB-WP14-08',
    workPackage: BlockerWorkPackage.wp14,
    stage: 'NUT-023 schema',
    reference: 'WP14.md, Owner actions: Owner action 8',
    title: 'Decide the NUT-023 source schema',
    description:
        'Decide whether a dedicated source_id column (and optionally import '
        'or refresh date and licence text) is wanted. Until decided, the '
        'identifier is the barcode column and only Open Food Facts is '
        'covered.',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.low,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'A schema change must be coordinated with WP 8 and WP 17 and is an '
        'owner decision.',
    actionRequired:
        'Choose whether to add the column or columns; record the decision.',
    recommendation: 'The record gives no recommendation.',
    consequences:
        'Until decided NUT-023(1) is only partly met (0.15 of the 0.30 '
        'NUT-023 allocation is unearned).',
    dependencies: ['Schema sequencing with WP 8 and WP 17'],
    evidence: [
      BlockerEvidence(
        'Owner actions list',
        reference: 'docs/delivery-record/WP14.md, "Owner actions" item 8',
      ),
      BlockerEvidence(
        'Progress table and blockers',
        reference: 'docs/delivery-record/WP14.md, "Effort points and progress"',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP14.md',
  ),
  OwnerBlocker(
    id: 'OB-WP14-09',
    workPackage: BlockerWorkPackage.wp14,
    stage: 'Acceptance',
    reference: 'WP14.md, Owner actions: Owner action 9',
    title: 'Record the WP 14 acceptance decision',
    description:
        'After a tagged release has produced signed artefacts, and the '
        'review, record the WP 14 acceptance decision.',
    category: BlockerCategory.ownerAcceptance,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'Only the owner can record acceptance; the record may not reach 100 '
        '% without it.',
    actionRequired:
        'Record acceptance (or the changes wanted) once the verification '
        'run and review are done.',
    recommendation: 'None: acceptance is the owner decision.',
    consequences:
        'WP 14 stays at its earned points and cannot be reported complete.',
    dependencies: ['OB-WP14-01', 'OB-WP14-02'],
    evidence: [
      BlockerEvidence(
        'Owner actions list',
        reference: 'docs/delivery-record/WP14.md, "Owner actions" item 9',
      ),
      BlockerEvidence(
        'Progress table and blockers',
        reference: 'docs/delivery-record/WP14.md, "Effort points and progress"',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP14.md',
  ),
  // --------------------------------------------------------------- WP 15
  OwnerBlocker(
    id: 'OB-WP15-01',
    workPackage: BlockerWorkPackage.wp15,
    stage: 'Stage 3 (disposition)',
    reference: 'NUT-022; D06 WP 15 scope; WP 15 record "Scope discrepancy"',
    title: 'Custom-food serving-definition entry units',
    description:
        'D06 says the entry units apply to food logging, portion sheets and '
        'recipe ingredients. Stage 2 covers the portion and ingredient '
        'sheets; the custom-food serving-definition amounts still take the '
        'reference unit only. The owner asked for this to be decided '
        'explicitly, not dropped.',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'NUT-022 acceptance text does not name custom-food servings; adding '
        'them is a scope call the agents may not make.',
    actionRequired:
        'Choose: (a) add a per-row unit selector to the custom-food serving '
        'amounts as WP 15 stage 3 (about 0.25 points), or (b) record the '
        'custom-food servings as outside NUT-022 for WP 15.',
    recommendation:
        'Option (a): it is small, reuses EntryUnit, and removes the only '
        'food-quantity entry where a user cannot type kilograms.',
    consequences:
        'Deferral keeps 0.25 points unearned and leaves the scope '
        'discrepancy open at acceptance; option (b) closes it with no code.',
    evidence: [
      BlockerEvidence(
        'Record section',
        reference: 'WP15.md, "Scope discrepancy kept visible"',
      ),
      BlockerEvidence(
        'Unchanged screen',
        reference:
            'app/lib/features/nutrition/presentation/custom_food_screen.dart',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP15.md',
  ),
  OwnerBlocker(
    id: 'OB-WP15-02',
    workPackage: BlockerWorkPackage.wp15,
    stage: 'Stage 1',
    reference: 'Nutrition calculation specification revision 1.4',
    title: 'Approve specification revision 1.4 (entry units, E42 to E49)',
    description:
        'Revision 1.4 adds §2.3 entry-unit rules and worked examples E42 to '
        'E49, all executed as tests. Revision 1.3 stays the approved text '
        'until the owner approves 1.4.',
    category: BlockerCategory.scopeApproval,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'Specification revisions are approved by the owner (as 1.3 was).',
    actionRequired:
        'Read §2.3 and E42 to E49 in docs/nutrition-calculation-spec.md and '
        'record approval of revision 1.4, or name the change you want.',
    recommendation:
        'Approve: no approved rule changed, every example runs as a test, '
        'and the R15-06 API-precision note is recorded.',
    consequences:
        'Until approved, the implemented behaviour is "proposed" and WP 15 '
        'cannot be accepted. The 0.20-point line "specification revision '
        '1.4 and owner decisions (including OQ-02)" is shared with '
        'OB-WP15-03 and OB-WP15-04.',
    evidence: [
      BlockerEvidence(
        'Specification',
        reference: 'docs/nutrition-calculation-spec.md, revision table',
      ),
      BlockerEvidence(
        'Executed examples',
        reference: 'app/test/domain/nutrition_spec_examples_units_test.dart',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP15.md',
  ),
  OwnerBlocker(
    id: 'OB-WP15-03',
    workPackage: BlockerWorkPackage.wp15,
    stage: 'Stage 1',
    reference: 'OQ-02 (D04); D-5 (parallel assessment)',
    title: 'Imperial entry units (lb, oz, fl oz): in scope or not',
    description:
        'OQ-02 asks whether imperial unit support is required in v1. '
        'Imperial units are display-only today; imperial entry is not '
        'offered. WP 9 weight entry is kg-only for the same reason.',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'OQ-02 has stayed open since WP 3; it changes conversion, display '
        'and test scope across nutrition, training and body data.',
    actionRequired:
        'Decide: metric only for v1, or imperial entry (name the units) in '
        'a later WP with its own allocation.',
    recommendation:
        'Metric only for v1 (GEN-003 default), with imperial entry recorded '
        'as a roadmap extension; this closes OQ-02 for WP 15 acceptance.',
    consequences:
        'Deferral leaves OQ-02 open on three work packages and keeps the '
        'shared 0.20-point WP 15 decision line (with OB-WP15-02 and '
        'OB-WP15-04) unearned.',
    evidence: [
      BlockerEvidence('Open question', reference: 'D04 OQ-02'),
      BlockerEvidence(
        'Current rule',
        reference: 'docs/nutrition-calculation-spec.md §2.3 (rev 1.4)',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP15.md',
  ),
  OwnerBlocker(
    id: 'OB-WP15-04',
    workPackage: BlockerWorkPackage.wp15,
    stage: 'Stage 1',
    reference: 'WP 15 stage 1 decision "mg entry"',
    title: 'Where, if anywhere, milligram entry is offered',
    description:
        'Milligram entry exists in the domain but is not offered in any '
        'sheet, because the 0.1 g store step makes it coarse (250 mg '
        'rounds to 0.3 g).',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.low,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'Offering a unit the store cannot represent faithfully is a '
        'product choice, recorded for the owner.',
    actionRequired:
        'Decide: keep mg hidden (current), or offer it on named screens '
        'with the rounding shown.',
    recommendation: 'Keep mg hidden until a finer store step is ever approved.',
    consequences:
        'No functional impact either way; the decision only needs '
        'recording for acceptance.',
    evidence: [
      BlockerEvidence(
        'Domain',
        reference: 'app/lib/domain/units/entry_unit.dart (forBase)',
      ),
      BlockerEvidence('Record', reference: 'WP15.md, stage 1 decisions'),
    ],
    deliveryRecord: 'docs/delivery-record/WP15.md',
  ),
  OwnerBlocker(
    id: 'OB-WP15-05',
    workPackage: BlockerWorkPackage.wp15,
    stage: 'Closure',
    reference: 'D06 WP 15 acceptance criteria',
    title: 'Owner acceptance of WP 15 stages 1 and 2',
    description:
        'Stages 1 and 2 are implemented; a separate agent reviewed them '
        '(R15-01 to R15-06 dispositioned) and the review-fix commit 26e9f10 '
        'was re-checked by an independent agent during the overnight '
        'campaign (see the WP 15 record). CI evidence: four workflows green '
        'at 353fcd8, and the integrated campaign commit carries the review '
        "fixes. Acceptance and closure (0.25 points) are the owner's; "
        'whether an agent review satisfies the acceptance criteria or a '
        'human reviewer is required is OB-PROG-01.',
    category: BlockerCategory.ownerAcceptance,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked: 'Acceptance is reserved to the owner.',
    actionRequired:
        'After OB-WP15-01 to OB-WP15-04, check the acceptance evidence in '
        'the WP 15 record against the D06 criteria and record acceptance.',
    recommendation:
        'Accept once the four decisions above are recorded; the acceptance '
        'tests (0.25 kg as 250 g, exact factors, round trip) pass.',
    consequences:
        'WP 15 stays at its earned implementation figure and open in the '
        'programme roll-up.',
    dependencies: [
      'OB-WP15-01',
      'OB-WP15-02',
      'OB-WP15-03',
      'OB-WP15-04',
      'OB-PROG-01',
    ],
    evidence: [
      BlockerEvidence(
        'Review table and CI evidence',
        reference: 'WP15.md, "Independent review of stages 1–2"',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP15.md',
  ),
  // --------------------------------------------------------------- WP 17
  OwnerBlocker(
    id: 'OB-WP17-01',
    workPackage: BlockerWorkPackage.wp17,
    stage: 'All',
    reference: 'Effort-point standard §6; review R17-10',
    title: 'Approve the WP 17 effort-point allocation (9.00 proposed)',
    description:
        'WP 17 was created by owner decision D-1 and its 9.00-point '
        'allocation with a stage breakdown was proposed, but the standard '
        "requires owner approval of a new WP's allocation. Earned credit "
        '(3.00) is reported against the unapproved figure.',
    category: BlockerCategory.scopeApproval,
    priority: BlockerPriority.high,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'The programme denominator changes (105 to 114 full, 97 to 106 '
        'core) only on an owner decision.',
    actionRequired:
        'Approve 9.00 with the stage table, or set another figure with '
        'reasons; record it in D04 §7.',
    recommendation:
        'Approve 9.00: it is sized relative to WP 7 (8) and WP 9 (9) and '
        'already split by stage with evidence lines.',
    consequences:
        'Until approved, every WP 17 percentage is provisional and the '
        'programme roll-up must show both denominators.',
    evidence: [
      BlockerEvidence(
        'Proposal',
        reference: 'WP17.md, "Effort points and progress"',
      ),
      BlockerEvidence(
        'Standard',
        reference: 'docs/governance/effort-points-and-progress-reporting.md §6',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP17.md',
  ),
  OwnerBlocker(
    id: 'OB-WP17-02',
    workPackage: BlockerWorkPackage.wp17,
    stage: 'S3b-ii',
    reference: 'NUT-014 remainder; review R17-01',
    title:
        'Confirm S3b-ii (frequent foods, quantity pre-fill, saved meals '
        'in recents) stays in WP 17',
    description:
        'S3b-i delivered the ten most recent foods and recipes. The NUT-014 '
        'remainder (20 most-frequent foods in 90 days, last-used quantity '
        'pre-fill, saved meals in recents, which needs a saved-meal id on '
        'log entries and therefore schema v9) is split out as S3b-ii, '
        '0.20 points, not started.',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.low,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'The saved-meal part needs a schema change, which D-2 defers to v9; '
        'keeping or moving the remainder is a scope decision.',
    actionRequired:
        'Confirm S3b-ii stays in WP 17 (frequent list and pre-fill now, '
        'saved meals after v9), or move it to the v9 stage entirely.',
    recommendation:
        'Keep it in WP 17 and let the non-schema parts proceed after the '
        'release; defer only the saved-meal part to S6.',
    consequences:
        'No user-visible loss either way; the decision fixes where 0.20 '
        'points are earned.',
    evidence: [
      BlockerEvidence('Review finding', reference: 'WP17.md, R17-01'),
      BlockerEvidence(
        'Delivered subset',
        reference: 'app/lib/features/nutrition/application/recent_items.dart',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP17.md',
  ),
  OwnerBlocker(
    id: 'OB-WP17-03',
    workPackage: BlockerWorkPackage.wp17,
    stage: 'S4d',
    reference: 'TRN-021; review R17-04',
    title:
        'Rest-timer survival across process death: implement in S4 before '
        'acceptance, or accept S4 without it',
    description:
        'The rest timer lives in memory only. Review R17-04 established that '
        'persisting it needs no schema change (a typed accessor on the '
        'settings table), so the deferral is a scope and effort choice '
        '(0.30 points, not started), not a technical boundary.',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.low,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'The WP 17 record (R17-04) keeps S4d in S4 at 0.30 points, not '
        'started, with no reallocation to v9, and says the owner decides '
        'whether it is done before S4 acceptance. The campaign brief adds '
        'that agents do not implement it without that decision.',
    actionRequired:
        'Decide: implement S4d in WP 17 S4 before S4 acceptance (about 0.30 '
        'points), or accept S4 without it and leave the 0.30 unearned.',
    recommendation:
        'Accept S4 without it for this release; the background notification '
        'already covers the common case of leaving the app during a rest, '
        'and the change can follow as its own small, reviewed commit.',
    consequences:
        'Without it, a rest in progress is lost if Android kills the '
        'process; the notification still fires. Doing it now adds a small '
        'settings accessor and controller change under full regression.',
    evidence: [
      BlockerEvidence('Review finding', reference: 'WP17.md, R17-04'),
      BlockerEvidence(
        'Timer',
        reference:
            'app/lib/features/training/application/rest_timer_controller.dart',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP17.md',
  ),
  OwnerBlocker(
    id: 'OB-WP17-04',
    workPackage: BlockerWorkPackage.wp17,
    stage: 'S5 / S6',
    reference: 'D-3 (parallel workstream assessment §14)',
    title:
        'Canonical seed recipes: keep editable or make read-only with '
        '"copy to edit"',
    description:
        'The accepted WP 7 behaviour keeps the 22 seed recipes editable '
        '(estimated until every ingredient is linked). The parallel brief '
        'asked for protection of the canonical seed recipes, which '
        'contradicts the accepted behaviour.',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.low,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'Changing an accepted WP 7 behaviour reopens an owner decision.',
    actionRequired:
        'Choose: keep editable (no change), or read-only seed recipes with '
        'copy-to-edit like supplied exercises (needs a provenance marker, '
        'v9).',
    recommendation:
        'Keep editable; the estimated-until-linked flow depends on editing '
        'and users already rely on it.',
    consequences:
        'Read-only would need the v9 provenance column and a migration of '
        'already-edited seed recipes.',
    evidence: [
      BlockerEvidence(
        'Assessment',
        reference: 'docs/verification/parallel-workstream-assessment-2026-11-06.md §5, §14',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP17.md',
  ),
  OwnerBlocker(
    id: 'OB-WP17-05',
    workPackage: BlockerWorkPackage.wp17,
    stage: 'S5',
    reference: 'D-4 (parallel workstream assessment §14)',
    title:
        'Workout catalogue content: approve the 30-plan draft and name '
        'the reviewer',
    description:
        'A draft of 30 workout templates across 10 categories exists, '
        'validated against the 89 current exercise ids. Content approval '
        "and the reviewer are the owner's call; S5 earns nothing until "
        'then (0.80 points).',
    category: BlockerCategory.scopeApproval,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'Editorial content needs an owner-named reviewer; the exercise set '
        'it references is still WP 8 stage 5 scope.',
    actionRequired:
        'Confirm the 89 exercises are the only allowed references for now, '
        'name who reviews the plans, and approve or amend the draft.',
    recommendation:
        'Approve the draft as release-1 content limited to the 89 '
        'exercises; schedule a second pass after WP 8 stage 5.',
    consequences: 'S5 and the S6 importer stay held; no prebuilt plans ship.',
    dependencies: ['OB-WP17-01'],
    evidence: [
      BlockerEvidence(
        'Draft and checker',
        reference: 'docs/workout-catalogue/README.md',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP17.md',
  ),
  OwnerBlocker(
    id: 'OB-WP17-06',
    workPackage: BlockerWorkPackage.wp17,
    stage: 'S6',
    reference: 'D-5 density (NUT-022(2)); see OB-WP15-03 for OQ-02',
    title: 'Whether a food may carry a density for volume to mass conversion',
    description:
        'NUT-022(2) reads: "Volume to mass conversion is only applied where '
        'the food has a stated density; otherwise the app asks for grams." '
        'No density exists in the model, so no volume to mass conversion '
        'exists. D-5 asks whether a food may carry a density (a schema '
        'change, v9).',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.low,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'Adds a column and validation rules; schema is frozen at v8 for '
        'WP 8 and v9 is owned by WP 17.',
    actionRequired:
        'Decide: no density in v1 (current), or an optional density per '
        'food in v9 with the conversion rule.',
    recommendation: 'No density in v1; revisit with the v9 allocation.',
    consequences:
        'Without density, a per-100 ml food cannot be logged in grams. '
        'Today the app offers only ml and l for such a food; whether that '
        'reading of "otherwise the app asks for grams" is acceptable is '
        'for the owner to confirm with this decision.',
    evidence: [
      BlockerEvidence('Requirement', reference: 'D04 NUT-022(2)'),
      BlockerEvidence(
        'Assessment',
        reference: 'docs/verification/parallel-workstream-assessment-2026-11-06.md §14',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP17.md',
  ),
  OwnerBlocker(
    id: 'OB-WP17-07',
    workPackage: BlockerWorkPackage.wp17,
    stage: 'S6c',
    reference: 'D-6 / OQ-04 (D04)',
    title: 'Recipe image: device-only storage and backup size',
    description:
        'OQ-04 asks whether recipes need photos and, if so, whether they are '
        'stored only on the device and included in the backup. S6c (0.70 '
        'points) is held on this.',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.low,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'Affects storage size, backup size and camera and gallery '
        'permissions; needs the v9 schema.',
    actionRequired:
        'Decide: no images in v1, or device-only images with a backup size '
        'limit and the permissions named.',
    recommendation:
        'No images in v1; keep the backup small and permission-free.',
    consequences: 'S6c stays held; recipes remain text-only.',
    evidence: [BlockerEvidence('Open question', reference: 'D04 OQ-04')],
    deliveryRecord: 'docs/delivery-record/WP17.md',
  ),
  OwnerBlocker(
    id: 'OB-WP17-08',
    workPackage: BlockerWorkPackage.wp17,
    stage: 'Scope',
    reference: 'D-7 (parallel workstream assessment §14)',
    title: 'CSV export of nutrition and training: new scope or not',
    description:
        'The parallel brief (§7) asked for CSV export of nutrition and '
        'training. WP 10 delivered measurement CSV export only. Whether '
        'the other two are in scope, and in which WP, is undecided.',
    category: BlockerCategory.scopeApproval,
    priority: BlockerPriority.low,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked: 'New scope needs an owner allocation (standard §6).',
    actionRequired:
        'Decide: out of scope for now, or allocate it (WP 17 or a new WP) '
        'with points.',
    recommendation:
        'Out of scope for this release; reuse the WP 10 exporter later '
        'under its own allocation.',
    consequences: 'No change to the app either way until allocated.',
    evidence: [
      BlockerEvidence(
        'Assessment',
        reference: 'docs/verification/parallel-workstream-assessment-2026-11-06.md §14',
      ),
      BlockerEvidence(
        'Existing exporter',
        reference: 'app/lib/features/measurements/application/export_measurements_csv.dart',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP17.md',
  ),
  OwnerBlocker(
    id: 'OB-WP17-09',
    workPackage: BlockerWorkPackage.wp17,
    stage: 'S3, S4',
    reference: 'WP 17 record, stage criteria',
    title: 'Owner acceptance of WP 17 stages S3 and S4',
    description:
        'S3 (Fuel: pick from library, recents, recipe duplicate and category '
        'filter) and S4 (Train: plan duplicate and delete, save session as '
        'plan, elapsed time, drag reorder) are implemented and '
        'independently reviewed with every finding dispositioned.',
    category: BlockerCategory.ownerAcceptance,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked: 'Acceptance is reserved to the owner.',
    actionRequired:
        'Try the features in the release build, read the S3/S4 review '
        'table and the overnight integration review (findings D-01 to '
        'D-08), and record acceptance or conditions. Two points need your '
        'call: (1) whether deleting a plan should also skip its future '
        'planned occurrences on the schedule (today they stay, labelled '
        '"Deleted workout", with no Start); (2) whether the plan row keeps '
        'its four trailing actions or moves Duplicate, Delete and Archive '
        'into a menu (integration review D-06, deferred).',
    recommendation:
        'Accept S3 and S4 after OB-WP17-01; note the S4 warm-up rule in '
        'save-as-plan (R17-02) as an accepted design choice or override '
        'it; keep the future occurrences of deleted plans as they are (the '
        'user can skip them) and move the row actions into a menu as a '
        'small follow-up.',
    consequences:
        'WP 17 stays at 3.00 earned of 9.00 and its review and acceptance '
        'lines at zero.',
    dependencies: ['OB-WP17-01', 'OB-WP17-02', 'OB-WP17-03', 'OB-PROG-01'],
    evidence: [
      BlockerEvidence(
        'Review table',
        reference: 'WP17.md, "Independent review of S3 and S4"',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP17.md',
  ),
  // ----------------------------------------------------------- Programme
  OwnerBlocker(
    id: 'OB-PROG-01',
    workPackage: BlockerWorkPackage.programme,
    stage: 'Acceptance of WP 15, WP 17 and WP 8 stage 3b',
    reference: 'WP 15 and WP 17 records, "Independent review" sections',
    title:
        'Whether agent reviews satisfy acceptance, or a human reviewer is '
        'required',
    description:
        'Every independent review in the active work packages was done by '
        'a separate agent with fresh context, as the records state, and '
        'each record adds that the owner may still require a human '
        'reviewer before acceptance. The campaign ran further agent reviews '
        '(cross-package integration, the blocker workspace, the WP 15 '
        'review-fix re-check). No decision says whether that is enough.',
    category: BlockerCategory.ownerDecision,
    priority: BlockerPriority.medium,
    initialStatus: BlockerStatus.awaitingOwner,
    assignee: BlockerAssignee.owner,
    whyBlocked:
        'Acceptance criteria name "independent review"; whether an agent '
        'review counts is a governance choice only the owner can make.',
    actionRequired:
        'Decide, for the active work packages: agent reviews with the '
        'recorded dispositions suffice, or a named human reviewer must '
        'sign off before acceptance (and for which packages).',
    recommendation:
        'Accept agent reviews as sufficient for WP 15 and WP 17 stages '
        'S3/S4, given the recorded probes and corrections, and require a '
        'human reviewer only for WP 8 stage 3b (migration and user data).',
    consequences:
        'Requiring a human reviewer everywhere delays every acceptance '
        'until one is available; accepting agent reviews lets the WP 15 '
        'review line (0.10) and the S3/S4 share of the WP 17 review line '
        '(0.50 for S3, S4 and S6; S6 has had no review) be earned once '
        'recorded.',
    evidence: [
      BlockerEvidence(
        'WP 15 review section',
        reference: 'WP15.md, "Independent review of stages 1–2"',
      ),
      BlockerEvidence(
        'WP 17 review section',
        reference: 'WP17.md, "Independent review of S3 and S4"',
      ),
      BlockerEvidence(
        'Campaign reviews',
        reference: 'docs/verification/overnight-campaign-2026-11-06.md',
      ),
    ],
    deliveryRecord: 'docs/delivery-record/WP17.md',
  ),
];
