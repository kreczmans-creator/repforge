import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/features/delivery/application/blocker_providers.dart';
import 'package:repforge/features/delivery/presentation/owner_blocker_detail_screen.dart';
import 'package:repforge/features/delivery/presentation/owner_blockers_screen.dart';
import 'package:repforge/ui/theme.dart';

import '../../helpers/pump.dart';
import 'blocker_fixtures.dart';

Widget _harness(AppDatabase db, Widget home) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    clockProvider.overrideWithValue(
      FixedClock(DateTime.utc(2026, 11, 6, 9, 30)),
    ),
    ownerBlockerRegisterProvider.overrideWithValue(testRegister),
  ],
  child: MaterialApp(theme: rfTheme(Brightness.dark), home: home),
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(600, 4800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  const detail = OwnerBlockerDetailScreen(blockerId: 'OB-D');

  testWidgets('shows every section and the evidence rows', (tester) async {
    tall(tester);
    await tester.pumpWidget(_harness(db, detail));
    await tester.pumpAndSettle();

    for (final heading in [
      'Description',
      'Why it is blocked',
      'Action required',
      'Recommended response',
      'Consequences of alternatives',
      'Dependencies',
      'Supporting evidence',
      'Related delivery record',
      'Status',
    ]) {
      expect(find.text(heading), findsOneWidget, reason: heading);
    }
    expect(find.text('Title OB-D'), findsOneWidget);
    expect(find.text('WP 17 · S-OB-D · REF-OB-D'), findsOneWidget);
    expect(find.text('Description OB-D'), findsOneWidget);
    expect(find.text('OB-A'), findsOneWidget); // dependency
    expect(find.text('Delivery record: D04 §7'), findsOneWidget);
    expect(find.byKey(const Key('blocker-evidence-1')), findsOneWidget);
    expect(find.text('CI run'), findsOneWidget);
    expect(find.text('docs/delivery-record/OB-D.md'), findsOneWidget);
    expect(
      find.text('Register status, not yet changed in the app'),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('no dependencies shows None', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      _harness(db, const OwnerBlockerDetailScreen(blockerId: 'OB-A')),
    );
    await tester.pumpAndSettle();
    expect(find.text('None'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('an unknown id shows the missing message', (tester) async {
    await tester.pumpWidget(
      _harness(db, const OwnerBlockerDetailScreen(blockerId: 'OB-NOPE')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('blocker-missing')), findsOneWidget);
    expect(find.text('This blocker is not in the register.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a saved status and note persist and show in the list', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(_harness(db, detail));
    await tester.pumpAndSettle();

    final done = find.descendant(
      of: find.byKey(const Key('blocker-status-choice')),
      matching: find.text('Done'),
    );
    await tester.ensureVisible(done);
    await tester.tap(done);
    await tester.pump();
    expect(find.text('Selected: Resolved'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('blocker-note-field')),
      '  Verified on device  ',
    );
    await tester.tap(find.byKey(const Key('blocker-save-status')));
    await tester.pumpAndSettle();
    expect(find.text('Status saved'), findsOneWidget);
    expect(find.text('Changed 2026-11-06T09:30:00.000Z UTC'), findsOneWidget);

    // A fresh widget over the same database shows the stored values.
    await unmount(tester);
    await tester.pumpWidget(_harness(db, detail));
    await tester.pumpAndSettle();
    expect(find.text('Verified on device'), findsOneWidget);
    expect(find.text('Changed 2026-11-06T09:30:00.000Z UTC'), findsOneWidget);
    expect(find.text('Selected: Resolved'), findsOneWidget);
    await unmount(tester);

    await tester.pumpWidget(_harness(db, const OwnerBlockersScreen()));
    await tester.pumpAndSettle();
    // Resolved moves OB-D out of the default Open scope.
    expect(find.byKey(const Key('blocker-row-OB-D')), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('blockers-scope')),
        matching: find.text('Resolved'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('blocker-row-OB-D')),
        matching: find.text('Resolved'),
      ),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('a note over 500 characters shows an inline error', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(_harness(db, detail));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('blocker-note-field')),
      'x' * 501,
    );
    await tester.tap(find.byKey(const Key('blocker-save-status')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('blocker-status-error')), findsOneWidget);
    expect(find.text('Status saved'), findsNothing);
    await unmount(tester);
  });
}
