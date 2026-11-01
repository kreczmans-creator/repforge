import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  testWidgets('bottom navigation switches between Home and Weight', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: RepForgeApp(router: createRouter()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your cockpit'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-weight')));
    await tester.pumpAndSettle();
    expect(find.text('Body weight'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    expect(find.text('Your cockpit'), findsOneWidget);

    // Unmount inside the body so drift's stream-cleanup timer fires in the
    // test zone (see weight_screen_test.dart).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
