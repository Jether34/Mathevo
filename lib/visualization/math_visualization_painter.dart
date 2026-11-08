part of '../main.dart';

typedef _PlotPoint3 = (double, double, double);

class _MathVisualizationPainter extends CustomPainter {
  const _MathVisualizationPainter({
    required this.mode,
    required this.is3D,
    required this.zoom,
    required this.expressionPlot,
    required this.calculusOperation,
    required this.rotationX,
    required this.rotationY,
    required this.angle,
    required this.hypotenuse,
    required this.slope,
    required this.intercept,
    required this.lower,
    required this.upper,
    required this.selectedX,
    required this.expression,
    required this.geometryOperation,
    required this.geometryFirst,
    required this.geometrySecond,
  });

  final _CalculatorMode mode;
  final bool is3D;
  final double zoom;
  final bool expressionPlot;
  final String calculusOperation;
  final double rotationX, rotationY;
  final double angle, hypotenuse, slope, intercept, lower, upper, selectedX;
  final String expression;
  final String geometryOperation;
  final double geometryFirst, geometrySecond;

  bool get _triangle => mode == _CalculatorMode.trigonometry;

  String get _sourceExpression =>
      _plotExpression.trim().isEmpty ? 'x^2' : _plotExpression.trim();

  PlotFormula get _formula => PlotFormula(_sourceExpression);

  List<String> get _equationSides => [
    _formula.leftExpression,
    _formula.rightExpression,
  ];

  bool get _hasXYVariables => _formula.hasXY;

  bool get _hasXYZVariables => _formula.hasXYZ;

  bool get _isExplicitZFunction => _formula.isExplicitZ;

  String get _explicitZFunction => _formula.functionExpression;

  void _paintImplicitCurve(Canvas canvas, Size size) {
    const cells = 84;
    const minimum = -1.6;
    const maximum = 1.6;
    const margin = 30.0;
    final plotWidth = size.width - margin * 2;
    final plotHeight = size.height - margin * 2;
    final plotSize = math.min(plotWidth, plotHeight);
    final left = (size.width - plotSize) / 2;
    final top = (size.height - plotSize) / 2;
    const engine = MathEngine();
    final (leftExpression, rightExpression) = (
      _equationSides.first,
      _equationSides.last,
    );
    double sample(double x, double y) {
      try {
        final variables = {'x': x, 'y': y};
        return engine.evaluateAtVariables(leftExpression, variables) -
            engine.evaluateAtVariables(rightExpression, variables);
      } on Object {
        return double.nan;
      }
    }

    Offset point(double x, double y) => Offset(
      left + (x - minimum) / (maximum - minimum) * plotSize,
      top + (maximum - y) / (maximum - minimum) * plotSize,
    );

    final values = List<double>.filled((cells + 1) * (cells + 1), double.nan);
    int index(int x, int y) => y * (cells + 1) + x;
    double coordinate(int value) =>
        minimum + (maximum - minimum) * value / cells;
    for (var y = 0; y <= cells; y++) {
      for (var x = 0; x <= cells; x++) {
        values[index(x, y)] = sample(coordinate(x), coordinate(y));
      }
    }

    final region = Path();
    final contour = Path();
    const edges = [(0, 1), (1, 2), (2, 3), (3, 0)];
    for (var y = 0; y < cells; y++) {
      for (var x = 0; x < cells; x++) {
        final xs = [x, x + 1, x + 1, x];
        final ys = [y, y, y + 1, y + 1];
        final f = [
          values[index(xs[0], ys[0])],
          values[index(xs[1], ys[1])],
          values[index(xs[2], ys[2])],
          values[index(xs[3], ys[3])],
        ];
        if (f.any((value) => !value.isFinite)) continue;
        final centerValue = sample(
          (coordinate(x) + coordinate(x + 1)) / 2,
          (coordinate(y) + coordinate(y + 1)) / 2,
        );
        if (centerValue.isFinite && centerValue <= 0) {
          region.addRect(
            Rect.fromLTRB(
              point(coordinate(x), coordinate(y + 1)).dx,
              point(coordinate(x), coordinate(y + 1)).dy,
              point(coordinate(x + 1), coordinate(y)).dx,
              point(coordinate(x + 1), coordinate(y)).dy,
            ),
          );
        }
        final crossings = <Offset>[];
        for (final (a, b) in edges) {
          if ((f[a] < 0) == (f[b] < 0)) continue;
          final amount = (f[a] / (f[a] - f[b])).clamp(0.0, 1.0);
          final px =
              coordinate(xs[a]) +
              (coordinate(xs[b]) - coordinate(xs[a])) * amount;
          final py =
              coordinate(ys[a]) +
              (coordinate(ys[b]) - coordinate(ys[a])) * amount;
          crossings.add(point(px, py));
        }
        for (var crossing = 0; crossing + 1 < crossings.length; crossing += 2) {
          contour
            ..moveTo(crossings[crossing].dx, crossings[crossing].dy)
            ..lineTo(crossings[crossing + 1].dx, crossings[crossing + 1].dy);
        }
      }
    }

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: .12)
      ..strokeWidth = .7;
    for (var tick = -1; tick <= 1; tick++) {
      final x = point(tick.toDouble(), 0).dx;
      final y = point(0, tick.toDouble()).dy;
      canvas.drawLine(Offset(x, top), Offset(x, top + plotSize), gridPaint);
      canvas.drawLine(Offset(left, y), Offset(left + plotSize, y), gridPaint);
    }
    canvas.drawPath(
      region,
      Paint()..color = const Color(0xFFAC5DEB).withValues(alpha: .34),
    );
    canvas.drawRect(
      Rect.fromLTWH(left, top, plotSize, plotSize),
      Paint()
        ..color = Colors.white.withValues(alpha: .68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawPath(
      contour,
      Paint()
        ..color = const Color(0xFF75E5F2)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    final origin = point(0, 0);
    canvas.drawLine(
      Offset(left, origin.dy),
      Offset(left + plotSize, origin.dy),
      Paint()..color = const Color(0xFF57D68D).withValues(alpha: .85),
    );
    canvas.drawLine(
      Offset(origin.dx, top + plotSize),
      Offset(origin.dx, top),
      Paint()..color = const Color(0xFFFF625A).withValues(alpha: .85),
    );
    _label(
      canvas,
      'Implicit equation region',
      const Offset(14, 12),
      Colors.white,
    );
    _label(
      canvas,
      'Shaded side: F(x,y) ≤ 0',
      Offset(14, size.height - 22),
      const Color(0xFFFFC66D),
    );
  }

  void _paintImplicitSurface(Canvas canvas, Size size) {
    const cells = 12;
    const minimum = -1.5;
    const maximum = 1.5;
    const engine = MathEngine();
    final (leftExpression, rightExpression) = (
      _equationSides.first,
      _equationSides.last,
    );
    double coordinate(int value) =>
        minimum + (maximum - minimum) * value / cells;
    int index(int x, int y, int z) => (z * (cells + 1) + y) * (cells + 1) + x;
    final values = List<double>.filled(
      (cells + 1) * (cells + 1) * (cells + 1),
      double.nan,
    );
    for (var z = 0; z <= cells; z++) {
      for (var y = 0; y <= cells; y++) {
        for (var x = 0; x <= cells; x++) {
          try {
            final variables = {
              'x': coordinate(x),
              'y': coordinate(y),
              'z': coordinate(z),
            };
            values[index(x, y, z)] =
                engine.evaluateAtVariables(leftExpression, variables) -
                engine.evaluateAtVariables(rightExpression, variables);
          } on Object {
            values[index(x, y, z)] = double.nan;
          }
        }
      }
    }

    final triangles = <(_PlotPoint3, _PlotPoint3, _PlotPoint3)>[];
    const corners = <(int, int, int)>[
      (0, 0, 0),
      (1, 0, 0),
      (1, 1, 0),
      (0, 1, 0),
      (0, 0, 1),
      (1, 0, 1),
      (1, 1, 1),
      (0, 1, 1),
    ];
    const tetrahedra = [
      (0, 5, 1, 6),
      (0, 1, 2, 6),
      (0, 2, 3, 6),
      (0, 3, 7, 6),
      (0, 7, 4, 6),
      (0, 4, 5, 6),
    ];
    const tetraEdges = [(0, 1), (0, 2), (0, 3), (1, 2), (1, 3), (2, 3)];
    for (var z = 0; z < cells; z++) {
      for (var y = 0; y < cells; y++) {
        for (var x = 0; x < cells; x++) {
          final points = corners
              .map(
                (corner) => (
                  coordinate(x + corner.$1),
                  coordinate(y + corner.$2),
                  coordinate(z + corner.$3),
                ),
              )
              .toList(growable: false);
          final field = corners
              .map(
                (corner) =>
                    values[index(x + corner.$1, y + corner.$2, z + corner.$3)],
              )
              .toList(growable: false);
          if (field.any((value) => !value.isFinite)) continue;
          for (final tetra in tetrahedra) {
            final ids = [tetra.$1, tetra.$2, tetra.$3, tetra.$4];
            final intersections = <_PlotPoint3>[];
            for (final (edgeA, edgeB) in tetraEdges) {
              final a = ids[edgeA], b = ids[edgeB];
              if ((field[a] < 0) == (field[b] < 0)) continue;
              final t = (field[a] / (field[a] - field[b])).clamp(0.0, 1.0);
              intersections.add((
                points[a].$1 + (points[b].$1 - points[a].$1) * t,
                points[a].$2 + (points[b].$2 - points[a].$2) * t,
                points[a].$3 + (points[b].$3 - points[a].$3) * t,
              ));
            }
            if (intersections.length == 3) {
              triangles.add((
                intersections[0],
                intersections[1],
                intersections[2],
              ));
            } else if (intersections.length == 4) {
              triangles
                ..add((intersections[0], intersections[1], intersections[2]))
                ..add((intersections[0], intersections[2], intersections[3]));
            }
          }
        }
      }
    }

    final cx = math.cos(rotationX), sx = math.sin(rotationX);
    final cy = math.cos(rotationY), sy = math.sin(rotationY);
    _PlotPoint3 rotate(_PlotPoint3 point) {
      final x = point.$1 * cy + point.$3 * sy;
      final z1 = -point.$1 * sy + point.$3 * cy;
      return (x, point.$2 * cx - z1 * sx, point.$2 * sx + z1 * cx);
    }

    Offset project(_PlotPoint3 point) {
      final rotated = rotate(point);
      return _projectRotating3D(
        size,
        rotated.$1 * 2,
        rotated.$2 * 2,
        rotated.$3 * 2,
      );
    }

    _paintFixed3DFrame(
      canvas,
      size,
      zMinimum: minimum,
      zMaximum: maximum,
      zCoordinate: (value) => value * 2,
      xMinimum: minimum,
      xMaximum: maximum,
      yMinimum: minimum,
      yMaximum: maximum,
    );

    final sorted = [...triangles]
      ..sort((a, b) {
        double depth((_PlotPoint3, _PlotPoint3, _PlotPoint3) triangle) =>
            (rotate(triangle.$1).$3 +
                rotate(triangle.$2).$3 +
                rotate(triangle.$3).$3) /
            3;
        return depth(a).compareTo(depth(b));
      });
    var totalSurfaceArea = 0.0;
    var largestFaceArea = 0.0;
    var largestFaceSides = (0.0, 0.0, 0.0);
    double distance(_PlotPoint3 a, _PlotPoint3 b) => math.sqrt(
      math.pow(a.$1 - b.$1, 2) +
          math.pow(a.$2 - b.$2, 2) +
          math.pow(a.$3 - b.$3, 2),
    );
    double faceArea(_PlotPoint3 a, _PlotPoint3 b, _PlotPoint3 c) {
      final ab = (b.$1 - a.$1, b.$2 - a.$2, b.$3 - a.$3);
      final ac = (c.$1 - a.$1, c.$2 - a.$2, c.$3 - a.$3);
      final cross = (
        ab.$2 * ac.$3 - ab.$3 * ac.$2,
        ab.$3 * ac.$1 - ab.$1 * ac.$3,
        ab.$1 * ac.$2 - ab.$2 * ac.$1,
      );
      return math.sqrt(
            cross.$1 * cross.$1 + cross.$2 * cross.$2 + cross.$3 * cross.$3,
          ) /
          2;
    }

    for (final triangle in sorted) {
      final area = faceArea(triangle.$1, triangle.$2, triangle.$3);
      totalSurfaceArea += area;
      if (area > largestFaceArea) {
        largestFaceArea = area;
        largestFaceSides = (
          distance(triangle.$1, triangle.$2),
          distance(triangle.$2, triangle.$3),
          distance(triangle.$3, triangle.$1),
        );
      }
      final points = [
        project(triangle.$1),
        project(triangle.$2),
        project(triangle.$3),
      ];
      final path = Path()
        ..moveTo(points[0].dx, points[0].dy)
        ..lineTo(points[1].dx, points[1].dy)
        ..lineTo(points[2].dx, points[2].dy)
        ..close();
      final centerZ = (triangle.$1.$3 + triangle.$2.$3 + triangle.$3.$3) / 3;
      final tint = ((centerZ - minimum) / (maximum - minimum)).clamp(0.0, 1.0);
      final color = Color.lerp(
        const Color(0xFF7753D6),
        const Color(0xFFFF8C9E),
        tint,
      )!;
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: .88));
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFE5D8FF).withValues(alpha: .27)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .55,
      );
    }
    _label(
      canvas,
      'Implicit surface F(x,y,z) = 0',
      const Offset(14, 12),
      Colors.white,
    );
    _label(
      canvas,
      'Expression surface - drag to orbit',
      Offset(14, size.height - 22),
      const Color(0xFFFFC66D),
    );
    _metricBadge(
      canvas,
      'Σ face area ≈ ${totalSurfaceArea.toStringAsFixed(2)} units²',
      Offset(14, size.height - 56),
      const Color(0xFF9BE7FF),
      maxWidth: size.width - 28,
    );
    _metricBadge(
      canvas,
      'Face sides ${largestFaceSides.$1.toStringAsFixed(2)}, ${largestFaceSides.$2.toStringAsFixed(2)}, ${largestFaceSides.$3.toStringAsFixed(2)} | area ${largestFaceArea.toStringAsFixed(3)}',
      const Offset(14, 38),
      const Color(0xFFFFC66D),
      maxWidth: size.width - 28,
    );
  }

  String get _plotExpression {
    if (mode != _CalculatorMode.calculus) return expression;
    final source = expression.trim().isEmpty ? 'x^2' : expression;
    try {
      if (calculusOperation == 'Derivative') {
        return const MathEngine().differentiate(source);
      }
      if (calculusOperation == 'Indefinite integral') {
        return const MathEngine()
            .integrateIndefinite(source)
            .replaceFirst(RegExp(r'\s*\+\s*C$'), '');
      }
    } on Object {
      return source;
    }
    return source;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF1E2230), BlendMode.src);
    final centralDifference = CentralDifferenceFormula.tryParse(expression);
    if (centralDifference != null &&
        mode != _CalculatorMode.geometry &&
        mode != _CalculatorMode.trigonometry) {
      if (is3D) {
        _paintCentralDifference3D(canvas, size, centralDifference);
      } else {
        _paintCentralDifference2D(canvas, size, centralDifference);
      }
      return;
    }
    final rawFormula = PlotFormula(expression);
    final scalarPlotMode =
        mode == _CalculatorMode.basic ||
        mode == _CalculatorMode.scientific ||
        mode == _CalculatorMode.graphing ||
        mode == _CalculatorMode.algebra ||
        mode == _CalculatorMode.calculus;
    if (scalarPlotMode && expression.trim().isNotEmpty && rawFormula.isScalar) {
      final value = const MathEngine().evaluate(rawFormula.source);
      if (mode == _CalculatorMode.graphing) {
        if (is3D) {
          _paintConstantFunction3D(canvas, size, value);
        } else {
          _paintConstantFunction2D(canvas, size, value);
        }
      } else if (is3D) {
        _paintScalarResult3D(canvas, size, rawFormula.source);
      } else {
        _paintScalarResult2D(canvas, size, rawFormula.source);
      }
      return;
    }
    if (expressionPlot) {
      if (mode == _CalculatorMode.geometry) {
        if (is3D) {
          _paint3DGeometry(canvas, size);
        } else {
          _paintGeometry(canvas, size);
        }
      } else if (_triangle) {
        _paintTriangle(canvas, size);
      } else if (is3D) {
        if (_formula.isParametricSurface) {
          _paintParametricSurface(canvas, size);
        } else if (_hasXYZVariables && !_isExplicitZFunction) {
          _paintImplicitSurface(canvas, size);
        } else {
          _paintSurface(canvas, size);
        }
      } else if (_hasXYVariables && !_isExplicitYFunction) {
        _paintImplicitCurve(canvas, size);
      } else if (_isExplicitYFunction) {
        _paintGraph(canvas, size, functionExpression: _explicitYFunction);
      } else if (mode == _CalculatorMode.calculus &&
          calculusOperation == 'Definite integral') {
        _paintIntegral(canvas, size);
      } else {
        _paintGraph(canvas, size);
      }
      return;
    }
    if (mode == _CalculatorMode.geometry) {
      if (is3D) {
        _paint3DGeometry(canvas, size);
      } else {
        _paintGeometry(canvas, size);
      }
    } else if (_triangle) {
      _paintTriangle(canvas, size);
    } else if (is3D) {
      _paintSurface(canvas, size);
    } else if (mode == _CalculatorMode.calculus &&
        calculusOperation == 'Definite integral') {
      _paintIntegral(canvas, size);
    } else if (mode == _CalculatorMode.calculus &&
        calculusOperation == 'Derivative') {
      _paintDerivative(canvas, size);
    } else if (mode == _CalculatorMode.calculus) {
      _paintGraph(canvas, size);
    } else {
      _paintGraph(canvas, size);
    }
  }

  bool get _isExplicitYFunction => _formula.isExplicitY;

  String get _explicitYFunction => _formula.functionExpression;

  void _paint3DGeometry(Canvas canvas, Size size) {
    // Scientific convention: X red, Y green, Z blue. Solid surfaces use a
    // cool cyan/blue fill with amber edge highlights for clear depth cues.
    const surfaceColor = Color(0xFF36C9E8);
    const rearColor = Color(0xFF286FA8);
    const baseColor = Color(0xFFFFC66D);
    const sideColor = Color(0xFF35C46A);
    const secondarySideColor = Color(0xFFFF625A);
    const thirdSideColor = Color(0xFF9B7EDE);
    final radius = geometryFirst.clamp(.1, 20).toDouble();
    final secondary = geometrySecond.clamp(.1, 20).toDouble();
    final vertices = <(double, double, double)>[];
    final faces = <(int, int, int)>[];
    final faceColors = <Color>[];

    void face(int a, int b, int c, Color color) {
      faces.add((a, b, c));
      faceColors.add(color);
    }

    void quad(int a, int b, int c, int d, Color color) {
      face(a, b, c, color);
      face(a, c, d, color);
    }

    final operation = geometryOperation;
    if (operation.contains('Sphere')) {
      const latitudes = 16;
      const longitudes = 28;
      for (var lat = 0; lat <= latitudes; lat++) {
        final phi = -math.pi / 2 + math.pi * lat / latitudes;
        for (var lon = 0; lon <= longitudes; lon++) {
          final theta = 2 * math.pi * lon / longitudes;
          vertices.add((
            radius * math.cos(phi) * math.cos(theta),
            radius * math.sin(phi),
            radius * math.cos(phi) * math.sin(theta),
          ));
        }
      }
      for (var lat = 0; lat < latitudes; lat++) {
        for (var lon = 0; lon < longitudes; lon++) {
          final a = lat * (longitudes + 1) + lon;
          final b = a + longitudes + 1;
          quad(a, a + 1, b + 1, b, surfaceColor);
        }
      }
    } else if (operation.contains('Cone')) {
      const sides = 40;
      final h = secondary;
      vertices.add((0, h / 2, 0));
      for (var i = 0; i < sides; i++) {
        final angle = 2 * math.pi * i / sides;
        vertices.add((
          radius * math.cos(angle),
          -h / 2,
          radius * math.sin(angle),
        ));
      }
      final baseCenter = vertices.length;
      vertices.add((0, -h / 2, 0));
      for (var i = 0; i < sides; i++) {
        final next = (i + 1) % sides;
        face(0, i + 1, next + 1, surfaceColor);
        face(baseCenter, next + 1, i + 1, baseColor);
      }
    } else if (operation.contains('Cylinder') ||
        operation.startsWith('Circle')) {
      const sides = 40;
      final h = operation.startsWith('Circle')
          ? math.max(radius * .32, .25)
          : secondary;
      for (var cap = 0; cap < 2; cap++) {
        final y = cap == 0 ? -h / 2 : h / 2;
        for (var i = 0; i < sides; i++) {
          final angle = 2 * math.pi * i / sides;
          vertices.add((radius * math.cos(angle), y, radius * math.sin(angle)));
        }
      }
      final bottomCenter = vertices.length;
      vertices.add((0, -h / 2, 0));
      final topCenter = vertices.length;
      vertices.add((0, h / 2, 0));
      for (var i = 0; i < sides; i++) {
        final next = (i + 1) % sides;
        quad(i, next, sides + next, sides + i, surfaceColor);
        face(bottomCenter, next, i, baseColor);
        face(topCenter, sides + i, sides + next, rearColor);
      }
    } else {
      // Area/perimeter operations become a shallow prism. Right-triangle
      // calculations use the same base/height in a triangular prism.
      final length = radius;
      final height = secondary;
      final depth = math.min(length, height) * .62;
      if (operation.contains('Triangle') || operation.contains('Pythagorean')) {
        final points = <(double, double)>[
          (-length / 2, -height / 2),
          (length / 2, -height / 2),
          (length * .1, height / 2),
        ];
        for (final z in [-depth / 2, depth / 2]) {
          for (final point in points) {
            vertices.add((point.$1, point.$2, z));
          }
        }
        face(0, 1, 2, surfaceColor);
        face(3, 5, 4, rearColor);
        for (var i = 0; i < 3; i++) {
          final next = (i + 1) % 3;
          quad(
            i,
            next,
            3 + next,
            3 + i,
            [sideColor, secondarySideColor, thirdSideColor][i],
          );
        }
      } else {
        final x = length / 2, y = height / 2, z = depth / 2;
        vertices.addAll([
          (-x, -y, -z),
          (x, -y, -z),
          (x, y, -z),
          (-x, y, -z),
          (-x, -y, z),
          (x, -y, z),
          (x, y, z),
          (-x, y, z),
        ]);
        quad(0, 3, 2, 1, surfaceColor);
        quad(4, 5, 6, 7, rearColor);
        quad(0, 1, 5, 4, sideColor);
        quad(1, 2, 6, 5, secondarySideColor);
        quad(2, 3, 7, 6, baseColor);
        quad(3, 0, 4, 7, thirdSideColor);
      }
    }

    final objectExtent = math.max(radius, secondary).clamp(.1, 20).toDouble();
    (double, double, double) rotate((double, double, double) p) {
      final cy = math.cos(rotationY), sy = math.sin(rotationY);
      final cx = math.cos(rotationX), sx = math.sin(rotationX);
      final x = p.$1 * cy + p.$3 * sy;
      final z1 = -p.$1 * sy + p.$3 * cy;
      final y = p.$2 * cx - z1 * sx;
      final z = p.$2 * sx + z1 * cx;
      return (x, y, z);
    }

    Offset project((double, double, double) p) {
      return _projectRotating3D(
        size,
        p.$1 / objectExtent * 2.4,
        p.$2 / objectExtent * 2.4,
        p.$3 / objectExtent * 2.4,
      );
    }

    _paintFixed3DFrame(
      canvas,
      size,
      zMinimum: -objectExtent,
      zMaximum: objectExtent,
      zCoordinate: (value) => value / objectExtent * 3,
      xMinimum: -objectExtent,
      xMaximum: objectExtent,
      yMinimum: -objectExtent,
      yMaximum: objectExtent,
    );

    final transformed = vertices.map(rotate).toList(growable: false);
    final orderedFaceIndices = List<int>.generate(faces.length, (i) => i)
      ..sort((indexA, indexB) {
        double depth((int, int, int) f) =>
            (transformed[f.$1].$3 +
                transformed[f.$2].$3 +
                transformed[f.$3].$3) /
            3;
        return depth(faces[indexA]).compareTo(depth(faces[indexB]));
      });
    for (final faceIndex in orderedFaceIndices) {
      final f = faces[faceIndex];
      final a = transformed[f.$1], b = transformed[f.$2], c = transformed[f.$3];
      final ab = (b.$1 - a.$1, b.$2 - a.$2, b.$3 - a.$3);
      final ac = (c.$1 - a.$1, c.$2 - a.$2, c.$3 - a.$3);
      final normal = (
        ab.$2 * ac.$3 - ab.$3 * ac.$2,
        ab.$3 * ac.$1 - ab.$1 * ac.$3,
        ab.$1 * ac.$2 - ab.$2 * ac.$1,
      );
      final magnitude = math.sqrt(
        normal.$1 * normal.$1 + normal.$2 * normal.$2 + normal.$3 * normal.$3,
      );
      final light = magnitude == 0
          ? .45
          : ((normal.$1 * -.35 + normal.$2 * .55 + normal.$3 * .76) / magnitude)
                .abs();
      final shade = (.34 + light * .62).clamp(.32, .94);
      final path = Path()
        ..moveTo(project(vertices[f.$1]).dx, project(vertices[f.$1]).dy)
        ..lineTo(project(vertices[f.$2]).dx, project(vertices[f.$2]).dy)
        ..lineTo(project(vertices[f.$3]).dx, project(vertices[f.$3]).dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = faceColors[faceIndex].withValues(alpha: shade),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFB8F4FF).withValues(alpha: .54)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .65,
      );
    }

    _label(canvas, geometryOperation, const Offset(14, 12), Colors.white);
  }

  void _paintGeometry(Canvas canvas, Size size) {
    final c = Offset(size.width * .5, size.height * .53);
    final scale = math.min(size.width * .032, size.height * .032);
    final a = geometryFirst.clamp(.1, 20) * scale;
    final b = geometrySecond.clamp(.1, 20) * scale;
    final stroke = Paint()
      ..color = const Color(0xFF4A86FF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final green = Paint()
      ..color = const Color(0xFF35C46A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = const Color(0xFF4A86FF).withValues(alpha: .18)
      ..style = PaintingStyle.fill;
    if (geometryOperation.startsWith('Circle')) {
      final r = math.min(a, math.min(size.width * .3, size.height * .34));
      if (geometryOperation == 'Circle area') {
        canvas.drawCircle(c, r, fill);
      }
      canvas.drawCircle(c, r, stroke);
      if (is3D) {
        canvas.drawOval(
          Rect.fromCenter(
            center: c + const Offset(0, 12),
            width: r * 2,
            height: r * .55,
          ),
          green,
        );
      }
    } else if (geometryOperation.startsWith('Rectangle') ||
        geometryOperation == 'Parallelogram area') {
      final w = math.min(a, size.width * .62),
          h = math.min(b, size.height * .55);
      final l = c.dx - w / 2, t = c.dy - h / 2;
      final skew = geometryOperation == 'Parallelogram area' ? w * .2 : 0.0;
      final p = Path()
        ..moveTo(l + skew, t)
        ..lineTo(l + w + skew, t)
        ..lineTo(l + w, t + h)
        ..lineTo(l, t + h)
        ..close();
      canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
      if (is3D) {
        const d = Offset(22, -16);
        for (final point in [
          Offset(l + skew, t),
          Offset(l + w + skew, t),
          Offset(l + w, t + h),
          Offset(l, t + h),
        ]) {
          canvas.drawLine(point, point + d, green);
        }
      }
    } else if (geometryOperation == 'Triangle area' ||
        geometryOperation == 'Pythagorean hypotenuse') {
      final w = math.min(a, size.width * .62),
          h = math.min(b, size.height * .55);
      final l = c.dx - w / 2, base = c.dy + h / 2;
      final p = Path()
        ..moveTo(l, base)
        ..lineTo(l + w, base)
        ..lineTo(l + w * .62, base - h)
        ..close();
      canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
      if (geometryOperation == 'Pythagorean hypotenuse') {
        canvas.drawLine(
          Offset(l + w * .62, base - h),
          Offset(l + w * .62, base),
          green,
        );
      }
    } else if (geometryOperation.contains('Cylinder')) {
      final r = math.min(a, size.width * .25),
          h = math.min(b, size.height * .48);
      final rect = Rect.fromCenter(center: c, width: r * 2, height: h);
      canvas.drawRect(rect, fill);
      canvas.drawLine(
        Offset(rect.left, rect.top),
        Offset(rect.left, rect.bottom),
        stroke,
      );
      canvas.drawLine(
        Offset(rect.right, rect.top),
        Offset(rect.right, rect.bottom),
        stroke,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.dx, rect.top),
          width: r * 2,
          height: r * .55,
        ),
        stroke,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(c.dx, rect.bottom),
          width: r * 2,
          height: r * .55,
        ),
        0,
        math.pi,
        false,
        stroke,
      );
      if (is3D) {
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(c.dx, rect.bottom),
            width: r * 2,
            height: r * .55,
          ),
          math.pi,
          math.pi,
          false,
          green,
        );
      }
    } else if (geometryOperation.contains('Cone')) {
      final r = math.min(a, size.width * .27),
          h = math.min(b, size.height * .53);
      final top = Offset(c.dx, c.dy - h / 2),
          left = Offset(c.dx - r, c.dy + h / 2),
          right = Offset(c.dx + r, c.dy + h / 2);
      final p = Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close();
      canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
      final base = Rect.fromCenter(
        center: Offset(c.dx, c.dy + h / 2),
        width: r * 2,
        height: r * .55,
      );
      canvas.drawArc(base, 0, math.pi, false, stroke);
      if (is3D) canvas.drawArc(base, math.pi, math.pi, false, green);
    } else {
      final r = math.min(a, math.min(size.width * .28, size.height * .34));
      canvas.drawCircle(c, r, fill);
      canvas.drawCircle(c, r, stroke);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 2, height: r * .72),
        green,
      );
    }
    _label(canvas, geometryOperation, const Offset(16, 14), Colors.white);
    _label(
      canvas,
      is3D ? '3D solid preview' : '2D shape preview',
      Offset(16, size.height - 22),
      const Color(0xFF78A5FF),
    );
  }

  void _paintTriangle(Canvas canvas, Size size) {
    if (is3D) {
      _paintTriangleSolid(canvas, size);
      return;
    }
    final baseY = size.height * .78;
    final startX = size.width * .12;
    final radians = angle * math.pi / 180;
    final scale = math.min(
      size.width * .68 / (hypotenuse * math.cos(radians)),
      size.height * .54 / (hypotenuse * math.sin(radians)),
    );
    final start = Offset(startX, baseY);
    final apex = Offset(
      startX + hypotenuse * math.cos(radians) * scale,
      baseY - hypotenuse * math.sin(radians) * scale,
    );
    final end = Offset(apex.dx, baseY);
    final extrusion = is3D ? const Offset(24, -17) : Offset.zero;
    if (is3D) {
      final front = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(end.dx, end.dy)
        ..lineTo(apex.dx, apex.dy)
        ..close();
      final back = Path()
        ..moveTo(start.dx + extrusion.dx, start.dy + extrusion.dy)
        ..lineTo(end.dx + extrusion.dx, end.dy + extrusion.dy)
        ..lineTo(apex.dx + extrusion.dx, apex.dy + extrusion.dy)
        ..close();
      final side = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(end.dx, end.dy)
        ..lineTo(end.dx + extrusion.dx, end.dy + extrusion.dy)
        ..lineTo(start.dx + extrusion.dx, start.dy + extrusion.dy)
        ..close();
      canvas.drawPath(
        side,
        Paint()..color = const Color(0xFF36C9E8).withValues(alpha: .28),
      );
      canvas.drawPath(
        back,
        Paint()..color = const Color(0xFF286FA8).withValues(alpha: .22),
      );
      canvas.drawPath(
        front,
        Paint()..color = const Color(0xFF36C9E8).withValues(alpha: .22),
      );
    }
    final blue = Paint()
      ..color = const Color(0xFF4A86FF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final red = Paint()
      ..color = const Color(0xFFFF594D)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final green = Paint()
      ..color = const Color(0xFF35C46A)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, apex, blue);
    canvas.drawLine(apex, end, red);
    canvas.drawLine(start, end, green);
    if (is3D) {
      canvas.drawLine(start, start + extrusion, blue..strokeWidth = 1.5);
      canvas.drawLine(apex, apex + extrusion, blue..strokeWidth = 1.5);
      canvas.drawLine(end, end + extrusion, blue..strokeWidth = 1.5);
      canvas.drawLine(start + extrusion, apex + extrusion, blue);
      canvas.drawLine(apex + extrusion, end + extrusion, red);
      canvas.drawLine(start + extrusion, end + extrusion, green);
    }
    final adjacent = hypotenuse * math.cos(radians);
    final opposite = hypotenuse * math.sin(radians);
    _label(
      canvas,
      'Hypotenuse = ${hypotenuse.toStringAsFixed(1)}',
      Offset(size.width * .07, size.height * .30),
      const Color(0xFF4A86FF),
    );
    _label(
      canvas,
      'Opposite = ${opposite.toStringAsFixed(2)}',
      Offset(size.width * .54, size.height * .34),
      const Color(0xFFFF594D),
    );
    _label(
      canvas,
      'Adjacent = ${adjacent.toStringAsFixed(2)}',
      Offset(size.width * .35, size.height * .83),
      const Color(0xFF35C46A),
    );
    _label(
      canvas,
      'θ = ${angle.toStringAsFixed(0)}°',
      Offset(start.dx + 12, baseY - 30),
      const Color(0xFF78A5FF),
    );
    canvas.drawCircle(start, 4, Paint()..color = Colors.white);
    canvas.drawCircle(end, 4, Paint()..color = Colors.white);
    canvas.drawCircle(apex, 4, Paint()..color = const Color(0xFF4A86FF));
  }

  void _paintTriangleSolid(Canvas canvas, Size size) {
    const xColor = Color(0xFFFF625A);
    const yColor = Color(0xFF57D68D);
    const zColor = Color(0xFF4A86FF);
    const surfaceColor = Color(0xFF36C9E8);
    final radians = angle * math.pi / 180;
    final adjacent = hypotenuse * math.cos(radians);
    final opposite = hypotenuse * math.sin(radians);
    final triangleArea = adjacent * opposite / 2;
    final depth = hypotenuse * .36;
    final objectExtent = math.max(hypotenuse, depth).clamp(.1, 100).toDouble();
    final cy = math.cos(rotationY), sy = math.sin(rotationY);
    final cx = math.cos(rotationX), sx = math.sin(rotationX);
    (double, double, double) rotate((double, double, double) p) {
      final x = p.$1 * cy + p.$3 * sy;
      final z1 = -p.$1 * sy + p.$3 * cy;
      final y = p.$2 * cx - z1 * sx;
      final z = p.$2 * sx + z1 * cx;
      return (x, y, z);
    }

    Offset project((double, double, double) p) {
      return _projectRotating3D(
        size,
        (p.$1 - adjacent / 2) / objectExtent * 5,
        (p.$2 - opposite / 2) / objectExtent * 5,
        (p.$3 - depth / 2) / objectExtent * 5,
      );
    }

    const a = (0.0, 0.0, 0.0);
    final b = (adjacent, 0.0, 0.0);
    final c = (adjacent, opposite, 0.0);
    final backA = (0.0, 0.0, depth);
    final backB = (adjacent, 0.0, depth);
    final backC = (adjacent, opposite, depth);
    _paintFixed3DFrame(
      canvas,
      size,
      zMinimum: -objectExtent * .6,
      zMaximum: objectExtent * .6,
      zCoordinate: (value) => value / objectExtent * 5,
      xMinimum: -objectExtent * .6,
      xMaximum: objectExtent * .6,
      yMinimum: -objectExtent * .6,
      yMaximum: objectExtent * .6,
    );
    final faces = <(List<(double, double, double)>, Color, double)>[
      ([a, b, c], surfaceColor, .86),
      ([backA, backC, backB], const Color(0xFF286FA8), .5),
      ([a, backA, backB, b], yColor, .48),
      ([b, backB, backC, c], xColor, .48),
      ([c, backC, backA, a], const Color(0xFF9B7EDE), .48),
    ];
    faces.sort((left, right) {
      double depthOf((List<(double, double, double)>, Color, double) face) =>
          face.$1.map((p) => rotate(p).$3).reduce((x, y) => x + y) /
          face.$1.length;
      return depthOf(left).compareTo(depthOf(right));
    });
    for (final face in faces) {
      final points = face.$1.map(project).toList(growable: false);
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = face.$2.withValues(alpha: face.$3),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFB8F4FF).withValues(alpha: .62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
    }

    void edge(
      (double, double, double) from,
      (double, double, double) to,
      Color color,
    ) => canvas.drawLine(
      project(from),
      project(to),
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    edge(a, b, yColor);
    edge(b, c, xColor);
    edge(c, a, const Color(0xFF9B7EDE));
    edge(backA, backB, yColor.withValues(alpha: .7));
    edge(backB, backC, xColor.withValues(alpha: .7));
    edge(backC, backA, zColor.withValues(alpha: .7));
    edge(a, backA, zColor);
    edge(b, backB, zColor);
    edge(c, backC, zColor);

    final angleArc = Path();
    final arcRadius = hypotenuse * .14;
    for (var step = 0; step <= 18; step++) {
      final arcAngle = radians * step / 18;
      final point = project((
        arcRadius * math.cos(arcAngle),
        arcRadius * math.sin(arcAngle),
        0,
      ));
      if (step == 0) {
        angleArc.moveTo(point.dx, point.dy);
      } else {
        angleArc.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      angleArc,
      Paint()
        ..color = const Color(0xFFFFC66D)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

    final hypotenuseLabel = project((adjacent * .5, opposite * .54, 0));
    final adjacentLabel = project((adjacent * .5, 0, 0));
    final oppositeLabel = project((adjacent, opposite * .5, 0));
    _label(
      canvas,
      'Hypotenuse = ${hypotenuse.toStringAsFixed(1)}',
      Offset(hypotenuseLabel.dx - 65, hypotenuseLabel.dy - 24),
      zColor,
    );
    _label(
      canvas,
      'Adjacent = ${adjacent.toStringAsFixed(2)}',
      Offset(adjacentLabel.dx - 25, adjacentLabel.dy + 8),
      yColor,
    );
    _label(
      canvas,
      'Opposite = ${opposite.toStringAsFixed(2)}',
      Offset(oppositeLabel.dx + 8, oppositeLabel.dy - 8),
      xColor,
    );
    _metricBadge(
      canvas,
      'Shaded triangle | A = ½bh = ${triangleArea.toStringAsFixed(2)} units²',
      const Offset(12, 12),
      const Color(0xFFFFFFFF),
      maxWidth: size.width - 24,
    );
    _label(
      canvas,
      'θ = ${angle.toStringAsFixed(0)}°',
      project((.18 * adjacent, .05 * opposite, 0)) + const Offset(4, -18),
      const Color(0xFFFFC66D),
    );
  }

  String _short(double value) =>
      value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

  double _niceTickStep(double span, {int targetTicks = 6}) {
    if (!span.isFinite || span <= 0) return 1;
    final rough = span / targetTicks;
    final power = math
        .pow(10, (math.log(rough) / math.ln10).floor())
        .toDouble();
    final scaled = rough / power;
    final factor = scaled <= 1
        ? 1.0
        : scaled <= 2
        ? 2.0
        : scaled <= 5
        ? 5.0
        : 10.0;
    return factor * power;
  }

  (double, double) _niceBounds(double minimum, double maximum) {
    if (!minimum.isFinite || !maximum.isFinite) return (-1, 1);
    if ((maximum - minimum).abs() < 1e-9) {
      final padding = math.max(1.0, minimum.abs() * .1);
      minimum -= padding;
      maximum += padding;
    } else {
      final padding = (maximum - minimum) * .08;
      minimum -= padding;
      maximum += padding;
    }
    final step = _niceTickStep(maximum - minimum);
    return (
      (minimum / step).floorToDouble() * step,
      (maximum / step).ceilToDouble() * step,
    );
  }

  List<double> _ticks(double minimum, double maximum, {int targetTicks = 6}) {
    final step = _niceTickStep(maximum - minimum, targetTicks: targetTicks);
    final start = (minimum / step).ceil();
    final end = (maximum / step).floor();
    return [for (var index = start; index <= end; index++) index * step];
  }

  Offset _paintDynamicGraphAxes(
    Canvas canvas,
    Size size, {
    required Rect plot,
    required double xMin,
    required double xMax,
    required double yMin,
    required double yMax,
  }) {
    Offset point(double x, double y) => Offset(
      plot.left + (x - xMin) / (xMax - xMin) * plot.width,
      plot.bottom - (y - yMin) / (yMax - yMin) * plot.height,
    );
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .13)
      ..strokeWidth = .8;
    for (final x in _ticks(xMin, xMax)) {
      final px = point(x, 0).dx;
      canvas.drawLine(Offset(px, plot.top), Offset(px, plot.bottom), grid);
      _label(
        canvas,
        _short(x),
        Offset(px - 8, plot.bottom + 4),
        Colors.white70,
      );
    }
    for (final y in _ticks(yMin, yMax)) {
      final py = point(0, y).dy;
      canvas.drawLine(Offset(plot.left, py), Offset(plot.right, py), grid);
      _label(canvas, _short(y), Offset(plot.left - 34, py - 7), Colors.white70);
    }
    final axis = Paint()
      ..color = Colors.white.withValues(alpha: .76)
      ..strokeWidth = 1.4;
    final xAxisY = (0.0).clamp(yMin, yMax);
    final yAxisX = (0.0).clamp(xMin, xMax);
    final origin = point(yAxisX, xAxisY);
    canvas.drawLine(
      Offset(plot.left, origin.dy),
      Offset(plot.right, origin.dy),
      axis,
    );
    canvas.drawLine(
      Offset(origin.dx, plot.top),
      Offset(origin.dx, plot.bottom),
      axis,
    );
    _label(canvas, 'x', Offset(plot.right - 12, origin.dy + 3), Colors.white);
    _label(canvas, 'y', Offset(origin.dx + 4, plot.top + 2), Colors.white);
    return origin;
  }

  Offset _projectFixed3D(Size size, double x, double y, double z) {
    const yaw = .68, pitch = .58;
    final cameraX = x * math.cos(yaw) - y * math.sin(yaw);
    final cameraDepth = x * math.sin(yaw) + y * math.cos(yaw);
    final cameraY = z * math.cos(pitch) - cameraDepth * math.sin(pitch);
    final scale = math.min(size.width / 10, size.height / 8) * .92;
    return Offset(
      size.width * .5 + cameraX * scale,
      size.height * .58 - cameraY * scale,
    );
  }

  Offset _projectRotating3D(Size size, double x, double y, double z) {
    final cy = math.cos(rotationY), sy = math.sin(rotationY);
    final cx = math.cos(rotationX), sx = math.sin(rotationX);
    final rotatedX = x * cy + z * sy;
    final rotatedZ = -x * sy + z * cy;
    final rotatedY = y * cx - rotatedZ * sx;
    return _projectFixed3D(
      size,
      rotatedX * zoom,
      rotatedY * zoom,
      rotatedZ * zoom,
    );
  }

  void _paintFixed3DFrame(
    Canvas canvas,
    Size size, {
    required double zMinimum,
    required double zMaximum,
    required double Function(double) zCoordinate,
    double xMinimum = -3,
    double xMaximum = 3,
    double yMinimum = -3,
    double yMaximum = 3,
    bool labelsOnly = false,
  }) {
    Offset p(double x, double y, double z) => _projectFixed3D(size, x, y, z);
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .15)
      ..strokeWidth = .7;
    double xCoordinate(double x) =>
        -3 + 6 * (x - xMinimum) / (xMaximum - xMinimum);
    double yCoordinate(double y) =>
        -3 + 6 * (y - yMinimum) / (yMaximum - yMinimum);
    final xTicks = _ticks(xMinimum, xMaximum, targetTicks: 6);
    final yTicks = _ticks(yMinimum, yMaximum, targetTicks: 6);
    if (!labelsOnly) {
      for (final tick in xTicks) {
        final x = xCoordinate(tick);
        canvas.drawLine(p(x, -3, -3), p(x, 3, -3), grid);
        canvas.drawLine(p(x, 3, -3), p(x, 3, 3), grid);
      }
      for (final tick in yTicks) {
        final y = yCoordinate(tick);
        canvas.drawLine(p(-3, y, -3), p(3, y, -3), grid);
        canvas.drawLine(p(-3, y, -3), p(-3, y, 3), grid);
      }
    }
    final zeroZ = zMinimum <= 0 && zMaximum >= 0 ? zCoordinate(0) : -3.0;
    void axis(Offset start, Offset end, Color color) => canvas.drawLine(
      start,
      end,
      Paint()
        ..color = color
        ..strokeWidth = 2,
    );
    final zeroX = xCoordinate(0).clamp(-3.0, 3.0);
    final zeroY = yCoordinate(0).clamp(-3.0, 3.0);
    axis(p(-3, zeroY, zeroZ), p(3, zeroY, zeroZ), const Color(0xFFFF625A));
    axis(p(zeroX, -3, zeroZ), p(zeroX, 3, zeroZ), const Color(0xFF57D68D));
    axis(p(0, 0, -3), p(0, 0, 3), const Color(0xFF4A86FF));
    for (final tick in xTicks.where((tick) => tick != 0)) {
      final xp = p(xCoordinate(tick), zeroY, zeroZ);
      _label(canvas, _short(tick), xp + const Offset(1, 2), Colors.white70);
    }
    for (final tick in yTicks.where((tick) => tick != 0)) {
      final yp = p(zeroX, yCoordinate(tick), zeroZ);
      _label(canvas, _short(tick), yp + const Offset(1, 2), Colors.white70);
    }
    for (final tick in _ticks(zMinimum, zMaximum, targetTicks: 5)) {
      final zp = p(0, 0, zCoordinate(tick));
      _label(canvas, _short(tick), zp + const Offset(4, -7), Colors.white70);
    }
    _label(
      canvas,
      'x',
      p(3, zeroY, zeroZ) + const Offset(5, -10),
      const Color(0xFFFF625A),
    );
    _label(
      canvas,
      'y',
      p(zeroX, 3, zeroZ) + const Offset(5, -10),
      const Color(0xFF57D68D),
    );
    _label(
      canvas,
      'z',
      p(0, 0, 3) + const Offset(4, -12),
      const Color(0xFF4A86FF),
    );
  }

  void _paintGraph(Canvas canvas, Size size, {String? functionExpression}) {
    final plottedExpression = functionExpression ?? _plotExpression;
    const xMin = -6.0, xMax = 6.0;
    double valueAt(double x) {
      var y = slope * x + intercept;
      if (plottedExpression.trim().isNotEmpty &&
          (mode == _CalculatorMode.graphing ||
              mode == _CalculatorMode.calculus)) {
        try {
          y = const MathEngine().evaluateAt(plottedExpression, x);
        } on Object {
          y = double.nan;
        }
      }
      return y;
    }

    final samples = <(double, double)>[];
    for (var index = 0; index <= 240; index++) {
      final x = xMin + (xMax - xMin) * index / 240;
      samples.add((x, valueAt(x)));
    }
    final finite =
        samples.map((sample) => sample.$2).where((y) => y.isFinite).toList()
          ..sort();
    if (finite.isEmpty) {
      _label(
        canvas,
        'No real values in this range',
        const Offset(18, 18),
        Colors.white,
      );
      return;
    }
    // Trim a small number of extreme samples around poles so the useful curve
    // remains visible while discontinuities are still broken at the viewport.
    final low = finite[(finite.length * .03).floor()];
    final high =
        finite[(finite.length * .97).floor().clamp(0, finite.length - 1)];
    final (yMin, yMax) = _niceBounds(low, high);
    final graphRect = Rect.fromLTRB(42, 38, size.width - 18, size.height - 28);
    Offset point(double x, double y) => Offset(
      graphRect.left + (x - xMin) / (xMax - xMin) * graphRect.width,
      graphRect.bottom - (y - yMin) / (yMax - yMin) * graphRect.height,
    );
    _paintDynamicGraphAxes(
      canvas,
      size,
      plot: graphRect,
      xMin: xMin,
      xMax: xMax,
      yMin: yMin,
      yMax: yMax,
    );
    final path = Path();
    var connected = false;
    for (final sample in samples) {
      final y = sample.$2;
      final p = point(sample.$1, y);
      if (!y.isFinite || y < yMin || y > yMax) {
        connected = false;
      } else if (!connected) {
        path.moveTo(p.dx, p.dy);
        connected = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF4A86FF)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    final selectedY = valueAt(selectedX);
    final selected = point(selectedX, selectedY);
    if (selectedY.isFinite && selectedY >= yMin && selectedY <= yMax) {
      canvas.drawCircle(selected, 6, Paint()..color = const Color(0xFFFF594D));
    }
    _label(
      canvas,
      expression.trim().isEmpty
          ? 'y = ${slope.toStringAsFixed(1)}x + ${intercept.toStringAsFixed(1)}'
          : 'y = ${functionExpression ?? expression}',
      const Offset(20, 16),
      Colors.white,
    );
    _label(
      canvas,
      'x = ${selectedX.toStringAsFixed(1)}',
      selected.dx.isFinite && selected.dy.isFinite
          ? Offset(selected.dx + 8, selected.dy - 22)
          : const Offset(20, 38),
      const Color(0xFFFF8A7F),
    );
  }

  void _paintDerivative(Canvas canvas, Size size) {
    final source = expression.trim().isEmpty ? 'x^2' : expression;
    _paintGraph(canvas, size, functionExpression: source);
    try {
      final derivative = const MathEngine().differentiate(source);
      final slopeAtPoint = const MathEngine().evaluateAt(derivative, selectedX);
      final yAtPoint = const MathEngine().evaluateAt(source, selectedX);
      final sampled = [
        for (var index = 0; index <= 120; index++)
          const MathEngine().evaluateAt(source, -6 + index * .1),
      ]..removeWhere((value) => !value.isFinite);
      sampled.sort();
      final (yMin, yMax) = _niceBounds(
        sampled[(sampled.length * .03).floor()],
        sampled[(sampled.length * .97).floor().clamp(0, sampled.length - 1)],
      );
      const xMin = -6.0, xMax = 6.0;
      final graphRect = Rect.fromLTRB(
        42,
        38,
        size.width - 18,
        size.height - 28,
      );
      Offset graphPoint(double x, double y) => Offset(
        graphRect.left + (x - xMin) / (xMax - xMin) * graphRect.width,
        graphRect.bottom - (y - yMin) / (yMax - yMin) * graphRect.height,
      );
      final point = graphPoint(selectedX, yAtPoint);
      const leftX = -5.5, rightX = 5.5;
      double tangentY(double x) => yAtPoint + slopeAtPoint * (x - selectedX);
      canvas.drawLine(
        graphPoint(leftX, tangentY(leftX)),
        graphPoint(rightX, tangentY(rightX)),
        Paint()
          ..color = const Color(0xFFFF594D)
          ..strokeWidth = 2.5,
      );
      canvas.drawCircle(point, 5, Paint()..color = const Color(0xFFFF594D));
      _label(
        canvas,
        "f'(${selectedX.toStringAsFixed(1)}) = ${slopeAtPoint.toStringAsFixed(2)}",
        Offset(point.dx + 8, point.dy - 18),
        const Color(0xFFFF8A7F),
      );
    } on Object {
      _label(
        canvas,
        'Enter a differentiable function',
        const Offset(18, 18),
        Colors.white,
      );
    }
  }

  void _paintIntegral(Canvas canvas, Size size) {
    final integrand = expression.trim().isEmpty ? 'x^2' : expression;
    double f(double x) {
      try {
        return const MathEngine().evaluateAt(integrand, x);
      } on Object {
        return double.nan;
      }
    }

    final samples =
        [for (var index = 0; index <= 120; index++) f(-5 + index / 12)]
          ..removeWhere((value) => !value.isFinite)
          ..sort();
    if (samples.isEmpty) return;
    final (yMin, yMax) = _niceBounds(
      samples[(samples.length * .03).floor()],
      samples[(samples.length * .97).floor().clamp(0, samples.length - 1)],
    );
    const xMin = -5.0, xMax = 5.0;
    final graphRect = Rect.fromLTRB(42, 38, size.width - 18, size.height - 28);
    Offset point(double x, double y) => Offset(
      graphRect.left + (x - xMin) / (xMax - xMin) * graphRect.width,
      graphRect.bottom - (y - yMin) / (yMax - yMin) * graphRect.height,
    );
    _paintDynamicGraphAxes(
      canvas,
      size,
      plot: graphRect,
      xMin: xMin,
      xMax: xMax,
      yMin: yMin,
      yMax: yMax,
    );
    final baseline = (0.0).clamp(yMin, yMax);
    final fill = Path()
      ..moveTo(point(lower, baseline).dx, point(lower, baseline).dy);
    for (var index = 0; index <= 60; index++) {
      final x = lower + (upper - lower) * index / 60;
      final y = f(x);
      if (y.isFinite) fill.lineTo(point(x, y).dx, point(x, y).dy);
    }
    fill.lineTo(point(upper, baseline).dx, point(upper, baseline).dy);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()
        ..color = const Color(0xFF35C46A).withValues(alpha: .34)
        ..style = PaintingStyle.fill,
    );
    final curve = Path();
    for (var index = 0; index <= 80; index++) {
      final x = -5 + index * 10 / 80;
      final y = f(x);
      if (!y.isFinite || y < yMin || y > yMax) continue;
      final p = point(x, y);
      if (index == 0) {
        curve.moveTo(p.dx, p.dy);
      } else {
        curve.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      curve,
      Paint()
        ..color = const Color(0xFF4A86FF)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    _label(canvas, 'y = $integrand', const Offset(20, 16), Colors.white);
    _label(
      canvas,
      'a = ${lower.toStringAsFixed(1)}',
      Offset(point(lower, baseline).dx - 22, graphRect.bottom + 3),
      const Color(0xFF78A5FF),
    );
    _label(
      canvas,
      'b = ${upper.toStringAsFixed(1)}',
      Offset(point(upper, baseline).dx - 22, graphRect.bottom + 3),
      const Color(0xFF78A5FF),
    );
  }

  void _paintParametricSurface(Canvas canvas, Size size) {
    const cells = 36;
    const parameterStart = 0.0;
    const parameterEnd = 2 * math.pi;
    const engine = MathEngine();
    final coordinates = _formula.parametricCoordinates!;
    final samples = List<_PlotPoint3>.filled((cells + 1) * (cells + 1), (0, 0, 0));
    int index(int u, int v) => v * (cells + 1) + u;
    double parameter(int step) =>
        parameterStart + (parameterEnd - parameterStart) * step / cells;
    for (var vIndex = 0; vIndex <= cells; vIndex++) {
      for (var uIndex = 0; uIndex <= cells; uIndex++) {
        final values = {
          'u': parameter(uIndex),
          'v': parameter(vIndex),
          'r': 2.0,
        };
        try {
          samples[index(uIndex, vIndex)] = (
            engine.evaluateAtVariables(coordinates['x']!, values),
            engine.evaluateAtVariables(coordinates['y']!, values),
            engine.evaluateAtVariables(coordinates['z']!, values),
          );
        } on Object {
          samples[index(uIndex, vIndex)] = (double.nan, double.nan, double.nan);
        }
      }
    }
    final finite = samples.where((point) =>
        point.$1.isFinite && point.$2.isFinite && point.$3.isFinite).toList();
    if (finite.isEmpty) {
      _label(canvas, 'Could not evaluate this parametric surface', const Offset(14, 14), Colors.white);
      return;
    }
    final extent = finite.fold<double>(0, (current, point) => math.max(
      current,
      math.max(point.$1.abs(), math.max(point.$2.abs(), point.$3.abs())),
    )).clamp(.1, 1e6).toDouble();
    final normalized = samples.map((point) => point.$1.isFinite && point.$2.isFinite && point.$3.isFinite
        ? (point.$1 / extent * 2.55, point.$2 / extent * 2.55, point.$3 / extent * 2.55)
        : (double.nan, double.nan, double.nan)).toList(growable: false);
    Offset surfacePoint(_PlotPoint3 point) =>
        _projectRotating3D(size, point.$1, point.$2, point.$3);
    Offset basePoint(double x, double y) => _projectFixed3D(size, x, y, -3);
    _paintFixed3DFrame(
      canvas,
      size,
      zMinimum: -extent,
      zMaximum: extent,
      zCoordinate: (value) => value / extent * 2.55,
      xMinimum: -extent,
      xMaximum: extent,
      yMinimum: -extent,
      yMaximum: extent,
    );

    final ground = <Offset>[
      basePoint(-2.7, -2.7),
      basePoint(2.7, -2.7),
      basePoint(2.7, 2.7),
      basePoint(-2.7, 2.7),
    ];
    canvas.drawPath(
      Path()..addPolygon(ground, true),
      Paint()..color = const Color(0xFF6546C8).withValues(alpha: .08),
    );

    double triangleArea(_PlotPoint3 a, _PlotPoint3 b, _PlotPoint3 c) {
      final ab = (b.$1 - a.$1, b.$2 - a.$2, b.$3 - a.$3);
      final ac = (c.$1 - a.$1, c.$2 - a.$2, c.$3 - a.$3);
      final cross = (
        ab.$2 * ac.$3 - ab.$3 * ac.$2,
        ab.$3 * ac.$1 - ab.$1 * ac.$3,
        ab.$1 * ac.$2 - ab.$2 * ac.$1,
      );
      return math.sqrt(cross.$1 * cross.$1 + cross.$2 * cross.$2 + cross.$3 * cross.$3) / 2;
    }

    var area = 0.0;
    var faceCount = 0;
    for (var v = 0; v < cells; v++) {
      for (var u = 0; u < cells; u++) {
        final corners = [
          index(u, v),
          index(u + 1, v),
          index(u + 1, v + 1),
          index(u, v + 1),
        ];
        final points = corners.map((i) => normalized[i]).toList();
        if (points.any((p) => !p.$1.isFinite || !p.$2.isFinite || !p.$3.isFinite)) continue;
        for (final face in [(0, 1, 2), (0, 2, 3)]) {
          final a = points[face.$1], b = points[face.$2], c = points[face.$3];
          area += triangleArea(samples[corners[face.$1]], samples[corners[face.$2]], samples[corners[face.$3]]);
          faceCount++;
          final polygon = [surfacePoint(a), surfacePoint(b), surfacePoint(c)];
          final path = Path()..addPolygon(polygon, true);
          final shade = ((a.$3 + b.$3 + c.$3) / 3 / 5.1 + .5).clamp(0.0, 1.0);
          final color = Color.lerp(const Color(0xFF168B67), const Color(0xFF42D392), shade)!;
          canvas.drawPath(path, Paint()..color = color.withValues(alpha: .14));
        }
        final projected = points.map(surfacePoint).toList();
        final wire = Path()
          ..moveTo(projected[0].dx, projected[0].dy)
          ..lineTo(projected[1].dx, projected[1].dy)
          ..lineTo(projected[2].dx, projected[2].dy)
          ..lineTo(projected[3].dx, projected[3].dy)
          ..close();
        canvas.drawPath(wire, Paint()
          ..color = const Color(0xFF20C879).withValues(alpha: .92)
          ..strokeWidth = .65
          ..style = PaintingStyle.stroke);
      }
    }
    final contourPaint = Paint()
      ..color = const Color(0xFFFF4058)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var v = 0; v < cells; v++) {
      for (var u = 0; u < cells; u++) {
        final corners = [index(u, v), index(u + 1, v), index(u + 1, v + 1), index(u, v + 1)];
        final points = corners.map((i) => samples[i]).toList();
        final crossings = <Offset>[];
        for (var edge = 0; edge < 4; edge++) {
          final a = points[edge], b = points[(edge + 1) % 4];
          if (!a.$3.isFinite || !b.$3.isFinite || (a.$3 < 0) == (b.$3 < 0)) continue;
          final t = a.$3 / (a.$3 - b.$3);
          final x = (a.$1 + (b.$1 - a.$1) * t) / extent * 2.55;
          final y = (a.$2 + (b.$2 - a.$2) * t) / extent * 2.55;
          crossings.add(basePoint(x, y));
        }
        for (var point = 0; point + 1 < crossings.length; point += 2) {
          canvas.drawLine(crossings[point], crossings[point + 1], contourPaint);
        }
      }
    }
    _label(canvas, 'Parametric surface  (u, v)', const Offset(14, 10), Colors.white);
    _metricBadge(
      canvas,
      '$faceCount mesh faces  •  surface area ≈ ${area.toStringAsFixed(2)} units²',
      Offset(12, size.height - 28),
      const Color(0xFF65E6A5),
      maxWidth: size.width - 24,
    );
  }

  void _paintSurface(Canvas canvas, Size size) {
    if (_formula.isParametricSurface) {
      _paintParametricSurface(canvas, size);
      return;
    }
    // A denser mesh makes curved surfaces read like the reference plot while
    // keeping evaluation work small enough for interactive rotation.
    const cells = 32;
    const min = -3.0;
    const max = 3.0;
    const engine = MathEngine();
    final enteredExpression = _plotExpression.trim();
    final source = _isExplicitZFunction
        ? _explicitZFunction
        : enteredExpression.isNotEmpty
        ? enteredExpression
        : mode == _CalculatorMode.calculus
        ? 'x^2+y^2'
        : '($slope)*x+($intercept)';
    final values = List<double>.filled((cells + 1) * (cells + 1), 0);
    int index(int x, int y) => y * (cells + 1) + x;
    double coordinate(int step) => min + (max - min) * step / cells;
    for (var y = 0; y <= cells; y++) {
      for (var x = 0; x <= cells; x++) {
        try {
          final px = coordinate(x), py = coordinate(y);
          values[index(x, y)] = engine.evaluateAtVariables(source, {
            'x': px,
            'y': py,
          });
        } on Object {
          values[index(x, y)] = double.nan;
        }
      }
    }
    final finiteValues = values.where((value) => value.isFinite).toList();
    if (finiteValues.isEmpty) {
      _label(
        canvas,
        'No real surface values in this range',
        const Offset(14, 14),
        Colors.white,
      );
      return;
    }
    final rawMinimum = finiteValues.reduce(math.min);
    final rawMaximum = finiteValues.reduce(math.max);
    final (zMinimum, zMaximum) = _niceBounds(rawMinimum, rawMaximum);
    double zCoordinate(double value) =>
        -3 + 6 * (value - zMinimum) / (zMaximum - zMinimum);
    Offset project(double x, double y, double z) =>
        _projectRotating3D(size, x, y, zCoordinate(z));
    _paintFixed3DFrame(
      canvas,
      size,
      zMinimum: zMinimum,
      zMaximum: zMaximum,
      zCoordinate: zCoordinate,
    );

    final baseCorners = <Offset>[
      project(min, min, zMinimum),
      project(max, min, zMinimum),
      project(max, max, zMinimum),
      project(min, max, zMinimum),
    ];
    final base = Path()
      ..moveTo(baseCorners.first.dx, baseCorners.first.dy)
      ..addPolygon(baseCorners, true);
    canvas.drawPath(
      base,
      Paint()
        ..color = const Color(0xFF6546C8).withValues(alpha: .22)
        ..style = PaintingStyle.fill,
    );
    final baseGrid = Paint()
      ..color = const Color(0xFF9B84F5).withValues(alpha: .76)
      ..strokeWidth = .7
      ..style = PaintingStyle.stroke;
    for (var tick = 0; tick <= cells; tick++) {
      final value = coordinate(tick);
      canvas.drawLine(
        project(value, min, zMinimum),
        project(value, max, zMinimum),
        baseGrid,
      );
      canvas.drawLine(
        project(min, value, zMinimum),
        project(max, value, zMinimum),
        baseGrid,
      );
    }

    double triangleArea(_PlotPoint3 a, _PlotPoint3 b, _PlotPoint3 c) {
      final ab = (b.$1 - a.$1, b.$2 - a.$2, b.$3 - a.$3);
      final ac = (c.$1 - a.$1, c.$2 - a.$2, c.$3 - a.$3);
      final cross = (
        ab.$2 * ac.$3 - ab.$3 * ac.$2,
        ab.$3 * ac.$1 - ab.$1 * ac.$3,
        ab.$1 * ac.$2 - ab.$2 * ac.$1,
      );
      return math.sqrt(
            cross.$1 * cross.$1 + cross.$2 * cross.$2 + cross.$3 * cross.$3,
          ) /
          2;
    }

    var meshArea = 0.0;
    var patchCount = 0;
    for (var y = 0; y < cells; y++) {
      for (var x = 0; x < cells; x++) {
        final z = [
          values[index(x, y)],
          values[index(x + 1, y)],
          values[index(x + 1, y + 1)],
          values[index(x, y + 1)],
        ];
        if (z.any((value) => !value.isFinite)) continue;
        final vertices = <_PlotPoint3>[
          (coordinate(x), coordinate(y), z[0]),
          (coordinate(x + 1), coordinate(y), z[1]),
          (coordinate(x + 1), coordinate(y + 1), z[2]),
          (coordinate(x), coordinate(y + 1), z[3]),
        ];
        final average = z.reduce((a, b) => a + b) / z.length;
        final tint = ((average - zMinimum) / (zMaximum - zMinimum))
            .clamp(0.0, 1.0)
            .toDouble();
        final faceColor = Color.lerp(
          const Color(0xFF168B67),
          const Color(0xFF42D392),
          tint,
        )!;
        for (final face in [(0, 1, 2), (0, 2, 3)]) {
          final a = vertices[face.$1],
              b = vertices[face.$2],
              c = vertices[face.$3];
          final area = triangleArea(a, b, c);
          meshArea += area;
          patchCount++;
          final p = [
            project(a.$1, a.$2, a.$3),
            project(b.$1, b.$2, b.$3),
            project(c.$1, c.$2, c.$3),
          ];
          final triangle = Path()
            ..moveTo(p[0].dx, p[0].dy)
            ..lineTo(p[1].dx, p[1].dy)
            ..lineTo(p[2].dx, p[2].dy)
            ..close();
          canvas.drawPath(
            triangle,
            Paint()
              ..color = faceColor.withValues(alpha: .12)
              ..style = PaintingStyle.fill,
          );
        }
      }
    }

    final surfaceMesh = Paint()
      ..color = const Color(0xFF20C879).withValues(alpha: .96)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var row = 0; row <= cells; row++) {
      final path = Path();
      var connected = false;
      for (var column = 0; column <= cells; column++) {
        final z = values[index(column, row)];
        if (!z.isFinite) {
          connected = false;
          continue;
        }
        final point = project(coordinate(column), coordinate(row), z);
        if (!connected) {
          path.moveTo(point.dx, point.dy);
          connected = true;
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, surfaceMesh);
    }
    for (var column = 0; column <= cells; column++) {
      final path = Path();
      var connected = false;
      for (var row = 0; row <= cells; row++) {
        final z = values[index(column, row)];
        if (!z.isFinite) {
          connected = false;
          continue;
        }
        final point = project(coordinate(column), coordinate(row), z);
        if (!connected) {
          path.moveTo(point.dx, point.dy);
          connected = true;
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, surfaceMesh);
    }

    if (zMinimum <= 0 && zMaximum >= 0) {
      final contourPaint = Paint()
        ..color = const Color(0xFFFF4058)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (var row = 0; row < cells; row++) {
        for (var column = 0; column < cells; column++) {
          final corners = <(double, double, double)>[
            (coordinate(column), coordinate(row), values[index(column, row)]),
            (
              coordinate(column + 1),
              coordinate(row),
              values[index(column + 1, row)],
            ),
            (
              coordinate(column + 1),
              coordinate(row + 1),
              values[index(column + 1, row + 1)],
            ),
            (
              coordinate(column),
              coordinate(row + 1),
              values[index(column, row + 1)],
            ),
          ];
          if (corners.any((corner) => !corner.$3.isFinite)) continue;
          final crossings = <Offset>[];
          for (var edge = 0; edge < corners.length; edge++) {
            final a = corners[edge], b = corners[(edge + 1) % corners.length];
            const zeroTolerance = 1e-9;
            final aIsZero = a.$3.abs() <= zeroTolerance;
            final bIsZero = b.$3.abs() <= zeroTolerance;
            if (aIsZero && bIsZero) {
              // Preserve contour segments that lie exactly on mesh edges,
              // such as z = x² along x = 0.
              crossings
                ..add(project(a.$1, a.$2, zMinimum))
                ..add(project(b.$1, b.$2, zMinimum));
              continue;
            }
            if (aIsZero) {
              crossings.add(project(a.$1, a.$2, zMinimum));
              continue;
            }
            if (bIsZero) {
              crossings.add(project(b.$1, b.$2, zMinimum));
              continue;
            }
            if ((a.$3 < 0) == (b.$3 < 0)) continue;
            final ratio = (a.$3 / (a.$3 - b.$3)).clamp(0.0, 1.0);
            crossings.add(project(
              a.$1 + (b.$1 - a.$1) * ratio,
              a.$2 + (b.$2 - a.$2) * ratio,
              zMinimum,
            ));
          }
          for (var point = 0; point + 1 < crossings.length; point += 2) {
            canvas.drawLine(
              crossings[point],
              crossings[point + 1],
              contourPaint,
            );
          }
        }
      }
    }

    _paintFixed3DFrame(
      canvas,
      size,
      zMinimum: zMinimum,
      zMaximum: zMaximum,
      zCoordinate: zCoordinate,
      labelsOnly: true,
    );
    _label(canvas, 'z = $source', const Offset(14, 10), Colors.white);
    _metricBadge(
      canvas,
      '$patchCount mesh faces  •  surface area ≈ ${meshArea.toStringAsFixed(2)} units²',
      Offset(12, size.height - 28),
      const Color(0xFF65E6A5),
      maxWidth: size.width - 24,
    );
  }

  void _label(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 210);
    final bounds = canvas.getLocalClipBounds();
    final safeOffset = Offset(
      offset.dx.clamp(
        bounds.left + 4,
        math.max(bounds.left + 4, bounds.right - painter.width - 4),
      ),
      offset.dy.clamp(
        bounds.top + 4,
        math.max(bounds.top + 4, bounds.bottom - painter.height - 4),
      ),
    );
    painter.paint(canvas, safeOffset);
  }

  void _metricBadge(
    Canvas canvas,
    String text,
    Offset offset,
    Color color, {
    required double maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(1, maxWidth - 16));
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        offset.dx,
        offset.dy,
        painter.width + 16,
        painter.height + 10,
      ),
      const Radius.circular(9),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = const Color(0xFF111827).withValues(alpha: .82),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: .42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    painter.paint(canvas, offset + const Offset(8, 5));
  }

  @override
  bool shouldRepaint(covariant _MathVisualizationPainter oldDelegate) => true;
}
