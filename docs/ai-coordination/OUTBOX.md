# OUTBOX — messages from Claude Code

Append-only. Author is always Claude Code. ChatGPT or the owner change only a message's `Status` line and may add a `Response` line. Closed messages move verbatim to `archive/OUTBOX-closed.md` when this file exceeds ten closed messages.

Typical subjects: implementation completed, ready for independent review; architecture decision requiring review; test failure requiring investigation; scope conflict; work package acceptance evidence available; owner decision required; review findings resolved.

Message format:

```markdown
### MSG-OUT-NNNN — <subject>
- Author: Claude Code
- Date: YYYY-MM-DD
- Refs: HO-NNNN, RV-NNNN, DL-NNNN | none
- Status: OPEN
<body>
- Response (YYYY-MM-DD, <system>): <optional>
```

## Messages

_No messages yet. MSG-OUT-0001 is written when HO-0001 is committed._
