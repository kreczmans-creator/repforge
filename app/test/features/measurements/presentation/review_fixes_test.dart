import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/features/measurements/presentation/measurement_chart_data.dart';
import 'package:repforge/ui/components/rf_trend_chart.dart';
import 'package:repforge/ui/theme.dart';

import '../../../helpers/pump.dart';
import 'measurement_harness.dart';

/// Tests for the independent review of stage 2 (H2, M1, M2, L1, L5).
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  group('H2: isolated trend values are drawn', () {
    testWidgets('every-other-day weight: trend marks are painted', (
      tester,
    ) async {
      final data = siteChartData(
        MeasurementSite.weight,
        [
          // Three-day blocks 11 days apart: each block yields one trend
          // value, more than 7 days from the next, so they stay isolated.
          for (var b = 0; b < 3; b++)
            for (var d = 0; d < 3; d++)
              reading(
                MeasurementSite.weight,
                80 + b * 0.5 + d * 0.1,
                DateTime(2026, 10, 1 + b * 11 + d, 8),
              ),
        ],
        MeasurementPeriod.weeks12,
        testNow,
      );
      final trend = data.series[1];
      expect(trend.points, isNotEmpty); // the summary claims a trend
      var isolated = 0;
      for (var i = 0; i < trend.points.length; i++) {
        final before = i > 0 && trend.points[i].joinPrevious;
        final after =
            i + 1 < trend.points.length && trend.points[i + 1].joinPrevious;
        if (!before && !after) isolated++;
      }
      expect(isolated, 3);
      expect(data.summary, contains('7-day trend, latest'));

      await tester.pumpWidget(
        MaterialApp(
          theme: rfTheme(Brightness.light),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: RfTrendChart(
                key: const Key('c'),
                series: data.series,
                unit: 'kg',
              ),
            ),
          ),
        ),
      );
      // Raw readings are circles; the square markers are the trend values.
      final chart = tester.renderObject(
        find
            .descendant(
              of: find.byKey(const Key('c')),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      final pattern = paints;
      for (var i = 0; i < isolated; i++) {
        pattern.rect();
      }
      expect(chart, pattern);
    });
  });

  group('M1: failed save', () {
    testWidgets('summary, focus on the first error, announcement (360x690)', (
      tester,
    ) async {
      final announcements = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
            m,
          ) async {
            announcements.add(m.toString());
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );
      await pumpTrack(
        tester,
        db,
        location: RfRoutes.trackEntry,
        size: const Size(360, 690),
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('field-weight')),
          matching: find.byType(TextField),
        ),
        '80.0',
      );
      // A field far below the fold.
      final far = find.descendant(
        of: find.byKey(const Key('field-forearmRight')),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(far);
      await tester.enterText(far, '5');
      await tester.pumpAndSettle();
      // Scroll back to the top: the bad field is off screen again.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const Key('field-forearmRight'))).dy,
        greaterThan(690),
      );

      // Save is reachable without scrolling.
      expect(
        tester.getRect(find.byKey(const Key('save-measurements'))).bottom,
        lessThanOrEqualTo(690),
      );
      await tester.tap(find.byKey(const Key('save-measurements')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('entry-error'))).data,
        '1 field needs attention: Right forearm',
      );
      // The field was scrolled into view and focused, error visible.
      final top = tester.getTopLeft(
        find.byKey(const Key('field-forearmRight')),
      );
      expect(top.dy, lessThan(690));
      expect(tester.widget<TextField>(far).focusNode!.hasFocus, isTrue);
      expect(find.text('Enter a value from 10.0 to 300.0 cm.'), findsOneWidget);
      expect(
        announcements.any((a) => a.contains('1 field needs attention')),
        isTrue,
      );
      await unmount(tester);
    });

    testWidgets('several errors are listed in screen order', (tester) async {
      await pumpTrack(
        tester,
        db,
        location: RfRoutes.trackEntry,
        size: const Size(360, 690),
      );
      for (final (key, text) in [
        ('field-calfLeft', '5'),
        ('field-weight', '12'),
      ]) {
        final f = find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(TextField),
        );
        await tester.ensureVisible(f);
        await tester.enterText(f, text);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-measurements')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('entry-error'))).data,
        '2 fields need attention: Weight, Left calf',
      );
      await unmount(tester);
    });
  });

  group('M2: body weight in at most three taps (UXD-008(3))', () {
    testWidgets('tab, Log weight, Save at 360x690', (tester) async {
      var taps = 0;
      Future<void> tap(Finder f) async {
        taps++;
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      await pumpTrack(
        tester,
        db,
        location: RfRoutes.home,
        size: const Size(360, 690),
      );
      await tap(find.byKey(const Key('nav-track')));
      await tap(find.byKey(const Key('log-weight')));
      // The weight field already has the focus: typing is not a tap.
      final field = find.descendant(
        of: find.byKey(const Key('field-weight')),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
      await tester.enterText(field, '81.2');
      await tap(find.byKey(const Key('save-measurements')));
      expect(taps, lessThanOrEqualTo(3));
      expect(find.text('81.2 kg · Nov 5, 2026'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('L1: comparing chosen readings', () {
    testWidgets('a later reading chosen for the earlier date is ordered', (
      tester,
    ) async {
      await pumpTrack(
        tester,
        db,
        location: '/track/compare?site=waist&a=2026-10-25&b=2026-10-26',
        seed: [
          reading(MeasurementSite.waist, 90, DateTime(2026, 10, 20, 8)),
          reading(MeasurementSite.waist, 89, DateTime(2026, 10, 28, 8)),
        ],
      );
      await tester.tap(find.byKey(const Key('choice-first-after')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('choice-second-before')));
      await tester.pumpAndSettle();
      // Oct 20 (90.0) to Oct 28 (89.0), not the reverse.
      expect(find.text('−1.0 cm'), findsOneWidget);
      expect(find.text('−1.1 %'), findsOneWidget);
      expect(
        find.textContaining(
          'From 90.0 cm on Oct 20, 2026 to 89.0 cm on Oct 28',
        ),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('the same reading for both dates says so', (tester) async {
      await pumpTrack(
        tester,
        db,
        location: '/track/compare?site=waist&a=2026-10-25&b=2026-10-26',
        seed: [reading(MeasurementSite.waist, 90, DateTime(2026, 10, 28, 8))],
      );
      await tester.tap(find.byKey(const Key('choice-first-after')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('choice-second-after')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Both dates use the same reading'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('compare-same-reading')), findsOneWidget);
      expect(find.byKey(const Key('compare-change')), findsNothing);
      await unmount(tester);
    });
  });

  group('L5: lazy lists', () {
    testWidgets('history and data table build only visible rows', (
      tester,
    ) async {
      await pumpTrack(
        tester,
        db,
        location: RfRoutes.trackSite(MeasurementSite.waist),
        size: const Size(360, 690),
        seed: [
          for (var i = 0; i < 150; i++)
            reading(
              MeasurementSite.waist,
              90 - i * 0.1,
              DateTime(2026, 11, 5, 8).subtract(Duration(days: i)),
            ),
        ],
      );
      int built(String prefix) => find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(prefix),
          )
          .evaluate()
          .length;
      expect(built('reading-'), lessThan(30));
      await tester.tap(find.byKey(const Key('period-all')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('chart-data-table')));
      await tester.tap(find.byKey(const Key('chart-data-table')));
      await tester.pumpAndSettle();
      expect(find.text('150 rows'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget); // lazy table list
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('M2/N1: Save above the keyboard', () {
    Future<void> openQuickWeight(WidgetTester tester) async {
      await pumpTrack(
        tester,
        db,
        location: RfRoutes.home,
        size: const Size(360, 690),
      );
      // A 300 px keyboard.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.tap(find.byKey(const Key('nav-track')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('log-weight')));
      await tester.pumpAndSettle();
    }

    testWidgets('Save is visible and tappable above the keyboard', (
      tester,
    ) async {
      await openQuickWeight(tester);
      final save = find.byKey(const Key('save-measurements'));
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(690 - 300));
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('field-weight')),
          matching: find.byType(TextField),
        ),
        '81.2',
      );
      await tester.tap(save); // fatal if covered
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('81.2 kg \u00b7 Nov 5, 2026'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the keyboard done key saves a weight', (tester) async {
      await openQuickWeight(tester);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('field-weight')),
          matching: find.byType(TextField),
        ),
        '80.4',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('80.4 kg \u00b7 Nov 5, 2026'), findsOneWidget);
      await unmount(tester);
    });
  });
}
