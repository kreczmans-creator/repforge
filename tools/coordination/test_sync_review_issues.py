import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sync_review_issues as S  # noqa: E402

REPO = "o/r"
SERVER = "https://github.com"
SHA = "a" * 40


class FakeApi:
    def __init__(self, issues=None):
        self.issues = issues or []
        self.calls = []

    def get(self, path):
        self.calls.append(("GET", path, None))
        page = int(path.rsplit("page=", 1)[1])
        return self.issues[(page - 1) * 100: page * 100]

    def post(self, path, data):
        self.calls.append(("POST", path, data))
        return {"number": 7}

    def patch(self, path, data):
        self.calls.append(("PATCH", path, data))
        return {}

    def writes(self):
        return [c for c in self.calls if c[0] != "GET"]


def make_root(status="AWAITING_REVIEW", review="none", supersedes="none", extra_ho=None):
    d = Path(tempfile.mkdtemp())
    (d / S.HANDOFFS).mkdir(parents=True)
    (d / S.REVIEWS).mkdir(parents=True)
    (d / S.HANDOFFS / "HO-0001.md").write_text(
        f"# HO-0001 — Thing\n\n- Status: {status}\n- Work package: WP 1\n- Branch: `b1`\n"
        f"- Commit: `{SHA}`\n- Parent: `{'b' * 40}`\n- Review: {review}\n"
        f"- Supersedes: {supersedes}\n\n## 1. x\n- Status: ignored\n", encoding="utf-8")
    if review != "none":
        (d / S.REVIEWS / "RV-0002.md").write_text(
            "# RV-0002\n\n- Outcome: CHANGES_REQUIRED\n- Commit reviewed: " + SHA +
            "\n- Date: 2026-01-02\n", encoding="utf-8")
    return d


def run(api, root, **kw):
    out = []
    rc = S.sync(api, root, REPO, SERVER, "main", out=out.append, **kw)
    return rc, out


def issue(root, number=3, state="open", **over):
    """Issue whose body matches the current root state."""
    reviews = S.load_reviews(root)
    h = S.load_handoffs(root, reviews)[0]
    d = {"number": number, "state": state, "title": "[AI review] HO-0001 — Thing",
         "body": S.build_body(h, REPO, SERVER, "main")}
    d.update(over)
    return d


class SyncTests(unittest.TestCase):
    def test_creates_issue(self):
        api = FakeApi()
        rc, out = run(api, make_root())
        self.assertEqual(rc, 0)
        posts = [c for c in api.writes() if c[1] == f"/repos/{REPO}/issues"]
        self.assertEqual(len(posts), 1)
        data = posts[0][2]
        self.assertEqual(data["title"], "[AI review] HO-0001 — Thing")
        self.assertEqual(data["labels"], ["ai-review"])
        self.assertTrue(data["body"].startswith(
            f"<!-- coordination: HO-0001 status=AWAITING_REVIEW reviews=none commit={SHA} -->"))
        self.assertIn("created #7 for HO-0001", out)
        self.assertEqual(api.writes()[0][1], f"/repos/{REPO}/labels")

    def test_label_exists_ok(self):
        class Api(FakeApi):
            def post(self, path, data):
                if path.endswith("/labels"):
                    raise S.ApiError(422, 'Validation Failed [{"code": "already_exists"}]')
                return super().post(path, data)
        rc, _ = run(Api(), make_root())
        self.assertEqual(rc, 0)

    def test_no_issue_for_superseded(self):
        api = FakeApi()
        run(api, make_root("SUPERSEDED"))
        self.assertFalse([c for c in api.writes() if c[1].endswith("/issues")])

    def test_unchanged(self):
        root = make_root()
        api = FakeApi([issue(root)])
        _, out = run(api, root)
        self.assertEqual(out, ["unchanged #3"])
        self.assertEqual([c[1] for c in api.writes()], [f"/repos/{REPO}/labels"])

    def test_status_change_updates_and_comments(self):
        old_root = make_root("AWAITING_REVIEW")
        iss = issue(old_root)
        new_root = make_root("CHANGES_REQUIRED", review="RV-0002")
        api = FakeApi([iss])
        run(api, new_root)
        w = {(c[0], c[1]): c[2] for c in api.writes()}
        self.assertIn("status=CHANGES_REQUIRED reviews=RV-0002", w[("PATCH", f"/repos/{REPO}/issues/3")]["body"])
        comment = w[("POST", f"/repos/{REPO}/issues/3/comments")]["body"]
        self.assertIn("Status changed: AWAITING_REVIEW → CHANGES_REQUIRED", comment)
        self.assertIn("Review on file: RV-0002 (CHANGES_REQUIRED) for commit aaaaaaa", comment)

    def test_close_states(self):
        for status, reason in (("SUPERSEDED", "not_planned"), ("ACCEPTED_BY_OWNER", "completed")):
            iss = issue(make_root())
            api = FakeApi([iss])
            run(api, make_root(status))
            closes = [c for c in api.writes() if c[0] == "PATCH" and c[2].get("state") == "closed"]
            self.assertEqual(len(closes), 1)
            self.assertEqual(closes[0][2]["state_reason"], reason)

    def test_superseded_comment(self):
        root = make_root("SUPERSEDED")
        (root / S.HANDOFFS / "HO-0002.md").write_text(
            f"# HO-0002 — New\n\n- Status: AWAITING_REVIEW\n- Branch: `b`\n- Commit: `{SHA}`\n"
            "- Review: none\n- Supersedes: HO-0001\n", encoding="utf-8")
        api = FakeApi([issue(make_root())])
        run(api, root)
        comments = [c[2]["body"] for c in api.writes() if c[1].endswith("/comments")]
        self.assertTrue(any("Superseded by HO-0002" in c for c in comments))

    def test_reopen(self):
        old = make_root("ACCEPTED_BY_OWNER")
        api = FakeApi([issue(old, state="closed")])
        run(api, make_root("CHANGES_REQUIRED"))
        self.assertTrue(any(c[0] == "PATCH" and c[2] == {"state": "open"} for c in api.writes()))

    def test_closed_matching_superseded_not_reopened(self):
        root = make_root("SUPERSEDED")
        api = FakeApi([issue(root, state="closed")])
        _, out = run(api, root)
        self.assertEqual(out, ["unchanged #3"])

    def test_pagination_and_pr_ignored(self):
        root = make_root()
        filler = [{"number": 100 + i, "state": "open", "title": f"other {i}", "body": ""}
                  for i in range(100)]
        pr = {"number": 999, "state": "open", "title": "[AI review] HO-0001 — Thing",
              "body": "", "pull_request": {}}
        real = issue(root, number=205)
        api = FakeApi(filler + [pr, real])
        _, out = run(api, root)
        gets = [c for c in api.calls if c[0] == "GET"]
        self.assertEqual(len(gets), 2)
        self.assertEqual(out, ["unchanged #205"])

    def test_dry_run_no_writes(self):
        api = FakeApi()
        rc, out = run(api, make_root(), dry_run=True)
        self.assertEqual(rc, 0)
        self.assertEqual(api.writes(), [])
        self.assertTrue(any("create issue for HO-0001" in l for l in out))

    def test_offline_dry_run_no_calls(self):
        api = FakeApi()
        run(api, make_root(), dry_run=True, offline=True)
        self.assertEqual(api.calls, [])

    def test_no_handoffs(self):
        d = Path(tempfile.mkdtemp())
        _, out = run(FakeApi(), d)
        self.assertEqual(out, ["no handoffs"])

    def test_footer_everywhere(self):
        api = FakeApi([issue(make_root())])
        run(api, make_root("CHANGES_REQUIRED", review="RV-0002"))
        api2 = FakeApi()
        run(api2, make_root())
        texts = [c[2]["body"] for c in api.writes() + api2.writes()
                 if c[2] and "body" in c[2]]
        self.assertGreaterEqual(len(texts), 3)
        for t in texts:
            self.assertTrue(t.endswith("\n\n---\n_Generated by [Claude Code](https://claude.ai/code)_"))

    def test_body_links(self):
        h = S.load_handoffs(make_root(review="RV-0002"), {})[0]
        body = S.build_body(h, REPO, SERVER, "main")
        self.assertIn(f"{SERVER}/{REPO}/compare/{'b' * 40}...{SHA}", body)
        self.assertIn(f"{SERVER}/{REPO}/blob/b1/docs/ai-coordination/handoffs/HO-0001.md", body)


if __name__ == "__main__":
    unittest.main()
