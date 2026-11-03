import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_list_tile.dart';
import 'package:repforge/ui/components/rf_macro_bar.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/components/rf_trend_chart.dart';
import 'package:repforge/ui/theme.dart';
import 'package:repforge/ui/tokens.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.dark}) =>
    MaterialApp(
      theme: rfTheme(brightness),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('RfButton', () {
    testWidgets('is at least 48 dp tall and taps once', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(RfButton(label: 'Go', onPressed: () => taps++)),
      );
      expect(
        tester.getSize(find.byType(RfButton)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.text('Go'));
      expect(taps, 1);
    });

    testWidgets('loading state ignores taps and shows a spinner', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(RfButton(label: 'Go', loading: true, onPressed: () => taps++)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Go'), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('primary button uses slate label on amber', (tester) async {
      await tester.pumpWidget(_wrap(RfButton(label: 'Go', onPressed: () {})));
      final style = tester.widget<FilledButton>(find.byType(FilledButton));
      final bg =
          style.style?.backgroundColor?.resolve({}) ??
          Theme.of(tester.element(find.byType(FilledButton)))
              .filledButtonTheme
              .style!
              .backgroundColor!
              .resolve({});
      expect(bg, RfBrand.amber);
    });
  });

  group('RfTextField.number', () {
    testWidgets('accepts one decimal and rejects letters', (tester) async {
      final c = TextEditingController();
      await tester.pumpWidget(
        _wrap(RfTextField.number(label: 'Weight', unit: 'kg', controller: c)),
      );
      await tester.enterText(find.byType(TextField), '82.4');
      expect(c.text, '82.4');
      await tester.enterText(find.byType(TextField), '82.45');
      expect(c.text, '82.4'); // second decimal rejected
      await tester.enterText(find.byType(TextField), '8a');
      expect(c.text, '82.4');
      await tester.enterText(find.byType(TextField), '82,4');
      expect(c.text, '82,4'); // comma accepted
      expect(find.text('kg'), findsOneWidget);
    });

    testWidgets('integer variant rejects decimals', (tester) async {
      final c = TextEditingController();
      await tester.pumpWidget(
        _wrap(RfTextField.integer(label: 'Reps', controller: c)),
      );
      await tester.enterText(find.byType(TextField), '12');
      expect(c.text, '12');
      await tester.enterText(find.byType(TextField), '12.5');
      expect(c.text, '125'); // digitsOnly strips the separator
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(
        tf.inputFormatters,
        contains(FilteringTextInputFormatter.digitsOnly),
      );
    });
  });

  group('RfMacroBar', () {
    testWidgets('clamps progress and exposes value semantics', (tester) async {
      await tester.pumpWidget(
        _wrap(const RfMacroBar(label: 'Protein', amount: 250, target: 200)),
      );
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 1.0);
      expect(find.bySemanticsLabel('Protein'), findsOneWidget);
      expect(find.text('250 / 200 g'), findsOneWidget);
    });

    testWidgets('zero target renders empty bar without error', (tester) async {
      await tester.pumpWidget(
        _wrap(const RfMacroBar(label: 'Fat', amount: 10, target: 0)),
      );
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.0);
    });
  });

  group('RfTrendChart', () {
    for (final n in [0, 1, 2, 30]) {
      testWidgets('renders with $n points', (tester) async {
        final points = [
          for (var i = 0; i < n; i++)
            RfTrendPoint(DateTime(2026, 1, 1 + i), 80 + (i % 5) * 0.4),
        ];
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              width: 360,
              child: RfTrendChart(
                unit: 'kg',
                series: [RfTrendSeries(label: 'Weight', points: points)],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        if (n == 0) {
          expect(find.text('No data yet.'), findsOneWidget);
        } else {
          expect(find.byType(CustomPaint), findsWidgets);
        }
      });
    }

    testWidgets('single-point series and wide tick labels render', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 360,
            child: RfTrendChart(
              unit: 'kg',
              series: [
                RfTrendSeries(
                  label: 'Volume',
                  points: [
                    RfTrendPoint(DateTime(2026, 10), 10000),
                    RfTrendPoint(DateTime(2026, 10, 29), 12345.6),
                  ],
                ),
                RfTrendSeries(
                  label: 'Single',
                  points: [RfTrendPoint(DateTime(2026, 10), 11000)],
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Volume'), findsOneWidget);
      expect(find.text('Single'), findsOneWidget);
    });

    testWidgets('flat series (all equal values) does not divide by zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 360,
            child: RfTrendChart(
              series: [
                RfTrendSeries(
                  label: 'W',
                  points: [
                    RfTrendPoint(DateTime(2026), 80),
                    RfTrendPoint(DateTime(2026, 1, 2), 80),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('RfListTile', () {
    testWidgets('is at least 48 dp tall', (tester) async {
      await tester.pumpWidget(
        _wrap(const RfListTile(title: 'Weigh-in', subtitle: 'Today')),
      );
      expect(
        tester.getSize(find.byType(RfListTile)).height,
        greaterThanOrEqualTo(48),
      );
    });
  });

  group('Theme', () {
    testWidgets('respects user text scaling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: rfTheme(Brightness.light),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(body: Text('Scaled')),
          ),
        ),
      );
      final size = tester.getSize(find.text('Scaled'));
      expect(size.height, greaterThan(30));
    });
  });
}
