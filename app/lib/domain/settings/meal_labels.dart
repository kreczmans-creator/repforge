import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';

/// The user's names and display order for the four meal slots (NUT-011).
///
/// Diary entries store the slot key ([MealSlot]), never the label, so
/// renaming a slot changes how existing and new entries are labelled. Labels
/// are 1–30 characters after trimming, not blank, and unique ignoring case;
/// [order] contains each slot exactly once. Instances are always valid:
/// build them with [MealLabels.create] or [MealLabels.fromJson].
@immutable
final class MealLabels {
  const MealLabels._(this._labels, this.order);

  /// Longest label allowed.
  static const maxLength = 30;

  /// Breakfast, Lunch, Dinner, Snacks in that order.
  static const defaults = MealLabels._({
    MealSlot.breakfast: 'Breakfast',
    MealSlot.lunch: 'Lunch',
    MealSlot.dinner: 'Dinner',
    MealSlot.snack: 'Snacks',
  }, MealSlot.values);

  final Map<MealSlot, String> _labels;

  /// The slots in the order they are shown.
  final List<MealSlot> order;

  /// The label of [slot].
  String labelOf(MealSlot slot) => _labels[slot]!;

  /// Validates and builds labels. [labels] must name every slot.
  static Result<MealLabels> create({
    required Map<MealSlot, String> labels,
    required List<MealSlot> order,
  }) {
    final trimmed = <MealSlot, String>{};
    final seen = <String>{};
    for (final slot in MealSlot.values) {
      final raw = labels[slot];
      if (raw == null) {
        return Err(
          ValidationError('Every meal needs a name.', field: slot.name),
        );
      }
      final label = raw.trim();
      if (label.isEmpty) {
        return Err(ValidationError('Enter a meal name.', field: slot.name));
      }
      if (label.length > maxLength) {
        return Err(
          ValidationError(
            'Meal names can be at most $maxLength characters.',
            field: slot.name,
          ),
        );
      }
      if (!seen.add(label.toLowerCase())) {
        return Err(
          ValidationError(
            'Meal names must be different from each other.',
            field: slot.name,
          ),
        );
      }
      trimmed[slot] = label;
    }
    if (order.length != MealSlot.values.length ||
        order.toSet().length != MealSlot.values.length) {
      return const Err(
        ValidationError('Order must list each meal once.', field: 'order'),
      );
    }
    return Ok(
      MealLabels._(Map.unmodifiable(trimmed), List.unmodifiable(order)),
    );
  }

  /// Encodes as `{"order":[slot names],"labels":{slot name: label}}`.
  String toJson() => jsonEncode({
    'order': [for (final s in order) s.name],
    'labels': {for (final s in MealSlot.values) s.name: _labels[s]},
  });

  /// Decodes [json]; null, malformed or invalid input gives [defaults].
  static MealLabels fromJson(String? json) {
    if (json == null) return defaults;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, Object?>) return defaults;
      final rawLabels = decoded['labels'];
      final rawOrder = decoded['order'];
      if (rawLabels is! Map<String, Object?> || rawOrder is! List) {
        return defaults;
      }
      final slots = MealSlot.values.asNameMap();
      final result = create(
        labels: {
          for (final e in rawLabels.entries) ?slots[e.key]: e.value! as String,
        },
        order: [for (final o in rawOrder) slots[o]!],
      );
      return switch (result) {
        Ok(:final value) => value,
        Err() => defaults,
      };
    } on Object {
      return defaults;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is MealLabels &&
      _sameOrder(other.order, order) &&
      MealSlot.values.every((s) => other._labels[s] == _labels[s]);

  static bool _sameOrder(List<MealSlot> a, List<MealSlot> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(order),
    Object.hashAll(MealSlot.values.map((s) => _labels[s])),
  );

  @override
  String toString() => 'MealLabels(${toJson()})';
}
