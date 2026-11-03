part of '../main.dart';

extension _Plot3DRenderer on _MathVisualizationPainter {
  void _paintCentralDifference3D(
    Canvas canvas,
    Size size,
    CentralDifferenceFormula formula,
  ) {
    const xColor = Color(0xFFFF625A);
    const yColor = Color(0xFF57D68D);
    const zColor = Color(0xFF4A86FF);
    const curveColor = Color(0xFF65DFF3);
    final cosX = math.cos(rotationX), sinX = math.sin(rotationX);
    final cosY = math.cos(rotationY), sinY = math.sin(rotationY);

    Offset project(double x, double y, double z) {
      final worldX = (x - formula.center) / 1.5;
      final worldY = y / 1.5;
      final worldZ =
          (z - formula.center * formula.center) /
          math.max(18.0, 2 * formula.center.abs().clamp(1, 10) * 1.5);
      final rotatedX = worldX * cosY + worldZ * sinY;
      final rotatedZ = -worldX * sinY + worldZ * cosY;
      final rotatedY = worldY * cosX - rotatedZ * sinX;
      final depth = worldY * sinX + rotatedZ * cosX;
      final perspective = 4.2 / (4.2 + depth / 1.5);
      final scale =
          math.min(size.width, size.height) * .27 * zoom * perspective;
      return Offset(
        size.width * .5 + rotatedX * scale,
        size.height * .56 - rotatedY * scale,
      );
    }

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .11)
      ..strokeWidth = .8;
    const gridHeight = 0.0;
    for (var index = 0; index <= 8; index++) {
      final x = formula.center - 2.6 + index * .65;
      canvas.drawLine(
        project(x, -2, gridHeight),
        project(x, 2, gridHeight),
        grid,
      );
      final y = -2 + index * .5;
      canvas.drawLine(
        project(formula.center - 2.6, y, gridHeight),
        project(formula.center + 2.6, y, gridHeight),
        grid,
      );
    }
    void axis(_PlotPoint3 end, Color color, String label) {
      final origin = project(0, 0, 0);
      final finish = project(end.$1, end.$2, end.$3);
      canvas.drawLine(
        origin,
        finish,
        Paint()
          ..color = color
          ..strokeWidth = 2,
      );
      _label(canvas, label, finish + const Offset(3, -10), color);
    }

    axis((6, 0, 0), xColor, 'x');
    axis((0, 3, 0), yColor, 'y');
    axis((0, 0, formula.center * formula.center + 12), zColor, 'z');

    final curve = Path();
    for (var index = 0; index <= 160; index++) {
      final x = formula.center - 2.6 + index * 5.2 / 160;
      final p = project(x, 0, x * x);
      if (index == 0) {
        curve.moveTo(p.dx, p.dy);
      } else {
        curve.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      curve,
      Paint()
        ..color = curveColor
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    final secant = Path()
      ..moveTo(
        project(
          formula.center - .9,
          0,
          formula.center * formula.center - formula.approximateDerivative * .9,
        ).dx,
        project(
          formula.center - .9,
          0,
          formula.center * formula.center - formula.approximateDerivative * .9,
        ).dy,
      )
      ..lineTo(
        project(
          formula.center + .9,
          0,
          formula.center * formula.center + formula.approximateDerivative * .9,
        ).dx,
        project(
          formula.center + .9,
          0,
          formula.center * formula.center + formula.approximateDerivative * .9,
        ).dy,
      );
    canvas.drawPath(
      secant,
      Paint()
        ..color = const Color(0xFF6EF0C2)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    for (final x in [formula.leftX, formula.rightX]) {
      final p = project(x, 0, x * x);
      canvas.drawCircle(p, 5, Paint()..color = const Color(0xFF6EF0C2));
      canvas.drawCircle(
        p,
        8,
        Paint()
          ..color = const Color(0xFF6EF0C2).withValues(alpha: .24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    final centerPoint = project(
      formula.center,
      0,
      formula.center * formula.center,
    );
    canvas.drawCircle(centerPoint, 5.5, Paint()..color = curveColor);
    _metricBadge(
      canvas,
      'z = x²  |  secant slope ≈ ${_short(formula.approximateDerivative)} at x = ${_short(formula.center)}',
      const Offset(12, 10),
      const Color(0xFF9BE7FF),
      maxWidth: size.width - 24,
    );
    _metricBadge(
      canvas,
      '3D curve, no surface area',
      Offset(12, size.height - 32),
      curveColor,
      maxWidth: size.width - 24,
    );
  }

  void _paintScalarResult3D(Canvas canvas, Size size, String source) {
    final value = const MathEngine().evaluate(source);
    final cosX = math.cos(rotationX), sinX = math.sin(rotationX);
    final cosY = math.cos(rotationY), sinY = math.sin(rotationY);
    Offset project(double x, double y, double z) {
      final rx = x * cosY + z * sinY;
      final rz = -x * sinY + z * cosY;
      final ry = y * cosX - rz * sinX;
      final depth = y * sinX + rz * cosX;
      final perspective = 4.2 / (4.2 + depth / 1.5);
      final scale =
          math.min(size.width, size.height) * .22 * zoom * perspective;
      return Offset(
        size.width * .5 + rx * scale,
        size.height * .55 - ry * scale,
      );
    }

    final origin = project(0, 0, 0);
    for (final (end, color, label) in <(_PlotPoint3, Color, String)>[
      ((3, 0, 0), const Color(0xFFFF625A), 'x'),
      ((0, 3, 0), const Color(0xFF57D68D), 'y'),
      ((0, 0, 3), const Color(0xFF4A86FF), 'z'),
    ]) {
      final finish = project(end.$1, end.$2, end.$3);
      canvas.drawLine(
        origin,
        finish,
        Paint()
          ..color = color
          ..strokeWidth = 2,
      );
      _label(canvas, label, finish + const Offset(3, -10), color);
    }
    final point = project(0, 0, value.clamp(-10, 10).toDouble());
    canvas.drawCircle(point, 7, Paint()..color = const Color(0xFF65DFF3));
    _metricBadge(
      canvas,
      'Scalar result: ${_short(value)} (point only)',
      const Offset(12, 10),
      const Color(0xFF9BE7FF),
      maxWidth: size.width - 24,
    );
  }
}
