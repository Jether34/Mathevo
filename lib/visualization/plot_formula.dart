import 'dart:math' as math;

/// Parsed plot input separated from canvas rendering and calculator widgets.
/// It classifies what an expression represents before a 2D/3D renderer decides
/// how to draw it.
class PlotFormula {
  PlotFormula(String input) : source = normalize(input) {
    final equality = RegExp(r'(?<![<>])=(?![=])').allMatches(source).toList();
    if (equality.isEmpty) {
      leftExpression = source;
      rightExpression = '0';
    } else {
      final split = equality.first;
      leftExpression = source.substring(0, split.start).trim();
      rightExpression = source.substring(split.end).trim();
    }
    final explicit = RegExp(
      r'^\s*([yz])\s*=\s*(.+)$',
      dotAll: true,
    ).firstMatch(source);
    dependentVariable = explicit?.group(1);
    functionExpression = explicit?.group(2)?.trim() ?? source;
    hasX = RegExp(r'\bx\b').hasMatch(functionExpression);
    hasY = RegExp(r'\by\b').hasMatch(functionExpression);
    hasZ = RegExp(r'\bz\b').hasMatch(functionExpression);
  }

  final String source;
  late final String leftExpression;
  late final String rightExpression;
  late final String? dependentVariable;
  late final String functionExpression;
  late final bool hasX;
  late final bool hasY;
  late final bool hasZ;

  bool get isExplicitY => dependentVariable == 'y' && !hasY;
  bool get isExplicitZ => dependentVariable == 'z';
  bool get hasXY => hasX && hasY;
  bool get hasXYZ => hasXY && hasZ;
  bool get isScalar => dependentVariable == null && !hasX && !hasY && !hasZ;
  bool get isImplicitCurve => hasXY && dependentVariable == null;
  bool get isImplicitSurface => hasXYZ && dependentVariable == null;

  CentralDifferenceFormula? get centralDifference =>
      CentralDifferenceFormula.tryParse(source);

  static String normalize(String input) => input
      .trim()
      .replaceAll('\u00D7', '*')
      .replaceAll('\u00F7', '/')
      .replaceAll(RegExp(r'\s+'), '');
}

/// Recognizes the central difference of x^2 at a numeric center and step.
/// The original input is a scalar calculation, but its two sample terms also
/// specify the curve and secant that should be visualized.
class CentralDifferenceFormula {
  const CentralDifferenceFormula({required this.center, required this.step});

  final double center;
  final double step;

  double get leftX => center - step;
  double get rightX => center + step;
  double get leftY => leftX * leftX;
  double get rightY => rightX * rightX;
  double get exactDerivative => 2 * center;
  double get approximateDerivative {
    final raw = (rightY - leftY) / (2 * step);
    return (raw - exactDerivative).abs() < 1e-10 ? exactDerivative : raw;
  }

  String get function => 'x^2';

  static final _pattern = RegExp(
    r'^\(\(([^()]+)\+([^()]+)\)\^2-\(([^()]+)-([^()]+)\)\^2\)/\(2\*([^()]+)\)$',
  );

  static CentralDifferenceFormula? tryParse(String input) {
    var source = PlotFormula.normalize(input);
    source = source.replaceFirst(RegExp(r'^[yz]='), '');
    final match = _pattern.firstMatch(source);
    if (match == null) return null;
    final centerPlus = double.tryParse(match.group(1)!);
    final firstStep = double.tryParse(match.group(2)!);
    final centerMinus = double.tryParse(match.group(3)!);
    final secondStep = double.tryParse(match.group(4)!);
    final denominatorStep = double.tryParse(match.group(5)!);
    if (centerPlus == null ||
        firstStep == null ||
        centerMinus == null ||
        secondStep == null ||
        denominatorStep == null ||
        denominatorStep == 0) {
      return null;
    }
    final tolerance = 1e-10 * math.max(1, centerPlus.abs());
    if ((centerPlus - centerMinus).abs() > tolerance ||
        (firstStep - secondStep).abs() > tolerance ||
        (firstStep - denominatorStep).abs() > tolerance) {
      return null;
    }
    return CentralDifferenceFormula(
      center: (centerPlus + centerMinus) / 2,
      step: denominatorStep,
    );
  }
}
