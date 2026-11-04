# Coordination checker

Validates the AI coordination documents in `docs/ai-coordination/` (stdlib-only Python 3.10+).

Checks: required files exist; handoffs (`HO-NNNN`), reviews (`RV-NNNN`), messages
(INBOX/OUTBOX/archive) and `DECISION-LOG.md` have valid metadata, statuses, dates, commit
hashes, headings and cross-references; `CURRENT-STATE.md` has its commit line and headings;
relative Markdown links and `CLAUDE.md` `@imports` resolve. Open handoffs, findings and
messages, id gaps and missing reviews are reported as warnings.

Run from the repo root:

    python3 tools/coordination/check_coordination.py [--root PATH] [--summary FILE]
    python3 -m unittest discover -s tools/coordination -p 'test_*.py'

`--summary FILE` appends a Markdown report (use `$GITHUB_STEP_SUMMARY` in CI), even on success.

Exit codes: `0` no errors (warnings allowed), `1` one or more errors.
