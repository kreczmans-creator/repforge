# Provenance and licensing requirements — proposed

- Status: **Proposed — for owner approval.** WP 8 stage 4 (documentation only).
- Requirements: LIB-011, LIB-012; owner decision 2 (OQ-09: original RepForge-authored content; compatible openly licensed datasets allowed with recorded provenance; no Bodybuilding.com content; multiple providers; commercial licensing deferred); ADR-0009.
- **This document is not legal advice.** Whether a licence is acceptable, and whether any dataset is admitted, is the owner's call, and the owner decides whether to seek legal review (section 7).

## 1. Principles
1. Catalogue content is original RepForge-authored content unless the owner admits an openly licensed dataset.
2. Every system record has a provider and a revision. Open datasets incorporated into the official catalogue are `system` content with recorded provenance and licence (OQ-21).
3. Facts are free: exercise names that are common terms, and anatomical and movement classifications as facts. Expression is not: instruction text, descriptions, images, video and the selection and arrangement of a database are protected by the rights of their authors. RepForge writes its own expression.
4. Proprietary apps, websites, books and videos are never a source. Bodybuilding.com is a breadth benchmark only: editors may compare **coverage** (which groups and movements exist) but must not copy or closely paraphrase any record, name list or text.
5. Commercial licensing is deferred, not ignored. A licence that would block later commercial distribution is not admitted.

## 2. Provider registry
Stage 3 stores providers in the provider table. This is the proposed field set; the registry file in each release carries it.

| Field | Meaning |
|---|---|
| `id` | Stable id (`repforge` for original content) |
| `name` | Display name |
| `kind` | `original` or `openDataset` |
| `licence` | SPDX identifier where one exists (`CC0-1.0`, `CC-BY-4.0`, `MIT`, `Apache-2.0`) or the licence name |
| `licenceUrl` | Link to the licence text |
| `attribution` | Exact attribution text to show where required |
| `sourceUrl` | Where the dataset was obtained |
| `sourceVersion` and `retrievedOn` | Version or commit, and date of retrieval |
| `admittedBy` and `admittedOn` | Owner approval record |
| `scope` | What is used (record types, fields, counts) |
| `modifications` | What RepForge changed (normalised names, re-tagged, rewritten text) |
| `shareAlike` | `none`, or a note on obligations (section 4) |
| `reviewStatus` | `proposed`, `approved`, `rejected`, `withdrawn` |
| `notes` | Anything the next editor must know |

Per-record provenance in a release entry: `providerId`, an optional `sourceRef` (the record id in the dataset), the author and reviewer initials, and a free note for transformations.

The 89 exercises already in the app (seed) carry provider `repforge` and the author "RepForge editorial (WP 8 seed)" in release 2, with the reviewer empty until a tranche review names one (IC-212). The owner may name a person or role instead.

## 3. Rules for original authoring
1. Write from your own knowledge of performing the movement and from standard anatomy.
2. Do not copy, translate or closely paraphrase from any website, app, book or video. Do not work with another source open beside the entry you are writing.
3. Names: use common generic terms. Do not use brand names, trademarked programme names or names coined by a single source.
4. Instructions: compose in your own words and structure, following `editorial-guide.md`.
5. Classifications are your judgement, recorded in the entry. Do not import another source's tagging wholesale.
6. At the end of each tranche the author signs an **originality statement**: "I wrote these entries myself. I did not copy them from any source." The statement is kept in the delivery record.
7. Drafting aids: if an editor uses a drafting tool, the editor remains the author, checks every entry, and the originality rule applies unchanged. The owner decides whether that use needs to be declared.
8. A reviewer who suspects copying raises it as a blocking finding. The entry is rewritten or dropped.
9. No images or video are added in WP 8 (media are deferred).

## 4. Criteria for admitting an openly licensed dataset
The owner approves each dataset before any record is used. Check, in order:

| # | Criterion | Admit when |
|---|---|---|
| 1 | Licence clear and recorded | A named licence applies to the data and text, with a link. No "free to use" statements without a licence |
| 2 | Permits copying, modification and redistribution in a mobile app | Yes |
| 3 | Permits commercial use (even though commercial licensing is deferred) | Yes. Non-commercial (NC) licences are not admitted |
| 4 | Permits derivative works | Yes. No-derivatives (ND) licences are not admitted, because every record is normalised and re-tagged |
| 5 | Attribution | Obligation is practical: RepForge can show the required text in a credits screen and in the licence register |
| 6 | Share-alike or copyleft | Default: not admitted. A share-alike licence (for example CC-BY-SA, ODbL, GPL family) can require RepForge to release adapted data under the same licence and might affect how the catalogue file is distributed. Admit only after the owner reviews the obligations (legal review recommended) |
| 7 | Clean origin | The dataset itself is not derived from proprietary content (for example scraped from a commercial site). If its origin is unclear, reject |
| 8 | Quality | A sample of at least 30 records passes the editorial guide after normalisation, and the near-duplicate check |
| 9 | Technical fit | Maps to the anatomy, pattern and equipment lists without inventing values |
| 10 | Stability | The dataset has a version or commit that can be pinned |

Permissive licences most likely to pass: CC0-1.0, CC-BY-4.0 (attribution only), MIT, Apache-2.0 (attribution and notice). Rows 5 and 6 decide the rest.

Process:
1. The editor writes a one-page dataset proposal: source, licence, scope, sample, mapping effort.
2. The owner decides (and seeks legal review if wished).
3. On approval, the provider is added to the registry, the licence register is updated, and an import branch holds the transformed records.
4. Every imported record passes the same integrity checks and independent review as an original record. Text from the dataset is treated as source material to be rewritten unless the licence allows reuse as it stands.
5. Records keep `providerId` and `sourceRef`. The attribution text appears in the app credits when stage 6 delivers them.
6. If a licence is withdrawn or an origin problem appears, the affected records are retired under `population-standards.md`, section 5.

## 5. Prohibited sources
- Bodybuilding.com content of any kind (benchmark only).
- Any proprietary app, website, book, magazine, course or video, including their exercise names lists, descriptions, images, tagging schemes and programme names.
- Content obtained by scraping, screenshots, export from an account, or reverse engineering.
- Datasets with NC, ND or unclear licences, or unclear origin.
- Personal data. Catalogue records contain no personal data.
- Medical or clinical guidance sources used as instruction text.

## 6. Licence register template
Kept in the delivery record (WP 8) and updated with each release. One row per provider.

| Provider id | Name | Kind | Licence (SPDX) | Licence URL | Attribution required | Share-alike | Source URL | Version | Retrieved | Records used | Admitted by | Admitted on | Status | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `repforge` | RepForge | original | proprietary (RepForge) | n/a | No | No | n/a | per release | n/a | all original | Owner | (date) | active | Original authored content |
| (dataset id) | | openDataset | | | | | | | | | | | proposed | |

A second table lists releases: provider id, release number, content hash, record counts, date, and the independent review reference.

## 7. Legal review
This document sets the engineering and editorial rules. It does not decide whether any licence is compatible with distribution in a mobile application, nor what share-alike obligations mean for RepForge. **Legal review is the owner's call.** The owner may seek advice before admitting a dataset, before commercial release, or before showing any third-party attribution.

## 8. Open questions for the owner
1. Is drafting assistance acceptable, with the editor as author, and does it need to be declared?
2. Are share-alike datasets out of scope entirely (the recommendation), or will the owner review case by case?
3. Where do attributions appear (a credits screen in Settings is proposed for stage 6)?
4. Is a legal review wanted before the first release that includes catalogue content from stage 5?
