import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/platform/fake_barcode_scanner.dart';
import 'package:repforge/data/platform/fake_rest_alert_scheduler.dart';
import 'package:repforge/data/platform/fake_user_file_gateway.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_lookup_service.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/training/rest_alert.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/application/scanner_preview.dart';
import 'package:repforge/features/training/application/rest_timer_controller.dart';

import '../test/helpers/scrolling.dart';

/// End-to-end flows on a real device or emulator. The first test uses an
/// in-memory database so it leaves nothing behind; the last test uses the
/// real on-device database file to prove that the production open path,
/// migrations and persistence across an app rebuild work on the device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpApp(
    WidgetTester tester, {
    AppDatabase? db,
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (db != null) databaseProvider.overrideWithValue(db),
          ...overrides,
        ],
        child: const RepForgeApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// On a device, `pumpAndSettle` returns as soon as no frame is scheduled,
  /// which happens while the app awaits a database write (no frame is
  /// pending during I/O). Pump until [finder] matches or [timeout] elapses.
  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(end)) {
        fail('Timed out waiting for $finder');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  /// Like [pumpUntil], for a finder that must match exactly [count] widgets
  /// (a fixed pump before such an assertion can be too short on a slow
  /// emulator).
  Future<void> pumpUntilCount(
    WidgetTester tester,
    Finder finder,
    int count, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().length != count) {
      if (DateTime.now().isAfter(end)) {
        fail('Timed out waiting for $count x $finder');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  /// Counterpart of [pumpUntil] for a widget that must disappear.
  Future<void> pumpUntilGone(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().isNotEmpty) {
      if (DateTime.now().isAfter(end)) {
        fail('Timed out waiting for $finder to disappear');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  /// Forms are lazy `ListView`s: on a phone-sized screen the save button is
  /// not built until scrolled into view, so `ensureVisible` cannot find it.
  /// The soft keyboard is dismissed first: its inset animation re-lays the
  /// list after the scroll and can unbuild the target again (run
  /// 41818013580 found `food-save` and then lost it before the tap).
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 3; attempt++) {
      await tester.scrollUntilVisible(
        finder,
        200,
        // Vertical only: a TextField's horizontal scroller can be last.
        scrollable: lastPageScrollable(),
      );
      await tester.pumpAndSettle();
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Could not keep $finder in view');
  }

  Finder keyWithPrefix(String prefix) => find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> && k.value.startsWith(prefix);
  });

  /// Track tab -> Add measurements -> weight (and optional note) -> Save.
  /// Save sits below the form, above the keyboard; the keyboard is dismissed
  /// first anyway so its inset animation cannot move the target under the
  /// tap.
  Future<void> logWeight(WidgetTester tester, String kg, {String? note}) async {
    await tester.tap(find.byKey(const Key('nav-track')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-measurements')));
    await pumpUntil(tester, find.byKey(const Key('field-weight')));
    await tester.enterText(find.byKey(const Key('field-weight')), kg);
    if (note != null) {
      await scrollTo(tester, find.byKey(const Key('note-input')));
      await tester.enterText(find.byKey(const Key('note-input')), note);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-measurements')));
    // Saving returns to the Track home, which lists the latest weight.
    await pumpUntil(tester, find.textContaining('$kg kg'));
    // The confirmation snackbar covers the bottom of the screen for a few
    // seconds; wait for it so it cannot swallow a later tap.
    await pumpUntilGone(tester, find.text('Saved 1 measurement'));
  }

  Future<void> restart(WidgetTester tester, {AppDatabase? db}) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp(tester, db: db);
  }

  testWidgets('weight, targets and food logging end to end (in-memory db)', (
    tester,
  ) async {
    final db = AppDatabase.inMemory();
    // A close that never completes (streams still open after a failed
    // assertion) must not hang the whole emulator job.
    addTearDown(
      () => db.close().timeout(const Duration(seconds: 10), onTimeout: () {}),
    );
    await pumpApp(tester, db: db);

    // Dashboard starts empty.
    expect(find.byKey(const Key('latest-weight')), findsOneWidget);
    expect(find.text('—'), findsOneWidget);

    // Track: log a weight.
    await logWeight(tester, '83.2');
    expect(find.textContaining('83.2 kg'), findsOneWidget);

    // Settings: calorie target.
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('target-calories')), '2100');
    await scrollTo(tester, find.byKey(const Key('save-targets')));
    await tester.tap(find.byKey(const Key('save-targets')));
    await pumpUntil(tester, find.text('Targets saved'));
    expect(find.text('Targets saved'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Fuel: create a custom food through the UI and log 150 g of it.
    await tester.tap(find.byKey(const Key('nav-fuel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('log-food')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-food')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('food-name')), 'Test oats');
    await tester.enterText(find.byKey(const Key('food-kcal')), '380');
    await tester.enterText(find.byKey(const Key('food-protein')), '13');
    await tester.enterText(find.byKey(const Key('food-carbs')), '60');
    await tester.enterText(find.byKey(const Key('food-fat')), '7');
    await scrollTo(tester, find.byKey(const Key('food-save')));
    await tester.tap(find.byKey(const Key('food-save')));
    // Portion sheet opens for the new food once the insert completes.
    await pumpUntil(tester, find.byKey(const Key('portion-amount')));
    expect(find.byKey(const Key('portion-amount')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('portion-amount')), '150');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('portion-log')));
    // Back on the diary: 380 × 1.5 = 570 kcal.
    await pumpUntil(tester, find.text('Test oats'));
    expect(find.text('Test oats'), findsOneWidget);
    expect(find.text('570'), findsWidgets);

    // Dashboard reflects both after a simulated restart on the same db.
    await restart(tester, db: db);
    await pumpUntil(tester, find.text('570 of 2100'));
    expect(find.text('570 of 2100'), findsOneWidget);
    expect(find.text('83.2'), findsOneWidget);
  });

  testWidgets('owner actions workspace is reachable from Settings and a '
      'status change survives a restart (in-memory db)', (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(
      () => db.close().timeout(const Duration(seconds: 10), onTimeout: () {}),
    );
    await pumpApp(tester, db: db);

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('open-owner-actions')));
    await tester.tap(find.byKey(const Key('open-owner-actions')));
    await pumpUntil(tester, find.byKey(const Key('blockers-summary')));
    expect(find.byKey(const Key('blockers-summary')), findsOneWidget);

    // Open the highest-priority WP 8 item and record a status change.
    await scrollTo(tester, find.byKey(const Key('blocker-row-OB-WP8-01')));
    await tester.tap(find.byKey(const Key('blocker-row-OB-WP8-01')));
    // The detail page is a lazy list: wait for its app bar, then scroll to
    // each control (the status list sits below the fold on a phone).
    await pumpUntil(tester, find.widgetWithText(AppBar, 'OB-WP8-01'));
    final inProgress = find.descendant(
      of: find.byKey(const Key('blocker-status-choice')),
      matching: find.text('In progress'),
    );
    await scrollTo(tester, inProgress);
    await tester.tap(inProgress);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('blocker-note-field')),
      'integration-test note',
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('blocker-save-status')));
    await tester.tap(find.byKey(const Key('blocker-save-status')));
    await pumpUntil(tester, find.text('Status saved'));

    // After a simulated restart on the same database the change is shown.
    await restart(tester, db: db);
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('open-owner-actions')));
    await tester.tap(find.byKey(const Key('open-owner-actions')));
    await pumpUntil(tester, find.byKey(const Key('blocker-row-OB-WP8-01')));
    await scrollTo(tester, find.byKey(const Key('blocker-row-OB-WP8-01')));
    await tester.tap(find.byKey(const Key('blocker-row-OB-WP8-01')));
    await pumpUntil(tester, find.widgetWithText(AppBar, 'OB-WP8-01'));
    await scrollTo(tester, find.byKey(const Key('blocker-state-updated')));
    // The note appears in the note field and in the history card.
    expect(find.text('integration-test note'), findsWidgets);
    expect(find.textContaining('Changed '), findsWidgets);
  });

  testWidgets('export measurements CSV and a backup through the fake file '
      'gateway (in-memory db, WP 10 stage 3b)', (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(
      () => db.close().timeout(const Duration(seconds: 10), onTimeout: () {}),
    );
    // No real share sheet: the fake records what would have been shared.
    final gateway = FakeUserFileGateway();
    await pumpApp(
      tester,
      db: db,
      overrides: [userFileGatewayProvider.overrideWithValue(gateway)],
    );

    await logWeight(tester, '83.2');

    // Track home: Export CSV hands the CSV to the gateway.
    await scrollTo(tester, find.byKey(const Key('export-csv')));
    await tester.tap(find.byKey(const Key('export-csv')));
    await pumpUntil(tester, find.byKey(const Key('export-feedback')));
    final csv = gateway.exports.single;
    expect(csv.mimeType, 'text/csv');
    expect(csv.fileName, startsWith('repforge-measurements-'));
    final lines = csv.text.split('\r\n');
    expect(lines.first, 'date,type,value,unit');
    expect(lines[1], endsWith(',Weight,83.2,kg'));
    expect(find.textContaining('saved'), findsNothing);
    await pumpUntilGone(tester, find.byKey(const Key('export-feedback')));

    // Settings > Backup and restore: the JSON backup contains the reading.
    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('open-backup')));
    await tester.tap(find.byKey(const Key('open-backup')));
    await pumpUntil(tester, find.byKey(const Key('export-backup')));
    await tester.tap(find.byKey(const Key('export-backup')));
    await pumpUntil(tester, find.byKey(const Key('backup-status')));
    final backup = gateway.exports.last;
    expect(backup.mimeType, 'application/json');
    expect(backup.fileName, startsWith('repforge-backup-'));
    expect(backup.text, contains('"app": "repforge"'));
    expect(backup.text, contains('83.2'));
    expect(gateway.exports, hasLength(2));
  });

  testWidgets('recipe logged earlier keeps its values after the recipe is '
      'edited (in-memory db, RCP-013)', (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(
      () => db.close().timeout(const Duration(seconds: 10), onTimeout: () {}),
    );
    await pumpApp(tester, db: db);

    await tester.tap(find.byKey(const Key('nav-fuel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-recipes')));
    await pumpUntil(tester, find.byKey(const Key('new-recipe')));
    await tester.tap(find.byKey(const Key('new-recipe')));
    await pumpUntil(tester, find.byKey(const Key('recipe-name-field')));
    await tester.enterText(
      find.byKey(const Key('recipe-name-field')),
      'IT stew',
    );
    await tester.enterText(find.byKey(const Key('recipe-portions-field')), '2');

    // Ingredient: create a custom food from the picker (380 kcal/100 g).
    await scrollTo(tester, find.byKey(const Key('add-ingredient')));
    await tester.tap(find.byKey(const Key('add-ingredient')));
    await pumpUntil(tester, find.byKey(const Key('new-food')));
    await tester.tap(find.byKey(const Key('new-food')));
    await pumpUntil(tester, find.byKey(const Key('food-name')));
    await tester.enterText(find.byKey(const Key('food-name')), 'IT oats');
    await tester.enterText(find.byKey(const Key('food-kcal')), '380');
    await tester.enterText(find.byKey(const Key('food-protein')), '13');
    await tester.enterText(find.byKey(const Key('food-carbs')), '60');
    await tester.enterText(find.byKey(const Key('food-fat')), '7');
    await scrollTo(tester, find.byKey(const Key('food-save')));
    await tester.tap(find.byKey(const Key('food-save')));
    await pumpUntil(tester, find.byKey(const Key('ingredient-amount')));
    await tester.enterText(find.byKey(const Key('ingredient-amount')), '200');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ingredient-save')));
    await pumpUntil(tester, find.byKey(const Key('ingredient-0')));

    await scrollTo(tester, find.byKey(const Key('recipe-save')));
    await tester.tap(find.byKey(const Key('recipe-save')));
    // Detail of the new recipe: 200 g x 3.8 / 2 = 380 kcal per portion.
    await pumpUntil(tester, find.byKey(const Key('recipe-log')));

    // Log 1.5 portions: 570 kcal.
    await tester.tap(find.byKey(const Key('recipe-log')));
    await pumpUntil(tester, find.byKey(const Key('log-portions-inc')));
    await tester.tap(find.byKey(const Key('log-portions-inc')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('log-submit')));
    await pumpUntil(tester, find.textContaining('Logged 1.5 portions'));

    // Edit the recipe: 100 g instead of 200 g (190 kcal per portion).
    await tester.tap(find.byKey(const Key('recipe-edit')));
    await pumpUntil(tester, find.byKey(const Key('ingredient-0')));
    // The row can be below the fold on a short screen (review N1).
    await scrollTo(tester, find.byKey(const Key('ingredient-0')));
    await tester.tap(find.byKey(const Key('ingredient-0')));
    await pumpUntil(tester, find.byKey(const Key('ingredient-amount')));
    await tester.enterText(find.byKey(const Key('ingredient-amount')), '100');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ingredient-save')));
    await pumpUntil(tester, find.text('100 g'));
    await scrollTo(tester, find.byKey(const Key('recipe-save')));
    await tester.tap(find.byKey(const Key('recipe-save')));
    await pumpUntilGone(tester, find.byKey(const Key('recipe-name-field')));

    // The earlier diary entry is unchanged.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await pumpUntil(tester, find.text('IT stew'));
    // On a device the "Logged 1.5 portions" snackbar can still be showing
    // (run 41894402215 matched it as a second "1.5 portions"); let it clear,
    // then assert on the diary row itself, including the logged snapshot.
    await pumpUntilGone(tester, find.textContaining('Logged 1.5 portions'));
    expect(find.text('570'), findsWidgets);
    expect(find.text('1.5 portions · P 20 · C 90 · F 11'), findsOneWidget);
  });

  testWidgets('scan a known barcode and log it (fake scanner)', (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(
      () => db.close().timeout(const Duration(seconds: 10), onTimeout: () {}),
    );
    final now = DateTime.now();
    final seeder = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    await seeder
        .read(foodRepositoryProvider)
        .upsert(
          Food(
            id: 'it-hazelnut',
            name: 'Scan test spread',
            barcode: '3017624010701',
            profile: const NutrientProfile(
              per100: ReferenceUnit.grams,
              per100Amounts: NutrientAmounts(kcal: 500),
              provenance: DataProvenance.userEntered,
            ),
            source: FoodSource.userCreated,
            createdAt: now,
            updatedAt: now,
          ),
        );
    seeder.dispose();

    final scanner = FakeBarcodeScanner();
    await pumpApp(
      tester,
      db: db,
      overrides: [
        barcodeScannerProvider.overrideWithValue(scanner),
        scannerPreviewBuilderProvider.overrideWithValue(
          (_) => const ColoredBox(color: Colors.black),
        ),
        foodLookupServiceProvider.overrideWithValue(_NoMatchLookup()),
      ],
    );

    Future<void> openScan() async {
      await tester.tap(find.byKey(const Key('nav-fuel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('log-food')));
      await tester.pumpAndSettle();
      await pumpUntil(tester, find.byKey(const Key('scan-barcode')));
      await tester.tap(find.byKey(const Key('scan-barcode')));
      await pumpUntil(tester, find.byKey(const Key('scan-cancel')));
    }

    await openScan();
    scanner
      ..emit('3017624010701')
      ..emit('3017624010701'); // same label held in view
    await pumpUntil(tester, find.byKey(const Key('portion-amount')));
    await tester.enterText(find.byKey(const Key('portion-amount')), '25');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('portion-log')));
    await pumpUntil(tester, find.text('Scan test spread'));
    expect(find.text('Scan test spread'), findsOneWidget);
    expect(find.text('125'), findsWidgets); // 500 kcal/100 g x 25 g

    // A further emission shortly after must do nothing: the scanner is
    // stopped, no sheet opens and no second entry appears.
    scanner.emit('3017624010701');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('portion-amount')), findsNothing);
    expect(find.text('Scan test spread'), findsOneWidget);
    expect(await db.select(db.foodLogEntries).get(), hasLength(1));

    // Not-found path: nothing is created or logged.
    await tester.tap(find.byKey(const Key('log-food')));
    await tester.pumpAndSettle();
    await pumpUntil(tester, find.byKey(const Key('scan-barcode')));
    await tester.tap(find.byKey(const Key('scan-barcode')));
    await pumpUntil(tester, find.byKey(const Key('scan-cancel')));
    scanner.emit('2000000000008');
    await pumpUntil(tester, find.byKey(const Key('scan-not-found')));
    expect(find.byKey(const Key('scan-create-food')), findsOneWidget);
    expect(find.byKey(const Key('scan-search-manually')), findsOneWidget);
    expect(await db.select(db.foodLogEntries).get(), hasLength(1));
    expect(await db.select(db.foods).get(), hasLength(1));
  });

  testWidgets('full training session: plan, one-tap sets, rest timer, PR, '
      'finish, history (in-memory db, fake alerts)', (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(
      () => db.close().timeout(const Duration(seconds: 10), onTimeout: () {}),
    );
    // Seed an exercise and a plan with a 60 s rest, and switch the rest
    // notifications on (the fake scheduler grants permission).
    final now = DateTime.now().toUtc();
    final seeder = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    await seeder
        .read(exerciseRepositoryProvider)
        .upsert(
          Exercise(
            id: 'it-squat',
            name: 'IT back squat',
            type: ExerciseType.weighted,
            category: ExerciseCategory.legs,
            primaryMuscle: MuscleGroup.quadriceps,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await seeder
        .read(workoutPlanRepositoryProvider)
        .upsert(
          WorkoutPlan(
            id: 'it-plan',
            name: 'IT leg day',
            createdAt: now,
            updatedAt: now,
            exercises: [
              PlanExercise(
                id: 'it-plan-row',
                exerciseId: 'it-squat',
                sortOrder: 0,
                targetSets: 3,
                repsMin: 5,
                repsMax: 5,
                targetLoad: LoadKg.fromStored(60),
                restSeconds: 60,
              ),
            ],
          ),
        );
    final settings = seeder.read(settingsRepositoryProvider);
    await settings.save(
      (await settings.read()).copyWith(restTimerNotifications: true),
    );
    seeder.dispose();

    final scheduler = FakeRestAlertScheduler();
    await pumpApp(
      tester,
      db: db,
      overrides: [
        restAlertProvider.overrideWithValue(_SilentRestAlert()),
        restAlertSchedulerProvider.overrideWithValue(scheduler),
      ],
    );

    Finder keyStartingWith(String prefix) => find.byWidgetPredicate((w) {
      final k = w.key;
      return k is ValueKey<String> && k.value.startsWith(prefix);
    });

    // While the rest timer runs its one-second tick keeps scheduling frames,
    // so pumpAndSettle would never return: pump frames until [finder] shows.
    Future<void> pumpFramesUntil(Finder finder) async {
      final end = DateTime.now().add(const Duration(seconds: 15));
      while (finder.evaluate().isEmpty) {
        if (DateTime.now().isAfter(end)) fail('Timed out waiting for $finder');
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Lets the database read and the scheduler call finish without
    // pumpAndSettle (the timer's tick never settles).
    Future<void> pumpIo() async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // Train tab > Plans > start the plan.
    await tester.tap(find.byKey(const Key('nav-train')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('open-plans')));
    await tester.tap(find.byKey(const Key('open-plans')));
    await pumpUntil(tester, find.byKey(const Key('plan-start-it-plan')));
    await scrollTo(tester, find.byKey(const Key('plan-start-it-plan')));
    await tester.tap(find.byKey(const Key('plan-start-it-plan')));
    await pumpUntil(tester, keyStartingWith('newset-log-'));
    expect(find.byKey(const Key('rest-timer-panel')), findsNothing);

    // Set 1: one tap on the pre-filled row (60 kg x 5 from the plan).
    final log = keyStartingWith('newset-log-');
    await scrollTo(tester, log);
    await tester.tap(log);
    await pumpFramesUntil(find.byKey(const Key('rest-timer-panel')));
    expect(find.byKey(const Key('rest-remaining')), findsOneWidget);
    // In the foreground nothing is scheduled; going to the background
    // schedules the notification for the timer's end and coming back cancels
    // it (ADR-0007).
    await pumpIo();
    expect(scheduler.scheduled, isEmpty);
    // `inactive` counts as background for the rest alert but, unlike
    // `paused`, the engine still draws frames, so pumping keeps working.
    void goBackground() => TestWidgetsFlutterBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    void goForeground() => TestWidgetsFlutterBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    goBackground();
    await pumpIo();
    final firstEnd = scheduler.scheduled[restNotificationId];
    expect(firstEnd, isNotNull);
    goForeground();
    await pumpIo();
    expect(scheduler.scheduled, isEmpty);

    // +15 s moves the end by at least 15 s (real clock); in the background
    // it is rescheduled for the new end.
    await tester.tap(find.byKey(const Key('rest-extend')));
    goBackground();
    await pumpIo();
    expect(
      scheduler.scheduled[restNotificationId]!.difference(firstEnd!),
      greaterThanOrEqualTo(const Duration(seconds: 15)),
    );
    goForeground();
    await pumpIo();

    // Skip hides the panel and cancels the notification.
    await tester.tap(find.byKey(const Key('rest-skip')));
    await pumpIo();
    expect(find.byKey(const Key('rest-timer-panel')), findsNothing);
    expect(scheduler.scheduled, isEmpty);
    await tester.pumpAndSettle();

    // The first set of an exercise is a personal record.
    await pumpUntil(tester, keyStartingWith('pr-badge-'));
    expect(keyStartingWith('pr-badge-'), findsOneWidget);

    // Set 2: another one-tap log (a tie, not a record), then skip.
    await scrollTo(tester, log);
    await tester.tap(log);
    await pumpFramesUntil(find.byKey(const Key('rest-timer-panel')));
    await tester.tap(find.byKey(const Key('rest-skip')));
    await pumpUntilCount(tester, keyStartingWith('set-text-'), 2);
    expect(keyStartingWith('set-text-'), findsNWidgets(2));
    expect(keyStartingWith('pr-badge-'), findsOneWidget);

    // Finish: the summary opens.
    await scrollTo(tester, find.byKey(const Key('finish-session')));
    await tester.tap(find.byKey(const Key('finish-session')));
    await pumpUntil(tester, find.byKey(const Key('detail-title')));
    expect(find.text('IT leg day'), findsWidgets);

    // The finished workout is in the history. The summary replaced the
    // session screen, so back leads to the plans list and then the Train tab.
    await tester.pageBack();
    await pumpUntil(tester, find.byKey(const Key('plan-start-it-plan')));
    await tester.pageBack();
    await pumpUntil(tester, find.byKey(const Key('open-history')));
    await scrollTo(tester, find.byKey(const Key('open-history')));
    await tester.tap(find.byKey(const Key('open-history')));
    await pumpUntil(tester, keyStartingWith('history-session-'));
    expect(keyStartingWith('history-session-'), findsOneWidget);
    expect(find.text('IT leg day'), findsWidgets);
  });

  testWidgets('real on-device database opens, migrates, persists a weight '
      'and a target across a fresh connection', (tester) async {
    await pumpApp(tester); // production providers: real file database
    await logWeight(tester, '77.7', note: 'integration-test');
    expect(find.textContaining('77.7 kg'), findsOneWidget);

    // WP 4 B1: a target written through Settings must survive a restart.
    // restart() disposes the ProviderScope, which closes the file database
    // (databaseProvider.onDispose) and the rebuilt app opens a FRESH
    // connection to the same persisted file.
    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('target-calories')), '2345');
    await scrollTo(tester, find.byKey(const Key('save-targets')));
    await tester.tap(find.byKey(const Key('save-targets')));
    await pumpUntil(tester, find.text('Targets saved'));

    await restart(tester);
    await pumpUntil(tester, find.text('0 of 2345'));
    expect(find.text('0 of 2345'), findsOneWidget);

    // Clean up the target so repeated runs on one device start clean.
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('target-calories')), '');
    await scrollTo(tester, find.byKey(const Key('save-targets')));
    await tester.tap(find.byKey(const Key('save-targets')));
    await pumpUntil(tester, find.text('Targets saved'));
    await tester.pageBack();
    await pumpUntilGone(tester, find.text('0 of 2345'));

    await tester.tap(find.byKey(const Key('nav-track')));
    await pumpUntil(tester, find.byKey(const Key('site-weight')));
    await tester.tap(find.byKey(const Key('site-weight')));
    await pumpUntil(tester, find.byKey(const Key('chart-summary')));
    // The history is a lazy sliver list: scroll the reading into view.
    await scrollTo(tester, find.textContaining('integration-test'));
    expect(find.textContaining('integration-test'), findsOneWidget);

    // Clean up so repeated runs on one device do not accumulate rows: delete
    // the reading through its delete button and the confirmation.
    final row = find.ancestor(
      of: find.textContaining('integration-test'),
      matching: keyWithPrefix('reading-'),
    );
    await tester.tap(
      find.descendant(of: row, matching: keyWithPrefix('delete-')),
    );
    await pumpUntil(tester, find.byKey(const Key('delete-confirm')));
    await tester.tap(find.byKey(const Key('delete-confirm')));
    await pumpUntilGone(tester, find.textContaining('integration-test'));
    expect(find.textContaining('integration-test'), findsNothing);
  });
}

/// Online lookup that knows nothing, so unknown barcodes are "not found".
final class _NoMatchLookup implements FoodLookupService {
  @override
  Future<Result<List<Food>>> search(String query, {int limit = 20}) async =>
      const Ok([]);

  @override
  Future<Result<Food?>> byBarcode(String barcode) async => const Ok(null);
}

/// Foreground alert that does nothing, so the emulator does not vibrate.
final class _SilentRestAlert implements RestAlert {
  @override
  Future<void> fire() async {}
}
