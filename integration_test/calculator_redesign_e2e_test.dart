import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mathevo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/auth_test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('calculator redesign works end to end on Android', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await preferences.setBool('mathverse.auth.signedIn', true);
    await preferences.setString('mathverse.profile.name', 'Device Tester');
    await preferences.setString('mathverse.profile.username', 'device_tester');

    await tester.pumpWidget(
      MathevoApp(
        authApi: FakeAuthApi(registered: true),
        tokenStore: MemoryAuthTokenStore(refreshToken: 'device-test'),
      ),
    );
    expect(find.byKey(const Key('app-loading-skeleton')), findsOneWidget);
    await _pumpUntil(tester, find.byKey(const Key('nav-calculator')));
    await tester.tap(find.byKey(const Key('nav-calculator')));
    await tester.pumpAndSettle();

    final plus = find.byKey(const ValueKey('basic-key-+'));
    final clear = find.byKey(const ValueKey('basic-key-C'));
    final delete = find.byKey(const ValueKey('basic-key-DEL'));
    final divide = find.byKey(const ValueKey('basic-key-divide'));
    expect(tester.getRect(clear).top, greaterThan(tester.getRect(divide).top));
    expect(tester.getRect(delete).top, greaterThan(tester.getRect(divide).top));

    await _tap(tester, find.byKey(const ValueKey('basic-key-2')));
    await _tap(tester, plus);
    await _tap(tester, find.byKey(const ValueKey('basic-key-3')));
    await _tap(tester, find.byKey(const ValueKey('basic-key-equals')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('calculation-result')))
          .properties
          .label,
      contains('5'),
    );

    await _tap(tester, clear);
    await _tap(tester, find.byKey(const ValueKey('basic-key-8')));
    await _tap(tester, delete);
    await _tap(tester, find.byKey(const ValueKey('basic-key-4')));
    await _tap(tester, plus);
    await _tap(tester, find.byKey(const ValueKey('basic-key-3')));
    await _tap(tester, find.byKey(const ValueKey('basic-key-equals')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('calculation-result')))
          .properties
          .label,
      contains('7'),
    );

    await _selectMode(tester, 'Graphing');
    expect(find.byKey(const ValueKey('function-key-x')), findsOneWidget);
    expect(find.byKey(const ValueKey('function-key-y')), findsOneWidget);
    expect(find.byKey(const ValueKey('function-key-z')), findsOneWidget);
    expect(find.textContaining('Parametric 3D: enter x='), findsNothing);

    const modeKeys = <(String, String)>[
      ('Scientific', 'sin('),
      ('Trigonometry', 'arcsin('),
      ('Algebra', ';'),
      ('Calculus', 'CALC_INTEGRAL'),
      ('Discrete math', 'gcd('),
      ('Statistics', 'mean('),
      ('Probability', 'binomial('),
      ('Physics', 'distance('),
    ];
    for (final (mode, functionKey) in modeKeys) {
      await _selectMode(tester, mode);
      expect(
        find.byKey(ValueKey('function-key-$functionKey')),
        findsOneWidget,
        reason: '$mode should show its matching math keys.',
      );
    }

    await _selectMode(tester, 'Calculus');
    expect(find.text('Derivatives'), findsNothing);
    expect(find.text('Integrals'), findsNothing);
    expect(find.text('Limits'), findsNothing);
    for (final operationKey in [
      'CALC_LEIBNIZ_FIRST',
      'CALC_LAGRANGE_FIRST',
      'CALC_LEIBNIZ_SECOND',
      'CALC_LAGRANGE_SECOND',
      'CALC_PARTIAL_X',
      'CALC_PARTIAL_Y',
      'CALC_PARTIAL_Z',
      'CALC_INTEGRAL',
      'CALC_DEFINITE_INTEGRAL',
      'CALC_DOUBLE_INTEGRAL',
      'CALC_TRIPLE_INTEGRAL',
      'CALC_LIMIT_TWO',
      'CALC_LIMIT_LEFT',
      'CALC_LIMIT_RIGHT',
      'CALC_LIMIT_POS_INFINITY',
      'CALC_LIMIT_NEG_INFINITY',
      'CALC_DERIVATIVE_T',
      'DIFF_EQ_DX',
      'DIFF_EQ_DY',
      'DIFF_EQ_DZ',
    ]) {
      expect(
        find.byKey(ValueKey('function-key-$operationKey')),
        findsOneWidget,
      );
    }
    for (final functionKey in [
      'f(x)',
      'f(g(x))',
      'f^(-1)',
      'abs(',
      'exp(',
      'ln(',
      'log10(',
      'log(',
      '^2',
      '^3',
      '^',
      '^(-1)',
      '^(1/2)',
      'sqrt(',
      'cbrt(',
      'nrt(',
      'sin(',
      'cos(',
      'tan(',
      'csc(',
      'sec(',
      'cot(',
      'arcsin(',
      'arccos(',
      'arctan(',
      'arccsc(',
      'arccot(',
      'pi',
      'e',
      'tau',
      'phi',
      'i',
      'infinity',
      ' + C',
    ]) {
      expect(find.byKey(ValueKey('function-key-$functionKey')), findsOneWidget);
    }

    final calculusDigit = tester.getRect(
      find.byKey(const ValueKey('basic-key-7')),
    );
    final calculusFunction = tester.getRect(
      find.byKey(const ValueKey('function-key-CALC_INTEGRAL')),
    );
    final addKey = tester.getRect(find.byKey(const ValueKey('function-key-+')));
    final divideKey = tester.getRect(
      find.byKey(const ValueKey('function-key-/')),
    );
    final clearKey = tester.getRect(
      find.byKey(const ValueKey('function-key-C')),
    );
    final deleteKey = tester.getRect(
      find.byKey(const ValueKey('function-key-DEL')),
    );
    expect(calculusDigit.height, greaterThan(calculusFunction.height));
    expect(addKey.top, greaterThan(calculusDigit.bottom));
    expect(divideKey.top, greaterThan(calculusDigit.bottom));
    expect(clearKey.top, greaterThan(divideKey.bottom));
    expect(deleteKey.top, greaterThan(divideKey.bottom));

    await _tap(tester, find.byKey(const ValueKey('function-key-C')));
    await _tap(
      tester,
      find.byKey(const ValueKey('function-key-CALC_LEIBNIZ_SECOND')),
    );
    await _tap(tester, find.byKey(const ValueKey('function-key-x')));
    await _tap(tester, find.byKey(const ValueKey('function-key-^2')));
    await _tap(tester, find.byKey(const ValueKey('function-key-CALC_EQUALS')));
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('calculation-result')))
          .properties
          .label,
      contains('d²y/dx² = 2'),
    );

    await _tap(tester, find.byKey(const ValueKey('function-key-C')));
    await _tap(
      tester,
      find.byKey(const ValueKey('function-key-CALC_DOUBLE_INTEGRAL')),
    );
    expect(find.byKey(const Key('calculus-bounds-dialog')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('calculus-bound-0')), '0');
    await tester.enterText(find.byKey(const ValueKey('calculus-bound-1')), '1');
    await tester.enterText(find.byKey(const ValueKey('calculus-bound-2')), '0');
    await tester.enterText(find.byKey(const ValueKey('calculus-bound-3')), '1');
    await _tap(tester, find.text('Done'));
    await _tap(tester, find.byKey(const ValueKey('function-key-x')));
    await _tap(tester, find.byKey(const ValueKey('function-key-*')));
    await _tap(tester, find.byKey(const ValueKey('function-key-y')));
    await _tap(tester, find.byKey(const ValueKey('function-key-CALC_EQUALS')));
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('calculation-result')))
          .properties
          .label,
      contains('≈ 0.25'),
    );

    await _tap(tester, find.byKey(const ValueKey('function-key-C')));
    await _tap(
      tester,
      find.byKey(const ValueKey('function-key-CALC_LIMIT_RIGHT')),
    );
    expect(find.byKey(const Key('calculus-bounds-dialog')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('calculus-bound-6')), '0');
    await _tap(tester, find.text('Done'));
    await _tap(tester, find.byKey(const ValueKey('function-key-x')));
    await _tap(tester, find.byKey(const ValueKey('function-key-CALC_EQUALS')));
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('calculation-result')))
          .properties
          .label,
      contains('0'),
    );

    await _tap(tester, find.byKey(const ValueKey('function-key-C')));
    await _tap(tester, find.byKey(const ValueKey('function-key-DIFF_EQ_DX')));
    await _tap(tester, find.byKey(const ValueKey('function-key-(')));
    await _tap(tester, find.byKey(const ValueKey('function-key-z')));
    await _tap(tester, find.byKey(const ValueKey('function-key--')));
    await _tap(tester, find.byKey(const ValueKey('function-key-b')));
    await _tap(tester, find.byKey(const ValueKey('function-key-)')));
    await _tap(tester, find.byKey(const ValueKey('function-key-x')));
    await _tap(tester, find.byKey(const ValueKey('function-key--')));
    await _tap(tester, find.byKey(const ValueKey('function-key-d')));
    await _tap(tester, find.byKey(const ValueKey('function-key-y')));
    await _tap(tester, find.byKey(const ValueKey('function-key-CALC_EQUALS')));
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('calculation-result')))
          .properties
          .label,
      contains('dx/dt=(z-b)x-dy'),
    );

    await _selectMode(tester, 'Discrete math');
    expect(find.byKey(const ValueKey('function-key-VAR_C')), findsOneWidget);
    expect(find.byKey(const ValueKey('function-key-C')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('function-key-VAR_C')));
    await tester.pumpAndSettle();
    expect(find.text('C'), findsWidgets);
  });
}

Future<void> _selectMode(WidgetTester tester, String mode) async {
  final finder = find.text(mode);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}
