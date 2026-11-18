import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mathevo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/auth_test_support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('key taps enter visible expressions with consistent sizing', (
    tester,
  ) async {
    await _openCalculator(tester);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();

    final numberKey = find.byKey(const ValueKey('calculator-key-2'));
    final plusKey = find.byKey(const ValueKey('calculator-common-key-+'));
    expect(numberKey, findsOneWidget);
    expect(plusKey, findsOneWidget);
    expect(tester.getSize(numberKey).height, tester.getSize(plusKey).height);

    await _tap(tester, numberKey);
    await _tap(tester, plusKey);
    await _tap(tester, find.byKey(const ValueKey('calculator-key-3')));
    expect(_expression(tester), '2+3');

    await _tap(tester, find.byKey(const ValueKey('calculator-common-key-=')));
    await _tap(tester, find.byKey(const Key('answer-simplified-choice')));
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('calculation-result')))
          .properties
          .label,
      contains('5'),
    );
    await _capture(binding, '01-basic-arithmetic-keypad-result');
  });

  testWidgets('every mode keypad key updates its expression or input', (
    tester,
  ) async {
    await _openCalculator(tester);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();

    const modes = [
      'Basic',
      'Scientific',
      'Geometry',
      'Trigonometry',
      'Graphing',
      'Algebra',
      'Calculus',
      'Number systems',
      'Discrete math',
      'Statistics',
      'Probability',
      'Physics',
    ];
    var currentMode = 'Basic';
    for (final mode in modes) {
      if (mode != currentMode) {
        await _selectMode(tester, currentMode, mode);
        currentMode = mode;
      }

      await _clearKeypadState(tester);
      await _exerciseCommonArithmeticKeys(tester, mode);

      for (final layer in ['numbers', 'symbols', 'functions']) {
        await _tap(tester, find.byKey(ValueKey('keyboard-layer-$layer')));
        final seenPages = <String>{};
        for (var page = 0; page < 8; page++) {
          final keyboard = find.byKey(const ValueKey('calculator-keyboard'));
          final keys = find
              .descendant(
                of: keyboard,
                matching: find.byWidgetPredicate((widget) {
                  final key = widget.key;
                  return key is ValueKey<String> &&
                      (key.value.startsWith('calculator-key-') ||
                          key.value.startsWith('function-key-'));
                }),
              )
              .evaluate()
              .map((element) => (element.widget.key! as ValueKey<String>).value)
              .toList();
          final pageSignature = keys.join('|');
          if (keys.isEmpty || !seenPages.add(pageSignature)) break;

          for (final keyName in keys) {
            final action = keyName
                .replaceFirst('calculator-key-', '')
                .replaceFirst('function-key-', '');
            await _clearKeypadState(tester);
            if (action == 'DEL' || action == 'C') {
              _seedEditableInput(tester, mode);
            }
            if (action.startsWith('NUM_OPERATOR_')) {
              _seedNumberSystemInputs(tester);
            }

            final before = _visibleInputState(tester);
            await _tap(tester, find.byKey(ValueKey(keyName)));
            await _dismissCalculusBounds(tester);
            await _dismissAnswerChoice(tester);
            final after = _visibleInputState(tester);

            if (action == 'DEL' || action == 'C') {
              expect(
                before,
                isNot(after),
                reason: '$mode $layer key $action must edit the visible input.',
              );
            } else {
              expect(
                after,
                isNot(before),
                reason:
                    '$mode $layer key $action did not appear in the expression or input.',
              );
            }
          }
          if (layer == 'functions') {
            await _tap(
              tester,
              find.byKey(const ValueKey('keyboard-layer-functions')),
            );
          } else {
            break;
          }
        }
      }
      await _clearKeypadState(tester);
      await _tap(tester, find.byKey(const ValueKey('keyboard-layer-numbers')));
      final sampleKey = find.byKey(const ValueKey('calculator-key-2'));
      final numericKeys = find
          .descendant(
            of: find.byKey(const ValueKey('calculator-keyboard')),
            matching: find.byWidgetPredicate((widget) {
              final key = widget.key;
              return key is ValueKey<String> &&
                  (key.value.startsWith('calculator-key-') ||
                      key.value.startsWith('function-key-'));
            }),
          )
          .evaluate()
          .map((element) => element.widget.key! as ValueKey<String>)
          .toList();
      final expressionKey = sampleKey.evaluate().isNotEmpty
          ? sampleKey
          : find.byKey(numericKeys.first);
      await _tap(tester, expressionKey);
      expect(
        _visibleInputState(tester),
        isNot('|'),
        reason: '$mode number key must show input in the expression card.',
      );
      await _capture(
        binding,
        'key-audit-${mode.toLowerCase().replaceAll(' ', '-')}-expression',
      );
    }
  });

  testWidgets('bottom EVAL C DEL controls work with one clear key', (
    tester,
  ) async {
    await _openCalculator(tester);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    final keyboard = find.byKey(const ValueKey('calculator-keyboard'));
    final keyboardHeight = tester.getSize(keyboard).height;
    expect(
      find.byKey(const ValueKey('calculator-keyboard-enter')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('calculator-key-C')), findsNothing);
    expect(
      find.byKey(const ValueKey('calculator-keyboard-clear')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calculator-keyboard-delete')),
      findsOneWidget,
    );
    final deleteRect = tester.getRect(
      find.byKey(const ValueKey('calculator-keyboard-delete')),
    );
    final clearRect = tester.getRect(
      find.byKey(const ValueKey('calculator-keyboard-clear')),
    );
    final evaluateRect = tester.getRect(
      find.byKey(const ValueKey('calculator-keyboard-enter')),
    );
    expect(deleteRect.left, lessThan(clearRect.left));
    expect(clearRect.left, lessThan(evaluateRect.left));
    expect(
      find
          .descendant(of: keyboard, matching: find.byType(OutlinedButton))
          .evaluate()
          .length,
      29,
    );
    expect(
      find.descendant(of: keyboard, matching: find.byType(FilledButton)),
      findsOneWidget,
    );

    await _tap(tester, find.byKey(const ValueKey('calculator-key-2')));
    await _tap(tester, find.byKey(const ValueKey('calculator-common-key-+')));
    await _tap(tester, find.byKey(const ValueKey('calculator-key-3')));
    expect(_expression(tester), '2+3');
    await _capture(binding, '16-basic-keyboard-eval-clear-delete');
    await _tap(
      tester,
      find.byKey(const ValueKey('calculator-keyboard-delete')),
    );
    expect(_expression(tester), '2+');
    await _tap(tester, find.byKey(const ValueKey('calculator-keyboard-clear')));
    expect(_expression(tester), isEmpty);
    expect(find.byKey(const Key('calculation-result')), findsNothing);

    await _tap(tester, find.byKey(const ValueKey('keyboard-layer-symbols')));
    expect(tester.getSize(keyboard).height, keyboardHeight);
    expect(find.byKey(const ValueKey('calculator-key-C')), findsNothing);
    expect(
      find
          .descendant(of: keyboard, matching: find.byType(OutlinedButton))
          .evaluate()
          .length,
      lessThanOrEqualTo(30),
    );
    await _tap(tester, find.byKey(const ValueKey('keyboard-layer-functions')));
    expect(tester.getSize(keyboard).height, keyboardHeight);
    expect(
      find
          .descendant(of: keyboard, matching: find.byType(OutlinedButton))
          .evaluate()
          .length,
      lessThanOrEqualTo(30),
    );
  });

  testWidgets('expression expands to keyboard and supports cursor editing', (
    tester,
  ) async {
    await _openCalculator(tester);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    final expressionCard = find.byKey(const Key('calculator-expression-panel'));
    final keyboard = find.byKey(const ValueKey('calculator-keyboard'));
    final navigation = find.byKey(const Key('floating-navigation-capsule'));
    final cardRect = tester.getRect(expressionCard);
    final keyboardRect = tester.getRect(keyboard);
    final navigationRect = tester.getRect(navigation);
    expect(keyboardRect.top - cardRect.bottom, closeTo(12, 1));
    expect(navigationRect.top - keyboardRect.bottom, closeTo(12, 1));

    await _tap(tester, find.byKey(const ValueKey('calculator-key-1')));
    for (var i = 0; i < 24; i++) {
      await _tap(tester, find.byKey(const ValueKey('calculator-common-key-+')));
      await _tap(tester, find.byKey(const ValueKey('calculator-key-1')));
    }
    expect(
      find.descendant(
        of: expressionCard,
        matching: find.byType(SingleChildScrollView),
      ),
      findsWidgets,
    );
    final expressionScroll = find
        .descendant(of: expressionCard, matching: find.byType(Scrollable))
        .first;
    final scrollPosition = tester
        .state<ScrollableState>(expressionScroll)
        .position;
    expect(scrollPosition.maxScrollExtent, greaterThan(0));
    expect(scrollPosition.axisDirection, AxisDirection.right);
    await _capture(binding, '20-long-expression-scrollable');

    final input = find.byKey(const Key('expression-input'));
    final textField = tester.widget<TextField>(input);
    expect(textField.readOnly, isFalse);
    expect(textField.enableInteractiveSelection, isTrue);
    expect(textField.showCursor, isTrue);
    expect(textField.style?.color, Colors.transparent);

    final inputRect = tester.getRect(input);
    await tester.tapAt(Offset(inputRect.left + 12, inputRect.top + 18));
    await tester.pumpAndSettle();
    expect(textField.controller!.selection.isValid, isTrue);
    expect(
      textField.controller!.selection.extentOffset,
      lessThan(textField.controller!.text.length),
    );
    final controller = textField.controller!;
    final cursor = controller.selection.extentOffset;
    final beforeEdit = controller.text;
    await _tap(tester, find.byKey(const ValueKey('calculator-common-key-+')));
    expect(
      controller.text,
      beforeEdit.replaceRange(cursor, cursor, '+'),
      reason: 'A keypad tap must insert at the draggable expression caret.',
    );
    await _capture(binding, '21-expression-editor-cursor-placement');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('scientific functions and symbols insert into expression', (
    tester,
  ) async {
    await _openCalculator(tester);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await _selectMode(tester, 'Basic', 'Scientific');
    final functionKey = find.byKey(const ValueKey('function-key-sin('));
    expect(functionKey, findsOneWidget);
    await _tap(tester, functionKey);
    expect(_expression(tester), 'sin(');

    await _tap(tester, find.byKey(const ValueKey('keyboard-layer-numbers')));
    await _tap(tester, find.byKey(const ValueKey('calculator-key-2')));
    expect(_expression(tester), 'sin(2');

    await _tap(tester, find.byKey(const ValueKey('keyboard-layer-symbols')));
    await _tap(tester, find.byKey(const ValueKey('calculator-key-sqrt(')));
    expect(_expression(tester), 'sin(2sqrt(');
  });

  testWidgets('C clears the active geometry and number system inputs', (
    tester,
  ) async {
    await _openCalculator(tester);
    await _selectMode(tester, 'Basic', 'Geometry');
    final geometryExpression = find.byKey(
      const Key('calculator-expression-panel'),
    );
    final geometryKeyboard = find.byKey(const ValueKey('calculator-keyboard'));
    expect(
      tester.getRect(geometryKeyboard).top -
          tester.getRect(geometryExpression).bottom,
      closeTo(12, 1),
    );
    final radius = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Radius',
    );
    expect(radius, findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('calculator-key-3')));
    expect(tester.widget<TextField>(radius).controller!.text, '3');
    await _tap(tester, find.byKey(const ValueKey('calculator-keyboard-clear')));
    expect(tester.widget<TextField>(radius).controller!.text, isEmpty);

    await _selectMode(tester, 'Geometry', 'Number systems');
    final firstNumber = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText?.startsWith('Value in base') == true,
    );
    expect(firstNumber, findsOneWidget);
    await _tap(
      tester,
      find.byKey(const ValueKey('calculator-key-NUM_DIGIT_1')),
    );
    expect(tester.widget<TextField>(firstNumber).controller!.text, '1');
    await _tap(tester, find.byKey(const ValueKey('calculator-keyboard-clear')));
    expect(tester.widget<TextField>(firstNumber).controller!.text, isEmpty);
  });

  testWidgets('probability function key inserts and evaluates on device', (
    tester,
  ) async {
    await _openCalculator(tester);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await _selectMode(tester, 'Basic', 'Probability');
    final key = find.byKey(const ValueKey('function-key-binomial('));
    expect(key, findsOneWidget);
    await _tap(tester, key);
    expect(_expression(tester), contains('binomial('));
    await _capture(binding, '12-probability-function-key-input');

    final input = find.byKey(const Key('expression-input'));
    await tester.enterText(input, 'binomial(10,3,0.5)');
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('calculator-keyboard-enter')));
    final choice = find.byKey(const Key('answer-simplified-choice'));
    if (choice.evaluate().isNotEmpty) await _tap(tester, choice);
    expect(_answer(tester), contains('0.1171875'));
    await _capture(binding, '12-probability-binomial-result');
  });

  testWidgets('physics function key inserts and evaluates on device', (
    tester,
  ) async {
    await _openCalculator(tester);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await _selectMode(tester, 'Basic', 'Physics');
    final key = find.byKey(const ValueKey('function-key-distance('));
    expect(key, findsOneWidget);
    await _tap(tester, key);
    expect(_expression(tester), contains('distance('));
    await _capture(binding, '13-physics-function-key-input');

    final input = find.byKey(const Key('expression-input'));
    await tester.enterText(input, 'distance(12,4)');
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('calculator-keyboard-enter')));
    final choice = find.byKey(const Key('answer-simplified-choice'));
    if (choice.evaluate().isNotEmpty) await _tap(tester, choice);
    expect(_answer(tester), '48');
    await _capture(binding, '13-physics-distance-result');
  });

  testWidgets('calculus functions remain reachable across keypad pages', (
    tester,
  ) async {
    await _openCalculator(tester);
    await _selectMode(tester, 'Basic', 'Calculus');

    expect(find.byKey(const ValueKey('function-key-x')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('function-key-CALC_LEIBNIZ_FIRST')),
      findsOneWidget,
    );
    final calculusKeyHeight = tester
        .getSize(find.byKey(const ValueKey('function-key-x')))
        .height;
    expect(
      calculusKeyHeight,
      tester
          .getSize(find.byKey(const ValueKey('calculator-common-key-+')))
          .height,
    );

    final pageControl = find.byKey(const ValueKey('keyboard-layer-functions'));
    var foundSine = false;
    for (var page = 0; page < 5; page++) {
      final sine = find.byKey(const ValueKey('function-key-sin('));
      if (sine.evaluate().isNotEmpty) {
        foundSine = true;
        await _tap(tester, sine);
        break;
      }
      await _tap(tester, pageControl);
    }
    expect(foundSine, isTrue, reason: 'Later calculus keys must be reachable.');
    expect(_expression(tester), 'sin(');
  });

  testWidgets('calculus operation keys appear in the expression card', (
    tester,
  ) async {
    await _openCalculator(tester);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await _selectMode(tester, 'Basic', 'Calculus');

    await _tap(
      tester,
      find.byKey(const ValueKey('function-key-CALC_INTEGRAL')),
    );
    expect(_expression(tester), 'integral of empty expression');
    await _capture(binding, '17-calculus-integral-operation-preview');

    await _tap(tester, find.byKey(const ValueKey('function-key-x')));
    expect(_expression(tester), 'integral of x');
    await _capture(binding, '18-calculus-integral-expression-preview');
    await _tap(tester, find.byKey(const ValueKey('calculator-keyboard-enter')));
    await _tap(tester, find.byKey(const Key('answer-simplified-choice')));
    expect(find.byKey(const Key('calculation-result')), findsOneWidget);
    expect(_answer(tester), contains('x'));
    expect(_expression(tester), 'integral of x');
    await _capture(binding, '19-calculus-integral-result');
  });

  testWidgets(
    'finite limit expression is visible before and after evaluation',
    (tester) async {
      await _openCalculator(tester);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await _selectMode(tester, 'Basic', 'Calculus');

      await _tap(
        tester,
        find.byKey(const ValueKey('function-key-CALC_LIMIT_TWO')),
      );
      expect(find.byKey(const Key('calculus-bounds-dialog')), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('function-key-x')));
      expect(_expression(tester), 'limit from both sides of x');
      await _capture(binding, 'finite-limit-x-approaches-zero-expression');

      await _tap(
        tester,
        find.byKey(const ValueKey('calculator-keyboard-enter')),
      );
      await _tap(tester, find.byKey(const Key('answer-simplified-choice')));
      expect(_answer(tester), contains('0'));
      expect(_expression(tester), 'limit from both sides of x');
      await _capture(binding, 'finite-limit-x-approaches-zero-result');
    },
  );

  testWidgets('equation equals inserts a relation and graph views remain', (
    tester,
  ) async {
    await _openCalculator(tester);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await _selectMode(tester, 'Basic', 'Algebra');

    await _tap(tester, find.byKey(const ValueKey('function-key-x')));
    await _tap(tester, find.byKey(const ValueKey('function-key-=')));
    await _tap(tester, find.byKey(const ValueKey('function-key-y')));
    await _tap(tester, find.byKey(const ValueKey('function-key-^')));
    await _tap(tester, find.byKey(const ValueKey('keyboard-layer-numbers')));
    await _tap(tester, find.byKey(const ValueKey('calculator-key-2')));
    expect(_expression(tester), 'x=y^2');
    expect(find.byKey(const Key('calculation-result')), findsNothing);

    await _selectMode(tester, 'Algebra', 'Graphing');
    final visualizationButton = find.byTooltip('Flip to visualization');
    expect(visualizationButton, findsOneWidget);
    await _tap(tester, visualizationButton);
    expect(find.byKey(const Key('visualization-plot-toggle')), findsOneWidget);
    expect(find.text('2D'), findsOneWidget);
    expect(find.text('3D'), findsOneWidget);
    await _capture(binding, '14-graphing-2d-view');
    await _tap(tester, find.text('3D'));
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const Key('visualization-chart-semantics')),
          )
          .properties
          .label,
      contains('3D function graph'),
    );
    await _capture(binding, '15-graphing-3d-view');
    await _tap(tester, find.text('Flip back to calculator'));
    expect(find.byKey(const Key('expression-input')), findsOneWidget);
  });
}

Future<void> _openCalculator(WidgetTester tester) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.clear();
  await preferences.setBool('mathverse.auth.signedIn', true);
  await preferences.setString('mathverse.profile.name', 'Keypad Tester');
  await preferences.setString('mathverse.profile.username', 'keypad_tester');

  await tester.pumpWidget(
    MathevoApp(
      authApi: FakeAuthApi(registered: true),
      tokenStore: MemoryAuthTokenStore(refreshToken: 'keypad-test'),
    ),
  );
  await _pumpUntil(tester, find.byKey(const Key('nav-calculator')));
  await tester.tap(find.byKey(const Key('nav-calculator')));
  await tester.pumpAndSettle();
}

Future<void> _selectMode(
  WidgetTester tester,
  String currentMode,
  String mode,
) async {
  await tester.tap(find.text(currentMode));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(mode),
    180,
    scrollable: find.byType(Scrollable).last,
  );
  final target = find.text(mode).last;
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _exerciseCommonArithmeticKeys(
  WidgetTester tester,
  String mode,
) async {
  final keyboard = find.byKey(const ValueKey('calculator-keyboard'));
  final keys = find
      .descendant(
        of: keyboard,
        matching: find.byWidgetPredicate((widget) {
          final key = widget.key;
          return key is ValueKey<String> &&
              key.value.startsWith('calculator-common-key-');
        }),
      )
      .evaluate()
      .map((element) => element.widget.key! as ValueKey<String>)
      .toList();
  expect(keys, hasLength(5));
  for (final key in keys) {
    await _clearKeypadState(tester);
    _seedEditableInput(tester, mode);
    final before = _visibleInputState(tester);
    await _tap(tester, find.byKey(key));
    await _dismissAnswerChoice(tester);
    expect(
      _visibleInputState(tester),
      isNot(before),
      reason:
          '$mode common arithmetic key ${key.value} must update the visible input.',
    );
  }
}

Future<void> _clearKeypadState(WidgetTester tester) async {
  final clear = find.byKey(const ValueKey('calculator-keyboard-clear'));
  if (clear.evaluate().isNotEmpty) await _tap(tester, clear);
}

void _seedEditableInput(WidgetTester tester, String mode) {
  if (mode == 'Number systems') {
    _seedNumberSystemInputs(tester);
    return;
  }
  if (mode == 'Geometry') {
    final radius = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Radius',
    );
    final fields = find.byType(TextField).evaluate();
    if (radius.evaluate().isNotEmpty) {
      final field = tester.widget<TextField>(radius.first);
      field.controller!.value = const TextEditingValue(
        text: '1',
        selection: TextSelection.collapsed(offset: 1),
      );
    } else if (fields.isNotEmpty) {
      final field = tester.widget<TextField>(find.byType(TextField).first);
      field.controller?.text = '1';
    }
    return;
  }
  final expression = find.byKey(const Key('expression-input'));
  if (expression.evaluate().isNotEmpty) {
    final field = tester.widget<TextField>(expression);
    field.controller!.value = const TextEditingValue(
      text: '1',
      selection: TextSelection.collapsed(offset: 1),
    );
  }
}

void _seedNumberSystemInputs(WidgetTester tester) {
  final fields = find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.labelText?.startsWith('First value in base') == true,
  );
  if (fields.evaluate().isNotEmpty) {
    tester.widget<TextField>(fields.first).controller!.text = '2';
  }
}

String _visibleInputState(WidgetTester tester) {
  final parts = <String>[];
  final expression = find.byKey(const Key('calculator-expression-display'));
  if (expression.evaluate().isNotEmpty) {
    parts.add(tester.widget<Semantics>(expression).properties.label ?? '');
  }
  if (find.byKey(const Key('fraction-insert')).evaluate().isNotEmpty) {
    parts.add('inline-fraction-editor-visible');
  }
  for (final element in find.byType(TextField).evaluate()) {
    final field = element.widget as TextField;
    parts.add(field.controller?.text ?? '');
  }
  final result = find.byKey(const Key('calculation-result'));
  if (result.evaluate().isNotEmpty) {
    parts.add(tester.widget<Semantics>(result).properties.label ?? '');
  }
  return parts.join('|');
}

Future<void> _dismissCalculusBounds(WidgetTester tester) async {
  final dialog = find.byKey(const Key('calculus-bounds-dialog'));
  final done = find.text('Done');
  if (dialog.evaluate().isNotEmpty && done.evaluate().isNotEmpty) {
    await _tap(tester, done.last);
  }
}

Future<void> _dismissAnswerChoice(WidgetTester tester) async {
  final choice = find.byKey(const Key('answer-simplified-choice'));
  if (choice.evaluate().isNotEmpty) await _tap(tester, choice);
}

String _expression(WidgetTester tester) => tester
    .widget<Semantics>(find.byKey(const Key('calculator-expression-display')))
    .properties
    .label!;

String _answer(WidgetTester tester) => tester
    .widget<Semantics>(find.byKey(const Key('calculation-result')))
    .properties
    .label!
    .replaceFirst(RegExp(r'^(?:Exact answer|Answer):\s*'), '')
    .replaceFirst(RegExp(r'^≈\s*'), '')
    .trim();

Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  await binding.takeScreenshot(name);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}
