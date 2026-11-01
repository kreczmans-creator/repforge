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

  /// Validates and saves. Ignored while a previous submit is in flight so a
  /// double tap or a second keyboard action cannot insert twice.
  Future<void> submit({required String weightText, String? note}) async {
    if (state is WeightFormSubmitting) return;
    state = const WeightFormSubmitting();
    final result = await ref.read(recordBodyWeightProvider)(
      weightText: weightText,
      note: note,
    );
    state = result.fold(WeightFormSaved.new, WeightFormFailed.new);
  }

  /// Deletes an entry. Independent of the form state: a delete failure is
  /// reported to the caller (shown as a snackbar), never as a form error.
  Future<Result<void>> delete(String id) =>
      ref.read(deleteWeightEntryProvider)(id);

  void reset() => state = const WeightFormIdle();
}

final weightFormControllerProvider =
    NotifierProvider<WeightFormController, WeightFormState>(
      WeightFormController.new,
    );
