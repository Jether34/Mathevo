/// Exact rational arithmetic for expressions containing numeric literals and
/// `+`, `-`, `*`, `/`, `^`, and parentheses. Other grammar falls back to the
/// numeric expression engine.
class ExactArithmeticException implements Exception {
  const ExactArithmeticException(this.message);
  final String message;

  @override
  String toString() => message;
}

class Rational {
  factory Rational(BigInt numerator, BigInt denominator) {
    if (denominator == BigInt.zero) {
      throw const ExactArithmeticException('Division by zero is undefined.');
    }
    final gcd = _gcd(numerator.abs(), denominator.abs());
    final sign = denominator.isNegative ? -BigInt.one : BigInt.one;
    return Rational._(numerator * sign ~/ gcd, denominator.abs() ~/ gcd);
  }

  const Rational._(this.numerator, this.denominator);

  factory Rational.integer(BigInt value) => Rational(value, BigInt.one);

  final BigInt numerator;
  final BigInt denominator;

  static BigInt _gcd(BigInt left, BigInt right) {
    while (right != BigInt.zero) {
      final remainder = left.remainder(right);
      left = right;
      right = remainder;
    }
    return left == BigInt.zero ? BigInt.one : left;
  }

  Rational operator +(Rational other) => Rational(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );

  Rational operator -(Rational other) => Rational(
    numerator * other.denominator - other.numerator * denominator,
    denominator * other.denominator,
  );

  Rational operator -() => Rational(-numerator, denominator);

  Rational operator *(Rational other) =>
      Rational(numerator * other.numerator, denominator * other.denominator);

  Rational operator /(Rational other) {
    if (other.numerator == BigInt.zero) {
      throw const ExactArithmeticException('Division by zero is undefined.');
    }
    return Rational(
      numerator * other.denominator,
      denominator * other.numerator,
    );
  }

  Rational pow(BigInt exponent) {
    if (numerator == BigInt.zero && exponent == BigInt.zero) {
      throw const ExactArithmeticException(
        'Zero to the zero power is undefined.',
      );
    }
    if (exponent.abs() > BigInt.from(1000)) {
      throw const ExactArithmeticException(
        'Exact exponents are limited to an absolute value of 1000.',
      );
    }
    final power = exponent.abs().toInt();
    if (exponent.isNegative) {
      if (numerator == BigInt.zero) {
        throw const ExactArithmeticException(
          'Zero cannot be raised to a negative power.',
        );
      }
      return Rational(denominator.pow(power), numerator.pow(power));
    }
    return Rational(numerator.pow(power), denominator.pow(power));
  }

  String get display => denominator == BigInt.one
      ? numerator.toString()
      : '$numerator/$denominator';

  double get approximate => numerator.toDouble() / denominator.toDouble();
}

class ExactArithmeticParser {
  ExactArithmeticParser(String source) : _tokens = _tokenize(source);

  static final _tokenPattern = RegExp(
    r'\d+(?:\.\d*)?(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?|[()+\-*/^]',
  );
  static final _literalPattern = RegExp(
    r'^(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$',
  );

  final List<String>? _tokens;
  late List<String> _activeTokens;
  var _position = 0;

  static Rational? tryParse(String source) {
    final parser = ExactArithmeticParser(source);
    final tokens = parser._tokens;
    if (tokens == null || tokens.isEmpty) return null;
    parser._activeTokens = tokens;
    try {
      final result = parser._parseExpression();
      if (parser._position != parser._activeTokens.length) return null;
      return result;
    } on _UnsupportedExactArithmetic {
      return null;
    }
  }

  static List<String>? _tokenize(String source) {
    final tokens = <String>[];
    var cursor = 0;
    for (final match in _tokenPattern.allMatches(source)) {
      if (source.substring(cursor, match.start).trim().isNotEmpty) return null;
      tokens.add(match.group(0)!);
      cursor = match.end;
    }
    if (source.substring(cursor).trim().isNotEmpty) return null;
    return tokens;
  }

  Rational _parseExpression() {
    var result = _parseTerm();
    while (_hasNext && (_peek == '+' || _peek == '-')) {
      final operator = _take();
      final right = _parseTerm();
      result = operator == '+' ? result + right : result - right;
    }
    return result;
  }

  Rational _parseTerm() {
    var result = _parseUnary();
    while (_hasNext && (_peek == '*' || _peek == '/')) {
      final operator = _take();
      final right = _parseUnary();
      result = operator == '*' ? result * right : result / right;
    }
    return result;
  }

  Rational _parseUnary() {
    if (_accept('+')) return _parseUnary();
    if (_accept('-')) return -_parseUnary();
    return _parsePower();
  }

  Rational _parsePower() {
    final base = _parsePrimary();
    if (!_accept('^')) return base;
    final exponent = _parseUnary();
    if (exponent.denominator != BigInt.one) {
      throw const _UnsupportedExactArithmetic();
    }
    return base.pow(exponent.numerator);
  }

  Rational _parsePrimary() {
    if (_accept('(')) {
      final result = _parseExpression();
      if (!_accept(')')) throw const _UnsupportedExactArithmetic();
      return result;
    }
    if (!_hasNext) throw const _UnsupportedExactArithmetic();
    final token = _take();
    if (!_literalPattern.hasMatch(token)) {
      throw const _UnsupportedExactArithmetic();
    }
    return _parseLiteral(token);
  }

  Rational _parseLiteral(String token) {
    final lower = token.toLowerCase();
    final exponentIndex = lower.indexOf('e');
    final mantissa = exponentIndex == -1
        ? lower
        : lower.substring(0, exponentIndex);
    final exponent = exponentIndex == -1
        ? 0
        : int.tryParse(lower.substring(exponentIndex + 1));
    if (exponent == null || exponent.abs() > 1000) {
      throw const _UnsupportedExactArithmetic();
    }
    final point = mantissa.indexOf('.');
    final decimalPlaces = point == -1 ? 0 : mantissa.length - point - 1;
    final digits = mantissa.replaceAll('.', '');
    if (digits.isEmpty) throw const _UnsupportedExactArithmetic();
    var numerator = BigInt.parse(digits);
    var denominator = BigInt.from(10).pow(decimalPlaces);
    final scale = exponent;
    if (scale > 0) {
      numerator *= BigInt.from(10).pow(scale);
    } else if (scale < 0) {
      denominator *= BigInt.from(10).pow(-scale);
    }
    return Rational(numerator, denominator);
  }

  bool get _hasNext => _position < _activeTokens.length;
  String get _peek => _activeTokens[_position];

  bool _accept(String expected) {
    if (!_hasNext || _peek != expected) return false;
    _position++;
    return true;
  }

  String _take() => _activeTokens[_position++];
}

class _UnsupportedExactArithmetic implements Exception {
  const _UnsupportedExactArithmetic();
}
