import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/nutrition/presentation/provenance_badge.dart';
import 'package:repforge/features/recipes/application/recipe_list_providers.dart';
import 'package:repforge/features/recipes/application/recipe_providers.dart';
import 'package:repforge/features/recipes/presentation/recipe_format.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Recipe list (RCP-011): cards with per-portion energy, provenance and total
/// time, a one-tap favourite toggle and a persistent favourites filter.
class RecipeListScreen extends ConsumerStatefulWidget {
  const RecipeListScreen({super.key});

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  String _query = '';

  Future<void> _new() async {
    final saved = await context.push<Recipe>(RfRoutes.fuelRecipeNew);
    if (!mounted || saved == null) return;
    await context.push<void>(RfRoutes.fuelRecipe(saved.id));
  }

  Future<void> _toggle(Recipe r) async {
    final result = await ref.read(toggleFavouriteProvider)(r.id);
    if (!mounted) return;
    if (result case Err(:final error)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userMessageFor(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(recipesProvider);
    final favOnly = ref.watch(recipeFavouritesOnlyProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      body: recipes.when(
        loading: () => const RfLoading(),
        error: (e, _) => const RfErrorState(message: 'Could not load recipes.'),
        data: (all) {
          final q = _query.trim().toLowerCase();
          final shown = [
            for (final r in all)
              if ((!favOnly || r.favourite) &&
                  (q.isEmpty || r.name.toLowerCase().contains(q)))
                r,
          ];
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
            children: [
              const RfScreenTitle(
                title: 'Recipes',
                caption: 'Per-portion nutrition from your ingredients',
              ),
              RfButton(
                key: const Key('new-recipe'),
                label: 'New recipe',
                icon: Icons.add,
                onPressed: _new,
              ),
              const SizedBox(height: RfSpace.s3),
              RfTextField(
                key: const Key('recipe-search'),
                label: 'Search recipes',
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: RfSpace.s2),
              Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  key: const Key('filter-favourites'),
                  label: const Text('Favourites'),
                  avatar: const Icon(Icons.star_outline, size: RfIcon.sm),
                  selected: favOnly,
                  onSelected: (v) async {
                    final result = await ref.read(
                      setRecipeFavouritesOnlyProvider,
                    )(value: v);
                    if (!context.mounted) return;
                    if (result case Err(:final error)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(userMessageFor(error))),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: RfSpace.s2),
              if (shown.isEmpty)
                RfEmptyState(
                  key: const Key('recipes-empty'),
                  icon: Icons.menu_book_outlined,
                  message: all.isEmpty
                      ? 'No recipes yet. Create one to get per-portion '
                            'nutrition from your ingredients.'
                      : favOnly && q.isEmpty
                      ? 'No favourite recipes yet. Tap the star on a recipe.'
                      : 'No recipes match.',
                )
              else
                for (final r in shown) ...[
                  _RecipeCard(
                    recipe: r,
                    onOpen: () => context.push(RfRoutes.fuelRecipe(r.id)),
                    onToggle: () => _toggle(r),
                  ),
                  const SizedBox(height: RfSpace.s2),
                ],
              const SizedBox(height: RfSpace.s8),
            ],
          );
        },
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.onOpen,
    required this.onToggle,
  });

  final Recipe recipe;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kcal = recipe.perPortion?.kcal;
    final total = recipe.totalMinutes;
    final meta = [
      if (recipe.category.trim().isNotEmpty) recipe.category.trim(),
      if (kcal == null)
        'no nutrition'
      else
        '${formatNumber(kcal, maxDecimals: 0)} kcal per portion',
      if (total != null) minutesLabel(total),
    ].join(' · ');
    return RfCard(
      key: Key('recipe-${recipe.id}'),
      onTap: onOpen,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: RfSpace.s1),
                Text(meta, style: context.rfText.caption),
                const SizedBox(height: RfSpace.s2),
                ProvenanceBadge(recipe.provenance),
              ],
            ),
          ),
          IconButton(
            key: Key('fav-${recipe.id}'),
            tooltip: recipe.favourite
                ? 'Remove from favourites'
                : 'Add to favourites',
            icon: Icon(
              recipe.favourite ? Icons.star : Icons.star_outline,
              color: recipe.favourite ? context.rf.accentText : null,
            ),
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }
}
