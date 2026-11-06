import 'dart:math' as math;

import 'math_engine.dart';

/// Small, explicit calculators for statistics, probability, and uniform motion.
/// These functions intentionally accept finite numeric inputs only.
class StatisticsProbabilityEngine {
  const StatisticsProbabilityEngine();
  static const _mathEngine = MathEngine();

  String calculateStatistics(String source) {
    final (name, values) = _call(source);
    if (values.isEmpty) {
      throw const MathInputException('Enter at least one data value.');
    }
    final sorted = [...values]..sort();
    final count = values.length;
    final mean = values.reduce((a, b) => a + b) / count;
    final result = switch (name.toLowerCase()) {
      'mean' || 'average' => mean,
      'median' =>
        count.isOdd
            ? sorted[count ~/ 2]
            : (sorted[count ~/ 2 - 1] + sorted[count ~/ 2]) / 2,
      'range' => sorted.last - sorted.first,
      'sum' => values.reduce((a, b) => a + b),
      'count' => values.length,
      'variance' || 'populationvariance' =>
        values
                .map((value) => math.pow(value - mean, 2))
                .reduce((a, b) => a + b) /
            count,
      'samplevariance' => _sampleVariance(values, mean),
      'stdev' ||
      'standarddeviation' => math.sqrt(_populationVariance(values, mean)),
      'samplestdev' ||
      'samplestandarddeviation' => math.sqrt(_sampleVariance(values, mean)),
      'q1' => _quantile(sorted, .25),
      'q3' => _quantile(sorted, .75),
      'mode' => null,
      _ => throw MathInputException('Unknown statistics function "$name".'),
    };
    if (name.toLowerCase() == 'mode') {
      final frequencies = <double, int>{};
      for (final value in values) {
        frequencies.update(value, (count) => count + 1, ifAbsent: () => 1);
      }
      final highest = frequencies.values.reduce(math.max);
      final modes =
          frequencies.entries
              .where((entry) => entry.value == highest)
              .map((entry) => _format(entry.key))
              .toList()
            ..sort((a, b) => double.parse(a).compareTo(double.parse(b)));
      return highest == 1 ? 'No repeated value' : modes.join(', ');
    }
    return _format(result!);
  }

  String calculateProbability(String source) {
    final (name, values) = _call(source);
    final result = switch (name.toLowerCase()) {
      'probability' || 'p' => _probability(values),
      'complement' => 1 - _probabilityValue(values),
      'odds' => _odds(values),
      'binomial' => _binomial(values),
      'combination' || 'ncr' => _choose(values),
      'permutation' || 'npr' => _permute(values),
      _ => throw MathInputException('Unknown probability function "$name".'),
    };
    return _format(result);
  }

  String calculatePhysics(String source) {
    final (name, values) = _call(source);
    if (values.length != 2) {
      throw const MathInputException(
        'Enter two values, for example distance(velocity, time).',
      );
    }
    final a = values[0];
    final b = values[1];
    final result = switch (name.toLowerCase()) {
      'distance' || 'd' => a * b,
      'velocity' || 'speed' || 'v' => _divide(a, b, 'Time'),
      'time' || 't' => _divide(a, b, 'Velocity'),
      _ => throw MathInputException('Unknown motion formula "$name".'),
    };
    return _format(result);
  }

  (String, List<double>) _call(String source) {
    final match = RegExp(
      r'^\s*([A-Za-z][A-Za-z0-9]*)\s*\((.*)\)\s*$',
    ).firstMatch(source);
    if (match == null) {
      throw const MathInputException(
        'Use a function with comma-separated numeric values, such as mean(2, 4, 6).',
      );
    }
    final body = match
        .group(2)!
        .trim()
        .replaceAll(RegExp(r'^[\[({]|[\])}]$'), '');
    final values = body.isEmpty
        ? <double>[]
        : body.split(RegExp(r'[,;\s]+')).map((part) {
            final value = double.tryParse(part) ?? _evaluateScalar(part);
            if (value == null || !value.isFinite) {
              throw MathInputException('"$part" is not a finite number.');
            }
            return value;
          }).toList();
    return (match.group(1)!, values);
  }

  static double? _evaluateScalar(String source) {
    try {
      return _mathEngine.calculate(source).value;
    } on MathInputException {
      return null;
    }
  }

  double _populationVariance(List<double> values, double mean) =>
      values.map((value) => math.pow(value - mean, 2)).reduce((a, b) => a + b) /
      values.length;

  double _sampleVariance(List<double> values, double mean) {
    if (values.length < 2) {
      throw const MathInputException(
        'Sample variance needs at least two data values.',
      );
    }
    return values
            .map((value) => math.pow(value - mean, 2))
            .reduce((a, b) => a + b) /
        (values.length - 1);
  }

  double _quantile(List<double> sorted, double fraction) {
    if (sorted.length < 2) {
      throw const MathInputException('Quartiles need at least two values.');
    }
    final position = (sorted.length - 1) * fraction;
    final lower = position.floor();
    final upper = position.ceil();
    return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower);
  }

  double _probability(List<double> values) {
    if (values.length != 2 ||
        values[0] < 0 ||
        values[1] <= 0 ||
        values[0] > values[1]) {
      throw const MathInputException(
        'Use probability(favorable outcomes, total outcomes), with 0 ≤ favorable ≤ total.',
      );
    }
    return values[0] / values[1];
  }

  double _probabilityValue(List<double> values) {
    if (values.length != 1 || values.single < 0 || values.single > 1) {
      throw const MathInputException('Enter one probability between 0 and 1.');
    }
    return values.single;
  }

  double _odds(List<double> values) {
    final probability = _probabilityValue(values);
    if (probability == 1) {
      throw const MathInputException(
        'Odds are undefined when probability is 1.',
      );
    }
    return probability / (1 - probability);
  }

  double _binomial(List<double> values) {
    if (values.length != 3) {
      throw const MathInputException('Use binomial(trials, successes, p).');
    }
    final n = _integer(values[0], 'Trials', maximum: 10000);
    final k = _integer(values[1], 'Successes', maximum: 10000);
    final p = values[2];
    if (k > n || p < 0 || p > 1) {
      throw const MathInputException(
        'Successes must be between 0 and trials, and p must be between 0 and 1.',
      );
    }
    return _choose([n.toDouble(), k.toDouble()]) *
        math.pow(p, k) *
        math.pow(1 - p, n - k);
  }

  double _choose(List<double> values) {
    if (values.length != 2) {
      throw const MathInputException('Use combination(n, r).');
    }
    final n = _integer(values[0], 'n', maximum: 10000);
    final r = _integer(values[1], 'r', maximum: 10000);
    if (r > n) throw const MathInputException('r cannot be greater than n.');
    var result = 1.0;
    for (var i = 1; i <= math.min(r, n - r); i++) {
      result = result * (n - math.min(r, n - r) + i) / i;
    }
    return result;
  }

  double _permute(List<double> values) {
    if (values.length != 2) {
      throw const MathInputException('Use permutation(n, r).');
    }
    final n = _integer(values[0], 'n', maximum: 10000);
    final r = _integer(values[1], 'r', maximum: 10000);
    if (r > n) throw const MathInputException('r cannot be greater than n.');
    var result = 1.0;
    for (var i = 0; i < r; i++) {
      result *= n - i;
    }
    return result;
  }

  int _integer(double value, String label, {required int maximum}) {
    if (value != value.roundToDouble() || value < 0 || value > maximum) {
      throw MathInputException('$label must be an integer from 0 to $maximum.');
    }
    return value.toInt();
  }

  double _divide(double numerator, double denominator, String divisor) {
    if (denominator == 0) {
      throw MathInputException('$divisor cannot be zero.');
    }
    return numerator / denominator;
  }

  String _format(num value) {
    if (!value.isFinite) {
      throw const MathInputException('The result is not finite.');
    }
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    final source = value.toStringAsPrecision(12);
    final pieces = source.split('e');
    final mantissa = pieces.first.contains('.')
        ? pieces.first
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '')
        : pieces.first;
    return pieces.length == 1 ? mantissa : '${mantissa}e${pieces.last}';
  }
}
