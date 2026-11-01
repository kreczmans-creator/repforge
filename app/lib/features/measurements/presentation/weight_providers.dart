import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/weight_entry.dart';

/// Live list of weight entries, newest first.
final weightEntriesProvider = StreamProvider<List<WeightEntry>>(
  (ref) => ref.watch(weightRepositoryProvider).watchAll(),
);

/// Most recent entry derived from the live list.
final latestWeightProvider = Provider<AsyncValue<WeightEntry?>>(
  (ref) => ref
      .watch(weightEntriesProvider)
      .whenData((entries) => entries.isEmpty ? null : entries.first),
);

/// State of the "record weight" form.
sealed class WeightFormState {
  const WeightFormState();
}

final class WeightFormIdle extends WeightFormState {
  const WeightFormIdle();
}

final class WeightFormSubmitting extends WeightFormState {
  const WeightFormSubmitting();
}

final class WeightFormFailed extends WeightFormState {
  const WeightFormFailed(this.error);
  final AppError error;
}

final class WeightFormSaved extends WeightFormState {
  const WeightFormSaved(this.entry);
  final WeightEntry entry;
}

/// Controller for the weight form. Holds only UI state; rules live in the use
/// case.
class WeightFormController extends Notifier<WeightFormState> {
  @override
  WeightFormState build() => const WeightFormIdle();

  Future<void> submit({required String weightText, String? note}) async {
    state = const WeightFormSubmitting();
    final result = await ref.read(recordBodyWeightProvider)(
      weightText: weightText,
      note: note,
    );
    state = result.fold(WeightFormSaved.new, WeightFormFailed.new);
  }

  Future<void> delete(String id) async {
    final result = await ref.read(deleteWeightEntryProvider)(id);
    if (result case Err(:final error)) {
      state = WeightFormFailed(error);
    }
  }

  void reset() => state = const WeightFormIdle();
}

final weightFormControllerProvider =
    NotifierProvider<WeightFormController, WeightFormState>(
      WeightFormController.new,
    );
