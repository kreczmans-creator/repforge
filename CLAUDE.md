# RepForge — instructions for Claude Code

RepForge is a Flutter and Dart fitness app (`app/`), local-first SQLite, Android and iOS. Governance lives in `docs/`: engineering standards, ADRs, D01–D08 in `docs/wp0/`, delivery records per work package. Read `docs/README.md` for the map.

## AI coordination (read before any task)

Two AI systems work here under `docs/ai-coordination/AI-COORDINATION-PROTOCOL.md`: ChatGPT reviews independently, Claude Code implements, the project owner decides. The two files below are imported into this session.

@docs/ai-coordination/CURRENT-STATE.md

@docs/ai-coordination/INBOX.md

### Before starting a task
1. Compare the commit in CURRENT-STATE with `git log -1`. If they differ, update CURRENT-STATE before relying on it.
2. Handle, or explicitly defer with a reason in `OUTBOX.md`, every INBOX message whose status is `OPEN` or `IN_PROGRESS`.
3. Open every file in `docs/ai-coordination/reviews/` with findings not `CLOSED` or `ACCEPTED_BY_OWNER`. Note those that touch the planned work.
4. Check dependencies: D06 ordering, open owner decisions, D05 §C verification items.

### After meaningful implementation (a WP stage, a fix set, a closure condition, anything needing a decision)
1. Commit the implementation; obtain CI run IDs.
2. Create `docs/ai-coordination/handoffs/HO-NNNN.md` from `HANDOFF-TEMPLATE.md` (the `/handoff` skill walks through it), citing the exact implementation commit SHA. Commit it.
3. Append a `MSG-OUT` to `OUTBOX.md`; update `CURRENT-STATE.md`; update D05 and the delivery record if they changed.
4. Run `python3 tools/coordination/check_coordination.py` before pushing; fix every error.

### After addressing review findings
- Change only the `Status` and `Resolution` cells of each finding in the review file. Set `RESOLVED` with the fixing commit and the proving test. Append a `MSG-OUT` listing each finding and its evidence.

### Never
- Overwrite, delete or rewrite a message, review or handoff. Append corrections as new entries.
- Record an owner decision that the owner did not state. Silence, green CI or a positive review is not approval.
- Fabricate test results, CI run IDs, device results or acceptance evidence. "Not run" and "unverified" are valid entries.
- Merge to `main`, accept work, or close a finding the reviewer or owner has not seen resolved.
- Put credentials, tokens or keys in any file.

## Engineering rules that apply to every change
- `docs/engineering-standards.md` (Dart style, layering, `Result` errors, 80 % hand-written coverage gate, Conventional Commits).
- Application checks from `app/`: `dart format .`, `flutter analyze --fatal-infos`, `flutter test`. CI: `ci.yml`, `android.yml`, `ios.yml`, `integration.yml`.
- Delivery records in `docs/delivery-record/WP<n>.md` are the acceptance record; D05 holds debt and risks; D06 holds roadmap status. Keep all three accurate.
