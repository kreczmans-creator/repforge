import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_coordination as cc  # noqa: E402

SHA = "a" * 40
PARENT = "b" * 40
NEWSHA = "c" * 40
COORD = "docs/ai-coordination"


def handoff(hid="HO-0001", status="ACCEPTED_BY_OWNER", review="RV-0001", commit=f"`{SHA}`",
            skip=(), swap=False, wp="WP 1 \u2014 Thing", parent=f"`{PARENT}`", responds="none",
            supersedes="none", body="Decision DL-0001."):
    heads = [f"## {h}" for h in cc.HANDOFF_HEADINGS if h not in skip]
    if swap:
        heads[0], heads[1] = heads[1], heads[0]
    meta = (f"- Author: Claude Code\n- Date: 2026-11-04\n- Status: {status}\n"
            f"- Work package: {wp}\n- Branch: `b`\n- Commit: {commit}\n- Parent: {parent}\n"
            f"- Review: {review}\n- Responds to: {responds}\n- Supersedes: {supersedes}\n")
    return f"# {hid} \u2014 Title\n\n{meta}\n" + f"\n\n{body}\n".join(heads) + f"\n\n{body}\n"


def review(rid="RV-0001", ho="HO-0001", rows=None, skip=(), outcome="APPROVED_FOR_OWNER_ACCEPTANCE",
           commit=SHA):
    rows = rows if rows is not None else [f"| {rid}-F1 | High | CLOSED | Bug | e | fixed |"]
    out = [f"# {rid} \u2014 Title\n", "- Author: ChatGPT", "- Date: 2026-11-04",
           "- Status: CLOSED", f"- Outcome: {outcome}", f"- Handoff: {ho}",
           f"- Commit reviewed: `{commit}`", ""]
    for h in cc.REVIEW_HEADINGS:
        if h in skip:
            continue
        out += [f"## {h}", ""]
        if h.startswith("4."):
            out += ["| ID | Severity | Status | Finding | Evidence | Resolution |",
                    "|---|---|---|---|---|---|"] + rows + [""]
    return "\n".join(out) + "\n"


def prow(wp="WP 1", title="Thing", deps="none", impl="DELIVERED", rev="APPROVED_FOR_OWNER_ACCEPTANCE",
         acc="ACCEPTED", open_="", latest="HO-0001"):
    return f"| {wp} | {title} | {deps} | {impl} | {rev} | {acc} | {open_} | {latest} |"


def programme(*rows):
    return ("# Programme\n\n" + "| " + " | ".join(cc.PROGRAMME_HEADER) + " |\n|" + "---|" * 8 + "\n"
            + "\n".join(rows) + "\n")


PROG = programme(prow(), prow("WP 2", "Next", "WP 1", "NOT_STARTED", "NONE", "NOT_ACCEPTED", "", "none"))


def git_repo(path):
    env = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t",
           "GIT_COMMITTER_EMAIL": "t@t", "PATH": os.environ["PATH"], "HOME": str(path)}

    def run(*args):
        return subprocess.run(["git", *args], cwd=path, env=env, check=True,
                              capture_output=True, text=True).stdout.strip()
    run("init", "-q")
    return run


def message(mid="MSG-IN-0001", status="CLOSED", refs="HO-0001", author="ChatGPT"):
    lines = [f"### {mid} — Subject"]
    if author:
        lines.append(f"- Author: {author}")
    lines += ["- Date: 2026-11-04", f"- Refs: {refs}", f"- Status: {status}", ""]
    return "\n".join(lines)


STATE = ("# State\n\n- Commit: `" + SHA + "`\n\n"
         + "\n\n".join(f"## {h}\n\n" + ("- Do WP 2.\n- Review it." if h.startswith("Next rec") else "")
                       for h in cc.STATE_HEADINGS) + "\nSee HO-0001.\n")
DLOG = ("| ID | Date | Decision | Decided by |\n|---|---|---|---|\n"
        "| DL-0001 | 2026-11-04 | Use X | Owner |\n")


class CoordinationTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        self.write("AI-COORDINATION-PROTOCOL.md", "# Protocol\n[state](CURRENT-STATE.md)\n")
        self.write("CURRENT-STATE.md", STATE)
        self.write("INBOX.md", "# Inbox\n\n" + message())
        self.write("OUTBOX.md", "# Outbox\n\n" + message("MSG-OUT-0001"))
        self.write("HANDOFF-TEMPLATE.md", "# Template\n")
        self.write("REVIEW-TEMPLATE.md", "# Template\n")
        self.write("DECISION-LOG.md", DLOG)
        self.write("handoffs/HO-0001.md", handoff())
        self.write("reviews/RV-0001.md", review())
        self.write("PROGRAMME.md", PROG)
        self.refresh()

    def write(self, rel, text, top=False):
        path = self.root / (rel if top else f"{COORD}/{rel}")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def refresh(self):
        report = cc.run_checks(self.root)
        self.write(cc.DASHBOARD, cc.render_dashboard(report.info))

    def run_check(self, refresh=True):
        if refresh:
            self.refresh()
        return cc.run_checks(self.root)

    def assertError(self, text, report=None):
        report = report or self.run_check()
        self.assertTrue(any(text in f"{f}: {m}" for f, m in report.errors),
                        f"no error containing {text!r}: {report.errors}")

    def assertWarn(self, text, report=None):
        report = report or self.run_check()
        self.assertTrue(any(text in f"{f}: {m}" for f, m in report.warnings),
                        f"no warning containing {text!r}: {report.warnings}")

    # --- success and warnings
    def test_valid_tree_passes(self):
        report = self.run_check()
        self.assertEqual(report.errors, [])
        self.assertEqual(report.warnings, [])
        self.assertEqual(cc.main(["--root", str(self.root)]), 0)

    def test_warnings_do_not_fail(self):
        self.write("handoffs/HO-0001.md", handoff(status="AWAITING_REVIEW", review="none"))
        (self.root / COORD / "reviews/RV-0001.md").unlink()
        self.write("PROGRAMME.md", programme(prow(rev="AWAITING_REVIEW", acc="NOT_ACCEPTED")))
        report = self.run_check()
        self.assertEqual(report.errors, [])
        self.assertWarn("AWAITING_REVIEW", report)
        self.assertEqual(cc.main(["--root", str(self.root)]), 0)

    def test_gap_warns(self):
        self.write("handoffs/HO-0003.md", handoff("HO-0003", status="AWAITING_REVIEW", review="none"))
        report = self.run_check()
        self.assertEqual(report.errors, [])
        self.assertEqual(report.warnings, report.warnings)
        self.assertFalse(any("HO-0002" in m for _, m in report.warnings))

    def test_out_of_order_headings_warn_only(self):
        self.write("handoffs/HO-0001.md", handoff(swap=True))
        report = self.run_check()
        self.assertEqual(report.errors, [])
        self.assertWarn("out of order", report)

    def test_open_finding_warns(self):
        self.write("reviews/RV-0001.md", review(rows=["| RV-0001-F1 | Low | OPEN | Nit | e | |"]))
        report = self.run_check()
        self.assertEqual(report.errors, [])
        self.assertWarn("open finding RV-0001-F1", report)
        self.assertEqual(len(report.info["findings"]), 1)

    def test_none_finding_row_allowed(self):
        self.write("reviews/RV-0001.md", review(rows=["| none | | | | | |"]))
        self.assertEqual(self.run_check().errors, [])

    def test_open_message_warns(self):
        self.write("INBOX.md", "# Inbox\n\n" + message(status="OPEN"))
        report = self.run_check()
        self.assertEqual(report.errors, [])
        self.assertWarn("open message MSG-IN-0001", report)

    def test_many_closed_messages_warn(self):
        body = "".join(message(f"MSG-IN-{n:04d}") for n in range(1, 13))
        self.write("INBOX.md", "# Inbox\n\n" + body)
        report = self.run_check()
        self.assertEqual(report.errors, [])
        self.assertWarn("consider archiving", report)

    # --- error classes
    def test_missing_required_file(self):
        (self.root / COORD / "OUTBOX.md").unlink()
        self.assertError("OUTBOX.md: required file is missing")

    def test_handoff_id_mismatch(self):
        self.write("handoffs/HO-0001.md", handoff("HO-0002"))
        self.assertError("does not match filename")

    def test_handoff_field_errors(self):
        self.write("handoffs/HO-0001.md", handoff(status="OPEN", commit="`abc`"))
        report = self.run_check()
        self.assertError("invalid status 'OPEN'", report)
        self.assertError("Commit must be exactly 40 hex", report)

    def test_handoff_dangling_review(self):
        self.write("handoffs/HO-0001.md", handoff(review="RV-0009"))
        self.assertError("review RV-0009 does not exist")

    def test_handoff_missing_heading(self):
        self.write("handoffs/HO-0001.md", handoff(skip=("5. Files changed",)))
        self.assertError("missing heading '## 5. Files changed'")

    def test_review_dangling_handoff(self):
        self.write("reviews/RV-0001.md", review(ho="HO-0042"))
        self.assertError("handoff 'HO-0042' does not exist")

    def test_review_bad_finding_rows(self):
        rows = ["| RV-0002-F1 | Huge | OPEN | x | | |", "| RV-0001-F2 | Low | WAT | y | | |"]
        self.write("reviews/RV-0001.md", review(rows=rows))
        report = self.run_check()
        self.assertError("must look like RV-0001-F", report)
        self.assertError("invalid severity 'Huge'", report)
        self.assertError("invalid status 'WAT'", report)

    def test_review_missing_heading(self):
        self.write("reviews/RV-0001.md", review(skip=("9. Re-review conditions",)))
        self.assertError("missing heading '## 9. Re-review conditions'")

    def test_message_missing_author_and_dangling_refs(self):
        self.write("INBOX.md", "# Inbox\n\n" + message(author="", refs="HO-0009, RV-0009, DL-0009"))
        report = self.run_check()
        self.assertError("missing metadata 'Author'", report)
        for ref in ("HO-0009", "RV-0009", "DL-0009"):
            self.assertError(f"reference {ref} does not exist", report)

    def test_duplicate_message_across_archive(self):
        self.write("archive/INBOX-2026.md", "# Archive\n\n" + message())
        self.assertError("message id MSG-IN-0001 appears more than once")

    def test_archive_must_be_closed(self):
        self.write("archive/INBOX-2026.md", "# Archive\n\n" + message("MSG-IN-0002", "OPEN"))
        self.assertError("archived messages must be CLOSED")

    def test_decision_log_errors(self):
        self.write("DECISION-LOG.md", DLOG + "| DL-0001 | 2026-13-45 | Dup | |\n")
        report = self.run_check()
        self.assertError("duplicate decision id DL-0001", report)
        self.assertError("invalid date", report)
        self.assertError("'Decided by' is empty", report)

    def test_current_state_errors(self):
        self.write("CURRENT-STATE.md", "# State\n\n- Commit: `xyz`\n\n## Blockers\n\nHO-0077\n")
        report = self.run_check()
        self.assertError("missing line '- Commit", report)
        self.assertError("missing heading '## Branch and commit'", report)
        self.assertError("HO-0077, which does not exist", report)

    # --- links
    def test_broken_link_errors_and_exemptions(self):
        self.write("AI-COORDINATION-PROTOCOL.md",
                   "[ok](CURRENT-STATE.md#x) [web](https://x.io/a) [m](mailto:a@b.c)\n"
                   "```\n[fenced](nope.md)\n```\n`[code](nope2.md)`\n[bad](missing.md)\n")
        report = self.run_check()
        self.assertEqual([m for _, m in report.errors], ["broken link 'missing.md'"])

    def test_claude_md_imports(self):
        self.write("CLAUDE.md", "@docs/ai-coordination/CURRENT-STATE.md\nmail a@b.com\n"
                   "`@ignored/path.md`\n```\n@fenced/path.md\n```\n@missing/file.md\n",
                   top=True)
        report = self.run_check()
        self.assertEqual([m for _, m in report.errors],
                         ["@import 'missing/file.md' does not exist"])

    # --- CLI / summary
    def test_summary_written_on_success_and_failure(self):
        out = self.root / "summary.md"
        self.assertEqual(cc.main(["--root", str(self.root), "--summary", str(out)]), 0)
        text = out.read_text()
        for section in ("Errors", "Warnings", "Open handoffs", "Open findings", "Open messages",
                        "Review queue", "Owner decision queue", "Next eligible packages"):
            self.assertIn(f"### {section}", text)
        (self.root / COORD / "INBOX.md").unlink()
        self.assertEqual(cc.main(["--root", str(self.root), "--summary", str(out)]), 1)
        self.assertIn("INBOX.md", out.read_text().split("## AI coordination check")[-1].split("### Warnings")[0])

    # --- v2 handoff rules
    def put_review_state(self, status, outcome, rows=None, commit=SHA, hcommit=SHA):
        self.write("handoffs/HO-0001.md", handoff(status=status, commit=f"`{hcommit}`"))
        self.write("reviews/RV-0001.md", review(outcome=outcome, rows=rows, commit=commit))
        self.write("PROGRAMME.md", programme(prow(rev="NONE", acc="NOT_ACCEPTED")))

    def test_review_none_with_decided_status(self):
        self.write("handoffs/HO-0001.md", handoff(status="CHANGES_REQUIRED", review="none"))
        self.assertError("Review: none but Status is CHANGES_REQUIRED")

    def test_listed_review_names_other_handoff(self):
        self.write("handoffs/HO-0002.md", handoff("HO-0002", review="RV-0001"))
        self.assertError("RV-0001 says Handoff: HO-0001")

    def test_review_commit_does_not_carry_across(self):
        self.write("handoffs/HO-0001.md", handoff(commit=f"`{NEWSHA}`"))
        self.assertError("review RV-0001 reviewed aaaaaaa but handoff commit is ccccccc")

    def test_status_must_match_outcome(self):
        self.write("handoffs/HO-0001.md", handoff(status="CHANGES_REQUIRED"))
        self.assertError("does not match RV-0001 Outcome APPROVED_FOR_OWNER_ACCEPTANCE")
        self.write("handoffs/HO-0001.md", handoff(status="APPROVED_FOR_OWNER_ACCEPTANCE"))
        self.write("PROGRAMME.md", programme(prow(acc="NOT_ACCEPTED")))
        self.assertEqual(self.run_check().errors, [])

    def test_accepted_requires_decision_reference(self):
        self.write("handoffs/HO-0001.md", handoff(body="nothing"))
        self.assertError("ACCEPTED_BY_OWNER without a DL- decision reference")

    def test_correction_must_be_new_commit(self):
        self.write("reviews/RV-0002.md", review("RV-0002", "HO-0002", outcome="CHANGES_REQUIRED",
                   rows=["| RV-0002-F1 | High | OPEN | Bug | e | |"]))
        self.write("handoffs/HO-0002.md", handoff("HO-0002", "CHANGES_REQUIRED", "RV-0002"))
        self.write("handoffs/HO-0003.md", handoff("HO-0003", "AWAITING_REVIEW", "none", responds="RV-0002"))
        self.assertError("a correction must be a new commit")
        self.write("handoffs/HO-0003.md", handoff("HO-0003", "AWAITING_REVIEW", "none",
                   responds="RV-0002", commit=f"`{NEWSHA}`"))
        self.assertNotIn("new commit", str(self.run_check().errors))
        self.write("handoffs/HO-0003.md", handoff("HO-0003", responds="RV-0009", supersedes="HO-0009"))
        report = self.run_check()
        self.assertError("Responds to RV-0009 does not exist", report)
        self.assertError("Supersedes HO-0009 does not exist", report)

    def test_supersedes_requires_superseded_status(self):
        self.write("handoffs/HO-0002.md", handoff("HO-0002", "AWAITING_REVIEW", "none",
                   supersedes="HO-0001", commit=f"`{NEWSHA}`"))
        self.assertError("HO-0001 is superseded by HO-0002 but its Status is ACCEPTED_BY_OWNER")

    def test_wp_and_parent_fields(self):
        self.write("handoffs/HO-0001.md", handoff(wp="WP", parent="`xyz`"))
        report = self.run_check()
        self.assertError("Work package must start with", report)
        self.assertError("Parent must be exactly 40 hex", report)
        self.write("handoffs/HO-0001.md", handoff(parent=f"`{SHA}`"))
        self.assertWarn("Parent equals Commit")

    def test_review_not_listed_by_handoff(self):
        self.write("handoffs/HO-0001.md", handoff(status="AWAITING_REVIEW", review="none"))
        self.assertError("RV-0001 is not listed in HO-0001's Review field")

    # --- v2 review rules
    def test_review_outcome_required(self):
        self.write("reviews/RV-0001.md", review(outcome="MAYBE"))
        self.assertError("missing or invalid Outcome 'MAYBE'")

    def test_changes_required_needs_blocking_finding(self):
        self.put_review_state("CHANGES_REQUIRED", "CHANGES_REQUIRED", ["| RV-0001-F1 | Low | OPEN | x | | |"])
        self.assertError("CHANGES_REQUIRED with no Critical/High/Medium finding")
        self.put_review_state("CHANGES_REQUIRED", "CHANGES_REQUIRED", ["| none | | | | | |"])
        self.assertError("CHANGES_REQUIRED with no Critical/High/Medium finding")

    def test_approved_with_open_high_finding(self):
        self.write("reviews/RV-0001.md", review(rows=["| RV-0001-F1 | High | OPEN | x | | |"]))
        self.assertError("APPROVED_FOR_OWNER_ACCEPTANCE but RV-0001-F1 (High) is OPEN")

    # --- programme
    def test_programme_errors(self):
        self.write("PROGRAMME.md", programme(
            prow(), prow(), prow("WP 3", deps="WP 9, WP 1 (soft)", impl="DONE"),
            prow("WP 4", impl="NOT_STARTED"), prow("WP 5", impl="IN_PROGRESS", acc="ACCEPTED"),
            prow("WP 6", rev="CHANGES_REQUIRED", latest="HO-0001"), prow("WP 7", latest="HO-0099")))
        report = self.run_check()
        for text in ("duplicate WP WP 1", "depends on WP 9, which is not a row", "invalid Implementation 'DONE'",
                     "WP 4: NOT_STARTED requires", "WP 5: Acceptance ACCEPTED requires",
                     "WP 6: Review CHANGES_REQUIRED disagrees", "WP 7: latest handoff HO-0099 does not exist",
                     "WP 3: HO-0001 belongs to 'WP 1"):
            self.assertError(text, report)

    def test_programme_review_none_needs_no_handoff(self):
        self.write("PROGRAMME.md", programme(prow(rev="NONE")))
        self.assertError("WP 1: Review NONE disagrees")
        self.write("PROGRAMME.md", programme(prow(rev="LEGACY", latest="none")))
        self.assertEqual(self.run_check().errors, [])

    def test_eligibility(self):
        rows = [dict(zip(("wp", "title", "depends", "implementation", "review", "acceptance"), r))
                for r in [("WP 1", "A", "none", "DELIVERED", "NONE", "CONDITIONALLY_ACCEPTED"),
                          ("WP 2", "B", "none", "DELIVERED", "APPROVED_FOR_OWNER_ACCEPTANCE", "NOT_ACCEPTED"),
                          ("WP 3", "C", "none", "DELIVERED", "AWAITING_REVIEW", "NOT_ACCEPTED"),
                          ("WP 12", "D", "WP 1, WP 2", "NOT_STARTED", "NONE", "NOT_ACCEPTED"),
                          ("WP 11", "E", "WP 3", "NOT_STARTED", "NONE", "NOT_ACCEPTED"),
                          ("WP 10", "F", "WP 3 (soft), WP 1", "NOT_STARTED", "NONE", "NOT_ACCEPTED"),
                          ("GOV 4", "G", "none", "IN_PROGRESS", "NONE", "NOT_ACCEPTED")]]
        self.assertEqual([e[0] for e in cc.compute_eligible(rows)], ["WP 10", "WP 12"])
        self.assertEqual([e[0] for e in self.run_check().info["eligible"]], ["WP 2"])

    # --- decision queue and dashboard
    def test_pending_decisions_collected(self):
        self.write("DECISION-LOG.md", DLOG + "| DL-0002 | 2026-11-04 | Pick Y | pending OWNER decision |\n")
        report = self.run_check()
        self.assertEqual(report.info["pending"], [("DL-0002", "Pick Y", "")])
        self.assertIn("DL-0002", (self.root / COORD / cc.DASHBOARD).read_text())

    def test_dashboard_content_and_determinism(self):
        self.write("PROGRAMME.md", programme(prow(), prow("WP 2", "Next", "WP 1", "NOT_STARTED", "NONE",
                                                         "NOT_ACCEPTED", "", "none")))
        first = cc.render_dashboard(self.run_check().info)
        self.assertEqual(first, cc.render_dashboard(self.run_check().info))
        for text in ("# Owner dashboard", "## Work in progress", "## Next actions", "- Do WP 2.",
                     "- WP 2 \u2014 Next (depends on: WP 1)", "| WP 1 | Thing | ACCEPTED |"):
            self.assertIn(text, first)
        self.assertEqual(first.count("_None._"), 8)
        self.assertIn("a\\|b", "".join(cc.table(["H"], [("a|b",)])))

    def test_dashboard_sections_for_review_states(self):
        self.write("reviews/RV-0002.md", review("RV-0002", "HO-0002", outcome="CHANGES_REQUIRED",
                   rows=["| RV-0002-F1 | High | OPEN | Bad | e | |", "| RV-0002-F2 | Low | OPEN | Meh | e | |"]))
        self.write("handoffs/HO-0002.md", handoff("HO-0002", "CHANGES_REQUIRED", "RV-0002", wp="WP 2 \u2014 N"))
        self.write("PROGRAMME.md", programme(prow(), prow("WP 2", "Next", "WP 1", "DELIVERED",
                                             "CHANGES_REQUIRED", "NOT_ACCEPTED", "", "HO-0002")))
        report = self.run_check()
        self.assertEqual(report.errors, [])
        text = (self.root / COORD / cc.DASHBOARD).read_text()
        self.assertIn("| HO-0002 | RV-0002 | High 1, Low 1 | CHANGES_REQUIRED |", text)
        self.assertIn("| RV-0002-F1 | High | OPEN | Bad |", text)

    def test_stale_dashboard_and_write_flag(self):
        self.assertEqual(self.run_check(refresh=False).errors, [])
        self.write("DECISION-LOG.md", DLOG + "| DL-0002 | 2026-11-04 | Pick Y | Pending owner decision |\n")
        self.assertError(cc.STALE_MSG, self.run_check(refresh=False))
        self.assertEqual(cc.main(["--root", str(self.root)]), 1)
        self.assertEqual(cc.main(["--root", str(self.root), "--write-dashboard"]), 0)
        self.assertEqual(cc.main(["--root", str(self.root)]), 0)
        (self.root / COORD / cc.DASHBOARD).unlink()
        self.assertError(cc.STALE_MSG, self.run_check(refresh=False))

    # --- evidence
    def test_evidence_pack(self):
        text = cc.render_evidence(self.root, "HO-0001", "acme/repo")
        base = "https://github.com/acme/repo"
        for expected in ("# Evidence pack for HO-0001", "# HO-0001 \u2014 Title",
                         f"{base}/commit/{SHA}", f"{base}/compare/{PARENT}...{SHA}", f"{base}/commit/{SHA}.diff",
                         f"{base}/commit/{SHA}/checks", f"{base}/blob/b/{COORD}/handoffs/HO-0001.md",
                         f"{base}/blob/b/{COORD}/REVIEW-TEMPLATE.md", f"{base}/blob/b/{COORD}/AI-COORDINATION-PROTOCOL.md",
                         "diff stat unavailable"):
            self.assertIn(expected, text)

    def test_evidence_lists_findings_of_responded_review(self):
        self.write("reviews/RV-0002.md", review("RV-0002", "HO-0002", outcome="CHANGES_REQUIRED",
                   rows=["| RV-0002-F1 | High | OPEN | Bad | e | |"]))
        self.write("handoffs/HO-0002.md", handoff("HO-0002", "CHANGES_REQUIRED", "RV-0002"))
        self.write("handoffs/HO-0003.md", handoff("HO-0003", "AWAITING_REVIEW", "none",
                   responds="RV-0002", commit=f"`{NEWSHA}`"))
        self.assertIn("| RV-0002-F1 | High | OPEN | Bad |", cc.render_evidence(self.root, "HO-0003", "a/b"))
        self.assertIsNone(cc.render_evidence(self.root, "HO-0042", "a/b"))
        self.assertEqual(cc.main(["--root", str(self.root), "--evidence", "HO-0042"]), 2)
        self.assertEqual(cc.main(["--root", str(self.root), "--evidence", "HO-0003", "--repo", "a/b"]), 0)


    # --- review-driven rules
    def test_resolved_is_not_final(self):
        self.write("reviews/RV-0001.md", review(rows=["| RV-0001-F1 | High | RESOLVED | Bug | e | fixed |"]))
        self.write("INBOX.md", "# Inbox\n\n" + message(status="RESOLVED"))
        report = self.run_check()
        self.assertEqual(report.errors, [])
        self.assertEqual(report.info["findings"], [])
        self.assertEqual([f[0] for f in report.info["resolved"]], ["RV-0001-F1"])
        self.assertEqual(report.info["messages"][0][1], "RESOLVED")
        dash = (self.root / COORD / cc.DASHBOARD).read_text()
        self.assertIn("## Awaiting re-review\n\n| Handoff | Review | ID | Severity | Finding |", dash)
        self.assertIn("| HO-0001 | RV-0001 | RV-0001-F1 | High | Bug |", dash)
        out = self.root / "s.md"
        cc.main(["--root", str(self.root), "--summary", str(out)])
        text = out.read_text()
        self.assertIn("### Awaiting re-review\n\n| ID", text)
        self.assertIn("### Messages awaiting confirmation\n\n| ID", text)

    def test_resolution_required(self):
        rows = ["| RV-0001-F1 | Low | RESOLVED | a | e | |", "| RV-0001-F2 | Low | CLOSED | b | e | \u2014 |",
                "| RV-0001-F3 | Low | ACCEPTED_BY_OWNER | c | e | fine |",
                "| RV-0001-F4 | Low | ACCEPTED_BY_OWNER | d | e | per DL-0001 |", "| RV-0001-F5 | Low | OPEN | e | | |"]
        self.write("reviews/RV-0001.md", review(rows=rows))
        report = self.run_check()
        self.assertError("RV-0001-F1: RESOLVED finding needs a Resolution", report)
        self.assertError("RV-0001-F2: CLOSED finding needs a Resolution", report)
        self.assertError("RV-0001-F3: ACCEPTED_BY_OWNER finding needs a DL- reference", report)
        self.assertEqual(len(report.errors), 3)

    def test_author_validation(self):
        self.write("handoffs/HO-0001.md", handoff().replace("Author: Claude Code", "Author: ChatGPT"))
        self.write("reviews/RV-0001.md", review().replace("Author: ChatGPT", "Author: Claude Code"))
        self.write("INBOX.md", "# Inbox\n\n" + message(author="Bob"))
        report = self.run_check()
        for kind in ("handoff", "review", "message"):
            self.assertError(f"for a {kind}", report)
        self.write("handoffs/HO-0001.md", handoff())
        self.write("reviews/RV-0001.md", review().replace("Author: ChatGPT", "Author: ChatGPT (relayed by the owner)"))
        self.write("INBOX.md", "# Inbox\n\n" + message(author="ChatGPT (relayed by the owner; indexed by Claude Code)")
                   + message("MSG-IN-0002", author="Owner"))
        self.assertEqual(self.run_check().errors, [])

    def test_exact_headings_and_branch(self):
        self.write("handoffs/HO-0001.md", handoff().replace("## 5. Files changed", "## 5. Files changed (draft)")
                   .replace("Branch: `b`", "Branch: ``"))
        report = self.run_check()
        self.assertError("missing heading '## 5. Files changed'", report)
        self.assertError("missing metadata 'Branch'", report)

    def test_unrecognised_record_names(self):
        self.write("reviews/rv-0002.md", review("RV-0002"))
        self.write("handoffs/HO-01.md", handoff("HO-0001"))
        self.write("handoffs/README.md", "# readme\n")
        report = self.run_check()
        self.assertError("reviews/rv-0002.md: unrecognised record file name", report)
        self.assertError("handoffs/HO-01.md: unrecognised record file name", report)
        self.assertEqual(len([e for e in report.errors if "unrecognised" in e[1]]), 2)

    def test_decision_log_decided_by_and_refs(self):
        self.write("DECISION-LOG.md", "| ID | Date | Decision | Decided by | Refs |\n|---|---|---|---|---|\n"
                   "| DL-0001 | 2026-11-04 | A | Owner | HO-0001, WP 3, TD-0001, notes.md |\n"
                   "| DL-0002 | 2026-11-04 | B | Claude Code | |\n"
                   "| DL-0003 | 2026-11-04 | C | pending owner decision | HO-0009, DL-0001, DL-0077 |\n")
        report = self.run_check()
        self.assertError("DL-0002: 'Decided by' must start with 'Owner'", report)
        self.assertError("DL-0003: Refs HO-0009 does not exist", report)
        self.assertError("DL-0003: Refs DL-0077 does not exist", report)
        self.assertEqual(len(report.errors), 3)

    def test_verify_commits(self):
        self.assertEqual(cc.run_checks(self.root).errors, [])  # off by default
        run = git_repo(self.root)
        (self.root / "f").write_text("x")
        run("add", "f")
        run("commit", "-q", "-m", "c")
        real = run("rev-parse", "HEAD")
        report = cc.run_checks(self.root, verify_commits=True)
        self.assertError("Commit aaaaaaa does not exist in git", report)
        self.assertError("Parent bbbbbbb does not exist in git", report)
        self.write("handoffs/HO-0001.md", handoff(commit=f"`{real}`", parent=f"`{real}`"))
        self.write("reviews/RV-0001.md", review(commit=real))
        self.assertEqual(cc.run_checks(self.root, verify_commits=True).errors, [])

    def test_verify_commits_without_git_repo_warns_once(self):
        with tempfile.TemporaryDirectory() as empty:
            self.root_backup, self.root = self.root, Path(empty)
            try:
                self.write("handoffs/HO-0001.md", handoff())
                self.write("reviews/RV-0001.md", review())
                self.write("PROGRAMME.md", PROG)
                report = cc.run_checks(self.root, verify_commits=True)
            finally:
                self.root = self.root_backup
        self.assertEqual(len([w for w in report.warnings if "--verify-commits skipped" in w[1]]), 1)
        self.assertFalse(any("does not exist in git" in m for _, m in report.errors))

    def test_append_only_since(self):
        run = git_repo(self.root)
        run("add", "-A")
        run("commit", "-q", "-m", "base")
        base = run("rev-parse", "HEAD")
        self.write("reviews/RV-0001.md", review().replace("| fixed |", "| changed |"))
        self.write("INBOX.md", "# Inbox\n")
        (self.root / COORD / "handoffs/HO-0001.md").rename(self.root / COORD / "handoffs/HO-0009.md")
        run("add", "-A")
        run("commit", "-q", "-m", "edit")
        report = cc.run_checks(self.root, since=base)
        self.assertError("handoffs/HO-0001.md: record was renamed", report)
        self.assertWarn("1 line(s) removed from docs/ai-coordination/reviews/RV-0001.md since", report)
        self.assertWarn("line(s) removed from docs/ai-coordination/INBOX.md", report)
        removed = [ln for _, ln in report.info["removed"]]
        self.assertTrue(any("fixed" in ln for ln in removed))
        self.assertIn("### Removed lines (append-only check)", cc.render_summary(report))
        missing = cc.run_checks(self.root, since="nope")
        self.assertWarn("ref 'nope' not found", missing)
        self.assertEqual(cc.run_checks(self.root, since="HEAD").warnings, cc.run_checks(self.root).warnings)


if __name__ == "__main__":
    unittest.main()
