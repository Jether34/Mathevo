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
    _paintAxes(canvas, size);
    final value = const MathEngine().evaluate(source);
    final y = value.isFinite ? value.clamp(-10, 10).toDouble() : 0.0;
    final point = Offset(size.width * .5, size.height * (.72 - y / 24));
    canvas.drawCircle(point, 7, Paint()..color = const Color(0xFF65DFF3));
    _label(
      canvas,
      'Scalar result: ${_short(value)}',
      const Offset(18, 16),
      Colors.white,
    );
  }
}
