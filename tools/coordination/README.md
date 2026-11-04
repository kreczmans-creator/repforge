# Coordination checker (v2)

Validates `docs/ai-coordination/` (stdlib-only Python 3.10+): required files; handoffs
(`HO-NNNN`), reviews (`RV-NNNN`), messages, `DECISION-LOG.md` and `CURRENT-STATE.md`
(metadata, statuses, commits, headings, cross-references); relative links and `CLAUDE.md`
`@imports`. v2 adds handoff/review consistency (Status vs review Outcome, reviewed commit
vs handoff commit, Responds to / Supersedes) and `PROGRAMME.md` (WP table, dependencies,
computed next-eligible packages). `AWAITING_REVIEW`, open findings and open messages are
warnings or info, not errors.

    python3 tools/coordination/check_coordination.py [--root PATH] [--summary FILE]
    python3 tools/coordination/check_coordination.py --write-dashboard
    python3 tools/coordination/check_coordination.py --evidence HO-0007 [--repo owner/name]
    python3 -m unittest discover -s tools/coordination -p 'test_*.py'

- `--summary FILE` appends a Markdown report (use `$GITHUB_STEP_SUMMARY` in CI): errors,
  warnings, open items, review queue, owner decision queue, next eligible packages.
- `--write-dashboard` regenerates `DASHBOARD.md` (deterministic, no dates). A normal run
  fails with "DASHBOARD.md is stale" when the file is missing or differs.
- `--verify-commits` checks recorded SHAs with `git cat-file`; `--append-only-since REF` errors on
  deleted/renamed records and warns on removed lines (listed in the summary). Both default off.
- `--evidence HO-NNNN` prints a reviewer bundle to stdout: handoff, GitHub links (repo from
  `--repo`, `$GITHUB_REPOSITORY` or `origin`), `git diff --stat parent..commit`, open findings.

Exit codes: `0` no errors (warnings allowed), `1` errors, `2` unknown handoff for `--evidence`.
