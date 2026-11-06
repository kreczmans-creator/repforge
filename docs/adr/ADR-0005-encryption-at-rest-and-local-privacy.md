# ADR-0005: Encryption at rest and privacy of locally stored fitness data

- Status: Accepted (owner direction to assess explicitly in WP 3, 2026-11-01; decision recorded 2026-11-03)
- Date: 2026-11-03

## Context
RepForge stores body weight, body measurements, food intake and training history in a SQLite file on the device (ADR-0004). This is personal data. The owner asked WP 3 to assess encryption at rest and the privacy implications of local storage before any further feature work.

## What the platforms already provide
- **Android (minSdk 26):** app-private storage under the application-support directory is readable only by the app's Linux user. Devices shipping Android 10+ use file-based encryption keyed to the lock screen; on older devices full-disk encryption covers the file. Android Auto Backup copies app-private files to the user's Google account unless the app opts out.
- **iOS:** the app container is sandboxed and covered by Data Protection. The default class for files created by Flutter plugins is *Complete until first user authentication*. iCloud backups include the Application Support directory unless a file is marked excluded.

## Options considered
1. **Rely on platform encryption; opt out of cloud backup of the database file; ship explicit JSON export/import for user-controlled backup.**
2. **SQLCipher application-level encryption** via `sqlcipher_flutter_libs` (now end-of-life) or a hooks-based SQLCipher build with the `sqlite3` package, with the key in Keystore/Keychain.
3. Platform encryption plus column-level encryption of selected fields.

## Decision
Option 1 for WP 3 onward:
- The database stays unencrypted at the application level; it relies on platform file encryption and sandboxing.
- Android `allowBackup` is set to `false` so the database is never copied to Google backup without the user's knowledge. iOS: the database directory is marked excluded from iCloud backup when the native hook is added in WP 12 (not possible from Dart alone; tracked as D05 TD-21).
- Backup is user-initiated JSON export/import (DAT-003, DAT-004) via the share sheet; the file is the user's responsibility and the app says so in the export screen.
- No analytics, no network transmission of personal data; food lookup sends only the search term or barcode.

## Rationale
SQLCipher would protect against an attacker who already has the raw file from an unlocked device or a rooted/jailbroken one. For a personal fitness log that threat is marginal compared with the costs: a second native build pipeline (the maintained SQLCipher path for `sqlite3` 3.x is not yet stable), key management in secure storage, slower queries, and harder support. Platform encryption plus not leaking the file to cloud backups covers the realistic risks (lost phone, shared cloud account) for v1.

## Consequences
- Revisit before WP 12 (cloud sync): data leaving the device needs transport encryption, a privacy policy and account deletion.
- If the owner later wants application-level encryption, the drift executor is the single place to swap (`open_database.dart`), so the change is contained.
- Users on a device without a lock screen have no encryption at rest; the Settings screen will say so (WP 4).
