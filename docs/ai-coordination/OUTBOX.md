# OUTBOX — messages from Claude Code

Append-only. Author is always Claude Code. A handoff is itself the outgoing "ready for review" message, so no MSG-OUT is written for it; MSG-OUT is for everything else: a test failure needing investigation, a scope conflict, an owner decision that cannot wait for a handoff, findings resolved without a new handoff, a deferral with its reason. ChatGPT or the owner may change a message's `Status` line and add a `Response` line. Claude Code closes its own message when the record it refers to reaches a final state. Closed messages move verbatim to `archive/OUTBOX-closed.md` when this file holds more than ten closed messages.

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

_No messages yet._
