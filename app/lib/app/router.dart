import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/features/dashboard/presentation/home_screen.dart';
import 'package:repforge/features/measurements/presentation/weight_screen.dart';
import 'package:repforge/features/nutrition/presentation/custom_food_screen.dart';
import 'package:repforge/features/nutrition/presentation/food_search_screen.dart';
import 'package:repforge/features/nutrition/presentation/fuel_screen.dart';
import 'package:repforge/features/nutrition/presentation/saved_meals_screen.dart';
import 'package:repforge/features/nutrition/presentation/weekly_summary_screen.dart';
import 'package:repforge/features/settings/presentation/settings_screen.dart';
import 'package:repforge/features/shell/pillar_placeholder_screen.dart';
import 'package:repforge/ui/components/rf_brand_mark.dart';
import 'package:repforge/ui/gallery/gallery_screen.dart';
import 'package:repforge/ui/tokens.dart';

/// Route paths. Features navigate by these constants, never by literals.
abstract final class RfRoutes {
  static const home = '/home';
  static const train = '/train';
  static const fuel = '/fuel';
  static const fuelSearch = '/fuel/search';
  static const fuelNewFood = '/fuel/new-food';
  static const fuelWeek = '/fuel/week';
  static const fuelSavedMeals = '/fuel/saved-meals';
  static const track = '/track';
  static const goals = '/goals';

  static const settings = '/settings';

  /// Debug-only component gallery.
  static const gallery = '/gallery';
}

// TODO(placeholder): Train, Fuel and Goals branches show labelled
// RfNotYetAvailable screens until WP 5–11 deliver them (standards §10).
/// Application router: brand app bar, five-pillar bottom navigation
/// (Home · Train · Fuel · Track · Goals, per the brand mock-up) with one
/// branch per tab. Train, Fuel and Goals are labelled placeholders until their
/// work packages land; Track hosts body-weight logging.
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
              builder: (context, state) => const PillarPlaceholderScreen(
                title: 'Train',
                caption: 'Plans, sessions and progress',
                feature: 'Exercise library, workout plans and session logging',
                workPackage: 'WP 8 and WP 9',
              ),
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
                  builder: (context, state) => const FoodSearchScreen(),
                ),
                GoRoute(
                  path: 'new-food',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => const CustomFoodScreen(),
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
