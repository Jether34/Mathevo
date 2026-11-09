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
      ('Integral calculus', 'CALC_INTEGRAL'),
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
