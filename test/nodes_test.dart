import 'package:flutter_test/flutter_test.dart';
import 'package:klator/math_renderer/renderer.dart';
import 'package:klator/math_renderer/cursor.dart';

void main() {
  group('MathNode - LiteralNode', () {
    test('creates with default empty text', () {
      final node = LiteralNode();
      expect(node.text, equals(''));
    });

    test('creates with specified text', () {
      final node = LiteralNode(text: '123');
      expect(node.text, equals('123'));
    });

    test('has unique id', () {
      final node1 = LiteralNode();
      final node2 = LiteralNode();
      expect(node1.id, isNot(equals(node2.id)));
    });
  });

  group('MathNode - FractionNode', () {
    test('creates with default numerator and denominator', () {
      final node = FractionNode();
      expect(node.numerator.length, equals(1));
      expect(node.denominator.length, equals(1));
      expect(node.numerator[0], isA<LiteralNode>());
      expect(node.denominator[0], isA<LiteralNode>());
    });

    test('creates with specified numerator and denominator', () {
      final node = FractionNode(
        num: [LiteralNode(text: '1')],
        den: [LiteralNode(text: '2')],
      );
      expect((node.numerator[0] as LiteralNode).text, equals('1'));
      expect((node.denominator[0] as LiteralNode).text, equals('2'));
    });
  });

  group('MathNode - ExponentNode', () {
    test('creates with default base and power', () {
      final node = ExponentNode();
      expect(node.base.length, equals(1));
      expect(node.power.length, equals(1));
    });

    test('creates with specified base and power', () {
      final node = ExponentNode(
        base: [LiteralNode(text: '2')],
        power: [LiteralNode(text: '3')],
      );
      expect((node.base[0] as LiteralNode).text, equals('2'));
      expect((node.power[0] as LiteralNode).text, equals('3'));
    });
  });

  group('MathNode - ParenthesisNode', () {
    test('creates with default content', () {
      final node = ParenthesisNode();
      expect(node.content.length, equals(1));
      expect(node.content[0], isA<LiteralNode>());
    });

    test('creates with specified content', () {
      final node = ParenthesisNode(content: [LiteralNode(text: '2+3')]);
      expect((node.content[0] as LiteralNode).text, equals('2+3'));
    });
  });

  group('MathNode - TrigNode', () {
    test('creates sin function', () {
      final node = TrigNode(function: 'sin');
      expect(node.function, equals('sin'));
      expect(node.argument.length, equals(1));
    });

    test('creates cos function', () {
      final node = TrigNode(function: 'cos');
      expect(node.function, equals('cos'));
    });

    test('creates with argument', () {
      final node = TrigNode(
        function: 'sin',
        argument: [LiteralNode(text: '30')],
      );
      expect((node.argument[0] as LiteralNode).text, equals('30'));
    });
  });

  group('MathNode - RootNode', () {
    test('creates square root', () {
      final node = RootNode(isSquareRoot: true);
      expect(node.isSquareRoot, isTrue);
    });

    test('creates nth root', () {
      final node = RootNode(isSquareRoot: false);
      expect(node.isSquareRoot, isFalse);
    });

    test('creates with radicand', () {
      final node = RootNode(
        isSquareRoot: true,
        radicand: [LiteralNode(text: '4')],
      );
      expect((node.radicand[0] as LiteralNode).text, equals('4'));
    });
  });

  group('MathNode - LogNode', () {
    test('creates natural log', () {
      final node = LogNode(isNaturalLog: true);
      expect(node.isNaturalLog, isTrue);
    });

    test('creates log with base', () {
      final node = LogNode(
        isNaturalLog: false,
        base: [LiteralNode(text: '10')],
      );
      expect(node.isNaturalLog, isFalse);
      expect((node.base[0] as LiteralNode).text, equals('10'));
    });
  });

  group('MathNode - PermutationNode', () {
    test('creates with default n and r', () {
      final node = PermutationNode();
      expect(node.n.length, equals(1));
      expect(node.r.length, equals(1));
    });

    test('creates with specified n and r', () {
      final node = PermutationNode(
        n: [LiteralNode(text: '5')],
        r: [LiteralNode(text: '2')],
      );
      expect((node.n[0] as LiteralNode).text, equals('5'));
      expect((node.r[0] as LiteralNode).text, equals('2'));
    });
  });

  group('MathNode - CombinationNode', () {
    test('creates with default n and r', () {
      final node = CombinationNode();
      expect(node.n.length, equals(1));
      expect(node.r.length, equals(1));
    });

    test('creates with specified n and r', () {
      final node = CombinationNode(
        n: [LiteralNode(text: '5')],
        r: [LiteralNode(text: '2')],
      );
      expect((node.n[0] as LiteralNode).text, equals('5'));
      expect((node.r[0] as LiteralNode).text, equals('2'));
    });
  });

  group('MathNode - AnsNode', () {
    test('creates with default index', () {
      final node = AnsNode();
      expect(node.index.length, equals(1));
    });

    test('creates with specified index', () {
      final node = AnsNode(index: [LiteralNode(text: '5')]);
      expect((node.index[0] as LiteralNode).text, equals('5'));
    });
  });

  group('MathNode - ComplexNode', () {
    test('creates with default content', () {
      final node = ComplexNode();
      expect(node.content.length, equals(1));
    });

    test('creates with specified content', () {
      final node = ComplexNode(content: [LiteralNode(text: 'i')]);
      expect((node.content[0] as LiteralNode).text, equals('i'));
    });
  });

  group('MathNode - ConstantNode', () {
    test('creates with specified constant', () {
      final node = ConstantNode('\u03C0');
      expect(node.constant, equals('\u03C0'));
    });
  });

  group('MathNode - NewlineNode', () {
    test('creates newline node', () {
      final node = NewlineNode();
      expect(node, isA<NewlineNode>());
    });
  });

  group('EditorCursor', () {
    test('creates with default values', () {
      const cursor = EditorCursor();
      expect(cursor.parentId, isNull);
      expect(cursor.path, isNull);
      expect(cursor.index, equals(0));
      expect(cursor.subIndex, equals(0));
    });

    test('creates with specified values', () {
      const cursor = EditorCursor(
        parentId: 'parent1',
        path: 'num',
        index: 2,
        subIndex: 5,
      );
      expect(cursor.parentId, equals('parent1'));
      expect(cursor.path, equals('num'));
      expect(cursor.index, equals(2));
      expect(cursor.subIndex, equals(5));
    });

    test('copyWith creates new cursor with updated values', () {
      const original = EditorCursor(index: 1, subIndex: 2);
      final copied = original.copyWith(subIndex: 5);

      expect(copied.index, equals(1));
      expect(copied.subIndex, equals(5));
      expect(original.subIndex, equals(2)); // Original unchanged
    });

    test('equality works correctly', () {
      const cursor1 = EditorCursor(index: 1, subIndex: 2);
      const cursor2 = EditorCursor(index: 1, subIndex: 2);
      const cursor3 = EditorCursor(index: 1, subIndex: 3);

      expect(cursor1, equals(cursor2));
      expect(cursor1, isNot(equals(cursor3)));
    });
  });

  group('EditorState - Deep Copy', () {
    test('captures and clones ConstantNode', () {
      final constant = ConstantNode('\u03BC\u2080');
      final originalNodes = [constant];
      const cursor = EditorCursor();
      final state = EditorState.capture(originalNodes, cursor);
      expect(state.expression[0], isA<ConstantNode>());
      expect((state.expression[0] as ConstantNode).constant, '\u03BC\u2080');
      expect(state.expression[0].id, isNot(constant.id));
    });

    test('captures and clones ComplexNode', () {
      final complex = ComplexNode(content: [LiteralNode(text: '5')]);
      final state = EditorState.capture([complex], const EditorCursor());
      expect(state.expression[0], isA<ComplexNode>());
      expect(state.expression[0].id, isNot(complex.id));
      expect(
        identical(
          (state.expression[0] as ComplexNode).content[0],
          complex.content[0],
        ),
        isFalse,
      );
    });
  });
}
