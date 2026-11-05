import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/ui/components/rf_trend_chart.dart';
import 'package:repforge/ui/theme.dart';

Widget _wrap(Widget child, {double width = 320}) => MaterialApp(
  theme: rfTheme(Brightness.light),
  home: Scaffold(
    body: SingleChildScrollView(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  final series = [
    RfTrendSeries(
      label: 'Left',
      points: [
        RfTrendPoint(DateTime(2026, 11), 55),
        RfTrendPoint(DateTime(2026, 11, 2), 55.5),
      ],
    ),
    RfTrendSeries(
      label: 'Right',
      marker: RfTrendMarker.diamond,
      dashed: true,
      points: [RfTrendPoint(DateTime(2026, 11), 54.5)],
    ),
  ];

  testWidgets('legend labels every series; chart announces them', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(RfTrendChart(series: series, unit: 'cm')));
    expect(find.text('Left'), findsOneWidget);
    expect(find.text('Right'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp('Trend chart, 3 values.*Series: Left, Right'),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('the data table lists every instant and series, accessibly', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(RfTrendChart(series: series, unit: 'cm', showDataTable: true)),
    );
    // Collapsed by default: the rows are not in the tree yet.
    expect(find.bySemanticsLabel(RegExp('Left: 55 cm')), findsNothing);
    await tester.tap(find.byKey(const Key('chart-data-table')));
    await tester.pumpAndSettle();
    expect(find.text('2 rows'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp(r'Nov 1, 2026 00:00\. Left: 55 cm\. Right: 54\.5 cm'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'Nov 2, 2026 00:00\. Left: 55\.5 cm\. Right: no reading'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('table decimals match the history list when requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        RfTrendChart(
          series: series,
          unit: 'cm',
          showDataTable: true,
          tableDecimals: 1,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('chart-data-table')));
    await tester.pumpAndSettle();
    expect(find.text('55.0 cm'), findsOneWidget);
  });

  testWidgets('every combination renders at 320 dp: gaps, markers, no line', (
    tester,
  ) async {
    final mixed = [
      RfTrendSeries(
        label: 'Points only',
        showLine: false,
        marker: RfTrendMarker.triangle,
        points: [
          for (var i = 0; i < 5; i++)
            RfTrendPoint(DateTime(2026, 11, 1 + i), 80.0 + i),
        ],
      ),
      RfTrendSeries(
        label: 'Broken line',
        marker: RfTrendMarker.square,
        dashed: true,
        showMarkers: false,
        points: [
          for (var i = 0; i < 6; i++)
            RfTrendPoint(
              DateTime(2026, 11, 1 + i),
              79.0 + i,
              joinPrevious: i != 3,
            ),
        ],
      ),
    ];
    await tester.pumpWidget(_wrap(RfTrendChart(series: mixed, unit: 'kg')));
    expect(tester.takeException(), isNull);
  });
}
