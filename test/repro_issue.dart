import 'package:flutter_test/flutter_test.dart';
import 'package:klator/math_engine/math_engine_exact.dart';
import 'package:klator/math_renderer/math_nodes.dart';

void main() {
  group('Final Verification', () {
    test('Quadratic Case: x^2 + 2x - 1 = 0', () {
      final nodes = [
        ExponentNode(
          base: [LiteralNode(text: 'x')],
          power: [LiteralNode(text: '2')],
        ),
        LiteralNode(text: ' + 2x - 1 = 0'),
      ];
      final result = ExactMathEngine.evaluate(nodes);

      expect(result.isEmpty, isFalse);

      final nodesString = result.mathNodes!
          .map((n) => n is LiteralNode ? n.text : n.runtimeType)
          .join('');
      // ignore: avoid_print
      print('DEBUG Quadratic String: $nodesString');

      expect(nodesString, contains('x = '));
      // Quadratic formula might produce terms in different order or format
      expect(nodesString.contains('−1') || nodesString.contains('-1'), isTrue);
      expect(nodesString, contains('RootNode'));
    });

    test('Simultaneous System Case: x+y=5, x-y=1', () {
      final nodes = [
        LiteralNode(text: 'x + y = 5'),
        NewlineNode(),
        LiteralNode(text: 'x - y = 1'),
      ];
      final result = ExactMathEngine.evaluate(nodes);

      expect(result.isEmpty, isFalse);

      final nodesString = result.mathNodes!
          .map((n) => n is LiteralNode ? n.text : n.runtimeType)
          .join('');
      // ignore: avoid_print
      print('DEBUG System String: $nodesString');

      // Look for individual components to be robust
      expect(nodesString, contains('x = 3'));
      expect(nodesString, contains('y = 2'));
    });
  });
}
