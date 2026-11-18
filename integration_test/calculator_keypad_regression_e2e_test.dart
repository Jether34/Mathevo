import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:math_keyboard/math_keyboard.dart';
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
    expect(
      tester
          .widget<MathField>(
            find.byKey(const Key('calculator-math-field-input')),
          )
          .controller!
          .currentEditingValue(),
      '2+3',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('expression-input')))
          .decoration
          ?.filled,
      isNot(true),
    );

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
        await _tapQuick(tester, find.byKey(ValueKey('keyboard-layer-$layer')));
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
            if (mode == 'Number systems') {
              _seedNumberSystemInputs(tester);
            } else if (action == 'DEL' || action == 'C') {
              _seedEditableInput(tester, mode);
            } else if (action.startsWith('^')) {
              // Exponents are structural in the math field and need a base.
              _seedEditableInput(tester, mode);
            }

            final before = _visibleInputState(tester);
            await _tapQuick(tester, find.byKey(ValueKey(keyName)));
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
            await _tapQuick(
              tester,
              find.byKey(const ValueKey('keyboard-layer-functions')),
            );
          } else {
            break;
          }
        }
      }
      await _clearKeypadState(tester);
      await _tapQuick(
        tester,
        find.byKey(const ValueKey('keyboard-layer-numbers')),
      );
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
      await _tapQuick(tester, expressionKey);
      await tester.pumpAndSettle();
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
      find.descendant(of: expressionCard, matching: find.byType(Scrollable)),
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

    final mathFieldFinder = find.byKey(
      const Key('calculator-math-field-input'),
    );
    final mathField = tester.widget<MathField>(mathFieldFinder);
    final controller = mathField.controller!;
    final startingCursor = controller.currentNode.courserPosition;
    final inputRect = tester.getRect(mathFieldFinder);
    final caretDrag = await tester.startGesture(
      Offset(inputRect.right - 12, inputRect.center.dy),
    );
    await caretDrag.moveTo(Offset(inputRect.right - 96, inputRect.center.dy));
    await tester.pump(const Duration(milliseconds: 250));
    await caretDrag.up();
    await tester.pumpAndSettle();
    expect(
      controller.currentNode.courserPosition,
      isNot(startingCursor),
      reason: 'Dragging in the expression must reposition its typing caret.',
    );
    final beforeEdit = _expression(tester);
    await _tap(tester, find.byKey(const ValueKey('calculator-common-key-+')));
    expect(
      _expression(tester),
      isNot(beforeEdit),
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
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('expression-input')))
          .controller!
          .text,
      'sin(',
      reason: 'The live math field must display incomplete function input.',
    );

    await _tap(tester, find.byKey(const ValueKey('keyboard-layer-numbers')));
    await _tap(tester, find.byKey(const ValueKey('calculator-key-2')));
    expect(_expression(tester), 'sin(2)');

    await _tap(tester, find.byKey(const ValueKey('keyboard-layer-symbols')));
    await _tap(tester, find.byKey(const ValueKey('calculator-key-sqrt(')));
    expect(_expression(tester), 'sin(2sqrt())');
    expect(
      tester
          .widget<MathField>(
            find.byKey(const Key('calculator-math-field-input')),
          )
          .controller!
          .currentEditingValue(),
      contains(r'\sqrt'),
    );
  });

  testWidgets('tapping places the math caret and fractions edit by part', (
    tester,
  ) async {
    await _openCalculator(tester);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();

    await _tap(tester, find.byKey(const ValueKey('calculator-key-1')));
    await _tap(tester, find.byKey(const ValueKey('calculator-key-2')));
    await _tap(tester, find.byKey(const ValueKey('calculator-key-3')));
    final fieldFinder = find.byKey(const Key('calculator-math-field-input'));
    var fieldRect = tester.getRect(fieldFinder);
    await tester.tapAt(Offset(fieldRect.left + 26, fieldRect.center.dy));
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('calculator-key-9')));

    var editor = tester.widget<MathField>(fieldFinder).controller!;
    expect(editor.currentEditingValue(), '1923');
    await _capture(binding, 'math-field-tap-places-caret');
    await tester.pump(const Duration(milliseconds: 600));
    await _capture(binding, 'math-field-caret-blink');

    await _tap(tester, find.byKey(const ValueKey('calculator-keyboard-clear')));
    await _tap(tester, find.byKey(const ValueKey('keyboard-layer-functions')));
    await _tap(tester, find.byKey(const ValueKey('function-key-a/b')));
    editor = tester.widget<MathField>(fieldFinder).controller!;
    expect(editor.currentEditingValue(), contains(r'\frac'));
    await _tap(tester, find.byKey(const ValueKey('keyboard-layer-numbers')));

    fieldRect = tester.getRect(fieldFinder);
    await tester.tapAt(Offset(fieldRect.left + 22, fieldRect.center.dy - 8));
    await _tap(tester, find.byKey(const ValueKey('calculator-key-3')));
    fieldRect = tester.getRect(fieldFinder);
    await tester.tapAt(Offset(fieldRect.left + 22, fieldRect.center.dy + 8));
    await _tap(tester, find.byKey(const ValueKey('calculator-key-4')));

    editor = tester.widget<MathField>(fieldFinder).controller!;
    expect(editor.currentEditingValue(), contains(r'\frac{3}{4}'));
    await _capture(binding, 'math-field-editable-fraction');
  });

  testWidgets('Basic Fx layer inserts its selected function into expression', (
    tester,
  ) async {
    await _openCalculator(tester);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();

    await _tap(tester, find.byKey(const ValueKey('keyboard-layer-functions')));
    final sineKey = find.byKey(const ValueKey('function-key-sin('));
    expect(sineKey, findsOneWidget);
    await _tap(tester, sineKey);

    expect(_expression(tester), 'sin(');
    expect(
      find.descendant(
        of: find.byKey(const Key('calculator-expression-panel')),
        matching: find.text('sin('),
      ),
      findsWidgets,
    );
    await _capture(binding, 'basic-fx-sine-appears-in-expression');
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
    final radiusMathField = find.byKey(const ValueKey('math-field-radius'));
    expect(radiusMathField, findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('calculator-key-3')));
    expect(tester.widget<TextField>(radius).controller!.text, '3');
    expect(
      tester
          .widget<MathField>(radiusMathField)
          .controller!
          .currentEditingValue(),
      '3',
    );
    await _tap(tester, find.byKey(const ValueKey('calculator-keyboard-clear')));
    expect(tester.widget<TextField>(radius).controller!.text, isEmpty);

    await _selectMode(tester, 'Geometry', 'Number systems');
    final firstNumber = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText?.startsWith('Value in base') == true,
    );
    expect(firstNumber, findsOneWidget);
    final firstNumberMathField = find.byKey(
      const ValueKey('math-field-value-in-base-10'),
    );
    expect(firstNumberMathField, findsOneWidget);
    await _tap(
      tester,
      find.byKey(const ValueKey('calculator-key-NUM_DIGIT_1')),
    );
    expect(tester.widget<TextField>(firstNumber).controller!.text, '1');
    expect(
      tester
          .widget<MathField>(firstNumberMathField)
          .controller!
          .currentEditingValue(),
      '1',
    );
    await _tap(tester, find.byKey(const ValueKey('calculator-keyboard-clear')));
    expect(tester.widget<TextField>(firstNumber).controller!.text, isEmpty);
  });

  testWidgets('number system arithmetic is visible and evaluates on device', (
    tester,
  ) async {
    await _openCalculator(tester);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await _selectMode(tester, 'Basic', 'Number systems');

    await _tap(
      tester,
      find.byKey(const ValueKey('calculator-key-NUM_DIGIT_2')),
    );
    await _tap(tester, find.byKey(const ValueKey('calculator-common-key-+')));
    expect(find.text('Calculate'), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const Key('number-system-expression-display')),
          )
          .properties
          .label,
      contains('2 +'),
    );

    final secondValue = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText?.startsWith('Second value in base') ==
              true,
    );
    await _tap(tester, secondValue);
    await _tap(
      tester,
      find.byKey(const ValueKey('calculator-key-NUM_DIGIT_1')),
    );
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const Key('number-system-expression-display')),
          )
          .properties
          .label,
      contains('2 + 1'),
    );
    await _capture(binding, 'number-system-shared-arithmetic-expression');

    await _tap(tester, find.byKey(const ValueKey('calculator-common-key-=')));
    expect(find.text('11 (base 2)'), findsOneWidget);
    await _capture(binding, 'number-system-shared-arithmetic-result');
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

  testWidgets('limit function key immediately renders an editable template', (
    tester,
  ) async {
    await _openCalculator(tester);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await _selectMode(tester, 'Basic', 'Calculus');

    await _tap(
      tester,
      find.byKey(const ValueKey('function-key-CALC_LIMIT_RIGHT')),
    );
    await tester.pumpAndSettle();

    expect(_expression(tester), 'right-hand limit of empty expression');
    expect(
      find.byKey(const Key('calculator-expression-display')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('expression-input')), findsOneWidget);
    await _capture(binding, 'calculus-right-limit-template-visible');

    await _tap(tester, find.byKey(const ValueKey('function-key-x')));
    expect(_expression(tester), 'right-hand limit of x');
    await _capture(binding, 'calculus-right-limit-function-entered');
  });

  testWidgets('derivative function key is painted inside expression box', (
    tester,
  ) async {
    await _openCalculator(tester);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await _selectMode(tester, 'Basic', 'Calculus');

    await _tap(
      tester,
      find.byKey(const ValueKey('function-key-CALC_LEIBNIZ_SECOND')),
    );
    await tester.pumpAndSettle();

    final expressionCard = find.byKey(const Key('calculator-expression-panel'));
    expect(
      find.descendant(
        of: expressionCard,
        matching: find.byKey(const Key('calculator-math-field')),
      ),
      findsOneWidget,
    );
    await _capture(binding, 'calculus-second-derivative-expression-visible');

    await _tap(tester, find.byKey(const ValueKey('function-key-x')));
    expect(_expression(tester), 'd^2y/dx^2 of x');
    await _capture(binding, 'calculus-second-derivative-body-entered');
  });

  testWidgets('caret drag edits characters in the calculus function', (
    tester,
  ) async {
    await _openCalculator(tester);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await _selectMode(tester, 'Basic', 'Calculus');
    await _tap(
      tester,
      find.byKey(const ValueKey('function-key-CALC_LEIBNIZ_SECOND')),
    );

    final input = find.byKey(const Key('calculator-math-field-input'));
    final mathController = tester.widget<MathField>(input).controller!;
    String formulaTex() => mathController.currentEditingValue();
    expect(formulaTex(), contains('d'));
    final inputRect = tester.getRect(input);
    final oldOffset = mathController.currentNode.courserPosition;
    final drag = await tester.startGesture(
      Offset(inputRect.right - 12, inputRect.center.dy),
    );
    await drag.moveTo(Offset(inputRect.right - 48, inputRect.center.dy));
    await tester.pump(const Duration(milliseconds: 250));
    await drag.up();
    await tester.pumpAndSettle();

    expect(mathController.currentNode.courserPosition, isNot(oldOffset));
    await _capture(binding, 'calculus-function-caret-after-drag');
    final beforeDelete = formulaTex();
    await _tap(
      tester,
      find.byKey(const ValueKey('calculator-keyboard-delete')),
    );
    expect(formulaTex().length, lessThan(beforeDelete.length));
  });

  testWidgets('drag edits integral bounds and evaluates the edited values', (
    tester,
  ) async {
    await _openCalculator(tester);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await _selectMode(tester, 'Basic', 'Calculus');
    await _tap(
      tester,
      find.byKey(const ValueKey('function-key-CALC_DEFINITE_INTEGRAL')),
    );
    await _dismissCalculusBounds(tester);

    final input = find.byKey(const Key('calculator-math-field-input'));
    final mathController = tester.widget<MathField>(input).controller!;
    String formulaTex() => mathController.currentEditingValue();
    expect(formulaTex(), isNotEmpty);

    _moveMathCaretTo(mathController, formulaTex().indexOf('0') + 1);
    await _tap(
      tester,
      find.byKey(const ValueKey('calculator-keyboard-delete')),
    );
    await _tap(tester, find.byKey(const ValueKey('keyboard-layer-numbers')));
    await _tap(tester, find.byKey(const ValueKey('calculator-key-1')));
    expect(formulaTex(), contains('1'), reason: 'lower bound after edit');

    _moveMathCaretTo(mathController, formulaTex().indexOf('2') + 1);
    await _tap(
      tester,
      find.byKey(const ValueKey('calculator-keyboard-delete')),
    );
    await _tap(tester, find.byKey(const ValueKey('calculator-key-3')));
    expect(formulaTex(), contains('3'), reason: 'upper bound after edit');

    _moveMathCaretTo(mathController, formulaTex().indexOf('(') + 1);
    await _tap(tester, find.byKey(const ValueKey('keyboard-layer-functions')));
    await _tap(tester, find.byKey(const ValueKey('function-key-x')));
    expect(formulaTex(), isNotEmpty);
    expect(
      _expression(tester),
      'integral with bounds of x',
      reason: formulaTex(),
    );
    await _tap(tester, find.byKey(const ValueKey('calculator-keyboard-enter')));
    await _tap(tester, find.byKey(const Key('answer-simplified-choice')));
    expect(_answer(tester), contains('4'));
    await _capture(binding, 'calculus-editable-bounds-evaluated');
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
  await tester.tap(find.text(currentMode).first);
  await tester.pumpAndSettle();
  expect(find.text('Choose a calculator mode'), findsOneWidget);
  final modeList = find.byType(ListView).last;
  var selected = false;
  for (var attempt = 0; attempt < 12; attempt++) {
    final targets = find.text(mode);
    if (targets.evaluate().isNotEmpty) {
      final target = targets.last;
      final targetRect = tester.getRect(target);
      final listRect = tester.getRect(modeList);
      if (targetRect.top >= listRect.top &&
          targetRect.bottom <= listRect.bottom) {
        await tester.tapAt(targetRect.center);
        await tester.pumpAndSettle();
        selected = true;
        break;
      }
    }
    await tester.drag(modeList, const Offset(0, -220));
    await tester.pumpAndSettle();
  }
  expect(selected, isTrue, reason: '$mode must be visible in the mode picker.');
  expect(find.text('Choose a calculator mode'), findsNothing);
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
    await _tapQuick(tester, find.byKey(key));
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
  if (clear.evaluate().isNotEmpty) await _tapQuick(tester, clear);
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
  final firstFields = find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.labelText?.startsWith('First value in base') == true,
  );
  if (firstFields.evaluate().isNotEmpty) {
    tester.widget<TextField>(firstFields.first).controller!.text = '2';
  }
  final secondFields = find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.labelText?.startsWith('Second value in base') ==
            true,
  );
  if (secondFields.evaluate().isNotEmpty) {
    tester.widget<TextField>(secondFields.first).controller!.text = '1';
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
  final numberSystemExpression = find.byKey(
    const Key('number-system-expression-display'),
  );
  if (numberSystemExpression.evaluate().isNotEmpty) {
    parts.add(
      tester.widget<Semantics>(numberSystemExpression).properties.label ?? '',
    );
  }
  for (final element in find.byType(TextField).evaluate()) {
    final field = element.widget as TextField;
    parts.add(field.controller?.text ?? '');
  }
  for (final element in find.byType(SelectableText).evaluate()) {
    parts.add((element.widget as SelectableText).data ?? '');
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
  final bytes = await binding.takeScreenshot(name);
  final directory = Directory(
    '${Directory.systemTemp.path}/calculator-keypad-e2e',
  );
  await directory.create(recursive: true);
  await File('${directory.path}/$name.png').writeAsBytes(bytes);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _moveMathCaretTo(MathFieldEditingController controller, int targetOffset) {
  if (controller.currentNode.parent != null) {
    fail('Formula templates must keep their caret in the root math block.');
  }
  while (controller.currentNode.courserPosition > targetOffset) {
    controller.goBack();
  }
  while (controller.currentNode.courserPosition < targetOffset) {
    controller.goNext();
  }
}

Future<void> _tapQuick(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}
