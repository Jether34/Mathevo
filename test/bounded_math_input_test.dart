import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_keyboard/math_keyboard.dart';
import 'package:math_keyboard/src/foundation/node.dart';

void main() {
  group('bounded math operators', () {
    test('summation renders with official symbol and editable scripts', () {
      final controller = MathFieldEditingController();
      controller.addBoundedOperator(
        r'\sum',
        values: const ['n=1', '5', 'n^2'],
        activeArgument: 2,
      );

      expect(controller.currentEditingValue(), r'\sum_{n=1}^{5}\, n^2');
    });

    test('tap location routes into lower, upper, body, and exponent slots', () {
      final controller = MathFieldEditingController();
      controller.addBoundedOperator(
        r'\int',
        values: const ['0', '2', 'x^2'],
        activeArgument: 2,
      );
      final integral = controller.boundedOperator!;

      controller.placeCursorAt(const Offset(32, 32), const Size(260, 48));
      expect(identical(controller.currentNode, integral.argNodes[0]), isTrue);

      controller.placeCursorAt(const Offset(32, 14), const Size(260, 48));
      expect(identical(controller.currentNode, integral.argNodes[1]), isTrue);

      controller.placeCursorAt(const Offset(180, 24), const Size(260, 48));
      expect(identical(controller.currentNode, integral.argNodes[2]), isTrue);

      controller.clear();
      controller.addLeaf('x');
      controller.addFunction('^', const [TeXArg.braces]);
      controller.addLeaf('2');
      controller.placeCursorAt(const Offset(24, 14), const Size(260, 48));
      expect(controller.currentNode.parent?.expression, '^');
    });

    test('double-integral bounds are separate math slots', () {
      final controller = MathFieldEditingController();
      controller.addBoundedOperator(
        r'\iint',
        values: const ['0', '2', '1', '4', 'x+y'],
        activeArgument: 4,
      );
      final integral = controller.boundedOperator!;
      for (final (y, expectedSlot) in [(-.9, 3), (-.4, 1), (.3, 0), (.8, 2)]) {
        controller.placeCursorAt(Offset(38, 24 + y * 18), const Size(260, 48));
        expect(
          identical(controller.currentNode, integral.argNodes[expectedSlot]),
          isTrue,
        );
      }
      expect(
        controller.currentEditingValue(),
        contains(r'\iint_{\substack{x=0\\y=1}}^{\substack{x=2\\y=4}}'),
      );
    });
  });
}
