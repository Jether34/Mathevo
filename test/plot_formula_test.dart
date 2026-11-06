import 'package:flutter_test/flutter_test.dart';
import 'package:mathevo/visualization/plot_formula.dart';

void main() {
  group('plot formula classification', () {
    test('recognizes the central difference of x squared', () {
      final formula = CentralDifferenceFormula.tryParse(
        '((3+0.01)^2-(3-0.01)^2)/(2*0.01)',
      );

      expect(formula, isNotNull);
      expect(formula!.center, 3);
      expect(formula.step, .01);
      expect(formula.leftX, closeTo(2.99, 1e-12));
      expect(formula.rightX, closeTo(3.01, 1e-12));
      expect(formula.approximateDerivative, closeTo(6, 1e-10));
      expect(formula.exactDerivative, 6);
    });

    test(
      'recognizes normalized multiplication and rejects mismatched steps',
      () {
        expect(
          CentralDifferenceFormula.tryParse(
            '((3 × 1 + 0.01)^2 - (3 - 0.01)^2) / (2 × 0.01)',
          ),
          isNull,
        );
        expect(
          CentralDifferenceFormula.tryParse('((3+0.01)^2-(3-0.02)^2)/(2*0.01)'),
          isNull,
        );
      },
    );

    test('distinguishes scalar results from graph functions', () {
      expect(PlotFormula('6').isScalar, isTrue);
      expect(PlotFormula('y=6').isExplicitY, isTrue);
      expect(PlotFormula('y=6').isScalar, isFalse);
      expect(PlotFormula('y=x^2').isExplicitY, isTrue);
      expect(PlotFormula('x^2+y^2=1').hasXY, isTrue);
      expect(PlotFormula('z=x^2+y^2').isExplicitZ, isTrue);
    });
  });
}
