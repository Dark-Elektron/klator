import 'package:flutter_test/flutter_test.dart';
import 'package:klator/math_engine/math_engine_exact.dart';
import 'package:klator/math_renderer/math_nodes.dart';

void main() {
  group('Complex Number Verification', () {
    test('i * i = -1', () {
      final nodes = [LiteralNode(text: 'i*i')];
      final result = ExactMathEngine.evaluate(nodes);
      expect(result.numerical, -1.0);
      expect(result.toNumericalString(), '\u22121');
    });

    test('5i * 5i = -25', () {
      final nodes = [LiteralNode(text: '5i*5i')];
      final result = ExactMathEngine.evaluate(nodes);
      expect(result.numerical, -25.0);
      expect(result.toNumericalString(), '\u221225');
    });

    test('5i display', () {
      final nodes = [LiteralNode(text: '5i')];
      final result = ExactMathEngine.evaluate(nodes);
      // toExactString uses unicode dot \u00B7
      expect(result.toExactString(), '5\u00B7i');
      expect(result.toNumericalString(), '5i');
    });

    test('2i display', () {
      final nodes = [LiteralNode(text: '2i')];
      final result = ExactMathEngine.evaluate(nodes);
      expect(result.toExactString(), '2\u00B7i');
      expect(result.toNumericalString(), '2i');
    });

    test('i display', () {
      final nodes = [LiteralNode(text: 'i')];
      final result = ExactMathEngine.evaluate(nodes);
      expect(result.toExactString(), 'i');
      expect(result.toNumericalString(), 'i');
    });

    test('sqrt(-4) = 2i', () {
      final nodes = [
        RootNode(isSquareRoot: true, radicand: [LiteralNode(text: '-4')]),
      ];
      final result = ExactMathEngine.evaluate(nodes);
      expect(result.toExactString(), '2\u00B7i');
      expect(result.toNumericalString(), '2i');
    });

    test('complex sum: 3 + 4i', () {
      final nodes = [LiteralNode(text: '3+4i')];
      final result = ExactMathEngine.evaluate(nodes);
      expect(result.toNumericalString(), '3 + 4i');
    });

    test('complex subtraction: 3 - i', () {
      final nodes = [LiteralNode(text: '3-i')];
      final result = ExactMathEngine.evaluate(nodes);
      expect(result.toNumericalString(), '3 \u2212 i');
    });

    test('negative imaginary: -2i', () {
      final nodes = [LiteralNode(text: '-2i')];
      final result = ExactMathEngine.evaluate(nodes);
      expect(result.toNumericalString(), '\u22122i');
    });
  });
}
