#!/usr/bin/env python3
"""Demonstrate the review cycle rules on a throwaway fixture (no network, no git).

Stages: handoff awaiting review -> review on file (CHANGES_REQUIRED) -> corrected
commit as a new handoff -> attempt to carry the old approval (refused) -> re-review
approves. Prints the checker's verdict at each stage. Exit 0 when every stage
behaves as the protocol says, 1 otherwise.
Usage: python3 tools/coordination/demo_cycle.py
"""
import subprocess
import sys
import tempfile
from pathlib import Path

CHECKER = Path(__file__).resolve().parent / "check_coordination.py"
SHA_A = "a" * 40
SHA_B = "b" * 40
SHA_P = "0" * 40

STATE_HEADINGS = [
    "Branch and commit", "Current implementation package", "Latest handoff",
    "Latest review status", "Outstanding corrections", "Outstanding owner decisions",
    "Outstanding verification requirements", "Next eligible package",
    "Programme progress", "Next recommended actions",
]
HANDOFF_SECTIONS = [
    "1. Handoff ID", "2. Work package and scope", "3. Branch and commit",
    "4. Summary of changes", "5. Files changed", "6. Tests executed and actual results",
    "7. CI workflow run IDs and results", "8. Independent review status",
    "9. Outstanding findings", "10. Technical debt updates", "11. Documentation updates",
    "12. Decisions required from ChatGPT", "13. Decisions required from the project owner",
    "14. Recommended next action",
]
REVIEW_SECTIONS = [
    "1. Review ID and handoff reference", "2. Exact commit reviewed", "3. Scope reviewed",
    "4. Findings classified by severity", "5. Evidence and file references",
    "6. Required corrections", "7. Non-blocking recommendations",
    "8. Regression tests required", "9. Re-review conditions", "10. Overall recommendation",
]


def handoff(hid, status, commit, parent, review="none", responds="none", supersedes="none"):
    body = [f"# {hid} — demo handoff", "", "- Author: Claude Code", "- Date: 2026-11-04",
            f"- Status: {status}", "- Work package: WP 99 — Demo package", "- Branch: `demo`",
            f"- Commit: `{commit}`", f"- Parent: `{parent}`", f"- Review: {review}",
            f"- Responds to: {responds}", f"- Supersedes: {supersedes}", ""]
    for s in HANDOFF_SECTIONS:
        body += [f"## {s}", "none", ""]
    return "\n".join(body)


def review(rid, hid, outcome, commit, finding_row):
    body = [f"# {rid} — review of {hid}: demo", "", "- Author: ChatGPT (relayed by the owner)",
            "- Date: 2026-11-04", "- Status: OPEN", f"- Outcome: {outcome}", f"- Handoff: {hid}",
            f"- Commit reviewed: `{commit}`", ""]
    for s in REVIEW_SECTIONS:
        body += [f"## {s}"]
        if s.startswith("4."):
            body += ["| ID | Severity | Status | Finding | Evidence | Resolution |",
                     "|---|---|---|---|---|---|", finding_row]
        else:
            body += ["none"]
        body += [""]
    return "\n".join(body)


def programme(review_state, latest, implementation="DELIVERED"):
    return ("# Programme\n\n| WP | Title | Depends on | Implementation | Review | Acceptance | Open items | Latest handoff |\n"
            "|---|---|---|---|---|---|---|---|\n"
            f"| WP 99 | Demo package | none | {implementation} | {review_state} | NOT_ACCEPTED | | {latest} |\n")


def write_base(coord):
    coord.mkdir(parents=True)
    (coord / "handoffs").mkdir()
    (coord / "reviews").mkdir()
    for name in ["AI-COORDINATION-PROTOCOL.md", "HANDOFF-TEMPLATE.md", "REVIEW-TEMPLATE.md"]:
        (coord / name).write_text(f"# {name}\n")
    (coord / "INBOX.md").write_text("# INBOX\n\n## Messages\n")
    (coord / "OUTBOX.md").write_text("# OUTBOX\n\n## Messages\n")
    (coord / "DECISION-LOG.md").write_text(
        "# Decisions\n\n| ID | Date | Decision | Decided by | Refs | Recorded by |\n|---|---|---|---|---|---|\n"
        "| none | — | — | — | — | — |\n")
    state = ["# Current state", "", f"- Commit: `{SHA_A}`", ""]
    for h in STATE_HEADINGS:
        state += [f"## {h}", "demo", ""]
    (coord / "CURRENT-STATE.md").write_text("\n".join(state))


def run(root, write_dashboard=False):
    args = [sys.executable, str(CHECKER), "--root", str(root)]
    if write_dashboard:
        args.append("--write-dashboard")
    return subprocess.run(args, capture_output=True, text=True)


def stage(title, root, expect_ok, must_contain=()):
    run(root, write_dashboard=True)
    result = run(root)
    out = result.stdout + result.stderr
    ok = (result.returncode == 0) == expect_ok and all(m in out for m in must_contain)
    verdict = "as expected" if ok else "UNEXPECTED"
    print(f"\n=== {title}\n--- checker exit {result.returncode} ({verdict})")
    print(out.strip())
    return ok


def main():
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        coord = root / "docs" / "ai-coordination"
        write_base(coord)
        ho, rv, pr = coord / "handoffs", coord / "reviews", coord / "PROGRAMME.md"
        results = []

        (ho / "HO-0101.md").write_text(handoff("HO-0101", "AWAITING_REVIEW", SHA_A, SHA_P))
        pr.write_text(programme("AWAITING_REVIEW", "HO-0101"))
        results.append(stage("1. Handoff submitted: awaiting review", root, True, ["HO-0101"]))

        f1 = "| RV-0101-F1 | High | OPEN | demo defect | path:1 | — |"
        (rv / "RV-0101.md").write_text(review("RV-0101", "HO-0101", "CHANGES_REQUIRED", SHA_A, f1))
        results.append(stage("2a. Review on file but handoff not updated: checker refuses the stale status",
                             root, False, ["RV-0101"]))

        (ho / "HO-0101.md").write_text(handoff("HO-0101", "CHANGES_REQUIRED", SHA_A, SHA_P, review="RV-0101"))
        pr.write_text(programme("CHANGES_REQUIRED", "HO-0101"))
        results.append(stage("2b. Handoff reflects CHANGES_REQUIRED; open finding is listed", root, True, ["RV-0101-F1"]))

        f1 = "| RV-0101-F1 | High | RESOLVED | demo defect | path:1 | fixed in bbbbbbb; demo_test |"
        (rv / "RV-0101.md").write_text(review("RV-0101", "HO-0101", "CHANGES_REQUIRED", SHA_A, f1))
        (ho / "HO-0101.md").write_text(handoff("HO-0101", "SUPERSEDED", SHA_A, SHA_P, review="RV-0101"))
        (ho / "HO-0102.md").write_text(handoff("HO-0102", "AWAITING_REVIEW", SHA_B, SHA_A,
                                               responds="RV-0101", supersedes="HO-0101"))
        pr.write_text(programme("AWAITING_REVIEW", "HO-0102"))
        results.append(stage("3. Corrected commit submitted as HO-0102 (supersedes HO-0101, responds to RV-0101)",
                             root, True, ["HO-0102"]))

        (ho / "HO-0102.md").write_text(handoff("HO-0102", "APPROVED_FOR_OWNER_ACCEPTANCE", SHA_B, SHA_A,
                                               review="RV-0101", responds="RV-0101", supersedes="HO-0101"))
        pr.write_text(programme("APPROVED_FOR_OWNER_ACCEPTANCE", "HO-0102"))
        results.append(stage("4. Attempt to carry RV-0101 over to the new commit: refused", root, False,
                             ["do not carry across commits"]))

        (ho / "HO-0102.md").write_text(handoff("HO-0102", "AWAITING_REVIEW", SHA_B, SHA_A,
                                               responds="RV-0101", supersedes="HO-0101"))
        pr.write_text(programme("AWAITING_REVIEW", "HO-0102"))
        none_row = "| none | — | — | no findings | — | — |"
        (rv / "RV-0102.md").write_text(review("RV-0102", "HO-0102", "APPROVED_FOR_OWNER_ACCEPTANCE", SHA_B, none_row))
        (ho / "HO-0102.md").write_text(handoff("HO-0102", "APPROVED_FOR_OWNER_ACCEPTANCE", SHA_B, SHA_A,
                                               review="RV-0102", responds="RV-0101", supersedes="HO-0101"))
        pr.write_text(programme("APPROVED_FOR_OWNER_ACCEPTANCE", "HO-0102"))
        results.append(stage("5. Re-review RV-0102 of the corrected commit approves; owner decision now owed",
                             root, True))
        dashboard = (coord / "DASHBOARD.md").read_text()
        print("\n--- dashboard excerpt:",
              "HO-0102 listed under 'Approved, awaiting owner acceptance'" if "HO-0102" in dashboard.split("### Approved, awaiting owner acceptance")[1].split("##")[0] else "HO-0102 NOT listed (UNEXPECTED)")
        results.append("HO-0102" in dashboard)

    print("\nDEMO RESULT:", "all stages behaved as the protocol specifies" if all(results) else "FAILED")
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
