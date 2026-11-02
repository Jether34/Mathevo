import 'package:flutter_test/flutter_test.dart';
import 'package:mathevo/math_engine.dart';

void main() {
  const engine = MathEngine();

  group('discrete number theory and combinatorics', () {
    test('computes gcd, lcm, primality, and bounded prime factors', () {
      expect(engine.calculateDiscrete('gcd(-84,30)'), '6');
      expect(engine.calculateDiscrete('lcm(12,18)'), '36');
      expect(engine.calculateDiscrete('isPrime(97)'), 'true');
      expect(
        engine.calculateDiscrete('primeFactors(360)'),
        '2 * 2 * 2 * 3 * 3 * 5',
      );
    });

    test('computes modular arithmetic with exact integer results', () {
      expect(engine.calculateDiscrete('mod(-17,5)'), '3');
      expect(engine.calculateDiscrete('modPow(2,10,1000)'), '24');
      expect(engine.calculateDiscrete('modInverse(3,11)'), '4');
      expect(
        () => engine.calculateDiscrete('modInverse(6,9)'),
        throwsA(isA<MathInputException>()),
      );
    });

    test('computes permutations, combinations, ratios, and percentages', () {
      expect(engine.calculateDiscrete('nCr(10,3)'), '120');
      expect(engine.calculateDiscrete('nPr(10,3)'), '720');
      expect(engine.calculateDiscrete('ratio(15,35)'), '3:7');
      expect(engine.calculateDiscrete('percent(15,80)'), '12');
    });

    test('performs finite set operations', () {
      expect(engine.calculateDiscrete('union({1,2},{2,3})'), '{1, 2, 3}');
      expect(
        engine.calculateDiscrete('intersection({1,2,3},{2,3,4})'),
        '{2, 3}',
      );
      expect(engine.calculateDiscrete('difference({1,2,3},{2})'), '{1, 3}');
    });

    test('evaluates propositional logic and emits a complete truth table', () {
      expect(engine.calculateDiscrete('tautology(A || !A)'), 'true');
      expect(engine.calculateDiscrete('satisfiable(A && B)'), 'true');
      expect(engine.calculateDiscrete('contradiction(A && !A)'), 'true');
      expect(
        engine.calculateDiscrete('truthTable(A && !B)'),
        'A  B  | result\nF  F  | F\nT  F  | T\nF  T  | F\nT  T  | F',
      );
    });

    test('rejects unsupported or invalid discrete commands explicitly', () {
      expect(
        () => engine.calculateDiscrete('modPow(2,-1,5)'),
        throwsA(isA<MathInputException>()),
      );
      expect(
        () => engine.calculateDiscrete('nCr(4,5)'),
        throwsA(isA<MathInputException>()),
      );
      expect(engine.calculateDiscrete('gcd('), isNull);
    });
  });
}
