#!/usr/bin/env python3
"""Validate the AI coordination documents under docs/ai-coordination/.

Usage: python3 tools/coordination/check_coordination.py [--root PATH] [--summary FILE]
           [--write-dashboard] [--evidence HO-NNNN [--repo OWNER/NAME]]
Exit code 0 when there are no errors, 1 otherwise. Stdlib only.
"""
import argparse
import os
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

COORD = "docs/ai-coordination"
REQUIRED_FILES = [
    "AI-COORDINATION-PROTOCOL.md", "CURRENT-STATE.md", "INBOX.md", "OUTBOX.md",
    "HANDOFF-TEMPLATE.md", "REVIEW-TEMPLATE.md", "DECISION-LOG.md", "PROGRAMME.md",
]
DASHBOARD = "DASHBOARD.md"
STALE_MSG = ("DASHBOARD.md is stale: run python3 tools/coordination/check_coordination.py "
             "--write-dashboard")
STATUSES = {"OPEN", "IN_PROGRESS", "BLOCKED", "RESOLVED", "ACCEPTED_BY_OWNER", "CLOSED"}
FINAL_STATUSES = {"ACCEPTED_BY_OWNER", "CLOSED"}      # RESOLVED still awaits confirmation
OPEN_STATUSES = {"OPEN", "IN_PROGRESS", "BLOCKED"}
DONE_FINDING_STATUSES = {"RESOLVED", "ACCEPTED_BY_OWNER", "CLOSED"}
SEVERITIES = ["Critical", "High", "Medium", "Low", "Info"]
BLOCKING_SEVERITIES = {"Critical", "High", "Medium"}
HANDOFF_STATUSES = {
    "AWAITING_REVIEW", "CHANGES_REQUIRED", "APPROVED_FOR_OWNER_ACCEPTANCE", "BLOCKED",
    "REVIEW_INCOMPLETE", "ACCEPTED_BY_OWNER", "SUPERSEDED",
}
CLOSED_HANDOFF_STATUSES = {"ACCEPTED_BY_OWNER", "SUPERSEDED"}
NO_REVIEW_STATUSES = {"AWAITING_REVIEW", "BLOCKED", "SUPERSEDED"}
OUTCOME_STATUSES = {  # review Outcome -> allowed handoff Status values
    "APPROVED_FOR_OWNER_ACCEPTANCE": {"APPROVED_FOR_OWNER_ACCEPTANCE", "ACCEPTED_BY_OWNER", "SUPERSEDED"},
    "CHANGES_REQUIRED": {"CHANGES_REQUIRED", "SUPERSEDED"},
    "BLOCKED": {"BLOCKED", "SUPERSEDED"},
    "REVIEW_INCOMPLETE": {"REVIEW_INCOMPLETE", "AWAITING_REVIEW", "SUPERSEDED"},
}
IMPLEMENTATIONS = {"NOT_STARTED", "IN_PROGRESS", "DELIVERED"}
PROGRAMME_REVIEWS = {"NONE", "LEGACY"} | set(HANDOFF_STATUSES - {"ACCEPTED_BY_OWNER", "SUPERSEDED"})
ACCEPTANCES = {"NOT_ACCEPTED", "CONDITIONALLY_ACCEPTED", "ACCEPTED", "CLOSED"}
ACCEPTED_ENOUGH = {"CONDITIONALLY_ACCEPTED", "ACCEPTED", "CLOSED"}
PROGRAMME_HEADER = ["WP", "Title", "Depends on", "Implementation", "Review", "Acceptance",
                    "Open items", "Latest handoff"]
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
    "Branch and commit", "Current implementation package", "Latest handoff",
    "Latest review status", "Outstanding corrections", "Outstanding owner decisions",
    "Outstanding verification requirements", "Next eligible package", "Programme progress",
    "Next recommended actions",
]

AUTHOR_RES = {  # record kind -> allowed Author values
    "handoff": re.compile(r"Claude Code"), "review": re.compile(r"ChatGPT.*"),
    "message": re.compile(r"Claude Code|Owner|ChatGPT.*"),
}
NO_RESOLUTION_RE = re.compile(r"[\s\u2014\u2013-]*")
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
APPEND_ONLY_RE = re.compile(rf"{COORD}/(INBOX\.md|OUTBOX\.md|archive/[^/]+\.md|reviews/[^/]+\.md)")
WP_ID_RE = re.compile(r"(?:WP|GOV) \d+")
WP_PREFIX_RE = re.compile(r"((?:WP|GOV) \d+)(?!\d)")
SOFT_RE = re.compile(r"\s*\(soft\)\s*$", re.I)
REMOTE_RE = re.compile(r"github\.com[:/]([^/\s]+/[^/\s]+?)(?:\.git)?/?$")
PENDING_RE = re.compile(r"pending owner decision", re.I)
INLINE_CODE_RE = re.compile(r"`[^`\n]*`")


class Report:
    """Collects errors, warnings and info records for the summary."""

    def __init__(self):
        self.errors, self.warnings = [], []
        self.info = {"handoffs": [], "findings": [], "resolved": [], "messages": [], "removed": [],
                     "commits": [], "ho": {}, "rv": {},
                     "programme": [], "pending": [], "eligible": [], "actions": []}

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
    heads = [" ".join(m.group(2).split())
             for m in map(HEADING_RE.match, lines) if m and len(m.group(1)) == 2]
    positions = []
    for req in required:
        idx = heads.index(req) if req in heads else None
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


def check_meta_basics(report, rel, meta, statuses=None, kind="message"):
    statuses = statuses or STATUSES
    author = meta.get("author", "")
    if author and not AUTHOR_RES[kind].fullmatch(author):
        report.error(rel, f"invalid Author '{author}' for a {kind}")
    for key in ("author", "date", "status"):
        if not meta.get(key):
            report.error(rel, f"missing metadata '{key.title()}'")
    if meta.get("date") and not valid_date(meta["date"]):
        report.error(rel, f"invalid date '{meta['date']}' (expected YYYY-MM-DD)")
    if meta.get("status") and meta["status"] not in statuses:
        report.error(rel, f"invalid status '{meta['status']}'")


def check_commit(report, rel, value, label="Commit"):
    if not value or not COMMIT_RE.fullmatch(unquote(value)):
        report.error(rel, f"{label} must be exactly 40 hex characters")


def list_ids(directory, prefix, pattern):
    if not directory.is_dir():
        return {}
    return {f"{prefix}-{m.group(1)}": p
            for p in sorted(directory.glob("*.md")) if (m := pattern.match(p.name))}


# ----------------------------------------------------------------- checks

def check_record_names(report, base, rel_base):
    """Flag *.md files in handoffs/ and reviews/ that would otherwise be silently ignored."""
    for sub_dir, pattern in (("handoffs", HO_FILE_RE), ("reviews", RV_FILE_RE)):
        for path in sorted((base / sub_dir).glob("*.md")) if (base / sub_dir).is_dir() else []:
            if path.name != "README.md" and not pattern.match(path.name):
                report.error(f"{rel_base}/{sub_dir}/{path.name}", "unrecognised record file name")


def check_required_files(report, base, rel_base):
    for name in REQUIRED_FILES:
        if not (base / name).is_file():
            report.error(f"{rel_base}/{name}", "required file is missing")


def check_decision_log(report, base, rel_base, handoffs, reviews):
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
        elif not (who.startswith("Owner") or PENDING_RE.search(who)):
            report.error(rel, f"{row_id}: 'Decided by' must start with 'Owner' or be 'Pending owner decision'")
        if PENDING_RE.search(who):
            report.info["pending"].append((row_id, cells[2], cells[4] if len(cells) > 4 else ""))
    for cells in rows:
        for m in REF_RE.finditer(cells[4] if len(cells) > 4 else ""):
            if m.group(0) not in {"HO": handoffs, "RV": reviews, "DL": ids}[m.group(1)]:
                report.error(rel, f"{cells[0]}: Refs {m.group(0)} does not exist")
    return ids


def check_current_state(report, base, rel_base, handoffs, reviews):
    path, rel = base / "CURRENT-STATE.md", f"{rel_base}/CURRENT-STATE.md"
    if not path.is_file():
        return
    text = read_text(path)
    if not STATE_COMMIT_RE.search(text):
        report.error(rel, "missing line '- Commit: `<40 hex>`'")
    check_headings_present(report, rel, text.splitlines(), STATE_HEADINGS)
    report.info["actions"] = section_lines(text.splitlines(), "Next recommended actions")
    for kind, known in (("HO", handoffs), ("RV", reviews)):
        for ref in sorted(set(re.findall(rf"\b{kind}-\d{{4}}\b", text))):
            if ref not in known:
                report.error(rel, f"references {ref}, which does not exist")


def section_lines(lines, heading):
    """Lines under '## heading' up to the next '## ', without leading/trailing blanks."""
    out, inside = [], False
    for line in lines:
        if line.startswith("## "):
            inside = line[3:].strip().lower().startswith(heading.lower())
        elif inside:
            out.append(line.rstrip())
    return "\n".join(out).strip("\n").split("\n") if "".join(out).strip() else []


def check_headings_present(report, rel, lines, required):
    """Like check_headings but order is free (no ordering warning)."""
    heads = [" ".join(m.group(2).lower().split()) for m in map(HEADING_RE.match, lines) if m]
    for req in required:
        if not any(h.startswith(req.lower()) for h in heads):
            report.error(rel, f"missing heading '## {req}'")


def short(sha):
    return unquote(sha or "")[:7]


def parse_findings(lines):
    """Finding rows (id, severity, status, finding, resolution); None when no table."""
    rows = parse_table(lines, ["ID", "Severity", "Status", "Finding"])
    return None if rows is None else [tuple(r[:4]) + (r[5] if len(r) > 5 else "",)
                                      for r in rows if r[0].lower() != "none"]


def check_review_refs(report, rel, review, reviews):
    """Validate the Review field; return the list of existing listed review ids."""
    listed = []
    if not review:
        report.error(rel, "missing metadata 'Review'")
    elif review != "none":
        for rv in (r.strip() for r in review.split(",")):
            if not RV_ID_RE.fullmatch(rv):
                report.error(rel, f"invalid review reference '{rv}'")
            elif rv not in reviews:
                report.error(rel, f"review {rv} does not exist")
            else:
                listed.append(rv)
    return listed


def check_handoff_link_field(report, rel, meta, key, pattern, known, label):
    """Validate a 'none | ID' field (Responds to / Supersedes); return the id or ''."""
    value = unquote(meta.get(key, ""))
    if not value:
        report.error(rel, f"missing metadata '{label}'")
    elif value != "none":
        if not pattern.fullmatch(value):
            report.error(rel, f"invalid {label} reference '{value}'")
        elif value not in known:
            report.error(rel, f"{label} {value} does not exist")
        else:
            return value
    return ""


def check_handoff_review_state(report, rel, hid, h, rv_data):
    """Status must be consistent with the listed reviews and their outcomes."""
    status, listed = h["status"], h["listed"]
    if not listed:
        if status not in NO_REVIEW_STATUSES and status in HANDOFF_STATUSES:
            report.error(rel, f"Review: none but Status is {status}")
        return
    for rv in listed:
        if rv_data[rv]["handoff"] != hid:
            report.error(rel, f"{rv} says Handoff: {rv_data[rv]['handoff'] or 'missing'}")
    latest = max(listed)
    if rv_data[latest]["commit"].lower() != h["commit"].lower():
        report.error(rel, f"review {latest} reviewed {short(rv_data[latest]['commit'])} but handoff "
                          f"commit is {short(h['commit'])}; approval or findings do not carry "
                          "across commits")
    outcome = rv_data[latest]["outcome"]
    if outcome in OUTCOME_STATUSES and status in HANDOFF_STATUSES \
            and status not in OUTCOME_STATUSES[outcome]:
        report.error(rel, f"Status {status} does not match {latest} Outcome {outcome}")


def check_handoff_responds(report, rel, h, rv_data):
    rv = h["responds"]
    if rv and h["commit"] and rv_data[rv]["commit"].lower() == h["commit"].lower():
        report.error(rel, f"responds to {rv} but has the same commit as the review; "
                          "a correction must be a new commit")


def check_handoffs(report, rel_base, handoffs, reviews):
    rv_data = report.info["rv"]
    for hid, path in handoffs.items():
        rel = f"{rel_base}/handoffs/{path.name}"
        text = read_text(path)
        lines = blank_fenced(text)
        check_title(report, rel, lines, hid)
        meta = header_meta(lines)
        check_meta_basics(report, rel, meta, HANDOFF_STATUSES, "handoff")
        check_commit(report, rel, meta.get("commit"))
        check_commit(report, rel, meta.get("parent"), "Parent")
        commit, parent = unquote(meta.get("commit", "")), unquote(meta.get("parent", ""))
        if commit and commit.lower() == parent.lower():
            report.warn(rel, "Parent equals Commit")
        wp = meta.get("work package", "")
        if not WP_ID_RE.match(wp):
            report.error(rel, f"Work package must start with 'WP <n>' or 'GOV <n>' (found '{wp}')")
        if not unquote(meta.get("branch", "")):
            report.error(rel, "missing metadata 'Branch'")
        review = unquote(meta.get("review", ""))
        h = {"status": meta.get("status", ""), "commit": commit, "parent": parent, "wp": wp,
             "date": meta.get("date", ""), "review": review, "branch": unquote(meta.get("branch", "")),
             "listed": check_review_refs(report, rel, review, reviews),
             "responds": check_handoff_link_field(report, rel, meta, "responds to", RV_ID_RE,
                                                  reviews, "Responds to"),
             "supersedes": check_handoff_link_field(report, rel, meta, "supersedes",
                                                    re.compile(r"HO-\d{4}"), handoffs, "Supersedes"),
             "title": (lines[0].split(None, 3)[-1] if lines else "").strip(), "rel": rel}
        report.info["ho"][hid] = h
        check_handoff_review_state(report, rel, hid, h, rv_data)
        check_handoff_responds(report, rel, h, rv_data)
        if h["status"] == "ACCEPTED_BY_OWNER" and not DL_ID_RE.search(text):
            report.error(rel, "ACCEPTED_BY_OWNER without a DL- decision reference")
        if h["status"] == "AWAITING_REVIEW":
            report.warn(rel, f"{hid} is AWAITING_REVIEW (in the review queue)")
        if h["status"] not in CLOSED_HANDOFF_STATUSES:
            report.info["handoffs"].append((hid, h["status"], h["title"], review, rel))
        check_headings(report, rel, lines, HANDOFF_HEADINGS)


def check_supersedes(report, handoffs_info):
    for hid, h in handoffs_info.items():
        old = handoffs_info.get(h["supersedes"])
        if old and old["status"] != "SUPERSEDED":
            report.error(old["rel"], f"{h['supersedes']} is superseded by {hid} "
                                     f"but its Status is {old['status']}")


def check_reviews_listed(report, handoffs_info, rv_data):
    for rid, r in rv_data.items():
        h = handoffs_info.get(r["handoff"])
        if h and rid not in h["listed"]:
            report.error(r["rel"], f"{rid} is not listed in {r['handoff']}'s Review field")


def check_resolution(report, rel, fid, status, resolution):
    if status in DONE_FINDING_STATUSES and NO_RESOLUTION_RE.fullmatch(resolution):
        report.error(rel, f"{fid}: {status} finding needs a Resolution")
    if status == "ACCEPTED_BY_OWNER" and not DL_ID_RE.search(resolution):
        report.error(rel, f"{fid}: ACCEPTED_BY_OWNER finding needs a DL- reference in Resolution")


def check_review_outcome(report, rel, rid, outcome, findings):
    if outcome == "CHANGES_REQUIRED" and not any(f[1] in BLOCKING_SEVERITIES for f in findings):
        report.error(rel, "CHANGES_REQUIRED with no Critical/High/Medium finding")
    if outcome == "APPROVED_FOR_OWNER_ACCEPTANCE":
        for fid, severity, status, _, _ in findings:
            if severity in ("Critical", "High") and status not in DONE_FINDING_STATUSES:
                report.error(rel, f"APPROVED_FOR_OWNER_ACCEPTANCE but {fid} ({severity}) is {status}")


def check_reviews(report, rel_base, reviews, handoffs):
    for rid, path in reviews.items():
        rel = f"{rel_base}/reviews/{path.name}"
        lines = blank_fenced(read_text(path))
        check_title(report, rel, lines, rid)
        meta = header_meta(lines)
        check_meta_basics(report, rel, meta, kind="review")
        check_commit(report, rel, meta.get("commit reviewed"), "Commit reviewed")
        outcome = meta.get("outcome", "")
        if outcome not in OUTCOME_STATUSES:
            report.error(rel, f"missing or invalid Outcome '{outcome}'")
        ho = unquote(meta.get("handoff", ""))
        if ho not in handoffs:
            report.error(rel, f"handoff '{ho or 'missing'}' does not exist")
        check_headings(report, rel, lines, REVIEW_HEADINGS)
        rows = parse_findings(lines)
        report.info["rv"][rid] = {"handoff": ho, "outcome": outcome, "rel": rel,
                                  "commit": unquote(meta.get("commit reviewed", "")),
                                  "findings": rows or []}
        if rows is None:
            report.error(rel, "missing findings table '| ID | Severity | Status | Finding |'")
            continue
        check_review_outcome(report, rel, rid, outcome, rows)
        for fid, severity, status, finding, resolution in rows:
            check_resolution(report, rel, fid, status, resolution)
            m = FINDING_ID_RE.fullmatch(fid)
            if not m or m.group(1) != rid:
                report.error(rel, f"finding id '{fid}' must look like {rid}-F<digits>")
            if severity not in SEVERITIES:
                report.error(rel, f"{fid}: invalid severity '{severity}'")
            if status not in STATUSES:
                report.error(rel, f"{fid}: invalid status '{status}'")
            elif status in OPEN_STATUSES:
                report.info["findings"].append((fid, severity, status, finding, rel))
                report.warn(rel, f"open finding {fid} ({severity}, {status})")
            elif status == "RESOLVED":
                report.info["resolved"].append((fid, severity, status, finding, rel))


def parse_deps(value):
    """('none' | 'WP 1, WP 2 (soft)') -> list of (wp, is_soft)."""
    if value.lower() in ("", "none"):
        return []
    return [(SOFT_RE.sub("", d).strip(), bool(SOFT_RE.search(d))) for d in value.split(",")]


def check_programme_row(report, rel, row, handoffs_info):
    wp = row["wp"]
    impl, rev, acc = row["implementation"], row["review"], row["acceptance"]
    for name, value, allowed in (("Implementation", impl, IMPLEMENTATIONS),
                                 ("Review", rev, PROGRAMME_REVIEWS), ("Acceptance", acc, ACCEPTANCES)):
        if value not in allowed:
            report.error(rel, f"{wp}: invalid {name} '{value}'")
    if impl == "NOT_STARTED" and (rev != "NONE" or acc != "NOT_ACCEPTED"):
        report.error(rel, f"{wp}: NOT_STARTED requires Review NONE and Acceptance NOT_ACCEPTED")
    if acc in ("ACCEPTED", "CLOSED") and impl != "DELIVERED":
        report.error(rel, f"{wp}: Acceptance {acc} requires Implementation DELIVERED")
    latest = row["latest"]
    if latest == "none":
        return
    h = handoffs_info.get(latest)
    if h is None:
        report.error(rel, f"{wp}: latest handoff {latest} does not exist")
        return
    m = WP_PREFIX_RE.match(h["wp"])
    if not m or m.group(1) != wp:
        report.error(rel, f"{wp}: {latest} belongs to '{h['wp']}'")
    expected = "APPROVED_FOR_OWNER_ACCEPTANCE" if h["status"] == "ACCEPTED_BY_OWNER" else h["status"]
    if h["status"] != "SUPERSEDED" and rev != expected:
        report.error(rel, f"{wp}: Review {rev} disagrees with {latest} Status {h['status']}")


def compute_eligible(rows):
    """WPs NOT_STARTED whose hard dependencies are accepted or approved: [(wp, title, deps)]."""
    by_wp = {r["wp"]: r for r in rows}
    out = []
    for r in rows:
        if r["implementation"] != "NOT_STARTED":
            continue
        hard = [d for d, soft in parse_deps(r["depends"]) if not soft]
        if all(d in by_wp and (by_wp[d]["acceptance"] in ACCEPTED_ENOUGH
                               or by_wp[d]["review"] == "APPROVED_FOR_OWNER_ACCEPTANCE") for d in hard):
            out.append((r["wp"], r["title"], r["depends"]))
    return sorted(out, key=lambda e: (int(e[0].split()[1]), e[0]))


def check_programme(report, base, rel_base, handoffs_info):
    path, rel = base / "PROGRAMME.md", f"{rel_base}/PROGRAMME.md"
    if not path.is_file():
        return
    table_rows = parse_table(blank_fenced(read_text(path)), PROGRAMME_HEADER)
    if table_rows is None:
        report.error(rel, "missing table with header '| " + " | ".join(PROGRAMME_HEADER) + " |'")
        return
    keys = ["wp", "title", "depends", "implementation", "review", "acceptance", "open", "latest"]
    rows, seen = [], set()
    for cells in table_rows:
        row = dict(zip(keys, cells))
        if not WP_ID_RE.fullmatch(row["wp"]):
            report.error(rel, f"invalid WP id '{row['wp']}'")
        elif row["wp"] in seen:
            report.error(rel, f"duplicate WP {row['wp']}")
        seen.add(row["wp"])
        rows.append(row)
    for row in rows:
        for dep, _ in parse_deps(row["depends"]):
            if dep not in seen:
                report.error(rel, f"{row['wp']}: depends on {dep}, which is not a row")
        if row["latest"] != "none" and not re.fullmatch(r"HO-\d{4}", row["latest"]):
            report.error(rel, f"{row['wp']}: invalid latest handoff '{row['latest']}'")
        check_programme_row(report, rel, row, handoffs_info)
    report.info["programme"] = rows
    report.info["eligible"] = compute_eligible(rows)


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
            if not archived and status in STATUSES and status not in FINAL_STATUSES:
                report.info["messages"].append((mid, status, subject, rel))
                if status != "RESOLVED":
                    report.warn(rel, f"open message {mid} ({status}): {subject}")
        if not archived and closed > MAX_CLOSED_LIVE:
            report.warn(rel, f"{closed} CLOSED messages; consider archiving")
    for mid, files in seen.items():
        if len(files) > 1:
            report.error(files[0], f"message id {mid} appears more than once ({', '.join(files)})")


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


# -------------------------------------------------------------- git checks

def git(root, *args):
    """CompletedProcess of `git <args>` run in root, or None when git cannot be run."""
    try:
        return subprocess.run(["git", *args], cwd=root, capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError):
        return None


def check_commits_exist(report, root):
    """--verify-commits: every recorded commit must exist in the local git object store."""
    info = report.info
    shas = [(h["rel"], label, h[key]) for h in info["ho"].values()
            for label, key in (("Commit", "commit"), ("Parent", "parent"))]
    shas += [(r["rel"], "Commit reviewed", r["commit"]) for r in info["rv"].values()]
    for rel, label, sha in shas:
        if not COMMIT_RE.fullmatch(sha):
            continue
        done = git(root, "cat-file", "-e", f"{sha}^{{commit}}")
        if done is None or "not a git repository" in done.stderr:
            report.warn(rel, "git is unavailable; --verify-commits skipped")
            return
        if done.returncode != 0:
            report.error(rel, f"{label} {sha[:7]} does not exist in git")


def check_append_only(report, root, ref):
    """--append-only-since: records must not be deleted; removed lines are listed for review."""
    if (git(root, "rev-parse", "--verify", f"{ref}^{{commit}}") or subprocess.CompletedProcess([], 1)).returncode:
        report.warn(COORD, f"ref '{ref}' not found; --append-only-since skipped")
        return
    status = git(root, "diff", "--name-status", ref, "HEAD", "--", COORD)
    numstat = git(root, "diff", "--numstat", ref, "HEAD", "--", COORD)
    for line in status.stdout.splitlines():
        code, *paths = line.split("\t")
        old = paths[0] if paths else ""
        if code[:1] in "DR" and re.match(rf"{COORD}/(handoffs|reviews|archive)/", old):
            report.error(old, f"record was {'deleted' if code[:1] == 'D' else 'renamed'} since {ref}")
    for line in numstat.stdout.splitlines():
        added, deleted, path = (line.split("\t") + ["", "", ""])[:3]
        if not deleted.isdigit() or int(deleted) == 0 or not APPEND_ONLY_RE.fullmatch(path):
            continue
        report.warn(path, f"{deleted} line(s) removed from {path} since {ref}: verify only "
                          "Status/Resolution/Review lines changed")
        diff = git(root, "diff", "-U0", ref, "HEAD", "--", path)
        report.info["removed"] += [(path, ln[1:]) for ln in diff.stdout.splitlines()
                                   if ln.startswith("-") and not ln.startswith("---")]


# ------------------------------------------------------------ entry points

def run_checks(root, verify_commits=False, since=None):
    report, base, rel_base = Report(), root / COORD, COORD
    handoffs = list_ids(base / "handoffs", "HO", HO_FILE_RE)
    reviews = list_ids(base / "reviews", "RV", RV_FILE_RE)
    check_required_files(report, base, rel_base)
    decisions = check_decision_log(report, base, rel_base, handoffs, reviews)
    check_current_state(report, base, rel_base, handoffs, reviews)
    check_reviews(report, rel_base, reviews, handoffs)
    check_handoffs(report, rel_base, handoffs, reviews)
    check_supersedes(report, report.info["ho"])
    check_reviews_listed(report, report.info["ho"], report.info["rv"])
    check_programme(report, base, rel_base, report.info["ho"])
    check_messages(report, base, rel_base, handoffs, reviews, decisions)
    check_links(report, root)
    check_dashboard(report, base, rel_base)
    if verify_commits:
        check_commits_exist(report, root)
    if since:
        check_append_only(report, root, since)
    check_record_names(report, base, rel_base)
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
    info = report.info
    queue = [(hid, h["wp"], short(h["commit"]), h["date"]) for hid, h in info["ho"].items()
             if h["status"] == "AWAITING_REVIEW"]
    lines = ["## AI coordination check", "",
             f"**{len(report.errors)} error(s), {len(report.warnings)} warning(s)**", ""]
    sections = [
        ("Errors", ["File", "Message"], report.errors),
        ("Warnings", ["File", "Message"], report.warnings),
        ("Open handoffs", ["ID", "Status", "Title", "Review", "File"], info["handoffs"]),
        ("Open findings", ["ID", "Severity", "Status", "Finding", "File"], info["findings"]),
        ("Awaiting re-review", ["ID", "Severity", "Status", "Finding", "File"], info["resolved"]),
        ("Open messages", ["ID", "Status", "Subject", "File"],
         [m for m in info["messages"] if m[1] != "RESOLVED"]),
        ("Messages awaiting confirmation", ["ID", "Status", "Subject", "File"],
         [m for m in info["messages"] if m[1] == "RESOLVED"]),
        ("Review queue", ["Handoff", "WP", "Commit", "Since"], queue),
        ("Owner decision queue", ["ID", "Decision", "Refs"], info["pending"]),
        ("Next eligible packages", ["WP", "Title", "Depends on"], info["eligible"]),
        ("Removed lines (append-only check)", ["File", "Line"], info["removed"]),
    ]
    for title, headers, rows in sections:
        lines += [f"### {title}", ""] + table(headers, rows)
    return "\n".join(lines) + "\n"


# -------------------------------------------------------------- dashboard

def open_findings(rv_data, rids):
    return [f[:4] for rid in rids for f in rv_data[rid]["findings"] if f[2] in OPEN_STATUSES]


def severity_counts(findings):
    counts = {s: sum(1 for f in findings if f[1] == s) for s in SEVERITIES}
    return ", ".join(f"{s} {n}" for s, n in counts.items() if n) or "none"


def render_dashboard(info):
    ho, rv, prog = info["ho"], info["rv"], info["programme"]
    by_status = lambda *s: [(hid, h) for hid, h in sorted(ho.items()) if h["status"] in s]  # noqa: E731
    out = ["# Owner dashboard", "",
           "GENERATED by `tools/coordination/check_coordination.py --write-dashboard` from "
           "PROGRAMME.md, handoffs/, reviews/ and DECISION-LOG.md. Do not edit by hand. "
           "Implementation delivered, technical approval and owner acceptance are different "
           "states.", ""]

    def section(title, *blocks):
        out.extend([f"## {title}", ""])
        for block in blocks:
            out.extend(block)

    wip = [(r["wp"], r["title"], r["latest"], ho[r["latest"]]["status"] if r["latest"] in ho else "")
           for r in prog if r["implementation"] == "IN_PROGRESS"]
    section("Work in progress", table(["WP", "Title", "Latest handoff", "Status"], wip))
    queue = [(hid, h["wp"], short(h["commit"]), h["date"], h["review"])
             for hid, h in by_status("AWAITING_REVIEW", "REVIEW_INCOMPLETE")]
    section("Awaiting independent review", table(["Handoff", "WP", "Commit", "Since", "Review"], queue))
    fixes, found = [], []
    for hid, h in by_status("CHANGES_REQUIRED"):
        opened = open_findings(rv, h["listed"][-1:])
        fixes.append((hid, ", ".join(h["listed"][-1:]), severity_counts(opened), h["status"]))
        found += opened
    section("Corrections required", table(["Handoff", "Review", "Open findings", "Status"], fixes),
            ["### Open findings", ""] + table(["ID", "Severity", "Status", "Finding"], found) if fixes else [])
    again = [(rv[m.group(1)]["handoff"], m.group(1), f[0], f[1], f[3]) for f in info["resolved"]
             for m in [FINDING_ID_RE.fullmatch(f[0])] if m]
    section("Awaiting re-review", table(["Handoff", "Review", "ID", "Severity", "Finding"], again))
    approved = [(hid, h["wp"], short(h["commit"])) for hid, h in by_status("APPROVED_FOR_OWNER_ACCEPTANCE")]
    section("Awaiting owner decision", table(["ID", "Decision", "Refs"], info["pending"]),
            ["### Approved, awaiting owner acceptance", ""] + table(["Handoff", "WP", "Commit"], approved))
    blocked = [(h["wp"], f"{hid} is BLOCKED") for hid, h in by_status("BLOCKED")]
    blocked += [(r["wp"], r["open"] or "Review BLOCKED") for r in prog if r["review"] == "BLOCKED"]
    blocked += [(r["wp"], r["open"]) for r in prog
                if r["open"] and r["acceptance"] == "CONDITIONALLY_ACCEPTED"]
    section("Blocked", table(["WP", "Open items"], blocked))
    done = [(r["wp"], r["title"], r["acceptance"]) for r in prog if r["acceptance"] in ("ACCEPTED", "CLOSED")]
    section("Completed", table(["WP", "Title", "Acceptance"], done))
    eligible = [f"- {wp} \u2014 {title} (depends on: {deps or 'none'})" for wp, title, deps in info["eligible"]]
    section("Next eligible packages", eligible + [""] if eligible else ["_None._", ""])
    section("Open messages", table(["ID", "Subject", "Status"], [(m[0], m[2], m[1]) for m in info["messages"]]))
    section("Next actions", info["actions"] + [""] if info["actions"] else ["_None._", ""])
    return "\n".join(out).rstrip("\n") + "\n"


def check_dashboard(report, base, rel_base):
    path = base / DASHBOARD
    if not path.is_file() or read_text(path) != render_dashboard(report.info):
        report.error(f"{rel_base}/{DASHBOARD}", STALE_MSG)


# --------------------------------------------------------------- evidence

def detect_repo(root):
    """owner/name from --repo, $GITHUB_REPOSITORY or origin's URL; else OWNER/REPO."""
    try:
        url = subprocess.run(["git", "-C", str(root), "config", "--get", "remote.origin.url"],
                             capture_output=True, text=True, timeout=10).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        url = ""
    m = REMOTE_RE.search(url)
    return os.environ.get("GITHUB_REPOSITORY") or (m.group(1) if m else "OWNER/REPO")


def diff_stat(root, parent, sha):
    try:
        done = subprocess.run(["git", "-C", str(root), "diff", "--stat", parent, sha],
                              capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError) as exc:
        return f"diff stat unavailable: {exc}"
    if done.returncode != 0:
        return f"diff stat unavailable: {done.stderr.strip() or 'git exited ' + str(done.returncode)}"
    return done.stdout.strip() or "diff stat unavailable: empty diff"


def render_evidence(root, hid, repo=None):
    """Markdown bundle for a reviewer, or None when the handoff does not exist."""
    report = run_checks(Path(root))
    h = report.info["ho"].get(hid)
    if h is None:
        return None
    repo = repo or detect_repo(root)
    gh, sha, parent, branch = f"https://github.com/{repo}", h["commit"], h["parent"], h["branch"]
    docs = f"{gh}/blob/{branch}/{COORD}"
    links = [("Commit", f"{gh}/commit/{sha}"), ("Compare", f"{gh}/compare/{parent}...{sha}"),
             ("Diff", f"{gh}/commit/{sha}.diff"), ("Checks", f"{gh}/commit/{sha}/checks"),
             ("Handoff", f"{docs}/handoffs/{hid}.md"), ("Review template", f"{docs}/REVIEW-TEMPLATE.md"),
             ("Protocol", f"{docs}/AI-COORDINATION-PROTOCOL.md")]
    findings = open_findings(report.info["rv"], [h["responds"]]) if h["responds"] else []
    handoff_text = read_text(Path(root) / h["rel"]).rstrip("\n")
    return "\n".join(
        [f"# Evidence pack for {hid}", "", "## Handoff (verbatim)", "", "~~~~markdown", handoff_text,
         "~~~~", "", "## Links", ""] + table(["What", "URL"], links)
        + ["## Diff stat", "", "```", diff_stat(root, parent, sha), "```", "",
           f"## Open findings from {h['responds'] or 'the review this handoff responds to'}", ""]
        + table(["ID", "Severity", "Status", "Finding"], findings)) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=".", help="repository root (default: cwd)")
    parser.add_argument("--summary", help="append a Markdown report to this file")
    parser.add_argument("--write-dashboard", action="store_true", help="regenerate DASHBOARD.md")
    parser.add_argument("--evidence", metavar="HO-NNNN", help="print a reviewer evidence pack")
    parser.add_argument("--verify-commits", action="store_true",
                        help="check recorded commits exist in git")
    parser.add_argument("--append-only-since", metavar="REF",
                        help="flag deleted/renamed records and removed lines since REF")
    parser.add_argument("--repo", help="GitHub owner/name used for evidence links")
    args = parser.parse_args(argv)
    root = Path(args.root)
    if args.evidence:
        text = render_evidence(root, args.evidence, args.repo)
        if text is None:
            print(f"ERROR: {args.evidence} does not exist", file=sys.stderr)
            return 2
        print(text, end="")
        return 0
    opts = {"verify_commits": args.verify_commits, "since": args.append_only_since}
    report = run_checks(root, **opts)
    if args.write_dashboard:
        (root / COORD / DASHBOARD).write_text(render_dashboard(report.info), encoding="utf-8")
        report = run_checks(root, **opts)
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
