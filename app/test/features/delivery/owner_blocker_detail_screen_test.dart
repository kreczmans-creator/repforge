import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/delivery/owner_blocker.dart';
import 'package:repforge/domain/delivery/owner_blocker_register.dart';
import 'package:repforge/features/delivery/application/blocker_providers.dart';
import 'package:repforge/features/delivery/presentation/owner_blocker_detail_screen.dart';
import 'package:repforge/features/delivery/presentation/owner_blockers_screen.dart';
import 'package:repforge/ui/theme.dart';

import '../../helpers/pump.dart';
import 'blocker_fixtures.dart';

Widget _harness(
  AppDatabase db,
  Widget home, {
  Brightness brightness = Brightness.dark,
  List<OwnerBlocker>? register,
  Clock? clock,
}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    clockProvider.overrideWithValue(
      clock ?? FixedClock(DateTime.utc(2026, 11, 6, 9, 30)),
    ),
    ownerBlockerRegisterProvider.overrideWithValue(register ?? testRegister),
  ],
  child: MaterialApp(theme: rfTheme(brightness), home: home),
);

Finder _option(String label) => find.descendant(
  of: find.byKey(const Key('blocker-status-choice')),
  matching: find.text(label),
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

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('blocker-save-status')));
    await tester.tap(find.byKey(const Key('blocker-save-status')));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String label) async {
    await tester.ensureVisible(_option(label));
    await tester.tap(_option(label));
    await tester.pump();
  }

  bool saveEnabled(WidgetTester tester) => tester
      .widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('blocker-save-status')),
          matching: find.byType(FilledButton),
        ),
      )
      .enabled;

  testWidgets('the status control lists every full label', (tester) async {
    tall(tester);
    await tester.pumpWidget(_harness(db, detail));
    await tester.pumpAndSettle();
    for (final s in BlockerStatus.values) {
      expect(_option(s.label), findsOneWidget, reason: s.label);
    }
    await unmount(tester);
  });

  testWidgets('a saved status and note persist and show in the list', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(_harness(db, detail));
    await tester.pumpAndSettle();

    await choose(tester, 'Resolved');
    expect(find.text('Selected: Resolved'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('blocker-note-field')),
      '  Verified on device  ',
    );
    await save(tester);
    expect(find.text('Status saved'), findsOneWidget);
    expect(find.text('Changed 6 Nov 2026, 09:30 UTC'), findsOneWidget);

    // A fresh widget over the same database shows the stored values.
    await unmount(tester);
    await tester.pumpWidget(_harness(db, detail));
    await tester.pumpAndSettle();
    expect(find.text('Verified on device'), findsWidgets);
    expect(find.text('Changed 6 Nov 2026, 09:30 UTC'), findsOneWidget);
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

  testWidgets('history lists two changes newest first after two saves', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(
      _harness(
        db,
        detail,
        clock: AdvancingClock(DateTime.utc(2026, 11, 7, 6, 30)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No changes recorded in the app yet.'), findsOneWidget);

    await choose(tester, 'In progress');
    await tester.enterText(
      find.byKey(const Key('blocker-note-field')),
      'first note',
    );
    await save(tester);
    await choose(tester, 'Resolved');
    await tester.enterText(
      find.byKey(const Key('blocker-note-field')),
      'second note',
    );
    await save(tester);

    expect(find.byKey(const Key('blocker-history')), findsOneWidget);
    expect(find.textContaining('Changed 7 Nov 2026, 06:3'), findsOneWidget);
    final newest = find.byKey(const Key('blocker-history-0'));
    final older = find.byKey(const Key('blocker-history-1'));
    expect(find.byKey(const Key('blocker-history-2')), findsNothing);
    expect(
      find.descendant(of: newest, matching: find.text('Resolved')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: newest, matching: find.text('second note')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: newest,
        matching: find.textContaining('7 Nov 2026, 06:3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: older, matching: find.text('In progress')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: older, matching: find.text('first note')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: older, matching: find.text('7 Nov 2026, 06:30 UTC')),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('Save is disabled until the status or the note changes', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(_harness(db, detail));
    await tester.pumpAndSettle();
    expect(saveEnabled(tester), isFalse);

    await choose(tester, 'Open');
    expect(saveEnabled(tester), isTrue);
    await choose(tester, 'Awaiting external verification');
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(find.byKey(const Key('blocker-note-field')), '   ');
    await tester.pump();
    expect(saveEnabled(tester), isFalse);
    await tester.enterText(find.byKey(const Key('blocker-note-field')), 'x');
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
    await unmount(tester);
  });

  testWidgets('resolving an owner decision without a note shows an error', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(
      _harness(db, const OwnerBlockerDetailScreen(blockerId: 'OB-A')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('blocker-resolution-hint')), findsNothing);
    await choose(tester, 'Resolved');
    expect(
      find.text(
        'Record the decision in the note; agents never resolve owner items.',
      ),
      findsOneWidget,
    );
    await save(tester);
    expect(find.byKey(const Key('blocker-status-error')), findsOneWidget);
    expect(find.text('Status saved'), findsNothing);
    expect(find.text('No changes recorded in the app yet.'), findsOneWidget);
    expect(await db.select(db.settings).get(), isEmpty);
    await unmount(tester);
  });

  testWidgets('a device action resolves without a note and hides the hint', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(
      _harness(db, const OwnerBlockerDetailScreen(blockerId: 'OB-C')),
    );
    await tester.pumpAndSettle();
    await choose(tester, 'Resolved');
    expect(find.byKey(const Key('blocker-resolution-hint')), findsNothing);
    await save(tester);
    expect(find.text('Status saved'), findsOneWidget);
    expect(find.byKey(const Key('blocker-status-error')), findsNothing);
    expect(find.byKey(const Key('blocker-history-0')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a note-only edit saves', (tester) async {
    tall(tester);
    await tester.pumpWidget(_harness(db, detail));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('blocker-note-field')),
      'waiting on lab',
    );
    await tester.pump();
    await save(tester);
    expect(find.text('Status saved'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('blocker-history-0')),
        matching: find.text('waiting on lab'),
      ),
      findsOneWidget,
    );
    expect(saveEnabled(tester), isFalse);
    await unmount(tester);
  });

  testWidgets('reopening a resolved item keeps the resolution in history', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(
      _harness(
        db,
        const OwnerBlockerDetailScreen(blockerId: 'OB-A'),
        clock: AdvancingClock(DateTime.utc(2026, 11, 7, 6, 30)),
      ),
    );
    await tester.pumpAndSettle();
    await choose(tester, 'Resolved');
    await tester.enterText(
      find.byKey(const Key('blocker-note-field')),
      'Approved scope',
    );
    await save(tester);
    await choose(tester, 'Open');
    await tester.enterText(find.byKey(const Key('blocker-note-field')), '');
    await save(tester);

    final newest = find.byKey(const Key('blocker-history-0'));
    final resolution = find.byKey(const Key('blocker-history-1'));
    expect(
      find.descendant(of: newest, matching: find.text('Open')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: resolution, matching: find.text('Resolved')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: resolution, matching: find.text('Approved scope')),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('the note field limits input to 500 characters with a counter', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(_harness(db, detail));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('blocker-note-field')),
      'x' * 501,
    );
    await tester.pump();
    expect(find.text('500/500'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('evidence and the record path are selectable', (tester) async {
    tall(tester);
    await tester.pumpWidget(_harness(db, detail));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsNWidgets(3));
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('every real register entry renders in ${brightness.name} at '
          '${scale}x text, 360 px wide', (tester) async {
        // Tall enough that the lazy list lays out every section.
        tester.view.physicalSize = const Size(360, 6000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final b in ownerBlockerRegister) {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 900),
                textScaler: TextScaler.linear(scale),
              ),
              child: _harness(
                db,
                OwnerBlockerDetailScreen(blockerId: b.id),
                brightness: brightness,
                register: ownerBlockerRegister,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: b.id);
          expect(find.text(b.title), findsOneWidget, reason: b.id);
        }
        expect(ownerBlockerRegister, isNotEmpty);
        await unmount(tester);
      });
    }
  }
}
