import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';

/// End-to-end flow on a real device or emulator: log a weight on the Weight
/// tab, then confirm the Home dashboard shows it.
///
/// The database is an in-memory instance so the test leaves no data on the
/// device; on-disk persistence is covered by the repository file test.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('log a weight and see it on the dashboard', (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const RepForgeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('latest-weight')), findsOneWidget);
    expect(find.text('—'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-track')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('weight-input')), '83.2');
    await tester.tap(find.byKey(const Key('save-weight')));
    await tester.pumpAndSettle();
    expect(find.text('83.2 kg'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    // Stat tile shows value and unit separately; the activity row shows the
    // label.
    expect(find.text('83.2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    // Activity row (and the snackbar while it is still showing).
    expect(find.textContaining('83.2 kg'), findsAtLeastNWidgets(1));
  });
}
