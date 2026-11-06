# Register entries staged for the integration gate (S7)

**Applied 2026-11-07 at the overnight campaign integration gate** (D04 §7 entry, D06 WP 17 entry and WP 15 status line, with the R17-01 wording "recents (subset of NUT-014)"). Kept for traceability.

These texts are applied verbatim to the named register files when the parallel branch is integrated. They are not applied earlier because the primary WP 8 session edits D04, D05 and D06 several times a day and parallel edits would conflict.

## D04 §7 — new amendment entry
```
### 2026-11-06 — WP 17 created; schema sequencing (owner, parallel workstream D-1 and D-2)
- **WP 17 "Fuel and Train workflow completion" created.** WP 7 and WP 9 remain closed. WP 17 owns: NUT-014 recent items and a "pick from library" entry in the Fuel add flow; recipe duplicate and category filter; plan duplicate, plan delete, save session as plan; session elapsed time, drag reorder, rest-timer survival; and, after schema v9, plan metadata, prebuilt-plan provenance, recipe tags and image (subject to D-3 to D-6 of the parallel workstream assessment).
- **Schema**: WP 8 keeps exclusive ownership of v8. WP 17 owns v9, which starts only after v8 is connected, migrated and accepted.
- **WP 15**: stages 1–2 delivered for review (kg/l entry in the portion and ingredient sheets; spec revision 1.4 proposed). Not accepted. The custom-food serving-definition amounts are an explicit open scope item.
```

## D06 — new work package entry (after WP 16)
```
### WP 17 — Fuel and Train workflow completion (added 2026-11-06, owner decision D-1)
- Status: **Active**; record `docs/delivery-record/WP17.md`.
- Objective: close the workflow gaps left after WP 7 and WP 9 without reopening them.
- Scope: Fuel add flow "pick from library" and recent items (NUT-014); recipe duplicate and category filter; plan duplicate, delete and save-session-as-plan; session elapsed time, drag reorder, rest-timer survival; after schema v9 (WP 8 v8 accepted first): plan metadata, prebuilt workout catalogue and library UI, recipe tags and image.
- Dependencies: WP 7, WP 9 (accepted); WP 8 stage 3d for the Train code rebase; WP 8 v8 acceptance for v9.
- Acceptance: each stage's criteria in the record; no change to accepted WP 7 / WP 9 behaviour under the full regression suite; definitions and history stay separate.
```

## D06 — WP 15 status line
```
- Status: **In progress** — stages 1–2 implemented on the parallel branch (`docs/delivery-record/WP15.md`), four CI workflows green at 353fcd8; not accepted; specification revision 1.4 proposed; custom-food serving entry units open.
```

## D05 — no new debt or risk items from the parallel workstream so far
Risks R-A to R-D are in the assessment §14 and are workstream risks, not product risks; they are closed at integration.
