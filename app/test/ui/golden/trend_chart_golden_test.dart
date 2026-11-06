import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/units/kilograms.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/measurements/presentation/measurement_chart_data.dart';
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

  /// Chart series built through the real mapping (`siteChartData`) from UTC
  /// readings at 12:00, so the gap rule decides the joins (L3).
  List<RfTrendSeries> viaSiteChartData(
    MeasurementSite site,
    List<(DateTime, double)> data,
  ) {
    final series = siteChartData(
      site,
      [
        for (final (i, (at, v)) in data.indexed)
          Measurement(
            id: 'g$i',
            site: site,
            value: site.isWeight
                ? MeasurementValue.kg(Kilograms.fromStored(v))
                : MeasurementValue.cm(Centimetres.fromStored(v)),
            recordedAt: at,
            createdAt: at,
            updatedAt: at,
          ),
      ],
      MeasurementPeriod.all,
      DateTime.utc(2026, 11, 5, 12),
    ).series;
    // The mapping returns local times; the golden pins them to UTC so the
    // axis dates do not depend on the machine's time zone (M1).
    return [
      for (final s in series)
        RfTrendSeries(
          label: s.label,
          marker: s.marker,
          dashed: s.dashed,
          showLine: s.showLine,
          showMarkers: s.showMarkers,
          markIsolated: s.markIsolated,
          points: [
            for (final p in s.points)
              RfTrendPoint(p.at.toUtc(), p.value, joinPrevious: p.joinPrevious),
          ],
        ),
    ];
  }

  final cases = <String, List<RfTrendSeries>>{
    // Weekly waist readings: 7 days apart join; the 9 day gap breaks.
    'trend_weekly': viaSiteChartData(MeasurementSite.waist, [
      for (var i = 0; i < 12; i++)
        (
          DateTime.utc(
            2026,
            8,
            1,
            12,
          ).add(Duration(days: i * 7 + (i > 5 ? 2 : 0))),
          ((92 - i * 0.4) * 10).round() / 10,
        ),
    ]),
    // Weighing every other day: readings as points, joined 7-day trend.
    'trend_every_other_day': viaSiteChartData(MeasurementSite.weight, [
      for (var i = 0; i < 20; i++)
        (
          DateTime.utc(2026, 9, 20, 12).add(Duration(days: i * 2)),
          ((82 - i * 0.12 + (i.isEven ? 0.3 : -0.2)) * 10).round() / 10,
        ),
    ]),
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
                      unit:
                          name.contains('thigh') ||
                              name.contains('left') ||
                              name.contains('weekly')
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
