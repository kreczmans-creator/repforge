# ADR-0003: Git tree, not ZIP archives, is the source of truth

- Status: Proposed (owner decision required)
- Date: 2026-10-31

## Context
The repository contains two ZIP archives of the Android project and a workflow that unzips one of them at build time. No application source is tracked as files. Changes inside the archive cannot be diffed, reviewed or blamed, and the two archives differ (D01 §2).

## Options considered
1. Keep uploading ZIPs and building from them.
2. Extract the archive into the tree and keep the ZIP alongside.
3. Extract the archive into the tree (`legacy/android/`), remove both ZIPs and the ZIP-based workflow, and build only from tracked files.

## Decision
Option 3, in two steps: extraction on a feature branch (WP 0/1), removal after the new Flutter pipeline produces an installable APK (WP 1 acceptance).

## Rationale
Version control only has value when it tracks the source. Removal is deferred until the replacement pipeline works so that nothing is lost in between; git history retains the archives in any case.

## Consequences
- The legacy source is extracted verbatim, unfixed, so the record matches the upload.
- The legacy workflow is switched to manual trigger in WP 1 and deleted with the ZIPs.
- Future changes to any source arrive as commits and pull requests, never as uploaded archives.
