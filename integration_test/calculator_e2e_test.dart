import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mathevo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/auth_test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('calculator modes solve representative problems on Android', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    final authApi = FakeAuthApi();

    await tester.pumpWidget(
      MathVerseApp(authApi: authApi, tokenStore: MemoryAuthTokenStore()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GET STARTED'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE YOUR ACCOUNT'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Emulator Tester');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'calculator-e2e@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'e2e-pass-123');
    await tester.tap(find.text('CREATE ACCOUNT'));
    await _pumpUntil(tester, find.byKey(const Key('nav-calculator')));

    await tester.tap(find.byKey(const Key('nav-calculator')));
    await tester.pumpAndSettle();

    // Basic arithmetic.
    await _enterExpression(tester, '12+7');
    await _pressEquals(tester);
    expect(_answer(tester), '19');

    // Scientific mode uses the default DEG setting.
    await _selectMode(tester, 'Scientific');
    await _enterExpression(tester, 'sin(30)');
    await _pressEquals(tester);
    expect(double.parse(_answer(tester)), closeTo(0.5, 1e-8));

    // Geometry numeric keypad and formula path: circle area, radius 3.
    await _selectMode(tester, 'Geometry');
    await tester.enterText(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.decoration?.labelText == 'Radius',
          )
          .first,
      '3',
    );
    await tester.tap(find.text('Calculate'));
    await tester.pumpAndSettle();
    expect(double.parse(_answer(tester)), closeTo(28.2743338823, 1e-8));

    // Trigonometry evaluates in degrees and returns the ratio.
    await _selectMode(tester, 'Trigonometry');
    await _enterExpression(tester, 'sin(30)');
    await _pressEquals(tester);
    expect(double.parse(_answer(tester)), closeTo(0.5, 1e-8));

    // Graph mode evaluates a typed function at the selected x value (2).
    await _selectMode(tester, 'Graphing');
    await _enterExpression(tester, 'x^2');
    await _pressEquals(tester);
    expect(_answer(tester), contains('4'));

    // Quadratic equation and a 2x2 linear system.
    await _selectMode(tester, 'Algebra');
    await _enterExpression(tester, 'x^2-5*x+6=0');
    await _pressEquals(tester);
    expect(_answer(tester), contains('2'));
    expect(_answer(tester), contains('3'));
    await tester.tap(find.text('C').last);
    await tester.pumpAndSettle();
    await _enterExpression(tester, '2*x+y=5;x-y=1');
    await _pressEquals(tester);
    expect(_answer(tester), 'x = 2, y = 1');

    // Symbolic derivative, indefinite integral, and definite integral.
    await _selectMode(tester, 'Integral calculus');
    await _enterExpression(tester, 'x^3');
    await _pressEquals(tester);
    expect(_answer(tester), contains('d/dx'));
    await tester.tap(find.text('Indefinite integral'));
    await tester.pumpAndSettle();
    await _enterExpression(tester, 'x^2');
    await _pressEquals(tester);
    expect(_answer(tester), contains('+ C'));
    await tester.tap(find.text('Definite integral'));
    await tester.pumpAndSettle();
    await _enterExpression(tester, 'x^2');
    await tester.enterText(_boundField('Lower bound'), '0');
    await tester.enterText(_boundField('Upper bound'), '3');
    await _pressEquals(tester);
    expect(_answer(tester), contains('9'));

    // Computer science number systems: 13 XOR 5 = 8, displayed in binary.
    await _selectMode(tester, 'Number systems');
    await tester.tap(find.text('Calculate'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '13');
    await tester.enterText(find.byType(TextField).last, '5');
    await tester.tap(find.text('XOR'));
    await tester.pumpAndSettle();
    await _pressEquals(tester);
    expect(_answer(tester), contains('1000'));

    // Drawing workspace route and actions are reachable on the device.
    await _selectMode(tester, 'Draw');
    expect(find.text('Handwritten calculation'), findsOneWidget);
    expect(find.byTooltip('Clear'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to calculator'));
    await tester.pumpAndSettle();
    expect(find.text('Calculator'), findsOneWidget);
  });
}

Future<void> _selectMode(WidgetTester tester, String mode) async {
  final finder = find.text(mode);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enterExpression(WidgetTester tester, String expression) async {
  final input = find.byKey(const Key('expression-input'));
  await tester.ensureVisible(input);
  await tester.enterText(input, expression);
  await tester.pumpAndSettle();
}

Future<void> _pressEquals(WidgetTester tester) async {
  final equals = find.text('=');
  await tester.ensureVisible(equals.last);
  await tester.tap(equals.last);
  await tester.pumpAndSettle();
}

String _answer(WidgetTester tester) {
  final finder = find.byKey(const Key('calculation-result'));
  if (finder.evaluate().isNotEmpty) {
    return (tester.widget<SelectableText>(finder.first).data ?? '').trim();
  }
  final candidates = find.byType(SelectableText).evaluate();
  if (candidates.isNotEmpty) {
    return ((candidates.last.widget as SelectableText).data ?? '').trim();
  }
  return '';
}

Finder _boundField(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}
