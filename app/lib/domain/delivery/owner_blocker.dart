import 'dart:convert';

import 'package:meta/meta.dart';

/// Work packages that can own a delivery blocker.
enum BlockerWorkPackage {
  wp8('WP 8', 'Exercise library and training architecture'),
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

/// The owner's persisted lifecycle change for one blocker.
@immutable
final class BlockerState {
  const BlockerState({
    required this.status,
    required this.updatedAt,
    this.note,
  });

  final BlockerStatus status;

  /// When the status was last changed (UTC).
  final DateTime updatedAt;

  /// Optional owner note recorded with the change.
  final String? note;

  Map<String, Object?> toJson() => {
    'status': status.name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (note != null) 'note': note,
  };

  /// Returns null for a malformed entry so one bad row never hides the
  /// others.
  static BlockerState? fromJson(Object? json) {
    if (json is! Map) return null;
    final status = BlockerStatus.values.asNameMap()[json['status']];
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (status == null || updatedAt == null) return null;
    final note = json['note'];
    return BlockerState(
      status: status,
      updatedAt: updatedAt.toUtc(),
      note: note is String && note.isNotEmpty ? note : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BlockerState &&
      other.status == status &&
      other.updatedAt == updatedAt &&
      other.note == note;

  @override
  int get hashCode => Object.hash(status, updatedAt, note);
}

/// Codec for the persisted map of blocker id to [BlockerState], stored as
/// one JSON object in the settings table. Malformed input decodes to an
/// empty map; malformed entries are dropped individually.
abstract final class BlockerStateCodec {
  static String encode(Map<String, BlockerState> states) =>
      jsonEncode({for (final e in states.entries) e.key: e.value.toJson()});

  static Map<String, BlockerState> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const {};
    }
    if (decoded is! Map) return const {};
    return {
      for (final e in decoded.entries)
        if (e.key is String && BlockerState.fromJson(e.value) != null)
          e.key as String: BlockerState.fromJson(e.value)!,
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
