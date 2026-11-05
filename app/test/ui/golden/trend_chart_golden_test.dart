import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_trend_chart.dart';
import 'package:repforge/ui/theme.dart';

import 'gallery_golden_test.dart' show loadBrandFonts;

/// Golden images of the trend chart with 1, 2 and 100 points (D06 WP 10
/// verification) and of a left/right chart with a gap, in both themes, with
/// the real brand fonts. Regenerate deliberately with
/// `flutter test --update-goldens test/ui/golden/trend_chart_golden_test.dart`
/// and review the images.
void main() {
  setUpAll(loadBrandFonts);

  List<RfTrendPoint> points(int n) => [
    for (var i = 0; i < n; i++)
      RfTrendPoint(
        DateTime.utc(
          2026,
          8,
        ).add(Duration(hours: i * (n == 100 ? 20 : 24 * 30))),
        82 + 3 * math.sin(i / 7) - i * 0.02,
        // Every 25th point follows a gap: the line is broken there.
        joinPrevious: i % 25 != 0,
      ),
  ];

  final cases = <String, List<RfTrendSeries>>{
    'trend_1_point': [RfTrendSeries(label: 'Weight', points: points(1))],
    'trend_2_points': [RfTrendSeries(label: 'Weight', points: points(2))],
    'trend_100_points': [
      RfTrendSeries(
        label: 'Weight readings',
        points: points(100),
        showLine: false,
      ),
      RfTrendSeries(
        label: '7-day trend',
        points: [
          for (final p in points(100).where((p) => p.at.day % 3 == 0))
            RfTrendPoint(p.at, p.value + 0.4, joinPrevious: p.joinPrevious),
        ],
        showMarkers: false,
        marker: RfTrendMarker.square,
      ),
    ],
    'trend_left_right': [
      RfTrendSeries(
        label: 'Left thigh',
        points: [
          for (var i = 0; i < 12; i++)
            RfTrendPoint(
              DateTime.utc(2026, 9, 1 + i * 3),
              56 + i * 0.3,
              joinPrevious: i != 0 && i != 6,
            ),
        ],
      ),
      RfTrendSeries(
        label: 'Right thigh',
        points: [
          for (var i = 0; i < 12; i++)
            RfTrendPoint(
              DateTime.utc(2026, 9, 1 + i * 3, 12),
              55 + i * 0.25,
              joinPrevious: i != 0 && i != 6,
            ),
        ],
        marker: RfTrendMarker.diamond,
        dashed: true,
      ),
    ],
  };

  for (final brightness in Brightness.values) {
    for (final MapEntry(key: name, value: series) in cases.entries) {
      testWidgets('$name (${brightness.name})', (tester) async {
        tester.view.physicalSize = const Size(360, 340);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: rfTheme(brightness),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: RepaintBoundary(
                  key: const Key('chart-frame'),
                  child: RfCard(
                    child: RfTrendChart(
                      series: series,
                      unit: name.contains('thigh') || name.contains('left')
                          ? 'cm'
                          : 'kg',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await expectLater(
          find.byKey(const Key('chart-frame')),
          matchesGoldenFile('goldens/${name}_${brightness.name}.png'),
        );
      });
    }
  }
}
