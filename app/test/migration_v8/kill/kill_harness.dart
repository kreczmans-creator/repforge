import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../recovery/recovery_tools.dart' show ws5TempPrefix;
import 'child_protocol.dart';

/// Parent side of the real process-kill tests (WP 8 3b-6, WS5): builds the
/// child (`child_main.dart`) once, starts it as a separate OS process, waits
/// for its protocol lines and terminates it with SIGKILL.
///
/// How the child is built (checked on Linux, Dart 3.13.7, sqlite3 3.8.0):
/// - `dart build cli` (default): AOT executable plus the sqlite3 build
///   hook's `libsqlite3.so` in `bundle/lib`. Starts in milliseconds.
/// - `dart run` (fallback, `REPFORGE_KILL_CHILD=dart-run`): JIT; the build
///   hook runs too. About 4 s per start.
/// - `dart compile exe` does NOT work: it bundles no native assets, so the
///   executable fails with `Couldn't resolve native function
///   'sqlite3_libversion'`.
/// The child reports its own pid in `PID` and `READY`; the tests check it
/// equals the pid they kill, so a launcher that forks cannot go unnoticed.
final class KillChildBinary {
  KillChildBinary._(this.command, this.mode, this._buildDir, this.workDir);

  /// Executable and leading arguments.
  final List<String> command;

  /// `build-cli` or `dart-run`.
  final String mode;

  /// Directory the child runs in (`app/`).
  final String workDir;
  final Directory? _buildDir;

  static const childSource = 'test/migration_v8/kill/child_main.dart';

  /// The `dart` executable: `REPFORGE_DART`, else `$FLUTTER_ROOT/bin/dart`,
  /// else `dart` on the PATH.
  static String dartExecutable() {
    final env = Platform.environment;
    if (env['REPFORGE_DART'] case final String d when d.isNotEmpty) return d;
    if (env['FLUTTER_ROOT'] case final String root when root.isNotEmpty) {
      final d = File('$root/bin/dart');
      if (d.existsSync()) return d.path;
    }
    return 'dart';
  }

  /// Builds (or prepares) the child. Run from `app/` (the test's working
  /// directory).
  static Future<KillChildBinary> prepare() async {
    final workDir = Directory.current.path;
    final dart = dartExecutable();
    if (Platform.environment['REPFORGE_KILL_CHILD'] == 'dart-run') {
      return KillChildBinary._(
        [dart, 'run', childSource],
        'dart-run',
        null,
        workDir,
      );
    }
    final dir = Directory.systemTemp.createTempSync('${ws5TempPrefix}child_');
    final result = await Process.run(dart, [
      'build',
      'cli',
      '-t',
      childSource,
      '-o',
      dir.path,
    ], workingDirectory: workDir);
    final exe = File('${dir.path}/bundle/bin/child_main');
    if (result.exitCode != 0 || !exe.existsSync()) {
      dir.deleteSync(recursive: true);
      throw StateError(
        'dart build cli failed (${result.exitCode}):\n'
        '${result.stdout}\n${result.stderr}',
      );
    }
    return KillChildBinary._([exe.path], 'build-cli', dir, workDir);
  }

  /// Starts a child.
  Future<KillChild> start(List<String> args) async {
    final p = await Process.start(command.first, [
      ...command.skip(1),
      ...args,
    ], workingDirectory: workDir);
    return KillChild._(p);
  }

  /// Deletes the built child.
  void dispose() {
    final d = _buildDir;
    if (d != null && d.existsSync()) d.deleteSync(recursive: true);
  }
}

/// A running child process and its protocol lines.
final class KillChild {
  KillChild._(this.process) {
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onLine);
    process.stderr
        .transform(utf8.decoder)
        .listen(_stderr.write, onError: (_) {});
    unawaited(process.exitCode.then((c) => _exit = c));
  }

  final Process process;
  final List<String> lines = [];
  final StringBuffer _stderr = StringBuffer();
  final List<(String, Completer<String>)> _waiters = [];
  int? _exit;

  int get pid => process.pid;
  String get stderrText => _stderr.toString();

  void _onLine(String line) {
    lines.add(line);
    for (final w in [..._waiters]) {
      if (line.startsWith(w.$1)) {
        _waiters.remove(w);
        w.$2.complete(line);
      }
    }
  }

  /// The first line starting with [prefix] (already read or still to
  /// come). Fails if the child exits first or after [timeout].
  Future<String> waitFor(
    String prefix, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    for (final l in lines) {
      if (l.startsWith(prefix)) return l;
    }
    final c = Completer<String>();
    _waiters.add((prefix, c));
    final exited = process.exitCode.then<String>((code) async {
      // Let the last stdout lines arrive before deciding.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      for (final l in lines) {
        if (l.startsWith(prefix)) return l;
      }
      throw StateError(
        'child exited ($code) before "$prefix"; lines: $lines; '
        'stderr: $stderrText',
      );
    });
    return await Future.any([c.future, exited]).timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'no "$prefix" from the child within $timeout; lines: $lines',
      ),
    );
  }

  /// The checkpoint ids the child reported (`CP <id> ...`).
  List<String> get checkpoints => [
    for (final l in lines)
      if (l.startsWith('$checkpointPrefix ')) l.split(' ')[1],
  ];

  /// Sends SIGKILL to this child (only this pid) and returns its exit code.
  /// `killed` comes from the exit code, not from the send: a child that had
  /// just exited by itself (not yet reaped) may still accept the signal.
  Future<({bool killed, int exitCode})> sigkill() async {
    if (_exit == null) Process.killPid(pid, ProcessSignal.sigkill);
    final code = await process.exitCode;
    return (killed: code == sigkillExitCode, exitCode: code);
  }

  /// Kills the child if it still runs (test tear-down; only this pid).
  Future<void> ensureDead() async {
    if (_exit == null) {
      Process.killPid(pid, ProcessSignal.sigkill);
      await process.exitCode;
    }
  }
}

/// The exit code `Process.exitCode` reports for a child ended by SIGKILL.
final int sigkillExitCode = -ProcessSignal.sigkill.signalNumber;
