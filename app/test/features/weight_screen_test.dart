import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/features/measurements/presentation/weight_screen.dart';
import 'package:repforge/ui/theme.dart';

import '../helpers/pump.dart';

Widget _harness(AppDatabase db) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 11, 1, 9))),
  ],
  child: MaterialApp(
    theme: rfTheme(Brightness.dark),
    home: const WeightScreen(),
  ),
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  testWidgets('shows the empty state when nothing is logged', (tester) async {
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weight-empty')), findsOneWidget);
    expect(find.text('Save weight'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('saving a valid weight adds it to the history', (tester) async {
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('weight-input')), '82.4');
    await tester.enterText(find.byKey(const Key('note-input')), 'morning');
    await tester.tap(find.byKey(const Key('save-weight')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weight-empty')), findsNothing);
    expect(find.text('82.4 kg'), findsOneWidget);
    expect(find.textContaining('morning'), findsOneWidget);
    expect(find.text('Saved 82.4 kg'), findsOneWidget); // snackbar
    expect(
      (tester.widget(
        find.byKey(const Key('weight-input')),
      ) as TextField).controller!.text,
      isEmpty,
    );
    await unmount(tester);
  });

  testWidgets('an out-of-range weight shows a validation message', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('weight-input')), '12');
    await tester.tap(find.byKey(const Key('save-weight')));
    await tester.pumpAndSettle();

    expect(
      find.text('Weight must be between 20.0 kg and 500.0 kg.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('weight-empty')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('deleting an entry removes it from the list', (tester) async {
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('weight-input')), '80');
    await tester.tap(find.byKey(const Key('save-weight')));
    await tester.pumpAndSettle();
    expect(find.text('80.0 kg'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete entry'));
    await tester.pumpAndSettle();

    expect(find.text('80.0 kg'), findsNothing);
    expect(find.byKey(const Key('weight-empty')), findsOneWidget);
    await unmount(tester);
  });
}
