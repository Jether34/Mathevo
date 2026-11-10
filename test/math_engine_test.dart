import 'package:flutter_test/flutter_test.dart';
import 'package:mathevo/exact_arithmetic.dart';
import 'package:mathevo/math_engine.dart';

void main() {
  const engine = MathEngine();

  test('evaluates arithmetic with precedence and parentheses', () {
    expect(engine.evaluate('(12 + 8) / 4'), 5);
    expect(engine.evaluate('2 + 3 * 4'), 14);
  });

  test('derives numeric reduction steps from the parsed expression tree', () {
    expect(const MathEngine().solutionSteps('3 * 5 + 7'), [
      '3 * 5 = 15',
      '15 + 7 = 22',
    ]);
  });

  test('rejects empty, malformed, and non-finite results', () {
    expect(() => engine.evaluate('  '), throwsA(isA<MathInputException>()));
    expect(
      () => engine.evaluate('2 + * 3'),
      throwsA(isA<MathInputException>()),
    );
    expect(() => engine.evaluate('1 / 0'), throwsA(isA<MathInputException>()));
  });

  test('preserves rational answers and marks fallback results approximate', () {
    expect(ExactArithmeticParser.tryParse('0.1')?.display, '1/10');
    expect(ExactArithmeticParser.tryParse('0.2')?.display, '1/5');
    final zero = engine.calculate('0');
    expect(zero.kind, MathResultKind.exact);
    expect(zero.displayValue, '0');
    expect(engine.calculate('2 + 2').displayValue, '4');
    expect(engine.calculate('1 / 3').displayValue, '1/3');
    expect(engine.calculate('0.1 + 0.2').displayValue, '3/10');
    expect(engine.calculate('2^3^2').displayValue, '512');
    expect(engine.calculate('-2^2').displayValue, '-4');
    expect(engine.calculate('2^-2').displayValue, '1/4');
    expect(engine.calculate('1e-3').displayValue, '1/1000');

    final irrational = engine.calculate('sqrt(2)');
    expect(irrational.kind, MathResultKind.approximate);
    expect(irrational.displayValue, startsWith('1.41421356237'));
    expect(formatApproximateValue(1e24), '1e+24');
  });

  test('capability registry does not claim unsupported symbolic work', () {
    final symbolic = mathCapabilities.singleWhere(
      (capability) => capability.id == 'symbolic_algebra',
    );
    expect(symbolic.status, MathSupportStatus.limited);
    expect(symbolic.note, contains('2 x 2 linear systems'));
  });

  test('solves linear and quadratic equations', () {
    expect(engine.solveEquation('2*x+4=0').roots, ['-2']);
    expect(engine.solveEquation('x^2-5*x+6=0').roots, ['2', '3']);
  });

  test('solves 2x2 systems and identifies singular cases', () {
    expect(engine.solveLinearSystem('2*x+y=5;x-y=1').display, 'x = 2, y = 1');
    expect(
      engine.solveLinearSystem('x+y=2;2*x+2*y=4').display,
      'Infinitely many solutions',
    );
    expect(engine.solveLinearSystem('x+y=2;2*x+2*y=5').display, 'No solution');
  });

  test(
    'supports selected symbolic antiderivatives and definite integration',
    () {
      expect(engine.integrateIndefinite('x^2'), contains('+ C'));
      expect(engine.integrateIndefinite('sin(x)'), contains('cos'));
      expect(
        engine.integrateDefinite('x^2', lower: 0, upper: 3).value,
        closeTo(9, 1e-8),
      );
    },
  );

  test('supports calculator calculus keys and numerical operations', () {
    expect(engine.differentiate('x^2'), '2*x');
    expect(engine.differentiate('2*x'), '2');
    expect(engine.differentiate('x^3'), '3*x^2');
    expect(engine.evaluate('sec(0)'), closeTo(1, 1e-12));
    expect(engine.evaluate('csc(1)'), closeTo(1 / 0.8414709848, 1e-8));
    expect(engine.evaluate('cot(1)'), closeTo(1 / 1.5574077247, 1e-8));
    expect(engine.evaluate('arcsin(1)'), closeTo(1.57079632679, 1e-10));
    expect(engine.evaluate('arccos(1)'), closeTo(0, 1e-12));
    expect(engine.evaluate('arctan(1)'), closeTo(0.78539816339, 1e-10));
    expect(engine.evaluate('arccsc(2)'), closeTo(0.52359877559, 1e-10));
    expect(engine.evaluate('arccot(1)'), closeTo(0.78539816339, 1e-10));
    expect(engine.evaluate('log(2, 8)'), closeTo(3, 1e-12));
    expect(engine.evaluate('tau'), closeTo(2 * 3.14159265359, 1e-10));
    expect(
      engine
          .integrateDouble('x*y', lowerX: 0, upperX: 1, lowerY: 0, upperY: 1)
          .value,
      closeTo(0.25, 1e-8),
    );
    expect(
      engine
          .integrateTriple(
            'x*y*z',
            lowerX: 0,
            upperX: 1,
            lowerY: 0,
            upperY: 1,
            lowerZ: 0,
            upperZ: 1,
          )
          .value,
      closeTo(0.125, 1e-8),
    );
    expect(
      engine.calculateLimit(
        'x^2',
        variable: 'x',
        point: 0,
        side: LimitSide.twoSided,
      ),
      closeTo(0, 1e-8),
    );
    expect(
      engine.calculateLimit('x', variable: 'x', point: 0, side: LimitSide.left),
      closeTo(0, 1e-8),
    );
    expect(
      engine.calculateLimit(
        'x',
        variable: 'x',
        point: 0,
        side: LimitSide.right,
      ),
      closeTo(0, 1e-8),
    );
    expect(
      () => engine.calculateLimit(
        '1/x',
        variable: 'x',
        point: 0,
        side: LimitSide.twoSided,
      ),
      throwsA(isA<MathInputException>()),
    );
  });
}
