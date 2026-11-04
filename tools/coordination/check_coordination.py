#!/usr/bin/env python3
"""Validate the AI coordination documents under docs/ai-coordination/.

Usage: python3 tools/coordination/check_coordination.py [--root PATH] [--summary FILE]
Exit code 0 when there are no errors, 1 otherwise. Stdlib only.
"""
import argparse
import re
import sys
from datetime import date
from pathlib import Path

COORD = "docs/ai-coordination"
REQUIRED_FILES = [
    "AI-COORDINATION-PROTOCOL.md", "CURRENT-STATE.md", "INBOX.md", "OUTBOX.md",
    "HANDOFF-TEMPLATE.md", "REVIEW-TEMPLATE.md", "DECISION-LOG.md",
]
STATUSES = {"OPEN", "IN_PROGRESS", "BLOCKED", "RESOLVED", "ACCEPTED_BY_OWNER", "CLOSED"}
FINAL_STATUSES = {"RESOLVED", "ACCEPTED_BY_OWNER", "CLOSED"}
SEVERITIES = {"Critical", "High", "Medium", "Low", "Info"}
MAX_CLOSED_LIVE = 10

HANDOFF_HEADINGS = [
    "1. Handoff ID", "2. Work package and scope", "3. Branch and commit",
    "4. Summary of changes", "5. Files changed", "6. Tests executed and actual results",
    "7. CI workflow run IDs and results", "8. Independent review status",
    "9. Outstanding findings", "10. Technical debt updates", "11. Documentation updates",
    "12. Decisions required from ChatGPT", "13. Decisions required from the project owner",
    "14. Recommended next action",
]
REVIEW_HEADINGS = [
    "1. Review ID and handoff reference", "2. Exact commit reviewed", "3. Scope reviewed",
    "4. Findings classified by severity", "5. Evidence and file references",
    "6. Required corrections", "7. Non-blocking recommendations",
    "8. Regression tests required", "9. Re-review conditions", "10. Overall recommendation",
]
STATE_HEADINGS = [
    "Work package", "Implementation status", "Acceptance status",
    "Outstanding owner decisions", "Outstanding review findings",
    "Outstanding verification requirements", "Blockers", "Next recommended actions",
]

HO_FILE_RE = re.compile(r"^HO-(\d{4})\.md$")
RV_FILE_RE = re.compile(r"^RV-(\d{4})\.md$")
TITLE_RE = re.compile(r"^#\s+((?:HO|RV)-\d{4})\s+[\u2014\u2013-]\s+\S")
META_RE = re.compile(r"^\s*[-*]\s+([A-Za-z][A-Za-z ]*?):\s*(.*?)\s*$")
MSG_HEAD_RE = re.compile(r"^###\s+(MSG-(?:IN|OUT)-(\d{4}))\b\s*[\u2014\u2013-]?\s*(.*)$")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*$")
COMMIT_RE = re.compile(r"[0-9a-fA-F]{40}")
STATE_COMMIT_RE = re.compile(r"^-\s+Commit:\s*`?([0-9a-fA-F]{40})`?\s*$", re.M)
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")
RV_ID_RE = re.compile(r"RV-\d{4}")
FINDING_ID_RE = re.compile(r"(RV-\d{4})-F\d+")
DL_ID_RE = re.compile(r"DL-\d{4}")
REF_RE = re.compile(r"\b(HO|RV|DL)-\d{4}\b")
SEPARATOR_CELL_RE = re.compile(r":?-{3,}:?$")
MD_LINK_RE = re.compile(r"\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
SCHEME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
IMPORT_RE = re.compile(r"(?<!\S)@([\w./-]+)")
INLINE_CODE_RE = re.compile(r"`[^`\n]*`")


class Report:
    """Collects errors, warnings and info records for the summary."""

    def __init__(self):
        self.errors, self.warnings = [], []
        self.info = {"handoffs": [], "findings": [], "messages": []}

    def error(self, file, msg):
        self.errors.append((file, msg))

    def warn(self, file, msg):
        self.warnings.append((file, msg))


# ---------------------------------------------------------------- helpers

def read_text(path):
    return path.read_text(encoding="utf-8", errors="replace")


def blank_fenced(text):
    """Blank out fenced code block lines (keeps line count)."""
    out, fenced = [], False
    for line in text.splitlines():
        if line.lstrip().startswith(("```", "~~~")):
            fenced = not fenced
            out.append("")
        else:
            out.append("" if fenced else line)
    return out


def parse_meta(lines):
    meta = {}
    for line in lines:
        m = META_RE.match(line)
        if m:
            meta.setdefault(m.group(1).strip().lower(), m.group(2).strip())
    return meta


def header_meta(lines):
    """Metadata bullets that appear before the first '## ' heading."""
    end = next((i for i, ln in enumerate(lines) if ln.startswith("## ")), len(lines))
    return parse_meta(lines[:end])


def unquote(value):
    return value.strip().strip("`").strip()


def valid_date(value):
    if not DATE_RE.fullmatch(value):
        return False
    try:
        date.fromisoformat(value)
    except ValueError:
        return False
    return True


def split_row(line):
    return [c.strip().strip("`").strip() for c in line.strip().strip("|").split("|")]


def parse_table(lines, header):
    """Return data rows of the first table whose header starts with `header`, else None."""
    want = [h.lower() for h in header]
    for i, line in enumerate(lines):
        if line.lstrip().startswith("|") and [c.lower() for c in split_row(line)[:len(want)]] == want:
            rows = []
            for row in lines[i + 1:]:
                if not row.lstrip().startswith("|"):
                    break
                cells = split_row(row)
                if not all(SEPARATOR_CELL_RE.match(c) for c in cells if c):
                    rows.append(cells + [""] * (len(want) - len(cells)))
            return rows
    return None


def check_headings(report, rel, lines, required):
    """ERROR for missing headings; WARN when present ones are out of order."""
    heads = [" ".join(m.group(2).lower().split())
             for m in map(HEADING_RE.match, lines) if m and len(m.group(1)) == 2]
    positions = []
    for req in required:
        idx = next((i for i, h in enumerate(heads) if h.startswith(req.lower())), None)
        if idx is None:
            report.error(rel, f"missing heading '## {req}'")
        else:
            positions.append(idx)
    if positions != sorted(positions):
        report.warn(rel, "required headings are out of order")


def check_title(report, rel, lines, expected_id):
    m = TITLE_RE.match(lines[0]) if lines else None
    if not m:
        report.error(rel, f"first line must be '# {expected_id} \u2014 <title>'")
    elif m.group(1) != expected_id:
        report.error(rel, f"title id {m.group(1)} does not match filename id {expected_id}")


def check_meta_basics(report, rel, meta):
    for key in ("author", "date", "status"):
        if not meta.get(key):
            report.error(rel, f"missing metadata '{key.title()}'")
    if meta.get("date") and not valid_date(meta["date"]):
        report.error(rel, f"invalid date '{meta['date']}' (expected YYYY-MM-DD)")
    if meta.get("status") and meta["status"] not in STATUSES:
        report.error(rel, f"invalid status '{meta['status']}'")


def check_commit(report, rel, value, label="Commit"):
    if not value or not COMMIT_RE.fullmatch(unquote(value)):
        report.error(rel, f"{label} must be exactly 40 hex characters")


def check_gaps(report, rel, kind, numbers):
    if numbers:
        missing = sorted(set(range(1, max(numbers) + 1)) - set(numbers))
        if missing:
            ids = ", ".join(f"{kind}-{n:04d}" for n in missing)
            report.warn(rel, f"{kind} ids are not contiguous from 0001; missing {ids}")


def list_ids(directory, prefix, pattern):
    if not directory.is_dir():
        return {}
    return {f"{prefix}-{m.group(1)}": p
            for p in sorted(directory.glob("*.md")) if (m := pattern.match(p.name))}


# ----------------------------------------------------------------- checks

def check_required_files(report, base, rel_base):
    for name in REQUIRED_FILES:
        if not (base / name).is_file():
            report.error(f"{rel_base}/{name}", "required file is missing")


def check_decision_log(report, base, rel_base):
    path, rel = base / "DECISION-LOG.md", f"{rel_base}/DECISION-LOG.md"
    ids = set()
    if not path.is_file():
        return ids
    rows = parse_table(blank_fenced(read_text(path)), ["ID", "Date", "Decision", "Decided by"])
    if rows is None:
        report.error(rel, "missing table with header '| ID | Date | Decision | Decided by |'")
        return ids
    for cells in rows:
        row_id, when, _, who = cells[:4]
        if row_id.lower() == "none":
            continue
        if not DL_ID_RE.fullmatch(row_id):
            report.error(rel, f"invalid decision id '{row_id}'")
        elif row_id in ids:
            report.error(rel, f"duplicate decision id {row_id}")
        ids.add(row_id)
        if not valid_date(when):
            report.error(rel, f"{row_id}: invalid date '{when}'")
        if not who:
            report.error(rel, f"{row_id}: 'Decided by' is empty")
    return ids


def check_current_state(report, base, rel_base, handoffs, reviews):
    path, rel = base / "CURRENT-STATE.md", f"{rel_base}/CURRENT-STATE.md"
    if not path.is_file():
        return
    text = read_text(path)
    if not STATE_COMMIT_RE.search(text):
        report.error(rel, "missing line '- Commit: `<40 hex>`'")
    check_headings_present(report, rel, text.splitlines(), STATE_HEADINGS)
    for kind, known in (("HO", handoffs), ("RV", reviews)):
        for ref in sorted(set(re.findall(rf"\b{kind}-\d{{4}}\b", text))):
            if ref not in known:
                report.error(rel, f"references {ref}, which does not exist")


def check_headings_present(report, rel, lines, required):
    """Like check_headings but order is free (no ordering warning)."""
    heads = [" ".join(m.group(2).lower().split()) for m in map(HEADING_RE.match, lines) if m]
    for req in required:
        if not any(h.startswith(req.lower()) for h in heads):
            report.error(rel, f"missing heading '## {req}'")


def check_handoffs(report, rel_base, handoffs, reviews):
    for hid, path in handoffs.items():
        rel = f"{rel_base}/handoffs/{path.name}"
        lines = blank_fenced(read_text(path))
        check_title(report, rel, lines, hid)
        meta = header_meta(lines)
        check_meta_basics(report, rel, meta)
        check_commit(report, rel, meta.get("commit"))
        review = unquote(meta.get("review", ""))
        if not review:
            report.error(rel, "missing metadata 'Review'")
        elif review != "none":
            for rv in (r.strip() for r in review.split(",")):
                if not RV_ID_RE.fullmatch(rv):
                    report.error(rel, f"invalid review reference '{rv}'")
                elif rv not in reviews:
                    report.error(rel, f"review {rv} does not exist")
        status = meta.get("status", "")
        if status in ("OPEN", "IN_PROGRESS") and review == "none":
            report.warn(rel, f"{hid} is {status} and has no independent review (Review: none)")
        if status not in FINAL_STATUSES:
            title = (lines[0].split(None, 3)[-1] if lines else "").strip()
            report.info["handoffs"].append((hid, status, title, review, rel))
        check_headings(report, rel, lines, HANDOFF_HEADINGS)


def check_reviews(report, rel_base, reviews, handoffs):
    for rid, path in reviews.items():
        rel = f"{rel_base}/reviews/{path.name}"
        lines = blank_fenced(read_text(path))
        check_title(report, rel, lines, rid)
        meta = header_meta(lines)
        check_meta_basics(report, rel, meta)
        check_commit(report, rel, meta.get("commit reviewed"), "Commit reviewed")
        ho = unquote(meta.get("handoff", ""))
        if ho not in handoffs:
            report.error(rel, f"handoff '{ho or 'missing'}' does not exist")
        check_headings(report, rel, lines, REVIEW_HEADINGS)
        rows = parse_table(lines, ["ID", "Severity", "Status", "Finding"])
        if rows is None:
            report.error(rel, "missing findings table '| ID | Severity | Status | Finding |'")
            continue
        for fid, severity, status, finding in (r[:4] for r in rows):
            if fid.lower() == "none":
                continue
            m = FINDING_ID_RE.fullmatch(fid)
            if not m or m.group(1) != rid:
                report.error(rel, f"finding id '{fid}' must look like {rid}-F<digits>")
            if severity not in SEVERITIES:
                report.error(rel, f"{fid}: invalid severity '{severity}'")
            if status not in STATUSES:
                report.error(rel, f"{fid}: invalid status '{status}'")
            elif status not in FINAL_STATUSES:
                report.info["findings"].append((fid, severity, status, finding, rel))
                report.warn(rel, f"open finding {fid} ({severity}, {status})")


def parse_messages(lines):
    """Yield (id, subject, meta) for each message heading."""
    heads = [i for i, ln in enumerate(lines) if MSG_HEAD_RE.match(ln)]
    for n, start in enumerate(heads):
        stop = next((j for j in range(start + 1, len(lines)) if HEADING_RE.match(lines[j])),
                    len(lines))
        m = MSG_HEAD_RE.match(lines[start])
        yield m.group(1), m.group(3), parse_meta(lines[start + 1:stop])


def message_sources(base, rel_base):
    """(path, rel, is_archive) for live and archive message files that exist."""
    for name in ("INBOX.md", "OUTBOX.md"):
        if (base / name).is_file():
            yield base / name, f"{rel_base}/{name}", False
    archive = base / "archive"
    for path in sorted(archive.glob("*.md")) if archive.is_dir() else []:
        yield path, f"{rel_base}/archive/{path.name}", True


def check_messages(report, base, rel_base, handoffs, reviews, decisions):
    seen = {}
    for path, rel, archived in message_sources(base, rel_base):
        closed = 0
        for mid, subject, meta in parse_messages(blank_fenced(read_text(path))):
            seen.setdefault(mid, []).append(rel)
            check_meta_basics(report, f"{rel} {mid}", meta)
            status = meta.get("status", "")
            closed += status == "CLOSED"
            if archived and status != "CLOSED":
                report.error(rel, f"{mid}: archived messages must be CLOSED (found '{status}')")
            for kind, ref in ((m.group(1), m.group(0)) for m in REF_RE.finditer(meta.get("refs", ""))):
                known = {"HO": handoffs, "RV": reviews, "DL": decisions}[kind]
                if ref not in known:
                    report.error(rel, f"{mid}: reference {ref} does not exist")
            if not archived and status in STATUSES and status != "CLOSED":
                report.info["messages"].append((mid, status, subject, rel))
                report.warn(rel, f"open message {mid} ({status}): {subject}")
        if not archived and closed > MAX_CLOSED_LIVE:
            report.warn(rel, f"{closed} CLOSED messages; consider archiving")
    for mid, files in seen.items():
        if len(files) > 1:
            report.error(files[0], f"message id {mid} appears more than once ({', '.join(files)})")
    for direction in ("IN", "OUT"):
        nums = [int(i.rsplit("-", 1)[1]) for i in seen if i.startswith(f"MSG-{direction}-")]
        check_gaps(report, f"{rel_base}", f"MSG-{direction}", nums)


def check_links(report, root):
    files = sorted((root / COORD).rglob("*.md")) if (root / COORD).is_dir() else []
    claude = root / "CLAUDE.md"
    if claude.is_file():
        files.append(claude)
    for path in files:
        rel = path.relative_to(root).as_posix()
        lines = [INLINE_CODE_RE.sub("", ln) for ln in blank_fenced(read_text(path))]
        for target in (t for ln in lines for t in MD_LINK_RE.findall(ln)):
            if SCHEME_RE.match(target) or target.startswith("#"):
                continue
            if not (path.parent / target.split("#")[0].split("?")[0]).exists():
                report.error(rel, f"broken link '{target}'")
        if path == claude:
            for target in (t.rstrip(".") for ln in lines for t in IMPORT_RE.findall(ln)):
                if target and not (root / target).exists():
                    report.error(rel, f"@import '{target}' does not exist")


# ------------------------------------------------------------ entry points

def run_checks(root):
    report, base, rel_base = Report(), root / COORD, COORD
    handoffs = list_ids(base / "handoffs", "HO", HO_FILE_RE)
    reviews = list_ids(base / "reviews", "RV", RV_FILE_RE)
    check_required_files(report, base, rel_base)
    decisions = check_decision_log(report, base, rel_base)
    check_current_state(report, base, rel_base, handoffs, reviews)
    check_handoffs(report, rel_base, handoffs, reviews)
    check_reviews(report, rel_base, reviews, handoffs)
    check_messages(report, base, rel_base, handoffs, reviews, decisions)
    check_links(report, root)
    check_gaps(report, f"{rel_base}/handoffs", "HO", [int(i[3:]) for i in handoffs])
    check_gaps(report, f"{rel_base}/reviews", "RV", [int(i[3:]) for i in reviews])
    return report


def cell(value):
    return str(value).replace("|", "\\|").replace("\n", " ")


def table(headers, rows):
    if not rows:
        return ["_None._", ""]
    out = ["| " + " | ".join(headers) + " |", "|" + "---|" * len(headers)]
    out += ["| " + " | ".join(cell(c) for c in row) + " |" for row in rows]
    return out + [""]


def render_summary(report):
    lines = ["## AI coordination check", "",
             f"**{len(report.errors)} error(s), {len(report.warnings)} warning(s)**", ""]
    sections = [
        ("Errors", ["File", "Message"], report.errors),
        ("Warnings", ["File", "Message"], report.warnings),
        ("Open handoffs", ["ID", "Status", "Title", "Review", "File"], report.info["handoffs"]),
        ("Open findings", ["ID", "Severity", "Status", "Finding", "File"], report.info["findings"]),
        ("Open messages", ["ID", "Status", "Subject", "File"], report.info["messages"]),
    ]
    for title, headers, rows in sections:
        lines += [f"### {title}", ""] + table(headers, rows)
    return "\n".join(lines) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=".", help="repository root (default: cwd)")
    parser.add_argument("--summary", help="append a Markdown report to this file")
    args = parser.parse_args(argv)
    report = run_checks(Path(args.root))
    for file, msg in report.errors:
        print(f"ERROR {file}: {msg}")
    for file, msg in report.warnings:
        print(f"WARN {file}: {msg}")
    print(f"{len(report.errors)} error(s), {len(report.warnings)} warning(s)")
    if args.summary:
        with open(args.summary, "a", encoding="utf-8") as fh:
            fh.write(render_summary(report))
    return 1 if report.errors else 0


if __name__ == "__main__":
    sys.exit(main())
