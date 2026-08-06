import 'dart:math' as math;

import 'package:flutter/material.dart';

class MultiLineChart extends StatelessWidget {
  const MultiLineChart({
    super.key,
    required this.labels,
    required this.series,
    this.height = 360,
  });

  final List<String> labels;
  final List<LineChartSeries> series;
  final double height;

  @override
  Widget build(BuildContext context) {
    final visibleSeries = series
        .where((item) => item.values.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _MultiLineChartPainter(
              labels: labels,
              series: visibleSeries,
              textStyle:
                  Theme.of(context).textTheme.bodySmall ?? const TextStyle(),
              gridColor: const Color(0xFFD7DDE7),
              axisColor: const Color(0xFFB5BFCC),
            ),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: visibleSeries.map((item) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 4,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 8),
                Text(item.label),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class LineChartSeries {
  const LineChartSeries({
    required this.label,
    required this.color,
    required this.values,
  });

  final String label;
  final Color color;
  final List<double> values;
}

class _MultiLineChartPainter extends CustomPainter {
  const _MultiLineChartPainter({
    required this.labels,
    required this.series,
    required this.textStyle,
    required this.gridColor,
    required this.axisColor,
  });

  final List<String> labels;
  final List<LineChartSeries> series;
  final TextStyle textStyle;
  final Color gridColor;
  final Color axisColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty || series.isEmpty) {
      _drawEmpty(canvas, size);
      return;
    }

    final maxValue = _maxValue();
    final axisMax = math.max(10.0, (maxValue / 10).ceil() * 10.0);
    final leftPadding = 70.0;
    final rightPadding = 22.0;
    final topPadding = 22.0;
    final bottomPadding = 54.0;
    final plot = Rect.fromLTWH(
      leftPadding,
      topPadding,
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;

    for (var step = 0; step <= 7; step++) {
      final value = axisMax * step / 7;
      final y = plot.bottom - (value / axisMax * plot.height);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _drawText(
        canvas,
        '${value.toStringAsFixed(0)}.00%',
        Offset(8, y - 8),
        textStyle.copyWith(color: const Color(0xFF56616F)),
      );
    }

    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);
    canvas.drawLine(plot.topLeft, plot.bottomLeft, axisPaint);

    for (var index = 0; index < labels.length; index++) {
      final x = _xFor(index, labels.length, plot);
      _drawCenteredText(
        canvas,
        labels[index],
        Offset(x, plot.bottom + 18),
        textStyle.copyWith(color: const Color(0xFF4B5563)),
      );
    }

    for (final item in series) {
      final points = <Offset>[];
      for (
        var index = 0;
        index < item.values.length && index < labels.length;
        index++
      ) {
        points.add(
          Offset(
            _xFor(index, labels.length, plot),
            _yFor(item.values[index], axisMax, plot),
          ),
        );
      }
      if (points.isEmpty) {
        continue;
      }

      final linePaint = Paint()
        ..color = item.color
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final dotPaint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;

      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, linePaint);

      for (final point in points) {
        canvas.drawCircle(point, 6, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MultiLineChartPainter oldDelegate) {
    return labels != oldDelegate.labels || series != oldDelegate.series;
  }

  double _maxValue() {
    var result = 0.0;
    for (final item in series) {
      for (final value in item.values) {
        result = math.max(result, value);
      }
    }
    return result;
  }

  double _xFor(int index, int count, Rect plot) {
    if (count <= 1) {
      return plot.center.dx;
    }
    return plot.left + (plot.width * index / (count - 1));
  }

  double _yFor(double value, double axisMax, Rect plot) {
    return plot.bottom - ((value / axisMax).clamp(0.0, 1.0) * plot.height);
  }

  void _drawEmpty(Canvas canvas, Size size) {
    _drawCenteredText(
      canvas,
      'Sin datos para graficar',
      Offset(size.width / 2, size.height / 2),
      textStyle,
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    painter.paint(canvas, center - Offset(painter.width / 2, 0));
  }
}
