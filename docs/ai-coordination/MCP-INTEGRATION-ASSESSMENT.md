# Future option: direct model-to-model communication through MCP

Status: Assessment only. Nothing in this document is built or deployed. The GitHub-file protocol works without it. The owner's revised brief (2026-11-04 §2) excludes OpenAI API review, Anthropic API orchestration, paid orchestration services, a custom always-on model-to-model server and unnecessary MCP infrastructure; options C and D below are therefore recorded as **excluded**, and option B is the only future candidate.
Date: 2026-11-04
Author: Claude Code (research by two subagents; sources listed; unconfirmed items marked)

## 1. What "direct" would mean

Today ChatGPT reaches the repository through its read-only GitHub connector or through the owner's paste, and writes only through the owner's commit. A direct integration would let ChatGPT read the handoff and commit the review file itself, and let Claude Code read it in the next session without anyone relaying. The repository stays the single record in every option below; MCP only removes the relay step.

## 2. Claude Code side (confirmed from code.claude.com docs, 2026-11-04)

- Claude Code is an MCP client. Project-scoped servers are declared in `.mcp.json` at the repo root; cloud sessions load it for single-repository sessions. Interactive sessions prompt for approval of project servers; `claude -p` and cloud sessions load them without a prompt. (`https://code.claude.com/docs/en/mcp.md`)
- Claude Code already connects to GitHub's hosted MCP server (`https://api.githubcopilot.com/mcp/`) with a fine-grained personal access token or OAuth. This session has such a server configured by the platform; nothing is stored in the repository.
- Claude Code can also run as an MCP server (`claude mcp serve`, stdio). That exposes Claude Code's tools to another client on the same machine; it is not a hosted endpoint ChatGPT could call. (Confirmed only through the docs search summary.)
- Remote HTTP servers with OAuth need an interactive login once; headless runs cannot complete the OAuth flow.

Conclusion: on the Claude side nothing new is needed. Claude Code reads the repository, including reviews ChatGPT commits, through git.

## 3. ChatGPT side (largely unconfirmed; official OpenAI pages were unreachable from the build container)

| Question | What the sources say | Confidence |
|---|---|---|
| Can ChatGPT use custom MCP servers? | Yes, through "custom connectors"; full tool access (read and write) requires **Developer mode** (beta), with write actions needing confirmation by default. | Medium (developer-mode guide seen only in search snippets) |
| Which plans? | Conflicting third-party lists: Business/Enterprise/Edu per an OpenAI developer post (2025); Plus/Pro also listed by some vendors. Free: not found. | **Unconfirmed** — owner to check Settings → Connectors on the owner's plan |
| Built-in GitHub connector | Read-only: search, read and cite code and pull requests; no commits, files or comments. | Medium (third-party sources) |
| GitHub hosted MCP server as a ChatGPT custom connector | An issue on `github/github-mcp-server` (#1081) reported OAuth discovery failing in ChatGPT; a workaround uses the owner's own GitHub OAuth App. Whether fixed now: unknown. | **Unconfirmed** |
| Toolsets reachable | If connected, the GitHub MCP server offers repository file create/update, issue and pull-request tools (the same server this session uses). | High for the server; unconfirmed for ChatGPT |
| OpenAI Responses API with remote MCP tool | Supported: `server_url`, `headers` for auth, per-call approval control. Needs an OpenAI API key and API billing, separate from a ChatGPT subscription. Cost beyond tokens: not found. | Medium (cookbook and guide seen in snippets) |
| Admin approval, data residency, region limits, tool-count limits | Not found. | **Unconfirmed** |

Sources (as retrieved 2026-11-04; dates mostly not visible): OpenAI developer-mode guide (`developers.openai.com/api/docs/guides/developer-mode`); OpenAI MCP tools guide (`developers.openai.com/api/docs/guides/tools-connectors-mcp`); OpenAI cookbook MCP tool guide; `github/github-mcp-server` README and issue #1081; third-party posts by Docker, Zuplo and others. The owner should confirm the plan facts in the ChatGPT help centre before relying on any of them.

## 4. Candidate architectures

| Option | How it works | What the owner must provide | Auditability | Cost and complexity |
|---|---|---|---|---|
| **A. Status quo (this protocol)** | Owner points ChatGPT at the handoff; owner commits the review file. | Nothing new. | Every record is a commit by the owner's account. | None. Two owner actions per cycle. |
| **B. ChatGPT custom connector → GitHub MCP server** | In Developer mode, ChatGPT connects to `api.githubcopilot.com/mcp/` (or the owner's OAuth App) and commits `reviews/RV-NNNN.md` itself. | A ChatGPT plan with Developer mode; a GitHub fine-grained token or OAuth App scoped to this repository, **contents: write on the working branch only** (branch protection keeps `main` closed); the owner's confirmation click on each write. | Commits appear under the token's identity. Use a dedicated GitHub account or app so ChatGPT's commits are distinguishable from the owner's. | No infrastructure. Risk: prompt injection through repository content with write tools enabled; mitigate with the narrowest token and manual confirmation of writes. |
| **C. Scheduled reviewer job (OpenAI API)** — excluded by owner brief §2 | A GitHub Actions workflow calls the OpenAI Responses API with the GitHub MCP tool whenever a new `HO-NNNN.md` lands, and opens a pull request with `RV-NNNN.md`. | An OpenAI API key and billing; a GitHub token; both as GitHub secrets (needs owner approval under protocol §8). | Fully logged in Actions; reviews arrive as pull requests the owner can inspect. | Paid API usage per review; code to maintain; the review model is not the owner's ChatGPT conversation, so context is lost unless the prompt rebuilds it. |
| **D. Claude Code as MCP server exposed to ChatGPT** — excluded by owner brief §2 | Tunnel `claude mcp serve` to the internet. | A host, a tunnel, authentication in front of a stdio server. | Weak; not designed for it. | Not recommended. |

## 5. Recommendation

Keep option A now. Trial option B when the owner confirms the plan supports Developer mode, with these conditions recorded as an owner decision first: a dedicated token scoped to one repository and the working branch, write confirmation left on, the first three reviews committed by B compared against the owner's own reading, and the result recorded in `DECISION-LOG.md`. Only after that may `CURRENT-STATE.md` describe the protocol as bidirectional. Option C is excluded by the owner's brief; if B is unavailable the evidence pack (`check_coordination.py --evidence`) keeps the owner's effort to one paste per review.

## 6. Message routing in options B and C

Unchanged from the file protocol: handoffs in `handoffs/`, reviews in `reviews/`, index entries in `INBOX.md`/`OUTBOX.md`, decisions in `DECISION-LOG.md`. ChatGPT writes only `reviews/RV-NNNN.md`, the `Status` lines of `OUTBOX.md` messages and index entries in `INBOX.md`. Claude Code and the owner write everything else. The checker (`tools/coordination/check_coordination.py`) validates whatever arrives, whoever wrote it.
