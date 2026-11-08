part of '../main.dart';

extension _Plot2DRenderer on _MathVisualizationPainter {
  void _paintCentralDifference2D(
    Canvas canvas,
    Size size,
    CentralDifferenceFormula formula,
  ) {
    const left = 38.0;
    const right = 14.0;
    const top = 42.0;
    const bottom = 30.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final xMin = math.min(-5.0, formula.center - 2.6);
    final xMax = math.max(5.0, formula.center + 2.6);
    const yMin = -5.0;
    final yMax = math.max(5.0, math.max(xMin * xMin, xMax * xMax) + 5);
    Offset point(double x, double y) => Offset(
      plot.left + (x - xMin) / (xMax - xMin) * plot.width,
      plot.bottom - (y - yMin) / (yMax - yMin) * plot.height,
    );

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .10)
      ..strokeWidth = .8;
    for (var tick = xMin.ceil(); tick <= xMax.floor(); tick++) {
      canvas.drawLine(
        point(tick.toDouble(), yMin),
        point(tick.toDouble(), yMax),
        grid,
      );
    }
    final yStep = yMax <= 12 ? 1.0 : 5.0;
    for (
      var tick = (yMin / yStep).ceil();
      tick <= (yMax / yStep).floor();
      tick++
    ) {
      final y = tick * yStep;
      canvas.drawLine(point(xMin, y), point(xMax, y), grid);
    }
    final axes = Paint()
      ..color = Colors.white.withValues(alpha: .68)
      ..strokeWidth = 1.4;
    canvas.drawLine(point(xMin, 0), point(xMax, 0), axes);
    canvas.drawLine(point(0, yMin), point(0, yMax), axes);
    for (var tick = -5; tick <= 5; tick++) {
      final location = point(tick.toDouble(), 0);
      canvas.drawLine(
        Offset(location.dx, location.dy - 3),
        Offset(location.dx, location.dy + 3),
        axes,
      );
      _label(
        canvas,
        '$tick',
        Offset(location.dx - 6, location.dy + 4),
        Colors.white70,
      );
    }
    for (
      var tick = (yMin / yStep).ceil();
      tick <= (yMax / yStep).floor();
      tick++
    ) {
      final value = tick * yStep;
      final location = point(0, value);
      canvas.drawLine(
        Offset(location.dx - 3, location.dy),
        Offset(location.dx + 3, location.dy),
        axes,
      );
      _label(
        canvas,
        _short(value),
        Offset(location.dx - 27, location.dy - 7),
        Colors.white70,
      );
    }

    canvas.save();
    canvas.clipRect(plot);
    final curve = Path();
    for (var index = 0; index <= 180; index++) {
      final x = xMin + (xMax - xMin) * index / 180;
      final p = point(x, x * x);
      if (index == 0) {
        curve.moveTo(p.dx, p.dy);
      } else {
        curve.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      curve,
      Paint()
        ..color = const Color(0xFF65DFF3)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    final secant = Path()
      ..moveTo(
        point(
          formula.center - .95,
          formula.center * formula.center - formula.approximateDerivative * .95,
        ).dx,
        point(
          formula.center - .95,
          formula.center * formula.center - formula.approximateDerivative * .95,
        ).dy,
      )
      ..lineTo(
        point(
          formula.center + .95,
          formula.center * formula.center + formula.approximateDerivative * .95,
        ).dx,
        point(
          formula.center + .95,
          formula.center * formula.center + formula.approximateDerivative * .95,
        ).dy,
      );
    canvas.drawPath(
      secant,
      Paint()
        ..color = const Color(0xFF6EF0C2)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke,
    );
    for (final sampleX in [formula.leftX, formula.rightX]) {
      final sample = point(sampleX, sampleX * sampleX);
      canvas.drawCircle(sample, 4.5, Paint()..color = const Color(0xFF6EF0C2));
      canvas.drawCircle(
        sample,
        7,
        Paint()
          ..color = const Color(0xFF6EF0C2).withValues(alpha: .2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    final centerPoint = point(formula.center, formula.center * formula.center);
    canvas.drawCircle(
      centerPoint,
      5.2,
      Paint()..color = const Color(0xFF65DFF3),
    );
    canvas.restore();

    _label(
      canvas,
      'f(x) = x²',
      Offset(plot.left + 4, plot.top + 4),
      Colors.white,
    );
    _label(
      canvas,
      'x',
      Offset(plot.right - 10, plot.bottom + 3),
      Colors.white70,
    );
    _label(canvas, 'y', Offset(point(0, 0).dx + 4, plot.top + 1), Colors.white);
    _metricBadge(
      canvas,
      'Central difference at x = ${_short(formula.center)}, h = ${_short(formula.step)}  |  f′(x) ≈ ${_short(formula.approximateDerivative)}',
      const Offset(12, 10),
      const Color(0xFF9BE7FF),
      maxWidth: size.width - 24,
    );
    _label(
      canvas,
      'secant through x − h and x + h',
      Offset(plot.left + 6, plot.bottom - 18),
      const Color(0xFF6EF0C2),
    );
  }

  void _paintScalarResult2D(Canvas canvas, Size size, String source) {
    final value = const MathEngine().evaluate(source);
    _paintScalarCoordinate2D(canvas, size, value);
    _label(
      canvas,
      'Scalar result: ${_short(value)}',
      const Offset(18, 16),
      Colors.white,
    );
  }

  void _paintConstantFunction2D(Canvas canvas, Size size, double value) {
    _paintScalarCoordinate2D(canvas, size, value, pointOnly: false);
    _label(canvas, 'y = ${_short(value)}', const Offset(18, 16), Colors.white);
  }

  void _paintScalarCoordinate2D(
    Canvas canvas,
    Size size,
    double value, {
    bool pointOnly = true,
  }) {
    if (!value.isFinite) return;
    const left = 38.0;
    const right = 18.0;
    const top = 40.0;
    const bottom = 28.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final padding = math.max(2.0, value.abs() * .12);
    final yMin = math.min(0.0, value) - padding;
    final yMax = math.max(0.0, value) + padding;
    final roughStep = (yMax - yMin) / 5;
    final exponent = math
        .pow(10, (math.log(roughStep) / math.ln10).floor())
        .toDouble();
    final normalized = roughStep / exponent;
    final factor = normalized <= 1
        ? 1.0
        : normalized <= 2
        ? 2.0
        : normalized <= 5
        ? 5.0
        : 10.0;
    final step = factor * exponent;
    Offset point(double x, double y) => Offset(
      plot.left + (x + 5) / 10 * plot.width,
      plot.bottom - (y - yMin) / (yMax - yMin) * plot.height,
    );
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .11)
      ..strokeWidth = .8;
    for (var x = -5; x <= 5; x++) {
      final px = point(x.toDouble(), 0).dx;
      canvas.drawLine(Offset(px, plot.top), Offset(px, plot.bottom), grid);
    }
    for (
      var tick = (yMin / step).ceil();
      tick <= (yMax / step).floor();
      tick++
    ) {
      final y = tick * step;
      final py = point(0, y).dy;
      canvas.drawLine(Offset(plot.left, py), Offset(plot.right, py), grid);
      _label(canvas, _short(y), Offset(plot.left - 31, py - 7), Colors.white70);
    }
    final axes = Paint()
      ..color = Colors.white.withValues(alpha: .7)
      ..strokeWidth = 1.4;
    final origin = point(0, 0);
    canvas.drawLine(
      Offset(plot.left, origin.dy),
      Offset(plot.right, origin.dy),
      axes,
    );
    canvas.drawLine(
      Offset(origin.dx, plot.top),
      Offset(origin.dx, plot.bottom),
      axes,
    );
    for (var x = -5; x <= 5; x++) {
      final px = point(x.toDouble(), 0).dx;
      canvas.drawLine(
        Offset(px, origin.dy - 3),
        Offset(px, origin.dy + 3),
        axes,
      );
      _label(canvas, '$x', Offset(px - 6, origin.dy + 4), Colors.white70);
    }
    final curvePaint = Paint()
      ..color = const Color(0xFF65DFF3)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (pointOnly) {
      final valuePoint = point(0, value);
      canvas.drawCircle(valuePoint, 7, Paint()..color = curvePaint.color);
      _label(
        canvas,
        _short(value),
        valuePoint + const Offset(9, -18),
        curvePaint.color,
      );
    } else {
      canvas.drawLine(point(-5, value), point(5, value), curvePaint);
      final selected = point(selectedX, value);
      canvas.drawCircle(selected, 5, Paint()..color = const Color(0xFFFF594D));
      _label(
        canvas,
        '(${_short(selectedX)}, ${_short(value)})',
        selected + const Offset(7, -18),
        Colors.white,
      );
    }
    _label(canvas, 'x', Offset(plot.right - 8, origin.dy + 17), Colors.white);
    _label(canvas, 'y', Offset(origin.dx + 4, plot.top), Colors.white);
  }
}
