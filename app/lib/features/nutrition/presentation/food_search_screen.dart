import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/nutrition/food_lookup_service.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/nutrition/application/nutrition_providers.dart';
import 'package:repforge/features/nutrition/presentation/portion_sheet.dart';
import 'package:repforge/features/nutrition/presentation/provenance_badge.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/tokens.dart';

/// Search the local food database and Open Food Facts; tap a result to
/// choose a portion and log it. Works offline with local results only.
class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _pick(Food food) async {
    final now = ref.read(clockProvider).now().toLocal();
    final entry = await showPortionSheet(
      context,
      food,
      initialMeal: defaultMealFor(now),
    );
    if (!mounted || entry == null) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(foodSearchControllerProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log food'),
        actions: [
          TextButton(
            key: const Key('new-food'),
            onPressed: () async {
              final food = await context.push<Food>(RfRoutes.fuelNewFood);
              if (!mounted || food == null) return;
              await _pick(food);
            },
            child: const Text('New food'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const SizedBox(height: RfSpace.s3),
          RfTextField(
            key: const Key('food-query'),
            controller: _query,
            label: 'Search foods',
            hint: 'e.g. chicken breast',
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: ref.read(foodSearchControllerProvider.notifier).setQuery,
          ),
          const SizedBox(height: RfSpace.s3),
          if (state.isEmptyQuery)
            Text(
              'Type at least two letters. Your own foods and foods you have '
              'logged before appear first; online results follow.',
              style: theme.textTheme.bodySmall,
            )
          else ...[
            if (state.local.isNotEmpty) ...[
              const RfSectionHeader(title: 'Your foods'),
              _Results(foods: state.local, onPick: _pick, keyPrefix: 'local'),
            ],
            const RfSectionHeader(title: 'Open Food Facts'),
            if (state.searchingOnline)
              const RfLoading()
            else if (state.onlineFailure != null)
              RfEmptyState(
                key: const Key('online-failure'),
                icon: Icons.cloud_off_outlined,
                message: switch (state.onlineFailure!) {
                  LookupOffline() =>
                    'You are offline. Local results only; create a new food '
                        'if nothing matches.',
                  LookupRateLimited() =>
                    'Open Food Facts is busy. Try again in a minute.',
                  LookupUnavailable() =>
                    'Open Food Facts is unavailable right now.',
                  LookupNotFound() => 'No online matches.',
                },
              )
            else if (state.online.isEmpty)
              Text('No online matches.', style: theme.textTheme.bodySmall)
            else
              _Results(foods: state.online, onPick: _pick, keyPrefix: 'online'),
            const SizedBox(height: RfSpace.s3),
            Text(
              'Community data is crowdsourced; check the label.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }
}

String _per100(Food f) =>
    '${whole(f.profile.per100Amounts.kcal)} kcal/100 '
    '${f.profile.per100.symbol}';

class _Results extends StatelessWidget {
  const _Results({
    required this.foods,
    required this.onPick,
    required this.keyPrefix,
  });

  final List<Food> foods;
  final ValueChanged<Food> onPick;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RfCard(
      padding: const EdgeInsets.symmetric(
        horizontal: RfSpace.s4,
        vertical: RfSpace.s1,
      ),
      child: Column(
        children: [
          for (final f in foods)
            ListTile(
              key: Key('$keyPrefix-${f.id}'),
              contentPadding: EdgeInsets.zero,
              onTap: () => onPick(f),
              title: Text(
                f.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Row(
                children: [
                  Flexible(
                    child: Text(
                      [if (f.brand != null) f.brand!, _per100(f)].join(' · '),
                      style: context.rfText.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: RfSpace.s2),
                  ProvenanceBadge(f.profile.provenance),
                ],
              ),
              trailing: const Icon(Icons.add_circle_outline),
            ),
        ],
      ),
    );
  }
}
