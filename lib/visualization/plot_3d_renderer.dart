part of '../main.dart';

extension _Plot3DRenderer on _MathVisualizationPainter {
  void _paintCentralDifference3D(
    Canvas canvas,
    Size size,
    CentralDifferenceFormula formula,
  ) {
    const curveColor = Color(0xFF65DFF3);
    final maximumZ = math.pow(formula.center.abs() + 3, 2).toDouble();
    final (zMinimum, zMaximum) = _niceBounds(0, maximumZ);
    double zCoordinate(double z) =>
        -3 + 6 * (z - zMinimum) / (zMaximum - zMinimum);
    Offset project(double x, double y, double z) =>
        _projectRotating3D(size, x - formula.center, y, zCoordinate(z));
    _paintFixed3DFrame(
      canvas,
      size,
      zMinimum: zMinimum,
      zMaximum: zMaximum,
      zCoordinate: zCoordinate,
      xMinimum: formula.center - 3,
      xMaximum: formula.center + 3,
    );

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
    _paintScalarCoordinate3D(canvas, size, value, constantSurface: false);
    _metricBadge(
      canvas,
      'Scalar result: ${_short(value)} (point only)',
      const Offset(12, 10),
      const Color(0xFF9BE7FF),
      maxWidth: size.width - 24,
    );
  }

  void _paintConstantFunction3D(Canvas canvas, Size size, double value) {
    _paintScalarCoordinate3D(canvas, size, value, constantSurface: true);
    _metricBadge(
      canvas,
      'Constant surface: z = ${_short(value)}',
      const Offset(12, 10),
      const Color(0xFF9BE7FF),
      maxWidth: size.width - 24,
    );
  }

  void _paintScalarCoordinate3D(
    Canvas canvas,
    Size size,
    double value, {
    required bool constantSurface,
  }) {
    if (!value.isFinite) return;
    final zMinimum = math.min(0.0, value) - math.max(1.0, value.abs() * .08);
    final zMaximum = math.max(0.0, value) + math.max(1.0, value.abs() * .08);
    double zCoordinate(double z) =>
        -3 + 6 * (z - zMinimum) / (zMaximum - zMinimum);
    Offset project(double x, double y, double z) =>
        _projectRotating3D(size, x, y, zCoordinate(z));
    _paintFixed3DFrame(
      canvas,
      size,
      zMinimum: zMinimum,
      zMaximum: zMaximum,
      zCoordinate: zCoordinate,
    );

    if (constantSurface) {
      final corners = <Offset>[
        project(-2.2, -2.2, value),
        project(2.2, -2.2, value),
        project(2.2, 2.2, value),
        project(-2.2, 2.2, value),
      ];
      final face = Path()
        ..moveTo(corners.first.dx, corners.first.dy)
        ..addPolygon(corners, true);
      canvas.drawPath(
        face,
        Paint()
          ..color = const Color(0xFF42C7E8).withValues(alpha: .24)
          ..style = PaintingStyle.fill,
      );
      final mesh = Paint()
        ..color = const Color(0xFF76E4F5).withValues(alpha: .7)
        ..strokeWidth = 1;
      for (var tick = -2; tick <= 2; tick++) {
        canvas.drawLine(
          project(tick.toDouble() * 1.1, -2.2, value),
          project(tick.toDouble() * 1.1, 2.2, value),
          mesh,
        );
        canvas.drawLine(
          project(-2.2, tick.toDouble() * 1.1, value),
          project(2.2, tick.toDouble() * 1.1, value),
          mesh,
        );
      }
    }
    final point = project(0, 0, value);
    if (constantSurface) {
      canvas.drawCircle(point, 5, Paint()..color = const Color(0xFF65DFF3));
      _label(
        canvas,
        'z = ${_short(value)}',
        point + const Offset(8, -18),
        Colors.white,
      );
    } else {
      canvas.drawCircle(point, 7, Paint()..color = const Color(0xFF65DFF3));
      _label(canvas, _short(value), point + const Offset(8, -18), Colors.white);
    }
  }
}
