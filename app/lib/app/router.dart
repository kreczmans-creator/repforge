import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/features/dashboard/presentation/home_screen.dart';
import 'package:repforge/features/measurements/presentation/weight_screen.dart';

/// Route paths. Features navigate by these constants, never by literals.
abstract final class RfRoutes {
  static const home = '/home';
  static const weight = '/weight';
}

/// Application router: a bottom-navigation shell with one branch per tab.
GoRouter createRouter({String initialLocation = RfRoutes.home}) => GoRouter(
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
              path: RfRoutes.weight,
              builder: (context, state) => const WeightScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (index) =>
          shell.goBranch(index, initialLocation: index == shell.currentIndex),
      destinations: const [
        NavigationDestination(
          key: Key('nav-home'),
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Home',
        ),
        NavigationDestination(
          key: Key('nav-weight'),
          icon: Icon(Icons.monitor_weight_outlined),
          selectedIcon: Icon(Icons.monitor_weight),
          label: 'Weight',
        ),
      ],
    ),
  );
}
