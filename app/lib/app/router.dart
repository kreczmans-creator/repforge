import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/features/dashboard/presentation/home_screen.dart';
import 'package:repforge/features/measurements/presentation/weight_screen.dart';
import 'package:repforge/features/nutrition/presentation/custom_food_screen.dart';
import 'package:repforge/features/nutrition/presentation/food_search_screen.dart';
import 'package:repforge/features/nutrition/presentation/fuel_screen.dart';
import 'package:repforge/features/nutrition/presentation/saved_meals_screen.dart';
import 'package:repforge/features/nutrition/presentation/scan_screen.dart';
import 'package:repforge/features/nutrition/presentation/weekly_summary_screen.dart';
import 'package:repforge/features/planning/presentation/meal_plan_screen.dart';
import 'package:repforge/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:repforge/features/recipes/presentation/recipe_editor_screen.dart';
import 'package:repforge/features/recipes/presentation/recipe_list_screen.dart';
import 'package:repforge/features/settings/presentation/settings_screen.dart';
import 'package:repforge/features/shell/pillar_placeholder_screen.dart';
import 'package:repforge/features/training/presentation/exercise_detail_screen.dart';
import 'package:repforge/features/training/presentation/exercise_editor_screen.dart';
import 'package:repforge/features/training/presentation/exercise_library_screen.dart';
import 'package:repforge/ui/components/rf_brand_mark.dart';
import 'package:repforge/ui/gallery/gallery_screen.dart';
import 'package:repforge/ui/tokens.dart';

/// Route paths. Features navigate by these constants, never by literals.
abstract final class RfRoutes {
  static const home = '/home';
  static const train = '/train';
  static const trainExerciseNew = '/train/exercises/new';

  /// Exercise detail for [id] (TRN-008).
  static String trainExercise(String id) => '/train/exercises/$id';

  /// Custom exercise editor for [id] (TRN-012).
  static String trainExerciseEdit(String id) => '/train/exercises/$id/edit';
  static const fuel = '/fuel';
  static const fuelSearch = '/fuel/search';

  /// Food picker for recipe ingredients (pops the chosen food).
  static const fuelPickFood = '/fuel/search?pick=1';
  static const fuelNewFood = '/fuel/new-food';
  static const fuelScan = '/fuel/scan';
  static const fuelWeek = '/fuel/week';
  static const fuelSavedMeals = '/fuel/saved-meals';
  static const fuelRecipes = '/fuel/recipes';
  static const fuelRecipeNew = '/fuel/recipes/new';

  /// Meal plan (RCP-014).
  static const fuelPlan = '/fuel/plan';

  /// Recipe detail for [id].
  static String fuelRecipe(String id) => '/fuel/recipes/$id';

  /// Recipe editor for [id].
  static String fuelRecipeEdit(String id) => '/fuel/recipes/$id/edit';
  static const track = '/track';
  static const goals = '/goals';

  static const settings = '/settings';

  /// Debug-only component gallery.
  static const gallery = '/gallery';
}

// TODO(placeholder): The Goals branch shows a labelled RfNotYetAvailable
// screen until WP 11 delivers it (standards §10).
/// Application router: brand app bar, five-pillar bottom navigation
/// (Home · Train · Fuel · Track · Goals, per the brand mock-up) with one
/// branch per tab. Train hosts the exercise library, Fuel nutrition, Track
/// body-weight logging; Goals is a labelled placeholder until WP 11.
final _rootKey = GlobalKey<NavigatorState>();

GoRouter createRouter({String initialLocation = RfRoutes.home}) => GoRouter(
  navigatorKey: _rootKey,
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _Shell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RfRoutes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RfRoutes.train,
              builder: (context, state) => const ExerciseLibraryScreen(),
              routes: [
                // 'new' is declared before ':id' so it is not an id.
                GoRoute(
                  path: 'exercises/new',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => const ExerciseEditorScreen(),
                ),
                GoRoute(
                  path: 'exercises/:id',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => ExerciseDetailScreen(
                    exerciseId: state.pathParameters['id']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootKey,
                      builder: (context, state) => ExerciseEditorScreen(
                        exerciseId: state.pathParameters['id'],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RfRoutes.fuel,
              builder: (context, state) => const FuelScreen(),
              routes: [
                GoRoute(
                  path: 'search',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => FoodSearchScreen(
                    pickOnly: state.uri.queryParameters['pick'] == '1',
                  ),
                ),
                GoRoute(
                  path: 'new-food',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => CustomFoodScreen(
                    initialBarcode: state.uri.queryParameters['barcode'],
                  ),
                ),
                GoRoute(
                  path: 'scan',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => const ScanScreen(),
                ),
                GoRoute(
                  path: 'week',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => const WeeklySummaryScreen(),
                ),
                GoRoute(
                  path: 'saved-meals',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => const SavedMealsScreen(),
                ),
                GoRoute(
                  path: 'plan',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => const MealPlanScreen(),
                ),
                GoRoute(
                  path: 'recipes',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => const RecipeListScreen(),
                  routes: [
                    // 'new' is declared before ':id' so it is not an id.
                    GoRoute(
                      path: 'new',
                      parentNavigatorKey: _rootKey,
                      builder: (context, state) => const RecipeEditorScreen(),
                    ),
                    GoRoute(
                      path: ':id',
                      parentNavigatorKey: _rootKey,
                      builder: (context, state) => RecipeDetailScreen(
                        recipeId: state.pathParameters['id']!,
                      ),
                      routes: [
                        GoRoute(
                          path: 'edit',
                          parentNavigatorKey: _rootKey,
                          builder: (context, state) => RecipeEditorScreen(
                            recipeId: state.pathParameters['id'],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RfRoutes.track,
              builder: (context, state) => const WeightScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RfRoutes.goals,
              builder: (context, state) => const PillarPlaceholderScreen(
                title: 'Goals',
                caption: 'Targets and weekly summaries',
                feature: 'Calorie, macro, weight and training goals',
                workPackage: 'WP 11',
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: RfRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    if (kDebugMode)
      GoRoute(
        path: RfRoutes.gallery,
        builder: (context, state) => const GalleryScreen(),
      ),
  ],
);

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final rf = context.rf;
    return Scaffold(
      appBar: AppBar(
        title: const RfBrandMark(),
        titleSpacing: RfSpace.gutter,
        actions: [
          IconButton(
            key: const Key('open-settings'),
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(RfRoutes.settings),
          ),
          if (kDebugMode)
            IconButton(
              key: const Key('open-gallery'),
              tooltip: 'Component gallery (debug)',
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => context.push(RfRoutes.gallery),
            ),
        ],
      ),
      // AppBar and NavigationBar handle top/bottom insets; this covers
      // display cutouts on the sides in landscape.
      body: SafeArea(top: false, bottom: false, child: shell),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: rf.border)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (index) => shell.goBranch(
            index,
            initialLocation: index == shell.currentIndex,
          ),
          destinations: const [
            NavigationDestination(
              key: Key('nav-home'),
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              key: Key('nav-train'),
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center),
              label: 'Train',
            ),
            NavigationDestination(
              key: Key('nav-fuel'),
              icon: Icon(Icons.restaurant_outlined),
              selectedIcon: Icon(Icons.restaurant),
              label: 'Fuel',
            ),
            NavigationDestination(
              key: Key('nav-track'),
              icon: Icon(Icons.monitor_weight_outlined),
              selectedIcon: Icon(Icons.monitor_weight),
              label: 'Track',
            ),
            NavigationDestination(
              key: Key('nav-goals'),
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag),
              label: 'Goals',
            ),
          ],
        ),
      ),
    );
  }
}
