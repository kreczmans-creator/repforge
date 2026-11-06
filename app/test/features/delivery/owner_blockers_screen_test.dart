import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/delivery/owner_blocker.dart';
import 'package:repforge/features/delivery/application/blocker_providers.dart';
import 'package:repforge/features/delivery/presentation/owner_blockers_screen.dart';
import 'package:repforge/ui/theme.dart';

import '../../helpers/pump.dart';
import 'blocker_fixtures.dart';

Widget _harness(
  AppDatabase db, {
  List<OwnerBlocker>? register,
  Brightness brightness = Brightness.dark,
}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 11, 6, 9))),
    ownerBlockerRegisterProvider.overrideWithValue(register ?? testRegister),
  ],
  child: MaterialApp(
    theme: rfTheme(brightness),
    home: const OwnerBlockersScreen(),
  ),
);

Finder _row(String id) => find.byKey(Key('blocker-row-$id'));

Future<void> _choose(WidgetTester tester, String filter, String option) async {
  await tester.tap(find.byKey(Key(filter)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _scope(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const Key('blockers-scope')),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(600, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('summary, grouping headers and counts', (tester) async {
    tall(tester);
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();

    expect(find.text('4 open · 3 awaiting you · 1 resolved'), findsOneWidget);
    expect(find.byKey(const Key('blockers-group-wp8')), findsOneWidget);
    expect(find.byKey(const Key('blockers-group-wp15')), findsOneWidget);
    expect(find.byKey(const Key('blockers-group-wp17')), findsOneWidget);
    expect(find.byKey(const Key('blockers-group-programme')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('blockers-group-wp8')),
        matching: find.text(
          'WP 8 · Exercise library and training architecture',
        ),
      ),
      findsOneWidget,
    );
    // Default scope is Open: OB-B is resolved so WP 8 shows one row.
    expect(
      find.descendant(
        of: find.byKey(const Key('blockers-group-wp8')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('blockers-group-wp17')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(_row('OB-B'), findsNothing);
    expect(find.byKey(const Key('blocker-assignee-OB-A')), findsOneWidget);
    expect(find.text('Owner action'), findsWidgets);
    expect(find.text('Agent-owned'), findsOneWidget);
    expect(find.text('Scope approval · S-OB-A · REF-OB-A'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('scope switches between open, resolved and all', (tester) async {
    tall(tester);
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();
    await _scope(tester, 'Resolved');
    expect(_row('OB-B'), findsOneWidget);
    expect(_row('OB-A'), findsNothing);
    await _scope(tester, 'All');
    expect(_row('OB-A'), findsOneWidget);
    expect(_row('OB-B'), findsOneWidget);
    await _scope(tester, 'Open');
    expect(_row('OB-B'), findsNothing);
    await unmount(tester);
  });

  testWidgets('each filter narrows the rows', (tester) async {
    tall(tester);
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();

    await _choose(tester, 'blockers-filter-wp', 'WP 17');
    expect(_row('OB-D'), findsOneWidget);
    expect(_row('OB-A'), findsNothing);
    await _choose(tester, 'blockers-filter-wp', 'All');
    expect(_row('OB-A'), findsOneWidget);

    await _choose(tester, 'blockers-filter-priority', 'High');
    expect(_row('OB-A'), findsOneWidget);
    expect(_row('OB-C'), findsOneWidget);
    expect(_row('OB-D'), findsNothing);
    await _choose(tester, 'blockers-filter-priority', 'All');

    await _choose(tester, 'blockers-filter-category', 'Owner acceptance');
    expect(_row('OB-E'), findsOneWidget);
    expect(_row('OB-A'), findsNothing);
    await _choose(tester, 'blockers-filter-category', 'All');

    await _choose(tester, 'blockers-filter-status', 'In progress');
    expect(_row('OB-E'), findsOneWidget);
    expect(_row('OB-D'), findsNothing);
    await unmount(tester);
  });

  testWidgets('filters that hide everything show the filtered empty state', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();
    await _choose(tester, 'blockers-filter-wp', 'Programme');
    expect(find.byKey(const Key('blockers-empty-filtered')), findsOneWidget);
    expect(find.text('Nothing matches these filters.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Clear filters restores the full list', (tester) async {
    tall(tester);
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();
    await _choose(tester, 'blockers-filter-wp', 'Programme');
    expect(find.byKey(const Key('blockers-empty-filtered')), findsOneWidget);
    await tester.tap(find.byKey(const Key('blockers-clear-filters')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('blockers-empty-filtered')), findsNothing);
    expect(_row('OB-A'), findsOneWidget);
    expect(_row('OB-D'), findsOneWidget);
    expect(_row('OB-B'), findsNothing); // default Open scope again
    await unmount(tester);
  });

  testWidgets('Status = Resolved switches the scope so it is never empty', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();
    await _choose(tester, 'blockers-filter-status', 'Resolved');
    expect(_row('OB-B'), findsOneWidget);
    expect(_row('OB-A'), findsNothing);
    expect(find.byKey(const Key('blockers-empty-filtered')), findsNothing);

    // Going back to Open drops the contradicting status filter.
    await _scope(tester, 'Open');
    expect(_row('OB-A'), findsOneWidget);
    expect(_row('OB-B'), findsNothing);
    await unmount(tester);
  });

  testWidgets('an open Status filter switches a Resolved scope to Open', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();
    await _scope(tester, 'Resolved');
    await _choose(tester, 'blockers-filter-status', 'In progress');
    expect(_row('OB-E'), findsOneWidget);
    expect(find.byKey(const Key('blockers-empty-filtered')), findsNothing);
    await unmount(tester);
  });

  testWidgets('the popup marks the current choice', (tester) async {
    tall(tester);
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();
    await _choose(tester, 'blockers-filter-priority', 'High');
    await tester.tap(find.byKey(const Key('blockers-filter-priority')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      find.descendant(
        of: find
            .ancestor(of: find.byIcon(Icons.check), matching: find.byType(Row))
            .first,
        matching: find.text('High'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('All').last);
    await tester.pumpAndSettle();
    await unmount(tester);
  });

  testWidgets('the restore note is shown', (tester) async {
    tall(tester);
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('blockers-restore-note')), findsOneWidget);
    expect(
      find.text(
        'Status changes are stored with your other settings and travel with '
        'backups; restoring an older backup also restores the older '
        'statuses.',
      ),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('the error state offers retry', (tester) async {
    tall(tester);
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          ownerBlockerRegisterProvider.overrideWithValue(testRegister),
          blockerStatesProvider.overrideWith((ref) {
            calls++;
            return calls == 1
                ? Stream<Map<String, BlockerState>>.error(Exception('boom'))
                : Stream.value(const <String, BlockerState>{});
          }),
        ],
        child: MaterialApp(
          theme: rfTheme(Brightness.dark),
          home: const OwnerBlockersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load the blockers.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load the blockers.'), findsNothing);
    expect(_row('OB-A'), findsOneWidget);
    expect(calls, 2);
    await unmount(tester);
  });

  testWidgets('an empty register shows the empty state', (tester) async {
    await tester.pumpWidget(_harness(db, register: const []));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('blockers-empty')), findsOneWidget);
    expect(
      find.text('No owner actions or blockers are recorded.'),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('tapping a row opens its detail', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          ownerBlockerRegisterProvider.overrideWithValue(testRegister),
        ],
        child: RepForgeApp(
          router: createRouter(initialLocation: RfRoutes.settingsOwnerActions),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_row('OB-A'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('blocker-save-status')), findsOneWidget);
    expect(find.text('OB-A'), findsWidgets);
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('renders in ${brightness.name} at a phone width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_harness(db, brightness: brightness));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_row('OB-A'), findsOneWidget);
      await unmount(tester);
    });
  }

  testWidgets('renders at 2x text scale without exceptions', (tester) async {
    tester.view.physicalSize = const Size(360, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 6000),
          textScaler: TextScaler.linear(2),
        ),
        child: _harness(db),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
