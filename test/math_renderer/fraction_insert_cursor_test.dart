import 'package:flutter_test/flutter_test.dart';
import 'package:klator/math_renderer/math_editor_controller.dart';
import 'package:klator/math_renderer/math_nodes.dart';

void main() {
  group('Fraction Insert Cursor', () {
    test('division on empty input places cursor in numerator', () {
      final controller = MathEditorController();

      controller.insertCharacter('/');

      final fractions = controller.expression.whereType<FractionNode>().toList();
      expect(fractions.length, 1);

      final fraction = fractions.first;
      expect(controller.cursor.parentId, equals(fraction.id));
      expect(controller.cursor.path, equals('num'));
      expect(controller.cursor.index, equals(0));
      expect(controller.cursor.subIndex, equals(0));
    });

    test('division with numerator content places cursor in denominator', () {
      final controller = MathEditorController();
      controller.insertCharacter('x');

      controller.insertCharacter('/');

      final fractions = controller.expression.whereType<FractionNode>().toList();
      expect(fractions.length, 1);

      final fraction = fractions.first;
      expect((fraction.numerator.first as LiteralNode).text, isNotEmpty);
      expect(controller.cursor.parentId, equals(fraction.id));
      expect(controller.cursor.path, equals('den'));
      expect(controller.cursor.index, equals(0));
      expect(controller.cursor.subIndex, equals(0));
    });
  });
}
