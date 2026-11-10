import 'dart:convert';

import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipe_repository.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/settings/settings.dart';

/// Result of [ImportLegacyRecipes].
final class LegacyImportSummary {
  const LegacyImportSummary({
    required this.imported,
    required this.alreadyPresent,
    required this.alreadyDone,
  });

  /// Recipes created by this run.
  final int imported;

  /// Recipes skipped because their id exists or was deleted by the user.
  final int alreadyPresent;

  /// True when an earlier run had already imported the bundled version.
  final bool alreadyDone;
}

/// Use case: import the legacy starter recipes bundled as
/// `assets/seed/legacy_recipes.json` (WP 7 decision 3).
///
/// Each becomes a recipe with the original ingredient lines kept as
/// `ingredientNotes` (they cannot be linked to foods reliably), the method as
/// cooking steps, the declared per-portion energy and macros (fibre unknown)
/// and the legacy note. Nutrition is therefore `estimated`. Freezing is
/// `unknown` whatever the legacy flag said: the flag is not a safety claim
/// the app can stand behind (RCP-005, OQ-13).
///
/// Runs once: when it succeeds the bundled version is recorded in settings
/// (`seedRecipesVersion`) and later calls do nothing. A recipe whose id
/// already exists, including one the user has since deleted, is never
/// created again. The JSON text is injected so tests need no asset. Nothing
/// is written when the file cannot be read; a failure part-way leaves the
/// version unrecorded and the next run skips what was already created.
final class ImportLegacyRecipes {
  const ImportLegacyRecipes({
    required this.recipes,
    required this.settings,
    required this.clock,
    required this.loadJson,
  });

  /// Version recorded in settings once this seed has been imported.
  static const seedVersion = 2;

  final RecipeRepository recipes;
  final SettingsRepository settings;
  final Clock clock;

  /// Supplies the JSON text of the asset.
  final Future<String> Function() loadJson;

  Future<Result<LegacyImportSummary>> call() async {
    try {
      if (await settings.readSeedRecipesVersion() >= seedVersion) {
        return const Ok(
          LegacyImportSummary(
            imported: 0,
            alreadyPresent: 0,
            alreadyDone: true,
          ),
        );
      }
      final parsed = _parse(await loadJson(), clock.now().toUtc());
      if (parsed case Err(:final error)) return Err(error);
      var imported = 0;
      var present = 0;
      for (final recipe in (parsed as Ok<List<Recipe>>).value) {
        if (await recipes.exists(recipe.id)) {
          present++;
          continue;
        }
        await recipes.upsert(recipe);
        imported++;
      }
      await settings.saveSeedRecipesVersion(seedVersion);
      return Ok(
        LegacyImportSummary(
          imported: imported,
          alreadyPresent: present,
          alreadyDone: false,
        ),
      );
    } on Object catch (e) {
      // Not only Exceptions: a missing asset makes rootBundle.loadString
      // throw a FlutterError (an Error). Whatever fails, the import records
      // nothing and reports a typed error.
      return Err(
        StorageError('Could not import the starter recipes.', cause: e),
      );
    }
  }

  static Result<List<Recipe>> _parse(String json, DateTime now) {
    const bad = ValidationError('The starter recipe file is not valid.');
    try {
      final root = jsonDecode(json);
      if (root is! Map<String, Object?> || root['formatVersion'] != 1) {
        return const Err(bad);
      }
      final list = root['recipes'];
      if (list is! List) return const Err(bad);
      final out = <Recipe>[];
      for (final item in list) {
        final m = item! as Map<String, Object?>;
        final per = m['perPortion']! as Map<String, Object?>;
        double? asDouble(Object? v) => (v as num?)?.toDouble();
        List<String> strings(Object? v) => [
          for (final s in (v as List?) ?? const <Object?>[]) s! as String,
        ];
        final recipe = Recipe(
          id: m['id']! as String,
          name: m['name']! as String,
          category: (m['category'] as String?) ?? '',
          description: (m['description'] as String?) ?? '',
          portions: (m['portions']! as num).toDouble(),
          ingredients: const [],
          ingredientNotes: strings(m['ingredientLines']),
          cookSteps: strings(m['methodSteps']),
          // m['legacyFreezerFriendly'] is deliberately not imported, so
          // freezing keeps its default, unknown.
          declaredPerPortion: NutrientAmounts(
            kcal: asDouble(per['kcal'])!,
            proteinG: asDouble(per['proteinG']),
            carbsG: asDouble(per['carbsG']),
            fatG: asDouble(per['fatG']),
          ),
          nutritionNote: m['nutritionNote'] as String?,
          createdAt: now,
          updatedAt: now,
        );
        if (validateRecipe(recipe) case Err(:final error)) return Err(error);
        out.add(recipe);
      }
      return Ok(out);
    } on Object {
      // Any shape error in a bundled file: nothing is imported.
      return const Err(bad);
    }
  }
}
