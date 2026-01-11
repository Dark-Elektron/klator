
import 'package:flutter_test/flutter_test.dart';
import 'package:klator/math_renderer/math_editor_controller.dart';
import 'package:klator/math_renderer/math_nodes.dart';
import 'package:klator/math_renderer/expression_selection.dart';

void main() {
  group('Selection Wrapping Regression Tests', () {
    late MathEditorController controller;

    setUp(() {
      controller = MathEditorController();
    });

    test('Wrap single fraction selection in parenthesis', () {
      // Setup: [FractionNode]
      final fraction = FractionNode(
        num: [LiteralNode(text: "1")],
        den: [LiteralNode(text: "2")],
      );
      controller.expression = [fraction];
      
      // Select the fraction
      controller.setSelection(SelectionRange(
        start: SelectionAnchor(nodeIndex: 0, charIndex: 0),
        end: SelectionAnchor(nodeIndex: 0, charIndex: 1),
      ));

      controller.insertCharacter('(');

      // Verify structure: [Literal, Parenthesis([Literal, Fraction, Literal]), Literal]
      // Because we now unconditionally insert literals, there should be 3 nodes.
      
      expect(controller.expression.length, 3);
      expect(controller.expression[0], isA<LiteralNode>());
      expect((controller.expression[0] as LiteralNode).text, isEmpty);
      
      expect(controller.expression[1], isA<ParenthesisNode>());
      final paren = controller.expression[1] as ParenthesisNode;
      expect(paren.content.length, greaterThanOrEqualTo(1));
      
      expect(controller.expression[2], isA<LiteralNode>());
      expect((controller.expression[2] as LiteralNode).text, isEmpty);
    });

    test('Wrap Fraction followed by Literal', () {
      // Setup: [FractionNode, LiteralNode("abc")]
      final fraction = FractionNode(
        num: [LiteralNode(text: "1")],
        den: [LiteralNode(text: "2")],
      );
      controller.expression = [
        fraction,
        LiteralNode(text: "abc")
      ];
      
      // Select Fraction (0) and Literal (1) fully
      controller.setSelection(SelectionRange(
        start: SelectionAnchor(nodeIndex: 0, charIndex: 0),
        end: SelectionAnchor(nodeIndex: 1, charIndex: 3), 
      ));

      controller.insertCharacter('(');

      // Should be: [Literal, Paren([Fraction, Literal("abc")]), Literal]
      // Literal[0] empty (prefix of Fraction)
      // Literal[2] empty (suffix of "abc")
      
      expect(controller.expression, hasLength(3));
      
      expect(controller.expression[0], isA<LiteralNode>());
      expect((controller.expression[0] as LiteralNode).text, isEmpty);
      
      expect(controller.expression[1], isA<ParenthesisNode>());
      final paren = controller.expression[1] as ParenthesisNode;
      expect(paren.content.length, 3); // Literal(""), Fraction, Literal("abc")
      
      expect(controller.expression[2], isA<LiteralNode>());
      expect((controller.expression[2] as LiteralNode).text, isEmpty);
    });
  });
}
