import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_coordination as cc  # noqa: E402

SHA = "a" * 40
COORD = "docs/ai-coordination"


def handoff(hid="HO-0001", status="CLOSED", review="RV-0001", commit=f"`{SHA}`",
            skip=(), swap=False):
    heads = [f"## {h}" for h in cc.HANDOFF_HEADINGS if h not in skip]
    if swap:
        heads[0], heads[1] = heads[1], heads[0]
    meta = (f"- Author: Claude Code\n- Date: 2026-11-04\n- Status: {status}\n"
            f"- Work package: WP\n- Branch: `b`\n- Commit: {commit}\n- Review: {review}\n")
    return f"# {hid} — Title\n\n{meta}\n" + "\n\nx\n".join(heads) + "\n\nx\n"


def review(rid="RV-0001", ho="HO-0001", rows=None, skip=()):
    rows = rows if rows is not None else [f"| {rid}-F1 | High | RESOLVED | Bug | e | fixed |"]
    out = [f"# {rid} — Title\n", "- Author: ChatGPT", "- Date: 2026-11-04",
           "- Status: CLOSED", f"- Handoff: {ho}", f"- Commit reviewed: `{SHA}`", ""]
    for h in cc.REVIEW_HEADINGS:
        if h in skip:
            continue
        out += [f"## {h}", ""]
        if h.startswith("4."):
            out += ["| ID | Severity | Status | Finding | Evidence | Resolution |",
                    "|---|---|---|---|---|---|"] + rows + [""]
    return "\n".join(out) + "\n"


def message(mid="MSG-IN-0001", status="CLOSED", refs="HO-0001", author="ChatGPT"):
    lines = [f"### {mid} — Subject"]
    if author:
        lines.append(f"- Author: {author}")
    lines += ["- Date: 2026-11-04", f"- Refs: {refs}", f"- Status: {status}", ""]
    return "\n".join(lines)


STATE = ("# State\n\n- Commit: `" + SHA + "`\n\n"
         + "\n\n".join(f"## {h}" for h in cc.STATE_HEADINGS) + "\n\nSee HO-0001.\n")
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

    def write(self, rel, text, top=False):
        path = self.root / (rel if top else f"{COORD}/{rel}")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def run_check(self):
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
        self.write("handoffs/HO-0001.md", handoff(status="OPEN", review="none"))
        report = self.run_check()
        self.assertEqual(report.errors, [])
        self.assertWarn("no independent review", report)
        self.assertEqual(cc.main(["--root", str(self.root)]), 0)

    def test_gap_warns(self):
        self.write("handoffs/HO-0003.md", handoff("HO-0003", review="none"))
        report = self.run_check()
        self.assertEqual(report.errors, [])
        self.assertWarn("HO-0002", report)

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
        self.write("handoffs/HO-0001.md", handoff(status="DONE", commit="`abc`"))
        report = self.run_check()
        self.assertError("invalid status 'DONE'", report)
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
        self.assertError("missing heading '## Work package'", report)
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
        for section in ("Errors", "Warnings", "Open handoffs", "Open findings", "Open messages"):
            self.assertIn(f"### {section}", text)
        (self.root / COORD / "INBOX.md").unlink()
        self.assertEqual(cc.main(["--root", str(self.root), "--summary", str(out)]), 1)
        self.assertIn("INBOX.md", out.read_text().split("## AI coordination check")[-1].split("### Warnings")[0])


if __name__ == "__main__":
    unittest.main()
