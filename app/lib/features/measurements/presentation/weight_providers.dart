import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/measurements/weight_entry.dart';

/// Live list of weight entries, newest first. Read by the dashboard; the
/// Track tab uses the measurement providers.
final weightEntriesProvider = StreamProvider<List<WeightEntry>>(
  (ref) => ref.watch(weightRepositoryProvider).watchAll(),
);

/// Most recent entry derived from the live list.
final latestWeightProvider = Provider<AsyncValue<WeightEntry?>>(
  (ref) => ref
      .watch(weightEntriesProvider)
      .whenData((entries) => entries.isEmpty ? null : entries.first),
);
