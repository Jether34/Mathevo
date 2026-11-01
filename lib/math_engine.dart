import 'dart:math' as math;

import 'package:math_expressions/math_expressions.dart';

import 'exact_arithmetic.dart';

enum MathResultKind { exact, approximate }

enum MathSupportStatus { supported, limited, planned, unsupported }

class MathCapability {
  const MathCapability({
    required this.id,
    required this.label,
    required this.status,
    required this.note,
  });

  final String id;
  final String label;
  final MathSupportStatus status;
  final String note;
}

/// The user-facing and code-level record of current computation coverage.
const mathCapabilities = <MathCapability>[
  MathCapability(
    id: 'real_expression_evaluation',
    label: 'Real expression evaluation',
    status: MathSupportStatus.limited,
    note: 'Offline numeric results for the supported math_expressions grammar.',
  ),
  MathCapability(
    id: 'exact_arithmetic',
    label: 'Exact arithmetic',
    status: MathSupportStatus.limited,
    note: 'Exact rational arithmetic for numeric literals and basic operators.',
  ),
  MathCapability(
    id: 'symbolic_algebra',
    label: 'Symbolic algebra and equation solving',
    status: MathSupportStatus.limited,
    note:
        'Linear/quadratic equations in one variable and 2 x 2 linear systems are supported.',
  ),
  MathCapability(
    id: 'calculus',
    label: 'Calculus',
    status: MathSupportStatus.limited,
    note:
        'Symbolic derivatives, limited antiderivatives, and numerical definite integrals are supported.',
  ),
  MathCapability(
    id: 'scientific_functions',
    label: 'Scientific functions',
    status: MathSupportStatus.limited,
    note:
        'Offline real-valued functions supported by math_expressions; domain and angle entry limits apply.',
  ),
  MathCapability(
    id: 'linear_systems',
    label: 'Linear equation systems',
    status: MathSupportStatus.limited,
    note:
        'Two-variable linear systems are supported; nonlinear systems are not.',
  ),
  MathCapability(
    id: 'graphing',
    label: 'Function graphing',
    status: MathSupportStatus.limited,
    note: 'Single-variable real functions are sampled for a 2D plot.',
  ),
  MathCapability(
    id: 'geometry',
    label: 'Geometry formulas',
    status: MathSupportStatus.limited,
    note:
        'Common circle, polygon, right-triangle, cylinder, cone, and sphere measures are available.',
  ),
  MathCapability(
    id: 'integer_base_operations',
    label: 'Integer base conversion and bitwise operations',
    status: MathSupportStatus.limited,
    note:
        'Binary, octal, decimal, hexadecimal, integer arithmetic, bitwise logic, and bounded shifts.',
  ),
];

class MathResult {
  const MathResult({
    required this.input,
    required this.value,
    required this.kind,
    required this.significantDigits,
    this.exactValue,
  });

  final String input;
  final double? value;
  final MathResultKind kind;
  final int significantDigits;
  final String? exactValue;

  String get displayValue =>
      exactValue ?? formatApproximateValue(value!, significantDigits);
}

String formatApproximateValue(double value, [int significantDigits = 12]) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', 'Must be finite.');
  }
  if (significantDigits < 1 || significantDigits > 15) {
    throw RangeError.range(significantDigits, 1, 15, 'significantDigits');
  }
  if (value == 0) return '0';

  final raw = value.toStringAsPrecision(significantDigits);
  final parts = raw.split('e');
  var mantissa = parts.first;
  if (mantissa.contains('.')) {
    mantissa = mantissa.replaceFirst(RegExp(r'0+$'), '');
    mantissa = mantissa.replaceFirst(RegExp(r'\.$'), '');
  }
  return parts.length == 1 ? mantissa : '${mantissa}e${parts.last}';
}

/// Evaluates a real-valued mathematical expression locally on the device.
/// The parser is intentionally limited to the grammar provided by
/// `math_expressions`; it never executes generated or arbitrary code.
class MathEngine {
  static final Map<String, Expression> _numericExpressionCache = {};

  const MathEngine();

  /// Symbolically differentiates supported expressions using the expression
  /// AST. The returned expression is simplified where the AST can do so.
  String differentiate(String input, {String variable = 'x'}) {
    final source = input.trim();
    if (source.isEmpty) throw const MathInputException('Enter an expression.');
    try {
      final expression = GrammarParser().parse(source);
      final derivative = expression.derive(variable).simplify();
      return derivative.toString();
    } on Object {
      throw const MathInputException(
        'Could not differentiate this expression. Check its syntax.',
      );
    }
  }

  /// Solves one-variable linear and quadratic polynomial equations.
  EquationSolution solveEquation(String input, {String variable = 'x'}) {
    final sides = input.split('=');
    if (sides.length != 2 || sides.any((side) => side.trim().isEmpty)) {
      throw const MathInputException(
        'Enter an equation with one equals sign, such as x^2 - 5*x + 6 = 0.',
      );
    }
    try {
      final parser = GrammarParser();
      final left = parser.parse(sides[0]);
      final right = parser.parse(sides[1]);
      final polynomial = _Polynomial.fromExpression(left - right, variable);
      final coefficients = polynomial.coefficients;
      final a = coefficients[2] ?? 0;
      final b = coefficients[1] ?? 0;
      final c = coefficients[0] ?? 0;
      final steps = <String>[
        'Set both sides equal to zero.',
        '${_formatPolynomial(a, b, c, variable)} = 0',
      ];
      if (a.abs() < 1e-12) {
        if (b.abs() < 1e-12) {
          if (c.abs() < 1e-12) {
            return EquationSolution(
              roots: const [],
              steps: [...steps, 'Every real number satisfies the identity.'],
              identity: true,
            );
          }
          return EquationSolution(
            roots: const [],
            steps: [...steps, 'No solution exists.'],
          );
        }
        final root = -c / b;
        steps.add('Isolate $variable: $variable = ${_formatReal(root)}');
        return EquationSolution(roots: [_formatReal(root)], steps: steps);
      }
      final discriminant = b * b - 4 * a * c;
      steps.add('Discriminant: D = b² - 4ac = ${_formatReal(discriminant)}');
      if (discriminant < -1e-12) {
        final real = -b / (2 * a);
        final imaginary = math.sqrt(-discriminant) / (2 * a).abs();
        final roots = [
          '${_formatReal(real)} + ${_formatReal(imaginary)}i',
          '${_formatReal(real)} - ${_formatReal(imaginary)}i',
        ];
        steps.add('Apply the quadratic formula; the roots are complex.');
        return EquationSolution(roots: roots, steps: steps);
      }
      final radical = math.sqrt(math.max(0, discriminant));
      final first = (-b - radical) / (2 * a);
      final second = (-b + radical) / (2 * a);
      final roots = (first - second).abs() < 1e-12
          ? [_formatReal(first)]
          : [_formatReal(first), _formatReal(second)];
      steps.add('$variable = (-b ± √D) / 2a = ${roots.join(' , ')}');
      return EquationSolution(roots: roots, steps: steps);
    } on MathInputException {
      rethrow;
    } on Object {
      throw MathInputException(
        'Could not solve this equation. Supported forms are linear and quadratic polynomials in $variable.',
      );
    }
  }

  LinearSystemSolution solveLinearSystem(String input) {
    final equations = input.split(';');
    if (equations.length != 2) {
      throw const MathInputException(
        'Enter two equations separated by a semicolon, for example 2*x+y=5; x-y=1.',
      );
    }
    try {
      final parser = GrammarParser();
      final rows = <List<double>>[];
      for (final equation in equations) {
        final sides = equation.split('=');
        if (sides.length != 2) {
          throw const MathInputException(
            'Each equation needs one equals sign.',
          );
        }
        final difference = parser.parse(sides[0]) - parser.parse(sides[1]);
        final coefficients = _LinearPair.fromExpression(difference);
        rows.add([coefficients.x, coefficients.y, coefficients.constant]);
      }
      final first = rows[0], second = rows[1];
      final determinant = first[0] * second[1] - second[0] * first[1];
      final steps = <String>[
        'Write both equations in the form ax + by + c = 0.',
        'Use the 2 x 2 coefficient determinant to check for a unique solution.',
      ];
      if (determinant.abs() < 1e-12) {
        final firstHasVariables =
            first[0].abs() >= 1e-12 || first[1].abs() >= 1e-12;
        final secondHasVariables =
            second[0].abs() >= 1e-12 || second[1].abs() >= 1e-12;
        final inconsistentZeroRow =
            (!firstHasVariables && first[2].abs() >= 1e-12) ||
            (!secondHasVariables && second[2].abs() >= 1e-12);
        final allZero =
            !firstHasVariables && !secondHasVariables && !inconsistentZeroRow;
        final sameLine =
            firstHasVariables &&
            secondHasVariables &&
            (first[0] * second[2] - second[0] * first[2]).abs() < 1e-12 &&
            (first[1] * second[2] - second[1] * first[2]).abs() < 1e-12;
        return LinearSystemSolution(
          display: inconsistentZeroRow
              ? 'No solution'
              : allZero || sameLine || !firstHasVariables || !secondHasVariables
              ? 'Infinitely many solutions'
              : 'No solution',
          steps: steps,
        );
      }
      final x = (first[1] * second[2] - second[1] * first[2]) / determinant;
      final y = (second[0] * first[2] - first[0] * second[2]) / determinant;
      steps.add('x = ${_formatReal(x)}, y = ${_formatReal(y)}');
      return LinearSystemSolution(
        display: 'x = ${_formatReal(x)}, y = ${_formatReal(y)}',
        steps: steps,
      );
    } on MathInputException {
      rethrow;
    } on Object {
      throw const MathInputException(
        'Only linear equations in x and y can be solved as a 2 x 2 system.',
      );
    }
  }

  /// Numerically evaluates a definite integral with adaptive Simpson
  /// quadrature. The result is always marked approximate.
  MathResult integrateDefinite(
    String input, {
    required double lower,
    required double upper,
    String variable = 'x',
    double tolerance = 1e-8,
    int maxDepth = 18,
  }) {
    final source = input.trim();
    if (source.isEmpty) throw const MathInputException('Enter an integrand.');
    if (!lower.isFinite ||
        !upper.isFinite ||
        !tolerance.isFinite ||
        tolerance <= 0) {
      throw const MathInputException(
        'Use finite bounds and a positive tolerance.',
      );
    }
    try {
      final expression = GrammarParser().parse(source);
      final variables = VariableCollector().evaluate(expression).toSet();
      if (variables.difference({variable}).isNotEmpty) {
        throw MathInputException(
          'Only the variable $variable can be integrated.',
        );
      }
      if (lower == upper) {
        return MathResult(
          input: source,
          value: 0,
          kind: MathResultKind.approximate,
          significantDigits: 12,
        );
      }
      final direction = lower < upper ? 1.0 : -1.0;
      final a = math.min(lower, upper);
      final b = math.max(lower, upper);
      double f(double x) {
        final context = ContextModel()..bindVariableName(variable, Number(x));
        final value = RealEvaluator(
          context,
          true,
        ).evaluate(expression).toDouble();
        if (!value.isFinite) {
          throw const MathInputException(
            'The integrand is not finite throughout this interval.',
          );
        }
        return value;
      }

      final fa = f(a), fb = f(b), mid = (a + b) / 2, fm = f(mid);
      final whole = (b - a) * (fa + 4 * fm + fb) / 6;
      double adaptive(
        double left,
        double right,
        double fLeft,
        double fMid,
        double fRight,
        double estimate,
        double epsilon,
        int depth,
      ) {
        final center = (left + right) / 2;
        final leftMid = (left + center) / 2;
        final rightMid = (center + right) / 2;
        final fLeftMid = f(leftMid), fRightMid = f(rightMid);
        final leftEstimate =
            (center - left) * (fLeft + 4 * fLeftMid + fMid) / 6;
        final rightEstimate =
            (right - center) * (fMid + 4 * fRightMid + fRight) / 6;
        final delta = leftEstimate + rightEstimate - estimate;
        if (depth <= 0 || delta.abs() <= 15 * epsilon) {
          return leftEstimate + rightEstimate + delta / 15;
        }
        return adaptive(
              left,
              center,
              fLeft,
              fLeftMid,
              fMid,
              leftEstimate,
              epsilon / 2,
              depth - 1,
            ) +
            adaptive(
              center,
              right,
              fMid,
              fRightMid,
              fRight,
              rightEstimate,
              epsilon / 2,
              depth - 1,
            );
      }

      final result =
          direction * adaptive(a, b, fa, fm, fb, whole, tolerance, maxDepth);
      return MathResult(
        input: source,
        value: result,
        kind: MathResultKind.approximate,
        significantDigits: 12,
      );
    } on MathInputException {
      rethrow;
    } on Object {
      throw const MathInputException(
        'Could not integrate this expression over the selected bounds.',
      );
    }
  }

  double evaluateAt(String input, double value, {String variable = 'x'}) {
    try {
      final expression = GrammarParser().parse(input.trim());
      final context = ContextModel()..bindVariableName(variable, Number(value));
      final result = RealEvaluator(
        context,
        true,
      ).evaluate(expression).toDouble();
      if (!result.isFinite) {
        throw const MathInputException('The result is not finite.');
      }
      return result;
    } on MathInputException {
      rethrow;
    } on Object {
      throw const MathInputException('Could not evaluate at this value.');
    }
  }

  /// Evaluates a numeric expression with multiple named variables bound.
  /// Parsed trees are reused so sampled 2D/3D plots do not parse per point.
  double evaluateAtVariables(String input, Map<String, double> values) {
    try {
      final source = input.trim();
      if (source.isEmpty) {
        throw const MathInputException('Enter an expression.');
      }
      final expression = _numericExpressionCache.putIfAbsent(source, () {
        if (_numericExpressionCache.length >= 32) {
          _numericExpressionCache.clear();
        }
        return GrammarParser().parse(source);
      });
      final context = ContextModel();
      for (final entry in values.entries) {
        context.bindVariableName(entry.key, Number(entry.value));
      }
      final result = RealEvaluator(
        context,
        true,
      ).evaluate(expression).toDouble();
      if (!result.isFinite) {
        throw const MathInputException('The result is not finite.');
      }
      return result;
    } on MathInputException {
      rethrow;
    } on Object {
      throw const MathInputException(
        'Could not evaluate with these variables.',
      );
    }
  }

  String integrateIndefinite(String input, {String variable = 'x'}) {
    final source = input.trim();
    if (source.isEmpty) throw const MathInputException('Enter an integrand.');
    try {
      final expression = GrammarParser().parse(source);
      final result = _integrateExpression(expression, variable).simplify();
      return '${result.toString()} + C';
    } on MathInputException {
      rethrow;
    } on Object {
      throw const MathInputException(
        'This integrand is outside the supported indefinite integration rules.',
      );
    }
  }

  Expression _integrateExpression(Expression expression, String variable) {
    if (expression is Number) {
      return Number(expression.value) * Variable(variable);
    }
    if (expression is Variable) {
      if (expression.name != variable) {
        throw MathInputException('Only the variable $variable is supported.');
      }
      return Power(Variable(variable), Number(2)) / Number(2);
    }
    if (expression is UnaryMinus) {
      return -_integrateExpression(expression.exp, variable);
    }
    if (expression is UnaryPlus) {
      return _integrateExpression(expression.exp, variable);
    }
    if (expression is Plus || expression is Minus) {
      final operator = expression as BinaryOperator;
      final left = _integrateExpression(operator.first, variable);
      final right = _integrateExpression(operator.second, variable);
      return expression is Minus ? left - right : left + right;
    }
    if (expression is Times || expression is Divide) {
      final operator = expression as BinaryOperator;
      if (expression is Times && _isConstantExpression(operator.first)) {
        return operator.first * _integrateExpression(operator.second, variable);
      }
      if (expression is Times && _isConstantExpression(operator.second)) {
        return operator.second * _integrateExpression(operator.first, variable);
      }
      if (expression is Divide && _isConstantExpression(operator.second)) {
        final value = _constantExpressionValue(operator.second);
        if (value == 0) throw const MathInputException('Division by zero.');
        return _integrateExpression(operator.first, variable) / operator.second;
      }
      throw const MathInputException(
        'For products or quotients, the non-integrated factor must be constant.',
      );
    }
    if (expression is Power &&
        expression.first is Variable &&
        expression.second is Number) {
      final base = expression.first as Variable;
      final exponent = (expression.second as Number).value;
      if (base.name != variable) {
        throw MathInputException('Only the variable $variable is supported.');
      }
      if ((exponent + 1).abs() < 1e-12) return Ln(Variable(variable));
      final nextPower = exponent + 1;
      return Power(Variable(variable), Number(nextPower)) / Number(nextPower);
    }
    if (expression is Sin &&
        expression.arg is Variable &&
        (expression.arg as Variable).name == variable) {
      return -Cos(Variable(variable));
    }
    if (expression is Cos &&
        expression.arg is Variable &&
        (expression.arg as Variable).name == variable) {
      return Sin(Variable(variable));
    }
    if (expression is Exponential &&
        expression.exp is Variable &&
        (expression.exp as Variable).name == variable) {
      return Exponential(Variable(variable));
    }
    throw const MathInputException(
      'This expression does not match the supported polynomial and basic trig rules.',
    );
  }

  static bool _isConstantExpression(Expression expression) =>
      expression is Literal && expression.isConstant();

  static double _constantExpressionValue(Expression expression) =>
      ((expression as Literal).getConstantValue() as num).toDouble();

  static String _formatReal(double value) {
    if (value.abs() < 1e-12) return '0';
    if ((value - value.roundToDouble()).abs() < 1e-10) {
      return value.round().toString();
    }
    return formatApproximateValue(value, 10);
  }

  static String _formatPolynomial(double a, double b, double c, String x) {
    final terms = <String>[];
    if (a.abs() > 1e-12) terms.add('${_formatReal(a)}$x²');
    if (b.abs() > 1e-12) terms.add('${_formatReal(b)}$x');
    if (c.abs() > 1e-12 || terms.isEmpty) terms.add(_formatReal(c));
    return terms.join(' + ').replaceAll('+ -', '- ');
  }

  /// Returns numeric post-order reductions for supported expression trees.
  /// Each line is evaluated by this engine; it does not invent symbolic rules.
  List<String> solutionSteps(String input) {
    final root = GrammarParser().parse(input.trim());
    final steps = <String>[];
    String cleanNumber(String source) =>
        source.replaceAll(RegExp(r'\.0\b'), '');
    String reduce(Expression expression) {
      if (expression is BinaryOperator) {
        final left = cleanNumber(reduce(expression.first));
        final right = cleanNumber(reduce(expression.second));
        final operator = switch (expression) {
          Plus() => '+',
          Minus() => '-',
          Times() => '*',
          Divide() => '/',
          Power() => '^',
          _ => null,
        };
        if (operator == null) return expression.toString();
        final line = '$left $operator $right';
        final answer = calculate(line).displayValue;
        steps.add('$line = $answer');
        return answer;
      }
      if (expression is UnaryMinus) return '-${reduce(expression.exp)}';
      return cleanNumber(expression.toString());
    }

    reduce(root);
    return steps;
  }

  /// Returns exact rational results where this engine's arithmetic grammar
  /// supports them, then falls back to approximate real-number evaluation.
  MathResult calculate(String input, {int significantDigits = 12}) {
    final source = input.trim();
    if (source.isEmpty) throw const MathInputException('Enter an expression.');
    if (source.length > 256) {
      throw const MathInputException(
        'Expressions must be 256 characters or fewer.',
      );
    }
    if (significantDigits < 1 || significantDigits > 15) {
      throw const MathInputException(
        'Precision must be between 1 and 15 significant digits.',
      );
    }
    try {
      final exact = ExactArithmeticParser.tryParse(source);
      if (exact != null) {
        final approximate = exact.approximate;
        return MathResult(
          input: source,
          value: approximate.isFinite ? approximate : null,
          kind: MathResultKind.exact,
          significantDigits: significantDigits,
          exactValue: exact.display,
        );
      }
    } on ExactArithmeticException catch (error) {
      throw MathInputException(error.message);
    }
    try {
      final expression = GrammarParser().parse(source);
      final value = RealEvaluator(
        ContextModel(),
        true,
      ).evaluate(expression).toDouble();
      if (!value.isFinite) {
        throw const MathInputException(
          'The result is not a finite real number.',
        );
      }
      return MathResult(
        input: source,
        value: value,
        kind: MathResultKind.approximate,
        significantDigits: significantDigits,
      );
    } on MathInputException {
      rethrow;
    } on Object {
      throw const MathInputException(
        'Could not evaluate this expression. Check its syntax and domain.',
      );
    }
  }

  /// Compatibility helper for callers that only need the numeric value.
  double evaluate(String input) {
    final value = calculate(input).value;
    if (value == null) {
      throw const MathInputException(
        'This exact result is outside the finite numeric range.',
      );
    }
    return value;
  }
}

class EquationSolution {
  const EquationSolution({
    required this.roots,
    required this.steps,
    this.identity = false,
  });
  final List<String> roots;
  final List<String> steps;
  final bool identity;

  String get display => identity
      ? 'All real numbers'
      : roots.isEmpty
      ? 'No solution'
      : roots.map((root) => 'x = $root').join(', ');
}

class LinearSystemSolution {
  const LinearSystemSolution({required this.display, required this.steps});
  final String display;
  final List<String> steps;
}

class _LinearPair {
  const _LinearPair(this.x, this.y, this.constant);
  final double x, y, constant;

  static _LinearPair fromExpression(Expression expression) {
    if (expression is Number) return _LinearPair(0, 0, expression.value);
    if (expression is Variable) {
      return switch (expression.name) {
        'x' => const _LinearPair(1, 0, 0),
        'y' => const _LinearPair(0, 1, 0),
        _ => throw const MathInputException('Use only x and y.'),
      };
    }
    if (expression is UnaryMinus || expression is UnaryPlus) {
      final operand = fromExpression((expression as UnaryOperator).exp);
      final factor = expression is UnaryMinus ? -1.0 : 1.0;
      return _LinearPair(
        operand.x * factor,
        operand.y * factor,
        operand.constant * factor,
      );
    }
    if (expression is Plus || expression is Minus) {
      final operator = expression as BinaryOperator;
      final left = fromExpression(operator.first),
          right = fromExpression(operator.second);
      final sign = expression is Minus ? -1.0 : 1.0;
      return _LinearPair(
        left.x + sign * right.x,
        left.y + sign * right.y,
        left.constant + sign * right.constant,
      );
    }
    if (expression is Times || expression is Divide) {
      final operator = expression as BinaryOperator;
      final left = fromExpression(operator.first),
          right = fromExpression(operator.second);
      if (expression is Times) {
        if (left.x == 0 && left.y == 0) {
          return _LinearPair(
            right.x * left.constant,
            right.y * left.constant,
            right.constant * left.constant,
          );
        }
        if (right.x == 0 && right.y == 0) {
          return _LinearPair(
            left.x * right.constant,
            left.y * right.constant,
            left.constant * right.constant,
          );
        }
        throw const MathInputException('Products of variables are nonlinear.');
      }
      if (right.x != 0 || right.y != 0 || right.constant == 0) {
        throw const MathInputException('Divide only by a non-zero constant.');
      }
      return _LinearPair(
        left.x / right.constant,
        left.y / right.constant,
        left.constant / right.constant,
      );
    }
    throw const MathInputException('Unsupported term in linear system.');
  }
}

class _Polynomial {
  _Polynomial(this.coefficients);
  final Map<int, double> coefficients;

  static _Polynomial fromExpression(Expression expression, String variable) {
    if (expression is Number) return _Polynomial({0: expression.value});
    if (expression is Variable) {
      if (expression.name != variable) {
        throw const MathInputException('Use only the variable x.');
      }
      return _Polynomial({1: 1});
    }
    if (expression is UnaryMinus) {
      return _scale(fromExpression(expression.exp, variable), -1);
    }
    if (expression is UnaryPlus) {
      return fromExpression(expression.exp, variable);
    }
    if (expression is Plus || expression is Minus) {
      final operator = expression as BinaryOperator;
      final left = fromExpression(operator.first, variable);
      final right = fromExpression(operator.second, variable);
      final sign = expression is Minus ? -1 : 1;
      final result = Map<int, double>.from(left.coefficients);
      for (final entry in right.coefficients.entries) {
        result.update(
          entry.key,
          (value) => value + sign * entry.value,
          ifAbsent: () => sign * entry.value,
        );
      }
      return _clean(result);
    }
    if (expression is Times) {
      final left = fromExpression(expression.first, variable);
      final right = fromExpression(expression.second, variable);
      final result = <int, double>{};
      for (final a in left.coefficients.entries) {
        for (final b in right.coefficients.entries) {
          final degree = a.key + b.key;
          if (degree > 2) {
            throw const MathInputException(
              'Only equations up to degree two are supported.',
            );
          }
          result.update(
            degree,
            (value) => value + a.value * b.value,
            ifAbsent: () => a.value * b.value,
          );
        }
      }
      return _clean(result);
    }
    if (expression is Divide) {
      final numerator = fromExpression(expression.first, variable);
      final denominator = fromExpression(expression.second, variable);
      if (denominator.coefficients.keys.any((degree) => degree != 0) ||
          (denominator.coefficients[0] ?? 0) == 0) {
        throw const MathInputException('Divide only by a non-zero constant.');
      }
      return _scale(numerator, 1 / denominator.coefficients[0]!);
    }
    if (expression is Power && expression.second is Number) {
      final power = (expression.second as Number).value;
      if (power < 0 || power > 2 || power != power.roundToDouble()) {
        throw const MathInputException(
          'Only powers zero, one, and two are supported.',
        );
      }
      var result = _Polynomial({0: 1});
      final base = fromExpression(expression.first, variable);
      for (var i = 0; i < power.toInt(); i++) {
        final expanded = <int, double>{};
        for (final a in result.coefficients.entries) {
          for (final b in base.coefficients.entries) {
            final degree = a.key + b.key;
            if (degree > 2) {
              throw const MathInputException(
                'Only equations up to degree two are supported.',
              );
            }
            expanded.update(
              degree,
              (v) => v + a.value * b.value,
              ifAbsent: () => a.value * b.value,
            );
          }
        }
        result = _clean(expanded);
      }
      return result;
    }
    throw const MathInputException('Unsupported equation term.');
  }

  static _Polynomial _scale(_Polynomial source, double factor) => _clean(
    source.coefficients.map(
      (degree, value) => MapEntry(degree, value * factor),
    ),
  );

  static _Polynomial _clean(Map<int, double> values) {
    values.removeWhere((_, value) => value.abs() < 1e-12);
    return _Polynomial(values);
  }
}

class MathInputException implements Exception {
  const MathInputException(this.message);
  final String message;

  @override
  String toString() => message;
}
