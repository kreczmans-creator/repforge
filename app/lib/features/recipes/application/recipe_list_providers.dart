import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/features/recipes/application/recipe_providers.dart';

/// Whether the recipe list shows favourites only (RCP-011). Stored in the
/// settings table so it survives a restart.
final recipeFavouritesOnlyProvider = StreamProvider<bool>(
  (ref) => ref.watch(settingsRepositoryProvider).watchRecipeFavouritesOnly(),
);

/// Use case: remember the favourites filter.
final class SetRecipeFavouritesOnly {
  const SetRecipeFavouritesOnly(this._settings);
  final SettingsRepository _settings;

  Future<Result<void>> call({required bool value}) async {
    try {
      await _settings.saveRecipeFavouritesOnly(value: value);
    } on Exception catch (e) {
      return Err(StorageError('Could not save the filter.', cause: e));
    }
    return const Ok(null);
  }
}

final setRecipeFavouritesOnlyProvider = Provider<SetRecipeFavouritesOnly>(
  (ref) => SetRecipeFavouritesOnly(ref.watch(settingsRepositoryProvider)),
);

/// One recipe by id: null when it does not exist (or was deleted).
// ignore: specify_nonobvious_property_types
final recipeByIdProvider = Provider.family<AsyncValue<Recipe?>, String>((
  ref,
  id,
) {
  final all = ref.watch(recipesProvider);
  return all.whenData((list) {
    for (final r in list) {
      if (r.id == id) return r;
    }
    return null;
  });
});
