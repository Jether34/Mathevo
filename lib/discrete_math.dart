import 'dart:math' as math;

class DiscreteMathException implements Exception {
  const DiscreteMathException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Exact, bounded operations for the discrete-math calculator mode.
///
/// Commands use ordinary function notation, for example `gcd(84,30)` or
/// `truthTable(A && !B)`. Unsupported commands fail explicitly.
class DiscreteMathEngine {
  const DiscreteMathEngine();

  static final _commandPattern = RegExp(
    r'^([A-Za-z][A-Za-z0-9_]*)\s*\((.*)\)$',
    dotAll: true,
  );

  String? solve(String source) {
    final match = _commandPattern.firstMatch(source.trim());
    if (match == null) return null;
    final command = match.group(1)!.toLowerCase();
    final body = match.group(2)!.trim();
    final args = _splitTopLevel(body);
    switch (command) {
      case 'gcd':
        _requireCount(command, args, 2);
        return _gcd(_integer(args[0]), _integer(args[1])).toString();
      case 'lcm':
        _requireCount(command, args, 2);
        final a = _integer(args[0]), b = _integer(args[1]);
        if (a == BigInt.zero || b == BigInt.zero) return '0';
        return ((a ~/ _gcd(a, b)) * b).abs().toString();
      case 'isprime':
        _requireCount(command, args, 1);
        return _isPrime(_integer(args[0])) ? 'true' : 'false';
      case 'primefactors':
      case 'factors':
        _requireCount(command, args, 1);
        return _primeFactors(_integer(args[0]));
      case 'mod':
        _requireCount(command, args, 2);
        final modulus = _positiveModulus(args[1]);
        return (_integer(args[0]) % modulus).toString();
      case 'modpow':
        _requireCount(command, args, 3);
        final base = _integer(args[0]);
        final exponent = _integer(args[1]);
        final modulus = _positiveModulus(args[2]);
        if (exponent.isNegative) {
          throw const DiscreteMathException(
            'modPow needs a non-negative exponent.',
          );
        }
        return _modPow(base, exponent, modulus).toString();
      case 'modinverse':
        _requireCount(command, args, 2);
        return _modInverse(
          _integer(args[0]),
          _positiveModulus(args[1]),
        ).toString();
      case 'ncr':
      case 'choose':
        _requireCount(command, args, 2);
        return _combination(_integer(args[0]), _integer(args[1])).toString();
      case 'npr':
      case 'permute':
        _requireCount(command, args, 2);
        return _permutation(_integer(args[0]), _integer(args[1])).toString();
      case 'pow':
        _requireCount(command, args, 2);
        final base = _integer(args[0]);
        final exponent = _integer(args[1]);
        if (exponent.isNegative || exponent > BigInt.from(4096)) {
          throw const DiscreteMathException(
            'Integer powers need a non-negative exponent no greater than 4096.',
          );
        }
        return base.pow(exponent.toInt()).toString();
      case 'ratio':
        _requireCount(command, args, 2);
        final a = _integer(args[0]), b = _integer(args[1]);
        final divisor = _gcd(a, b);
        if (divisor == BigInt.zero) {
          throw const DiscreteMathException('The ratio 0:0 is undefined.');
        }
        return '${a ~/ divisor}:${b ~/ divisor}';
      case 'percent':
        _requireCount(command, args, 2);
        final percent = _real(args[0]), value = _real(args[1]);
        return _formatReal(percent * value / 100);
      case 'union':
      case 'setunion':
        return _setOperation(command, args, (a, b) => a.union(b));
      case 'intersection':
      case 'setintersection':
        return _setOperation(command, args, (a, b) => a.intersection(b));
      case 'difference':
      case 'setdifference':
        return _setOperation(command, args, (a, b) => a.difference(b));
      case 'symmetricdifference':
      case 'setsymmetricdifference':
        return _setOperation(
          command,
          args,
          (a, b) => a.difference(b).union(b.difference(a)),
        );
      case 'truthtable':
        _requireCount(command, args, 1);
        return _truthTable(args.single);
      case 'tautology':
      case 'istautology':
        _requireCount(command, args, 1);
        return _allTruthValues(args.single, expected: true) ? 'true' : 'false';
      case 'satisfiable':
        _requireCount(command, args, 1);
        return _allTruthValues(args.single, expected: true, any: true)
            ? 'true'
            : 'false';
      case 'contradiction':
      case 'iscontradiction':
        _requireCount(command, args, 1);
        return _allTruthValues(args.single, expected: false) ? 'true' : 'false';
      default:
        throw DiscreteMathException('Unknown discrete-math key: $command.');
    }
  }

  static void _requireCount(String command, List<String> args, int count) {
    if (args.length != count || args.any((arg) => arg.trim().isEmpty)) {
      throw DiscreteMathException('$command expects $count argument(s).');
    }
  }

  static List<String> _splitTopLevel(String source) {
    final parts = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      if (char == '(' || char == '{' || char == '[') depth++;
      if (char == ')' || char == '}' || char == ']') depth--;
      if (depth < 0) {
        throw const DiscreteMathException('Unbalanced delimiters.');
      }
      if (char == ',' && depth == 0) {
        parts.add(source.substring(start, i).trim());
        start = i + 1;
      }
    }
    if (depth != 0) throw const DiscreteMathException('Unbalanced delimiters.');
    if (source.isNotEmpty || parts.isNotEmpty) {
      parts.add(source.substring(start).trim());
    }
    return parts;
  }

  static BigInt _integer(String source) {
    final value = BigInt.tryParse(source.trim());
    if (value == null) {
      throw DiscreteMathException('Expected an integer, received "$source".');
    }
    return value;
  }

  static double _real(String source) {
    final value = double.tryParse(source.trim());
    if (value == null || !value.isFinite) {
      throw DiscreteMathException(
        'Expected a finite number, received "$source".',
      );
    }
    return value;
  }

  static BigInt _positiveModulus(String source) {
    final modulus = _integer(source);
    if (modulus <= BigInt.zero) {
      throw const DiscreteMathException(
        'The modulus must be a positive integer.',
      );
    }
    return modulus;
  }

  static BigInt _gcd(BigInt a, BigInt b) {
    a = a.abs();
    b = b.abs();
    while (b != BigInt.zero) {
      final remainder = a % b;
      a = b;
      b = remainder;
    }
    return a;
  }

  static bool _isPrime(BigInt n) {
    if (n < BigInt.two) return false;
    const smallPrimes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37];
    for (final prime in smallPrimes) {
      final p = BigInt.from(prime);
      if (n == p) return true;
      if (n % p == BigInt.zero) return false;
    }
    if (n.isEven) return false;
    var d = n - BigInt.one;
    var shifts = 0;
    while (d.isEven) {
      d >>= 1;
      shifts++;
    }
    // These bases are deterministic for unsigned 64-bit integers.
    final bases = n.bitLength <= 64
        ? [2, 325, 9375, 28178, 450775, 9780504, 1795265022]
        : smallPrimes;
    for (final base in bases) {
      final a = BigInt.from(base) % n;
      if (a == BigInt.zero) continue;
      var x = _modPow(a, d, n);
      if (x == BigInt.one || x == n - BigInt.one) continue;
      var witness = true;
      for (var r = 1; r < shifts; r++) {
        x = (x * x) % n;
        if (x == n - BigInt.one) {
          witness = false;
          break;
        }
      }
      if (witness) return false;
    }
    return true;
  }

  static String _primeFactors(BigInt n) {
    if (n == BigInt.zero) {
      throw const DiscreteMathException(
        'Zero has no finite prime factorization.',
      );
    }
    if (n.abs() > BigInt.from(1000000000000)) {
      throw const DiscreteMathException(
        'Prime factorization is currently limited to |n| <= 1,000,000,000,000.',
      );
    }
    final factors = <String>[];
    if (n.isNegative) factors.add('-1');
    var value = n.abs();
    for (
      var divisor = BigInt.two;
      divisor * divisor <= value;
      divisor += divisor == BigInt.two ? BigInt.one : BigInt.two
    ) {
      while (value % divisor == BigInt.zero) {
        factors.add(divisor.toString());
        value ~/= divisor;
      }
    }
    if (value > BigInt.one) factors.add(value.toString());
    return factors.join(' * ');
  }

  static BigInt _modPow(BigInt base, BigInt exponent, BigInt modulus) {
    var power = exponent;
    var factor = base % modulus;
    if (factor.isNegative) factor += modulus;
    var result = BigInt.one % modulus;
    while (power > BigInt.zero) {
      if (power.isOdd) result = (result * factor) % modulus;
      power >>= 1;
      factor = (factor * factor) % modulus;
    }
    return result;
  }

  static BigInt _modInverse(BigInt value, BigInt modulus) {
    var oldR = value % modulus;
    if (oldR.isNegative) oldR += modulus;
    var r = modulus;
    var oldS = BigInt.one;
    var s = BigInt.zero;
    while (r != BigInt.zero) {
      final quotient = oldR ~/ r;
      (oldR, r) = (r, oldR - quotient * r);
      (oldS, s) = (s, oldS - quotient * s);
    }
    if (oldR != BigInt.one) {
      throw const DiscreteMathException(
        'A modular inverse exists only when the value and modulus are coprime.',
      );
    }
    final inverse = oldS % modulus;
    return inverse.isNegative ? inverse + modulus : inverse;
  }

  static BigInt _combination(BigInt n, BigInt r) {
    if (n.isNegative || r.isNegative || r > n || n > BigInt.from(10000)) {
      throw const DiscreteMathException('nCr requires 0 <= r <= n <= 10,000.');
    }
    final k = math.min(r.toInt(), n.toInt() - r.toInt());
    var result = BigInt.one;
    for (var i = 1; i <= k; i++) {
      result = result * BigInt.from(n.toInt() - k + i) ~/ BigInt.from(i);
    }
    return result;
  }

  static BigInt _permutation(BigInt n, BigInt r) {
    if (n.isNegative || r.isNegative || r > n || n > BigInt.from(10000)) {
      throw const DiscreteMathException('nPr requires 0 <= r <= n <= 10,000.');
    }
    var result = BigInt.one;
    for (var i = 0; i < r.toInt(); i++) {
      result *= n - BigInt.from(i);
    }
    return result;
  }

  static String _setOperation(
    String command,
    List<String> args,
    Set<String> Function(Set<String>, Set<String>) operation,
  ) {
    _requireCount(command, args, 2);
    Set<String> parseSet(String source) {
      final trimmed = source.trim();
      if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
        throw DiscreteMathException('$command expects sets such as {1,2,3}.');
      }
      final inner = trimmed.substring(1, trimmed.length - 1).trim();
      if (inner.isEmpty) return <String>{};
      return _splitTopLevel(
        inner,
      ).map((item) => item.trim()).where((item) => item.isNotEmpty).toSet();
    }

    final result = operation(parseSet(args[0]), parseSet(args[1])).toList()
      ..sort((a, b) {
        final aNumber = num.tryParse(a), bNumber = num.tryParse(b);
        if (aNumber != null && bNumber != null) {
          return aNumber.compareTo(bNumber);
        }
        return a.compareTo(b);
      });
    return '{${result.join(', ')}}';
  }

  static Set<String> _variables(String expression) {
    final tokens = _tokens(expression);
    const operators = {
      '!',
      '~',
      '&',
      '&&',
      '|',
      '||',
      '^',
      '->',
      '=>',
      '<->',
      '<=>',
      '(',
      ')',
      'and',
      'or',
      'not',
      'xor',
      'implies',
      'iff',
    };
    final variables = tokens
        .where((token) => !operators.contains(token.toLowerCase()))
        .toSet();
    if (variables.length > 8) {
      throw const DiscreteMathException(
        'Truth tables are limited to eight propositional variables.',
      );
    }
    return variables;
  }

  static List<String> _tokens(String expression) {
    final matches = RegExp(
      r'<->|<=>|->|=>|&&|\|\||[!~&|^()]|[A-Za-z][A-Za-z0-9_]*',
    ).allMatches(expression).toList();
    final joined = matches.map((match) => match.group(0)!).join();
    final normalized = expression.toLowerCase().replaceAll(
      RegExp(r'\b(and|or|not|xor|implies|iff)\b'),
      '',
    );
    final compactNormalized = normalized.replaceAll(RegExp(r'\s+'), '');
    final compactJoined = joined.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (compactNormalized != compactJoined) {
      // Word operators are present in the original expression; tokenize each
      // token independently so their spelling remains available to the parser.
      final wordMatches = RegExp(
        r'<->|<=>|->|=>|&&|\|\||[!~&|^()]|[A-Za-z][A-Za-z0-9_]*',
      ).allMatches(expression);
      final uncovered = expression.replaceAll(
        RegExp(r'<->|<=>|->|=>|&&|\|\||[!~&|^()]|[A-Za-z][A-Za-z0-9_]*'),
        '',
      );
      if (uncovered.trim().isNotEmpty || wordMatches.isEmpty) {
        throw const DiscreteMathException('Invalid propositional expression.');
      }
    }
    return matches.map((match) => match.group(0)!).toList();
  }

  static bool _evaluateProposition(
    String expression,
    Map<String, bool> assignment,
  ) {
    final parser = _PropositionParser(_tokens(expression), assignment);
    final value = parser.parse();
    if (!parser.isAtEnd) {
      throw const DiscreteMathException('Invalid propositional expression.');
    }
    return value;
  }

  static bool _allTruthValues(
    String expression, {
    required bool expected,
    bool any = false,
  }) {
    final variables = _variables(expression).toList()..sort();
    if (variables.isEmpty) {
      throw const DiscreteMathException(
        'Enter at least one proposition, such as A.',
      );
    }
    final rows = 1 << variables.length;
    var found = false;
    for (var mask = 0; mask < rows; mask++) {
      final assignment = <String, bool>{};
      for (var bit = 0; bit < variables.length; bit++) {
        assignment[variables[bit]] = (mask & (1 << bit)) != 0;
      }
      final value = _evaluateProposition(expression, assignment);
      if (any) {
        if (value == expected) return true;
        continue;
      }
      if (value != expected) return false;
      found = true;
    }
    return found;
  }

  static String _truthTable(String expression) {
    final variables = _variables(expression).toList()..sort();
    if (variables.isEmpty) {
      throw const DiscreteMathException(
        'Enter at least one proposition, such as A.',
      );
    }
    final rows = 1 << variables.length;
    final output = StringBuffer('${variables.join('  ')}  | result\n');
    for (var mask = 0; mask < rows; mask++) {
      final assignment = <String, bool>{};
      for (var bit = 0; bit < variables.length; bit++) {
        assignment[variables[bit]] = (mask & (1 << bit)) != 0;
      }
      final values = variables
          .map((variable) => assignment[variable]! ? 'T' : 'F')
          .join('  ');
      final result = _evaluateProposition(expression, assignment) ? 'T' : 'F';
      output.writeln('$values  | $result');
    }
    return output.toString().trimRight();
  }
}

class _PropositionParser {
  _PropositionParser(this.tokens, this.assignment);

  final List<String> tokens;
  final Map<String, bool> assignment;
  int index = 0;

  bool get isAtEnd => index >= tokens.length;
  String? get current => isAtEnd ? null : tokens[index];

  bool parse() {
    if (tokens.isEmpty) {
      throw const DiscreteMathException('Enter a propositional expression.');
    }
    return _equivalence();
  }

  bool _equivalence() {
    var left = _implication();
    while (_is({'<->', '<=>', 'iff'})) {
      index++;
      final right = _implication();
      left = left == right;
    }
    return left;
  }

  bool _implication() {
    final left = _disjunction();
    if (_is({'->', '=>', 'implies'})) {
      index++;
      return !left || _implication();
    }
    return left;
  }

  bool _disjunction() {
    var left = _exclusiveOr();
    while (_is({'|', '||', 'or'})) {
      index++;
      final right = _exclusiveOr();
      left = left || right;
    }
    return left;
  }

  bool _exclusiveOr() {
    var left = _conjunction();
    while (_is({'^', 'xor'})) {
      index++;
      final right = _conjunction();
      left = left != right;
    }
    return left;
  }

  bool _conjunction() {
    var left = _unary();
    while (_is({'&', '&&', 'and'})) {
      index++;
      final right = _unary();
      left = left && right;
    }
    return left;
  }

  bool _unary() {
    if (_is({'!', '~', 'not'})) {
      index++;
      return !_unary();
    }
    if (_is({'('})) {
      index++;
      final value = _equivalence();
      if (!_is({')'})) {
        throw const DiscreteMathException('A closing parenthesis is missing.');
      }
      index++;
      return value;
    }
    final token = current;
    if (token == null || !_isIdentifier(token)) {
      throw const DiscreteMathException(
        'Expected a proposition such as A or P1.',
      );
    }
    index++;
    final value = assignment[token];
    if (value == null) {
      throw DiscreteMathException('No truth value was assigned to $token.');
    }
    return value;
  }

  bool _is(Set<String> values) =>
      current != null && values.contains(current!.toLowerCase());

  static bool _isIdentifier(String value) =>
      RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(value) &&
      !{
        'and',
        'or',
        'not',
        'xor',
        'implies',
        'iff',
      }.contains(value.toLowerCase());
}

String _formatReal(double value) {
  if (!value.isFinite) {
    throw const DiscreteMathException('The result is not finite.');
  }
  if (value == 0) return '0';
  final raw = value.toStringAsPrecision(12);
  final parts = raw.split('e');
  var mantissa = parts.first;
  if (mantissa.contains('.')) {
    mantissa = mantissa.replaceFirst(RegExp(r'0+$'), '');
    mantissa = mantissa.replaceFirst(RegExp(r'\.$'), '');
  }
  return parts.length == 1 ? mantissa : '${mantissa}e${parts.last}';
}
