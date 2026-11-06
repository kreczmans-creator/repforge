import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/ui/tokens.dart';

/// One dated value in a trend series.
@immutable
final class RfTrendPoint {
  const RfTrendPoint(this.at, this.value, {this.joinPrevious = true});
  final DateTime at;
  final double value;

  /// False breaks the line before this point: no segment is drawn between it
  /// and the previous point of the series (a gap). The chart never adds
  /// points between readings, so it never interpolates.
  final bool joinPrevious;

  @override
  bool operator ==(Object other) =>
      other is RfTrendPoint &&
      other.at == at &&
      other.value == value &&
      other.joinPrevious == joinPrevious;

  @override
  int get hashCode => Object.hash(at, value, joinPrevious);
}

/// Marker shape of a series. Series are told apart by marker shape and line
/// style as well as colour (UXD-009(1)).
enum RfTrendMarker { circle, square, diamond, triangle }

/// One named series on a trend chart.
@immutable
final class RfTrendSeries {
  const RfTrendSeries({
    required this.label,
    required this.points,
    this.color,
    this.marker = RfTrendMarker.circle,
    this.dashed = false,
    this.showLine = true,
    this.showMarkers = true,
    this.markIsolated = false,
  });
  final String label;

  /// Points in any order; sorted by time when drawn.
  final List<RfTrendPoint> points;

  /// Defaults to the next colour in `RfSemanticColors.chartSeries`.
  final Color? color;

  /// Shape of the point markers (and of the legend glyph).
  final RfTrendMarker marker;

  /// Draw the line dashed instead of solid.
  final bool dashed;

  /// False draws the series as separate points only.
  final bool showLine;

  /// False hides the point markers (the line alone, e.g. a derived trend).
  final bool showMarkers;

  /// With [showMarkers] false: still draw a marker on every point that has no
  /// line segment to a neighbour (an isolated value would otherwise be
  /// invisible).
  final bool markIsolated;
}

/// Line chart over time with a value axis in [unit], first/last dates and a
/// legend whose glyphs repeat each series' marker and line style.
///
/// Handles 0, 1, 2 or many points; the x axis is proportional to time, so
/// gaps between measurements are visible rather than evenly spaced. Lines
/// join only points flagged `joinPrevious`; the caller decides which real
/// consecutive readings are joined. The chart never adds a point, so nothing
/// is interpolated. [showDataTable] adds a collapsible table of all values that
/// a screen reader can read row by row (UXD-009(2)).
class RfTrendChart extends StatelessWidget {
  const RfTrendChart({
    required this.series,
    super.key,
    this.unit = '',
    this.height = 200,
    this.emptyMessage = 'No data yet.',
    this.showDataTable = false,
    this.tableDecimals,
  });

  final List<RfTrendSeries> series;
  final String unit;
  final double height;
  final String emptyMessage;

  /// Adds the "Data table" disclosure below the chart.
  final bool showDataTable;

  /// Fixed number of decimals for values in the data table (for example 1 to
  /// match the history list); null trims trailing zeros like the axis.
  final int? tableDecimals;

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
    Color colorOf(int i) =>
        series[i].color ?? rf.chartSeries[i % rf.chartSeries.length];
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
      ..write(', range ${formatNumber(min)} to ${formatNumber(max)} $unit');
    if (series.length > 1) {
      summary.write('. Series: ${series.map((s) => s.label).join(', ')}');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: summary.toString(),
          image: true,
          excludeSemantics: true,
          child: SizedBox(
            height: height,
            child: CustomPaint(
              painter: _TrendPainter(
                series: [
                  for (var i = 0; i < series.length; i++)
                    _Series(
                      color: colorOf(i),
                      marker: series[i].marker,
                      dashed: series[i].dashed,
                      showLine: series[i].showLine,
                      showMarkers: series[i].showMarkers,
                      markIsolated: series[i].markIsolated,
                      points: [...series[i].points]
                        ..sort((a, b) => a.at.compareTo(b.at)),
                    ),
                ],
                min: min,
                max: max,
                first: first,
                last: last,
                gridColor: rf.border,
                labelStyle: context.rfText.meta.copyWith(
                  letterSpacing: 0,
                  color: rf.textSecondary,
                ),
                unit: unit,
                textDirection: Directionality.of(context),
              ),
              child: const SizedBox.expand(),
            ),
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
                    CustomPaint(
                      size: const Size(28, 14),
                      painter: _LegendGlyph(
                        color: colorOf(i),
                        marker: series[i].marker,
                        dashed: series[i].dashed,
                        showLine: series[i].showLine,
                        showMarker:
                            series[i].showMarkers || series[i].markIsolated,
                      ),
                    ),
                    const SizedBox(width: RfSpace.xs),
                    Flexible(
                      child: Text(
                        series[i].label,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
        if (showDataTable) ...[
          const SizedBox(height: RfSpace.sm),
          _ChartDataTable(series: series, unit: unit, decimals: tableDecimals),
        ],
      ],
    );
  }
}

/// Collapsible table with one row per instant and one column per series.
/// Each row is one semantics node reading "date, series value, ...".
class _ChartDataTable extends StatelessWidget {
  const _ChartDataTable({
    required this.series,
    required this.unit,
    required this.decimals,
  });

  final List<RfTrendSeries> series;
  final String unit;
  final int? decimals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat.yMMMd().add_Hm();
    final instants = <int>{
      for (final s in series)
        for (final p in s.points) p.at.millisecondsSinceEpoch,
    }.toList()..sort();
    final lookup = [
      for (final s in series)
        {for (final p in s.points) p.at.millisecondsSinceEpoch: p.value},
    ];
    final unitSuffix = unit.isEmpty ? '' : ' $unit';
    String fmtValue(double v) =>
        decimals == null ? formatNumber(v) : v.toStringAsFixed(decimals!);
    final headerSpoken =
        'Date, ${series.map((s) => s.label).join(', ')}, values in $unit';
    Widget cell(String text, {bool bold = false, int flex = 1}) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: RfSpace.xs),
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: bold ? FontWeight.w700 : null,
          ),
        ),
      ),
    );
    Widget rowAt(int index) {
      final t = instants[index];
      final when = fmt.format(DateTime.fromMillisecondsSinceEpoch(t));
      final texts = [
        for (final l in lookup)
          if (l[t] case final v?) '${fmtValue(v)}$unitSuffix' else '–',
      ];
      final spoken = StringBuffer(when);
      for (var i = 0; i < series.length; i++) {
        spoken.write(
          '. ${series[i].label}: '
          '${texts[i] == '–' ? 'no reading' : texts[i]}',
        );
      }
      return Semantics(
        label: spoken.toString(),
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [cell(when, flex: 2), for (final x in texts) cell(x)],
        ),
      );
    }

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const Key('chart-data-table'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        minTileHeight: rfMinTouchTarget,
        title: Text('Data table', style: theme.textTheme.titleSmall),
        subtitle: Text(
          '${instants.length} rows',
          style: theme.textTheme.bodySmall,
        ),
        children: [
          Semantics(
            label: headerSpoken,
            excludeSemantics: true,
            child: Row(
              children: [
                cell('Date', bold: true, flex: 2),
                for (final s in series) cell(s.label, bold: true),
              ],
            ),
          ),
          if (instants.length <= 12)
            for (var i = 0; i < instants.length; i++) rowAt(i)
          else
            // Many rows: a lazy list in a fixed-height box, so only the
            // visible rows are built.
            SizedBox(
              height: 360,
              child: ListView.builder(
                itemCount: instants.length,
                itemBuilder: (_, i) => rowAt(i),
              ),
            ),
        ],
      ),
    );
  }
}

@immutable
class _Series {
  const _Series({
    required this.color,
    required this.marker,
    required this.dashed,
    required this.showLine,
    required this.showMarkers,
    required this.markIsolated,
    required this.points,
  });
  final Color color;
  final RfTrendMarker marker;
  final bool dashed;
  final bool showLine;
  final bool showMarkers;
  final bool markIsolated;
  final List<RfTrendPoint> points;

  bool sameAs(_Series o) =>
      color == o.color &&
      marker == o.marker &&
      dashed == o.dashed &&
      showLine == o.showLine &&
      showMarkers == o.showMarkers &&
      markIsolated == o.markIsolated &&
      listEquals(points, o.points);
}

/// Draws a marker of [shape] centred on [c].
void _drawMarker(Canvas canvas, Offset c, RfTrendMarker shape, Paint paint) {
  const r = 4.0;
  switch (shape) {
    case RfTrendMarker.circle:
      canvas.drawCircle(c, r, paint);
    case RfTrendMarker.square:
      canvas.drawRect(
        Rect.fromCenter(center: c, width: 2 * r, height: 2 * r),
        paint,
      );
    case RfTrendMarker.diamond:
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - r - 1)
          ..lineTo(c.dx + r + 1, c.dy)
          ..lineTo(c.dx, c.dy + r + 1)
          ..lineTo(c.dx - r - 1, c.dy)
          ..close(),
        paint,
      );
    case RfTrendMarker.triangle:
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - r - 1)
          ..lineTo(c.dx + r + 1, c.dy + r)
          ..lineTo(c.dx - r - 1, c.dy + r)
          ..close(),
        paint,
      );
  }
}

/// Draws [path] solid, or as dashes of 7 px with 4 px gaps.
void _drawLine(Canvas canvas, Path path, Paint paint, {required bool dashed}) {
  if (!dashed) {
    canvas.drawPath(path, paint);
    return;
  }
  for (final metric in path.computeMetrics()) {
    var d = 0.0;
    while (d < metric.length) {
      canvas.drawPath(
        metric.extractPath(d, math.min(d + 7, metric.length)),
        paint,
      );
      d += 11;
    }
  }
}

class _LegendGlyph extends CustomPainter {
  _LegendGlyph({
    required this.color,
    required this.marker,
    required this.dashed,
    required this.showLine,
    required this.showMarker,
  });

  final Color color;
  final RfTrendMarker marker;
  final bool dashed;
  final bool showLine;
  final bool showMarker;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    if (showLine) {
      final line = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      _drawLine(
        canvas,
        Path()
          ..moveTo(0, mid)
          ..lineTo(size.width, mid),
        line,
        dashed: dashed,
      );
    }
    if (showMarker) {
      _drawMarker(
        canvas,
        Offset(size.width / 2, mid),
        marker,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_LegendGlyph old) =>
      old.color != color ||
      old.marker != marker ||
      old.dashed != dashed ||
      old.showLine != showLine ||
      old.showMarker != showMarker;
}

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

  static const _bottom = 20.0;
  static const _right = 8.0;
  static const _axisGap = 6.0;
  static const _ticks = 4;

  @override
  void paint(Canvas canvas, Size size) {
    // Pad the value range so a flat series does not sit on the edge.
    final span = (max - min).abs();
    final pad = span == 0 ? (max.abs() * 0.05).clamp(0.5, 5.0) : span * 0.1;
    final lo = min - pad;
    final hi = max + pad;

    // Lay out tick labels first so the axis is as wide as the widest label.
    final tickPainters = [
      for (var i = 0; i <= _ticks; i++)
        _painter(formatNumber(lo + (hi - lo) * i / _ticks)),
    ];
    final axisWidth =
        tickPainters.map((p) => p.width).reduce(math.max) + _axisGap;
    // The unit sits above the value axis.
    final unitPainter = unit.isEmpty ? null : _painter(unit);
    final top = unitPainter == null ? 8.0 : unitPainter.height + 6;
    final plot = Rect.fromLTRB(
      axisWidth,
      top,
      size.width - _right,
      size.height - _bottom,
    );
    unitPainter?.paint(canvas, Offset.zero);
    final totalMs = last.millisecondsSinceEpoch - first.millisecondsSinceEpoch;
    final singleInstant = totalMs <= 0;

    double x(DateTime t) => singleInstant
        ? plot.center.dx
        : plot.left +
              (t.millisecondsSinceEpoch - first.millisecondsSinceEpoch) /
                  totalMs *
                  plot.width;
    double y(double v) => plot.bottom - (v - lo) / (hi - lo) * plot.height;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= _ticks; i++) {
      final yy = y(lo + (hi - lo) * i / _ticks);
      canvas.drawLine(Offset(plot.left, yy), Offset(plot.right, yy), grid);
      final tp = tickPainters[i];
      tp.paint(
        canvas,
        Offset(axisWidth - _axisGap - tp.width, yy - tp.height / 2),
      );
    }
    // Year only when the axis spans two calendar years.
    final df = first.year == last.year ? DateFormat.MMMd() : DateFormat.yMMMd();
    _label(canvas, df.format(first), Offset(plot.left, plot.bottom + 4));
    _label(
      canvas,
      df.format(last),
      Offset(plot.right, plot.bottom + 4),
      anchorX: 1,
    );

    for (final s in series) {
      if (s.points.isEmpty) continue;
      final offsets = [for (final p in s.points) Offset(x(p.at), y(p.value))];
      if (s.showLine) {
        final line = Paint()
          ..color = s.color
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        // Gap rule: a run ends where the next point is marked as not joined
        // (`joinPrevious` false); no segment is drawn across, and no point is
        // added, so nothing is interpolated.
        var run = <Offset>[offsets.first];
        void flush() {
          if (run.length > 1) {
            final path = Path()..moveTo(run.first.dx, run.first.dy);
            for (final o in run.skip(1)) {
              path.lineTo(o.dx, o.dy);
            }
            _drawLine(canvas, path, line, dashed: s.dashed);
          }
        }

        for (var i = 1; i < s.points.length; i++) {
          if (!s.points[i].joinPrevious) {
            flush();
            run = <Offset>[];
          }
          run.add(offsets[i]);
        }
        flush();
      }
      final dot = Paint()..color = s.color;
      for (var i = 0; i < offsets.length; i++) {
        // A point has a line segment when it joins its predecessor or its
        // successor joins it; otherwise it is isolated.
        final joinedBefore = i > 0 && s.points[i].joinPrevious;
        final joinedAfter =
            i + 1 < s.points.length && s.points[i + 1].joinPrevious;
        final isolated = !s.showLine || !(joinedBefore || joinedAfter);
        if (s.showMarkers || (s.markIsolated && isolated)) {
          _drawMarker(canvas, offsets[i], s.marker, dot);
        }
      }
    }
  }

  TextPainter _painter(String text) => TextPainter(
    text: TextSpan(text: text, style: labelStyle),
    textDirection: textDirection,
    maxLines: 1,
    ellipsis: '…',
  )..layout();

  void _label(Canvas canvas, String text, Offset at, {double anchorX = 0}) {
    final tp = _painter(text);
    tp.paint(canvas, Offset(at.dx - tp.width * anchorX, at.dy));
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.min != min ||
      old.max != max ||
      old.first != first ||
      old.last != last ||
      old.gridColor != gridColor ||
      old.labelStyle != labelStyle ||
      old.unit != unit ||
      old.textDirection != textDirection ||
      !_sameSeries(old.series, series);

  static bool _sameSeries(List<_Series> a, List<_Series> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!a[i].sameAs(b[i])) return false;
    }
    return true;
  }
}
