# Programme status

Author: Claude Code. Updated: 2026-11-05. Mirrors D06 (`docs/wp0/D06-work-package-roadmap.md`), which stays authoritative on scope and sequencing. Dependencies are D06's; `(soft)` marks a soft dependency. Three independent axes: Implementation (`NOT_STARTED`, `IN_PROGRESS`, `DELIVERED`), Review (`NONE`, `LEGACY` = reviewed inside the delivery record before this protocol, or a handoff status), Acceptance (`NOT_ACCEPTED`, `CONDITIONALLY_ACCEPTED`, `ACCEPTED`, `CLOSED`). Delivered is not approved; approved is not accepted. The checker validates this table and computes eligibility; `DASHBOARD.md` is generated from it.

| WP | Title | Depends on | Implementation | Review | Acceptance | Open items | Latest handoff |
|---|---|---|---|---|---|---|---|
| WP 0 | Project recovery and technical baseline | none | DELIVERED | LEGACY | CLOSED | | none |
| WP 1 | Cross-platform framework and architecture foundation | WP 0 | DELIVERED | LEGACY | CLOSED | | none |
| WP 2 | Application foundation and design system | WP 1 | DELIVERED | LEGACY | ACCEPTED | TalkBack/VoiceOver device pass and Stage 2 glyph exports tracked (D06) | none |
| WP 3 | Domain models and local persistence | WP 2 | DELIVERED | LEGACY | ACCEPTED | TD-22..26 tracked with resolution packages | none |
| WP 4 | Navigation, dashboard and application shell | WP 3 | DELIVERED | LEGACY | ACCEPTED | TD-27..31 tracked | none |
| WP 5 | Nutrition and food database | WP 4 | DELIVERED | LEGACY | ACCEPTED | D05 V-01 airplane-mode device verification (owner) due at WP 6 acceptance | none |
| WP 6 | Barcode scanning and food logging | WP 5 | DELIVERED | LEGACY | CONDITIONALLY_ACCEPTED | Owner device checklist (Android; iOS or approved deviation); D05 V-01; TD-34 EAN-8/UPC-E on real products; TD-36 "Scan again" variant | none |
| WP 7 | Recipe management and meal planning | WP 5 | DELIVERED | LEGACY | CLOSED | Accepted and closed 2026-11-05 at 7c62e9c (DL-0007); TD-40 open as debt | none |
| WP 8 | Exercise library and training architecture | WP 4 | DELIVERED | AWAITING_REVIEW | NOT_ACCEPTED | Delivered at b1ab45a (record 18c4c91); owner decisions 1–5 queued (DL-0008) | HO-0003 |
| WP 9 | Workout planning and workout execution | WP 8 | NOT_STARTED | NONE | NOT_ACCEPTED | | none |
| WP 10 | Body composition and measurement tracking | WP 4 | NOT_STARTED | NONE | NOT_ACCEPTED | TD-22 resolved here before any restore action is exposed | none |
| WP 11 | Analytics and progress visualisation | WP 5, WP 9, WP 10 | NOT_STARTED | NONE | NOT_ACCEPTED | NUT-019 day-total badge allocated here (owner 2026-11-04) | none |
| WP 12 | User accounts, backup and synchronisation (optional) | WP 3 | NOT_STARTED | NONE | NOT_ACCEPTED | TD-21 iOS iCloud exclusion shim | none |
| WP 13 | Health platform integrations | WP 10, WP 9 | NOT_STARTED | NONE | NOT_ACCEPTED | | none |
| WP 14 | Quality assurance and release engineering (continuous) | WP 1 (soft) | IN_PROGRESS | NONE | NOT_ACCEPTED | Continuous from WP 1 (D06); signed release process not started | none |
| WP 15 | Nutrition entry units and serving sizes | WP 5, WP 7 | NOT_STARTED | NONE | NOT_ACCEPTED | Scope wording per owner brief 2026-11-04 pending DL-0005 | none |
| GOV 1 | AI coordination infrastructure | none | DELIVERED | AWAITING_REVIEW | NOT_ACCEPTED | RV-0001 REVIEW_INCOMPLETE on HO-0001; re-review requested on HO-0002; DL-0001..0003, DL-0005 | HO-0002 |

Notes:
- WP 0 and WP 1 closed with the merge of pull request #1 to `main` (30e51b0). WP 2–7 are accepted on the development branch; merge to `main` not authorised.
- Eligibility (protocol §7): hard dependencies accepted (conditionally or fully) or technically approved. WP 10 (depends on WP 4) and WP 12 (optional, depends on WP 3) are eligible now; WP 9 becomes eligible when WP 8 is technically approved or accepted; WP 15 depends on WP 5 and WP 7 (both accepted) and is eligible once DL-0005 fixes its scope wording.
- Order of work (protocol §7): corrections owed → closure conditions Claude Code can perform (none open) → lowest eligible package; the choice between WP 10 now and WP 9 after the WP 8 review is queued as DL-0009.
