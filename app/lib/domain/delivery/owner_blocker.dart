import 'dart:convert';

import 'package:meta/meta.dart';

/// Work packages that can own a delivery blocker.
enum BlockerWorkPackage {
  wp8('WP 8', 'Exercise library and training architecture'),
  wp11('WP 11', 'Analytics and progress visualisation'),
  wp12('WP 12', 'Accounts, backup and sync backend'),
  wp13('WP 13', 'Health platform integration'),
  wp14('WP 14', 'Quality assurance and release engineering'),
  wp15('WP 15', 'Nutrition entry units'),
  wp17('WP 17', 'Fuel and Train workflow completion'),
  programme('Programme', 'Cross-package delivery and release');

  BlockerWorkPackage(this.label, this.title);

  /// Short label ("WP 8").
  final String label;

  /// Work-package title.
  final String title;
}

/// Why an item cannot be completed by the delivery agents alone.
enum BlockerCategory {
  ownerDecision('Owner decision'),
  scopeApproval('Scope approval'),
  physicalDeviceAction('Physical device action'),
  independentVerification('Independent verification'),
  ownerAcceptance('Owner acceptance'),
  technicalBlocker('Genuine technical blocker'),
  externalInfrastructure('External infrastructure dependency');

  BlockerCategory(this.label);
  final String label;
}

/// Delivery priority, highest first.
enum BlockerPriority {
  high('High'),
  medium('Medium'),
  low('Low');

  BlockerPriority(this.label);
  final String label;
}

/// Lifecycle of a blocker. Only [resolved] closes it; a resolved blocker
/// stays in the register so the audit trail is complete.
enum BlockerStatus {
  open('Open'),
  inProgress('In progress'),
  awaitingOwner('Awaiting owner'),
  awaitingExternalVerification('Awaiting external verification'),
  resolved('Resolved');

  BlockerStatus(this.label);
  final String label;

  bool get isOpen => this != resolved;
}

/// Who must act next.
enum BlockerAssignee {
  owner('Owner action'),
  agent('Agent-owned');

  BlockerAssignee(this.label);
  final String label;
}

/// One reference that supports a blocker: a commit, test run, review,
/// CI run, record or specification section.
@immutable
final class BlockerEvidence {
  const BlockerEvidence(this.label, {this.reference});

  /// What the evidence is ("Delivery record", "CI run").
  final String label;

  /// Where to find it: a path, SHA, run id or section ("D04 §7").
  final String? reference;

  @override
  bool operator ==(Object other) =>
      other is BlockerEvidence &&
      other.label == label &&
      other.reference == reference;

  @override
  int get hashCode => Object.hash(label, reference);
}

/// One owner action or genuine delivery blocker, as recorded in the
/// canonical register (`ownerBlockerRegister`). Immutable; the lifecycle
/// state that the owner changes in the app lives in [BlockerState].
@immutable
final class OwnerBlocker {
  const OwnerBlocker({
    required this.id,
    required this.workPackage,
    required this.stage,
    required this.reference,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.initialStatus,
    required this.assignee,
    required this.whyBlocked,
    required this.actionRequired,
    required this.recommendation,
    required this.consequences,
    required this.evidence,
    required this.deliveryRecord,
    this.dependencies = const [],
  });

  /// Unique, stable id ("OB-WP15-01"). Never reused.
  final String id;
  final BlockerWorkPackage workPackage;

  /// Stage or sub-stage within the work package ("3b-9", "S4d").
  final String stage;

  /// Requirement or decision reference ("OQ-02", "D-4", "R-30 / B-07").
  final String reference;

  /// One line.
  final String title;
  final String description;
  final BlockerCategory category;
  final BlockerPriority priority;

  /// Status recorded in the delivery records at the time of the register.
  /// The persisted [BlockerState] overrides it once the owner changes it.
  final BlockerStatus initialStatus;
  final BlockerAssignee assignee;
  final String whyBlocked;
  final String actionRequired;

  /// Recommended owner response.
  final String recommendation;

  /// Consequences of the alternatives, including deferral.
  final String consequences;

  /// Other blocker ids or external items this one waits for.
  final List<String> dependencies;
  final List<BlockerEvidence> evidence;

  /// Path of the related delivery record.
  final String deliveryRecord;

  /// Whether the owner must act (as opposed to an agent).
  bool get isOwnerAction => assignee == BlockerAssignee.owner;
}

/// One recorded lifecycle change: the status set, when, and the note given.
@immutable
final class BlockerChange {
  const BlockerChange({required this.status, required this.at, this.note});

  final BlockerStatus status;

  /// When the change was recorded (UTC).
  final DateTime at;

  /// Optional owner note recorded with the change.
  final String? note;

  Map<String, Object?> toJson() => {
    'status': status.name,
    'at': at.toUtc().toIso8601String(),
    if (note != null) 'note': note,
  };

  /// Null for a malformed entry. Every field is type-checked, so a foreign
  /// or hand-edited value never throws.
  static BlockerChange? fromJson(Object? json, {String atKey = 'at'}) {
    if (json is! Map) return null;
    final status = BlockerStatus.values.asNameMap()[json['status']];
    final rawAt = json[atKey];
    final at = rawAt is String ? DateTime.tryParse(rawAt) : null;
    if (status == null || at == null) return null;
    final note = json['note'];
    return BlockerChange(
      status: status,
      at: at.toUtc(),
      note: note is String && note.trim().isNotEmpty ? note : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BlockerChange &&
      other.status == status &&
      other.at == at &&
      other.note == note;

  @override
  int get hashCode => Object.hash(status, at, note);
}

/// The owner's persisted lifecycle state for one blocker: the current
/// change and every earlier one, oldest first, so a resolved entry keeps
/// its resolution note and time even after it is reopened.
@immutable
final class BlockerState {
  const BlockerState({
    required this.status,
    required this.updatedAt,
    this.note,
    this.history = const [],
  });

  /// A state whose history is [earlier] followed by the new change.
  factory BlockerState.after(BlockerState? earlier, BlockerChange change) =>
      BlockerState(
        status: change.status,
        updatedAt: change.at,
        note: change.note,
        history: [
          if (earlier != null) ...earlier.history,
          if (earlier != null) earlier.current,
        ],
      );

  final BlockerStatus status;

  /// When the status was last changed (UTC).
  final DateTime updatedAt;

  /// Optional owner note recorded with the change.
  final String? note;

  /// Earlier changes, oldest first; empty for the first change.
  final List<BlockerChange> history;

  /// The current change as a [BlockerChange].
  BlockerChange get current =>
      BlockerChange(status: status, at: updatedAt, note: note);

  /// Every change including the current one, oldest first.
  List<BlockerChange> get allChanges => [...history, current];

  Map<String, Object?> toJson() => {
    'status': status.name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (note != null) 'note': note,
    if (history.isNotEmpty) 'history': [for (final h in history) h.toJson()],
  };

  /// Returns null for a malformed entry so one bad row never hides the
  /// others. A malformed history item is dropped; the current change is
  /// kept.
  static BlockerState? fromJson(Object? json) {
    final current = BlockerChange.fromJson(json, atKey: 'updatedAt');
    if (current == null) return null;
    final rawHistory = (json! as Map)['history'];
    return BlockerState(
      status: current.status,
      updatedAt: current.at,
      note: current.note,
      history: [
        if (rawHistory is List)
          for (final h in rawHistory) ?BlockerChange.fromJson(h),
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BlockerState &&
      other.status == status &&
      other.updatedAt == updatedAt &&
      other.note == note &&
      _sameHistory(other.history);

  bool _sameHistory(List<BlockerChange> other) {
    if (other.length != history.length) return false;
    for (var i = 0; i < history.length; i++) {
      if (other[i] != history[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(status, updatedAt, note, history.length);
}

/// Codec for the persisted map of blocker id to [BlockerState], stored as
/// one JSON object in the settings table. Malformed input decodes to an
/// empty map; malformed entries are dropped individually. Writers that
/// change one entry go through [merge], which keeps every other entry
/// byte-for-byte, including ones this build cannot read (for example a
/// status written by a newer build), so a save never deletes data.
abstract final class BlockerStateCodec {
  static String encode(Map<String, BlockerState> states) =>
      jsonEncode({for (final e in states.entries) e.key: e.value.toJson()});

  static Map<String, BlockerState> decode(String? raw) {
    final decoded = _object(raw);
    if (decoded == null) return const {};
    return {
      for (final e in decoded.entries)
        if (BlockerState.fromJson(e.value) case final BlockerState s) e.key: s,
    };
  }

  /// [raw] with [blockerId] set to [state] and everything else unchanged.
  /// Throws [FormatException] when [raw] is present but is not a JSON
  /// object, so the caller refuses rather than overwrites. A stored entry
  /// for [blockerId] that this build cannot read is moved aside under
  /// `<id>#unreadable-<n>` instead of being replaced, so no data is lost.
  static String merge(String? raw, String blockerId, BlockerState state) {
    if (raw != null && raw.trim().isNotEmpty && _object(raw) == null) {
      throw const FormatException('ownerBlockerStates is not a JSON object');
    }
    final map = Map<String, Object?>.of(_object(raw) ?? const {});
    final existing = map[blockerId];
    if (existing != null && BlockerState.fromJson(existing) == null) {
      var n = 1;
      while (map.containsKey('$blockerId#unreadable-$n')) {
        n++;
      }
      map['$blockerId#unreadable-$n'] = existing;
    }
    map[blockerId] = state.toJson();
    return jsonEncode(map);
  }

  static Map<String, Object?>? _object(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    return {
      for (final e in decoded.entries)
        if (e.key is String) e.key as String: e.value,
    };
  }
}

/// A register entry combined with its effective state.
@immutable
final class BlockerView {
  const BlockerView({required this.blocker, this.state});

  final OwnerBlocker blocker;

  /// The owner's persisted change, or null when the register status stands.
  final BlockerState? state;

  BlockerStatus get status => state?.status ?? blocker.initialStatus;
  bool get isOpen => status.isOpen;
  bool get isOwnerAction => blocker.isOwnerAction;
}

/// Orders by priority (high first), then open before resolved, then id.
int compareBlockerViews(BlockerView a, BlockerView b) {
  final p = a.blocker.priority.index.compareTo(b.blocker.priority.index);
  if (p != 0) return p;
  if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
  return a.blocker.id.compareTo(b.blocker.id);
}
