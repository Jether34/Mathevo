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
      final perspective = 4.2 / (4.2 + rotated.$3 / 1.5);
      final scale = math.min(size.width, size.height) * .34 * perspective;
      return Offset(
        size.width / 2 + rotated.$1 * scale,
        size.height / 2 - rotated.$2 * scale,
      );
    }

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
    _paint3DAxes(canvas, size, project);
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

  void _paint3DAxes(
    Canvas canvas,
    Size size,
    Offset Function((double, double, double)) project,
  ) {
    const axisDefinitions = <((double, double, double), Color, String)>[
      ((1.65, 0, 0), Color(0xFFFF625A), 'x'),
      ((0, 1.65, 0), Color(0xFF57D68D), 'y'),
      ((0, 0, 1.65), Color(0xFF4A86FF), 'z'),
    ];
    final origin = project((0, 0, 0));
    for (final (end, color, label) in axisDefinitions) {
      final finish = project(end);
      canvas.drawLine(
        origin,
        finish,
        Paint()
          ..color = color
          ..strokeWidth = 2.1,
      );
      _label(canvas, label, finish + const Offset(3, -10), color);
    }
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
      if (is3D) {
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
        if (_hasXYZVariables && !_isExplicitZFunction) {
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
    final transformCanvas =
        is3D &&
        mode != _CalculatorMode.geometry &&
        mode != _CalculatorMode.trigonometry;
    if (transformCanvas) {
      final centerX = size.width / 2;
      final centerY = size.height / 2;
      final transform = Matrix4.identity()
        ..setEntry(3, 2, .001)
        ..translateByDouble(centerX, centerY, 0, 1)
        ..rotateX(rotationX)
        ..rotateY(rotationY)
        ..scaleByDouble(zoom, zoom, 1, 1)
        ..translateByDouble(-centerX, -centerY, 0, 1);
      canvas.save();
      canvas.transform(transform.storage);
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
    if (transformCanvas) canvas.restore();
  }

  bool get _isExplicitYFunction => _formula.isExplicitY;

  String get _explicitYFunction => _formula.functionExpression;

  void _paint3DGeometry(Canvas canvas, Size size) {
    // Scientific convention: X red, Y green, Z blue. Solid surfaces use a
    // cool cyan/blue fill with amber edge highlights for clear depth cues.
    const xColor = Color(0xFFFF625A);
    const yColor = Color(0xFF57D68D);
    const zColor = Color(0xFF4A86FF);
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

    final scale =
        math.min(size.width, size.height) *
        .31 *
        zoom /
        math.max(radius, secondary).clamp(.1, 20);
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
      final q = rotate(p);
      final perspective = 4.2 / (4.2 + q.$3 / math.max(radius, secondary));
      final s = scale * perspective;
      return Offset(size.width * .5 + q.$1 * s, size.height * .52 - q.$2 * s);
    }

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

    void axis((double, double, double) end, Color color, String label) {
      final start = project((0, 0, 0));
      final finish = project(end);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(start, finish, paint);
      final direction = finish - start;
      if (direction.distance > 0) {
        final unit = direction / direction.distance;
        final normal = Offset(-unit.dy, unit.dx);
        final arrow = Path()
          ..moveTo(finish.dx, finish.dy)
          ..lineTo(
            finish.dx - unit.dx * 8 + normal.dx * 4,
            finish.dy - unit.dy * 8 + normal.dy * 4,
          )
          ..lineTo(
            finish.dx - unit.dx * 8 - normal.dx * 4,
            finish.dy - unit.dy * 8 - normal.dy * 4,
          )
          ..close();
        canvas.drawPath(arrow, Paint()..color = color);
      }
      _label(canvas, label, finish + const Offset(3, -11), color);
    }

    axis((radius * 1.35, 0, 0), xColor, 'x');
    axis((0, secondary * .75, 0), yColor, 'y');
    axis((0, 0, radius * 1.35), zColor, 'z');
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
    final sceneScale =
        math.min(
          size.width * .52 / (adjacent + depth),
          size.height * .46 / (opposite + depth),
        ) *
        zoom;
    final cy = math.cos(rotationY), sy = math.sin(rotationY);
    final cx = math.cos(rotationX), sx = math.sin(rotationX);
    final originX = size.width * .5;
    final originY = size.height * .52;
    var sceneShift = Offset.zero;

    (double, double, double) rotate((double, double, double) p) {
      final x = p.$1 * cy + p.$3 * sy;
      final z1 = -p.$1 * sy + p.$3 * cy;
      final y = p.$2 * cx - z1 * sx;
      final z = p.$2 * sx + z1 * cx;
      return (x, y, z);
    }

    Offset project((double, double, double) p) {
      final q = rotate(p);
      final perspective = 4.5 / (4.5 + q.$3 / hypotenuse);
      return Offset(
            originX + q.$1 * sceneScale * perspective,
            originY - q.$2 * sceneScale * perspective,
          ) +
          sceneShift;
    }

    const a = (0.0, 0.0, 0.0);
    final b = (adjacent, 0.0, 0.0);
    final c = (adjacent, opposite, 0.0);
    final backA = (0.0, 0.0, depth);
    final backB = (adjacent, 0.0, depth);
    final backC = (adjacent, opposite, depth);
    final projectedVertices = [
      a,
      b,
      c,
      backA,
      backB,
      backC,
    ].map(project).toList(growable: false);
    final left = projectedVertices.map((point) => point.dx).reduce(math.min);
    final right = projectedVertices.map((point) => point.dx).reduce(math.max);
    final top = projectedVertices.map((point) => point.dy).reduce(math.min);
    final bottom = projectedVertices.map((point) => point.dy).reduce(math.max);
    sceneShift = Offset(
      size.width * .5 - (left + right) / 2,
      size.height * .52 - (top + bottom) / 2,
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

  void _paintAxes(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .09)
      ..strokeWidth = 1;
    for (var value = -5; value <= 5; value++) {
      final x = size.width * (.5 + value / 12);
      final y = size.height * (.72 - value / 24);
      canvas.drawLine(Offset(x, 20), Offset(x, size.height - 28), grid);
      canvas.drawLine(Offset(24, y), Offset(size.width - 18, y), grid);
    }
    final axis = Paint()
      ..color = Colors.white.withValues(alpha: .65)
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(28, size.height * .72),
      Offset(size.width - 18, size.height * .72),
      axis,
    );
    canvas.drawLine(
      Offset(size.width * .5, 16),
      Offset(size.width * .5, size.height - 20),
      axis,
    );
    for (var value = -5; value <= 5; value++) {
      final x = size.width * (.5 + value / 12);
      final y = size.height * (.72 - value / 24);
      canvas.drawLine(
        Offset(x, size.height * .72 - 3),
        Offset(x, size.height * .72 + 3),
        axis,
      );
      canvas.drawLine(
        Offset(size.width * .5 - 3, y),
        Offset(size.width * .5 + 3, y),
        axis,
      );
      _label(
        canvas,
        '$value',
        Offset(x - 6, size.height * .72 + 4),
        Colors.white70,
      );
      _label(
        canvas,
        '$value',
        Offset(size.width * .5 - 24, y - 6),
        Colors.white70,
      );
    }
    _label(
      canvas,
      'x',
      Offset(size.width - 16, size.height * .72 + 4),
      Colors.white,
    );
    _label(canvas, 'y', Offset(size.width * .5 + 4, 18), Colors.white);
  }

  String _short(double value) =>
      value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

  void _paintGraph(Canvas canvas, Size size, {String? functionExpression}) {
    _paintAxes(canvas, size);
    final plottedExpression = functionExpression ?? _plotExpression;
    Offset point(double x) {
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
      return Offset(size.width * (.5 + x / 12), size.height * (.72 - y / 24));
    }

    final path = Path();
    var connected = false;
    for (var index = 0; index <= 80; index++) {
      final x = -6 + index * 12 / 80;
      final p = point(x);
      if (!p.dy.isFinite) {
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
    final selected = point(selectedX);
    if (selected.dx.isFinite && selected.dy.isFinite) {
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
      final point = Offset(
        size.width * (.5 + selectedX / 12),
        size.height * (.72 - yAtPoint / 24),
      );
      const leftX = -5.5;
      const rightX = 5.5;
      double tangentY(double x) => yAtPoint + slopeAtPoint * (x - selectedX);
      canvas.drawLine(
        Offset(
          size.width * (.5 + leftX / 12),
          size.height * (.72 - tangentY(leftX) / 24),
        ),
        Offset(
          size.width * (.5 + rightX / 12),
          size.height * (.72 - tangentY(rightX) / 24),
        ),
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
    _paintAxes(canvas, size);
    final integrand = expression.trim().isEmpty ? 'x^2' : expression;
    double f(double x) {
      try {
        return const MathEngine().evaluateAt(integrand, x).clamp(-10, 10);
      } on Object {
        return 0;
      }
    }

    Offset point(double x) =>
        Offset(size.width * (.5 + x / 10), size.height * (.72 - f(x) / 28));
    final fill = Path()..moveTo(point(lower).dx, size.height * .72);
    for (var index = 0; index <= 60; index++) {
      final x = lower + (upper - lower) * index / 60;
      fill.lineTo(point(x).dx, point(x).dy);
    }
    fill.lineTo(point(upper).dx, size.height * .72);
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
      final p = point(x);
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
      Offset(point(lower).dx - 22, size.height * .76),
      const Color(0xFF78A5FF),
    );
    _label(
      canvas,
      'b = ${upper.toStringAsFixed(1)}',
      Offset(point(upper).dx - 22, size.height * .76),
      const Color(0xFF78A5FF),
    );
  }

  void _paintSurface(Canvas canvas, Size size) {
    const cells = 18;
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
    final cosX = math.cos(rotationX), sinX = math.sin(rotationX);
    final cosY = math.cos(rotationY), sinY = math.sin(rotationY);
    Offset project(double x, double y, double z) {
      final rotatedX = x * cosY + z * sinY;
      final rotatedZ = -x * sinY + z * cosY;
      final rotatedY = y * cosX - rotatedZ * sinX;
      final depth = y * sinX + rotatedZ * cosX;
      final perspective = 4.2 / (4.2 + depth / 1.5);
      final scale = math.min(size.width, size.height) * .13 * perspective;
      return Offset(
        size.width * .5 + rotatedX * scale,
        size.height * .55 - rotatedY * scale,
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
          (coordinate(x), coordinate(y), z[0].clamp(-5, 5)),
          (coordinate(x + 1), coordinate(y), z[1].clamp(-5, 5)),
          (coordinate(x + 1), coordinate(y + 1), z[2].clamp(-5, 5)),
          (coordinate(x), coordinate(y + 1), z[3].clamp(-5, 5)),
        ];
        final average = z.reduce((a, b) => a + b) / z.length;
        final tint = ((average.clamp(-5, 5) + 5) / 10).toDouble();
        final faceColor = Color.lerp(
          const Color(0xFF7046C8),
          const Color(0xFF42C7D5),
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
            Paint()..color = faceColor.withValues(alpha: .82),
          );
          canvas.drawPath(
            triangle,
            Paint()
              ..color = const Color(0xFFE5F5FF).withValues(alpha: .58)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .7,
          );
        }
      }
    }
    final origin = project(0, 0, 0);
    for (final (end, color, label) in <(_PlotPoint3, Color, String)>[
      ((3.4, 0, 0), const Color(0xFFFF625A), 'x'),
      ((0, 3.4, 0), const Color(0xFF57D68D), 'y'),
      ((0, 0, 4), const Color(0xFF4A86FF), 'z'),
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
    _label(canvas, 'z = $source', const Offset(14, 12), Colors.white);
    _metricBadge(
      canvas,
      '$patchCount shaded faces | surface area ≈ ${meshArea.toStringAsFixed(2)} units²',
      Offset(12, size.height - 38),
      const Color(0xFF9BE7FF),
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
