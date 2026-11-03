import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:repforge/ui/tokens.dart';

/// One dated value in a trend series.
@immutable
final class RfTrendPoint {
  const RfTrendPoint(this.at, this.value);
  final DateTime at;
  final double value;
}

/// One named series on a trend chart.
@immutable
final class RfTrendSeries {
  const RfTrendSeries({required this.label, required this.points, this.color});
  final String label;

  /// Points in any order; sorted by time when drawn.
  final List<RfTrendPoint> points;

  /// Defaults to the next colour in `RfSemanticColors.chartSeries`.
  final Color? color;
}

/// Line chart over time with a labelled value axis and first/last dates.
/// Handles 0, 1, 2 or many points; the x axis is proportional to time, so
/// gaps between measurements are visible rather than evenly spaced.
class RfTrendChart extends StatelessWidget {
  const RfTrendChart({
    required this.series,
    super.key,
    this.unit = '',
    this.height = 200,
    this.emptyMessage = 'No data yet.',
  });

  final List<RfTrendSeries> series;
  final String unit;
  final double height;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rf = context.rf;
    final all = [for (final s in series) ...s.points];
    if (all.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(emptyMessage, style: theme.textTheme.bodySmall),
        ),
      );
    }
    final values = all.map((p) => p.value);
    final min = values.reduce(math.min);
    final max = values.reduce(math.max);
    final first = all.map((p) => p.at).reduce((a, b) => a.isBefore(b) ? a : b);
    final last = all.map((p) => p.at).reduce((a, b) => a.isAfter(b) ? a : b);
    final summary = StringBuffer()
      ..write('Trend chart, ${all.length} values from ')
      ..write(DateFormat.yMMMd().format(first))
      ..write(' to ')
      ..write(DateFormat.yMMMd().format(last))
      ..write(', range ${_fmt(min)} to ${_fmt(max)} $unit');
    return Semantics(
      label: summary.toString(),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: height,
            child: CustomPaint(
              painter: _TrendPainter(
                series: [
                  for (var i = 0; i < series.length; i++)
                    (
                      color:
                          series[i].color ??
                          rf.chartSeries[i % rf.chartSeries.length],
                      points: [...series[i].points]
                        ..sort((a, b) => a.at.compareTo(b.at)),
                    ),
                ],
                min: min,
                max: max,
                first: first,
                last: last,
                gridColor: rf.border,
                labelStyle: context.rfText.meta.copyWith(letterSpacing: 0),
                unit: unit,
                textDirection: Directionality.of(context),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          if (series.length > 1) ...[
            const SizedBox(height: RfSpace.sm),
            Wrap(
              spacing: RfSpace.lg,
              runSpacing: RfSpace.xs,
              children: [
                for (var i = 0; i < series.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color:
                              series[i].color ??
                              rf.chartSeries[i % rf.chartSeries.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: RfSpace.xs),
                      Text(series[i].label, style: theme.textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

typedef _Series = ({Color color, List<RfTrendPoint> points});

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.series,
    required this.min,
    required this.max,
    required this.first,
    required this.last,
    required this.gridColor,
    required this.labelStyle,
    required this.unit,
    required this.textDirection,
  });

  final List<_Series> series;
  final double min;
  final double max;
  final DateTime first;
  final DateTime last;
  final Color gridColor;
  final TextStyle labelStyle;
  final String unit;
  final TextDirection textDirection;

  static const _axisWidth = 44.0;
  static const _bottom = 20.0;
  static const _top = 8.0;
  static const _right = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      _axisWidth,
      _top,
      size.width - _right,
      size.height - _bottom,
    );
    // Pad the value range so a flat series does not sit on the edge.
    final span = (max - min).abs();
    final pad = span == 0 ? (max.abs() * 0.05).clamp(0.5, 5.0) : span * 0.1;
    final lo = min - pad;
    final hi = max + pad;
    final totalMs = math.max(
      1,
      last.millisecondsSinceEpoch - first.millisecondsSinceEpoch,
    );

    double x(DateTime t) =>
        plot.left +
        (t.millisecondsSinceEpoch - first.millisecondsSinceEpoch) /
            totalMs *
            plot.width;
    double y(double v) => plot.bottom - (v - lo) / (hi - lo) * plot.height;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    const ticks = 4;
    for (var i = 0; i <= ticks; i++) {
      final v = lo + (hi - lo) * i / ticks;
      final yy = y(v);
      canvas.drawLine(Offset(plot.left, yy), Offset(plot.right, yy), grid);
      _label(
        canvas,
        RfTrendChart._fmt(v),
        Offset(0, yy),
        maxWidth: _axisWidth - 6,
        align: TextAlign.right,
        anchorY: 0.5,
      );
    }
    final df = DateFormat.MMMd();
    _label(canvas, df.format(first), Offset(plot.left, plot.bottom + 4));
    _label(
      canvas,
      df.format(last),
      Offset(plot.right, plot.bottom + 4),
      align: TextAlign.right,
      anchorX: 1,
    );

    for (final s in series) {
      if (s.points.isEmpty) continue;
      final line = Paint()
        ..color = s.color
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final dot = Paint()..color = s.color;
      final offsets = [
        for (final p in s.points)
          Offset(s.points.length == 1 ? plot.center.dx : x(p.at), y(p.value)),
      ];
      if (offsets.length > 1) {
        final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
        for (final o in offsets.skip(1)) {
          path.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(path, line);
      }
      for (final o in offsets) {
        canvas.drawCircle(o, 3.5, dot);
      }
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at, {
    double? maxWidth,
    TextAlign align = TextAlign.left,
    double anchorX = 0,
    double anchorY = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: textDirection,
      textAlign: align,
    )..layout(maxWidth: maxWidth ?? double.infinity);
    final dx = maxWidth != null
        ? at.dx + (maxWidth - tp.width)
        : at.dx - tp.width * anchorX;
    tp.paint(canvas, Offset(dx, at.dy - tp.height * anchorY));
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.series != series ||
      old.min != min ||
      old.max != max ||
      old.first != first ||
      old.last != last ||
      old.gridColor != gridColor ||
      old.labelStyle != labelStyle;
}
