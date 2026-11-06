import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/features/recipes/application/recipe_list_providers.dart';

void main() {
  test('SetRecipeFavouritesOnly returns Ok and persists the value', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final settings = DriftSettingsRepository(
      db,
      clock: FixedClock(DateTime.utc(2026, 11, 4)),
    );
    final set = SetRecipeFavouritesOnly(settings);
    final r = await set(value: true);
    expect(r.isOk, isTrue);
    expect(await settings.watchRecipeFavouritesOnly().first, isTrue);
    await set(value: false);
    expect(await settings.watchRecipeFavouritesOnly().first, isFalse);
  });
}
