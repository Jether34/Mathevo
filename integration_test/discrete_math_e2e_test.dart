import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mathevo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/auth_test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('discrete math keys solve validated examples on Android', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await preferences.setBool('mathverse.auth.signedIn', true);
    await preferences.setString('mathverse.profile.name', 'Emulator Learner');
    await preferences.setString('mathverse.profile.username', 'emu_learner');

    await tester.pumpWidget(
      MathevoApp(
        authApi: FakeAuthApi(registered: true),
        tokenStore: MemoryAuthTokenStore(refreshToken: 'emulator-refresh'),
      ),
    );
    await _pumpUntil(tester, find.byKey(const Key('nav-calculator')));

    await tester.tap(find.byKey(const Key('nav-calculator')));
    await tester.pump(const Duration(milliseconds: 350));

    final mode = find.text('Discrete math');
    await tester.ensureVisible(mode);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(mode);
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const ValueKey('function-key-gcd(')), findsOneWidget);
    expect(find.byKey(const ValueKey('function-key-modPow(')), findsOneWidget);
    expect(find.byKey(const ValueKey('function-key-union(')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('function-key-truthTable(')),
      findsOneWidget,
    );

    await _tapCommand(tester, 'gcd(', 'gcd(84,30)', [
      '8',
      '4',
      ',',
      '3',
      '0',
      ')',
    ]);
    await _pressEquals(tester, '6');
    await _tapCommand(tester, 'modPow(', 'modPow(2,10,1000)', [
      '2',
      ',',
      '1',
      '0',
      ',',
      '1',
      '0',
      '0',
      '0',
      ')',
    ]);
    await _pressEquals(tester, '24');
    await _tapCommand(tester, 'union(', 'union({1,2},{2,3})', [
      '{',
      '1',
      ',',
      '2',
      '}',
      ',',
      '{',
      '2',
      ',',
      '3',
      '}',
      ')',
    ]);
    await _pressEquals(tester, '{1, 2, 3}');
    await _tapCommand(tester, 'tautology(', 'tautology(A||!A)', [
      'A',
      '||',
      '!',
      'A',
      ')',
    ]);
    await _pressEquals(tester, 'true');
    await _tapCommand(tester, 'truthTable(', 'truthTable(A&&!B)', [
      'A',
      '&&',
      '!',
      'B',
      ')',
    ]);
    await _pressEquals(tester, 'A  B  | result');
  });
}

Future<void> _tapCommand(
  WidgetTester tester,
  String commandKey,
  String expectedExpression,
  List<String> argumentKeys,
) async {
  await _tapFunction(tester, commandKey);
  for (final key in argumentKeys) {
    if (key.length == 1 && RegExp(r'\d').hasMatch(key)) {
      await tester.tap(find.text(key).last);
    } else {
      await _tapFunction(tester, key);
    }
    await tester.pump(const Duration(milliseconds: 80));
  }
  final toggle = find.byKey(const Key('expression-edit-toggle'));
  expect(toggle, findsOneWidget);
  await tester.tap(toggle);
  await tester.pump(const Duration(milliseconds: 100));
  final input = tester.widget<TextField>(
    find.byKey(const Key('expression-input')),
  );
  expect(input.controller?.text, expectedExpression);
  await tester.tap(toggle);
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tapFunction(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey('function-key-$key'));
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 80));
  await tester.tap(finder);
}

Future<void> _pressEquals(WidgetTester tester, String expected) async {
  final equals = find.text('=').last;
  await tester.ensureVisible(equals);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.tap(equals);
  await tester.pump(const Duration(milliseconds: 350));

  final result = find.byKey(const Key('calculation-result'));
  expect(result, findsOneWidget);
  final rendered = tester.widget<Semantics>(result).properties.label ?? '';
  expect(rendered, contains(expected));
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}
