/// Line protocol between the kill-test parent and `child_main.dart` (WP 8
/// 3b-6, WS5). The child writes one line per event to stdout and flushes it
/// before it continues, so a line the parent has read describes a state the
/// child really reached.
///
/// Child arguments:
/// - `--migration <name>`: a key of `migrationsUnderTest`;
/// - `--db <path>`: the database file (a copy; never a fixture);
/// - `--stop-at <from>:<stage>` (optional): at that checkpoint write
///   [readyPrefix] and block until killed;
/// - `--target <n>` (optional): stop the chain at version n;
/// - `--foreground` (optional): open with `NativeDatabase` in the calling
///   isolate instead of the app engine's background isolate;
/// - `--spill` (optional): a 10-page cache and, at the stop checkpoint
///   inside the transaction, enough scratch rows to force dirty pages into
///   the database file (a hot journal; see `child_main.dart`);
/// - `--max-block-seconds <n>` (optional, default 300): a blocked child
///   exits by itself after n seconds, so a crashed parent leaves no process
///   behind.
library;

/// `PID <pid> sqlite=<version> mode=<background|foreground>`: first line.
const pidPrefix = 'PID';

/// `MIGRATING <migration> <db path>`: written just before the open that
/// runs the migration (the timing origin of the random kills).
const migratingPrefix = 'MIGRATING';

/// `CP <from>:<stage> uv=<user_version or ?>`: every checkpoint passed.
const checkpointPrefix = 'CP';

/// `READY <from>:<stage> pid=<pid>`: blocked at the `--stop-at` checkpoint.
const readyPrefix = 'READY';

/// `SPILLED <from>:<stage>`: `--spill` wrote its scratch rows.
const spilledPrefix = 'SPILLED';

/// `DONE uv=<user_version> ms=<duration>`: the migration completed.
const donePrefix = 'DONE';

/// `ERROR <message>`: the migration failed (exit code [errorExitCode]).
const errorPrefix = 'ERROR';

/// Exit codes of the child.
const doneExitCode = 0;
const errorExitCode = 1;
const usageExitCode = 2;

/// A blocked child that was never killed exits with this code.
const blockTimeoutExitCode = 3;
