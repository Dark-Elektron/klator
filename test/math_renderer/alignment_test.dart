import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klator/math_renderer/math_result_display.dart';
import 'package:klator/math_renderer/renderer.dart';
import 'package:klator/math_renderer/math_editor_controller.dart';

void main() {
  group('Vertical Alignment Tests', () {
    testWidgets('PermutationNode is centered in MathResultDisplay', (
      tester,
    ) async {
      final node = PermutationNode(
        n: [LiteralNode(text: 'n')],
        r: [LiteralNode(text: 'r')],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MathResultDisplay(
                nodes: [LiteralNode(text: '1'), LiteralNode(text: '+'), node],
              ),
            ),
          ),
        ),
      );

      final pFinder = find.text('P');
      expect(pFinder, findsOneWidget);

      final oneFinder = find.text('1');
      expect(oneFinder, findsOneWidget);

      final pCenter = tester.getCenter(pFinder);
      final oneCenter = tester.getCenter(oneFinder);

      expect(pCenter.dy, moreOrLessEquals(oneCenter.dy, epsilon: 1.0));
    });

    testWidgets('CombinationNode is centered in MathResultDisplay', (
      tester,
    ) async {
      final node = CombinationNode(
        n: [LiteralNode(text: 'n')],
        r: [LiteralNode(text: 'r')],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MathResultDisplay(
                nodes: [LiteralNode(text: '1'), LiteralNode(text: '+'), node],
              ),
            ),
          ),
        ),
      );

      final cFinder = find.text('C');
      expect(cFinder, findsOneWidget);

      final oneFinder = find.text('1');
      expect(oneFinder, findsOneWidget);

      final cCenter = tester.getCenter(cFinder);
      final oneCenter = tester.getCenter(oneFinder);

      expect(cCenter.dy, moreOrLessEquals(oneCenter.dy, epsilon: 1.0));
    });

    testWidgets('AnsNode is centered in MathResultDisplay', (tester) async {
      final node = AnsNode(index: [LiteralNode(text: '0')]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MathResultDisplay(
                nodes: [LiteralNode(text: '1'), LiteralNode(text: '+'), node],
              ),
            ),
          ),
        ),
      );

      final ansFinder = find.text('ans');
      expect(ansFinder, findsOneWidget);

      final oneFinder = find.text('1');
      expect(oneFinder, findsOneWidget);

      final ansCenter = tester.getCenter(ansFinder);
      final oneCenter = tester.getCenter(oneFinder);

      expect(ansCenter.dy, moreOrLessEquals(oneCenter.dy, epsilon: 1.0));
    });

    testWidgets('PermutationNode is centered in MathRenderer (Editor)', (
      tester,
    ) async {
      final node = PermutationNode(
        n: [LiteralNode(text: 'n')],
        r: [LiteralNode(text: 'r')],
      );
      final controller = MathEditorController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MathRenderer(
                expression: [
                  LiteralNode(text: '1'),
                  LiteralNode(text: '+'),
                  node,
                ],
                rootKey: GlobalKey(),
                controller: controller,
                structureVersion: 0,
                textScaler: TextScaler.noScaling,
              ),
            ),
          ),
        ),
      );

      final pFinder = find.text('P');
      expect(pFinder, findsOneWidget);

      final oneFinder = find.text('1');
      expect(oneFinder, findsOneWidget);

      final pCenter = tester.getCenter(pFinder);
      final oneCenter = tester.getCenter(oneFinder);

      expect(pCenter.dy, moreOrLessEquals(oneCenter.dy, epsilon: 1.0));
    });
  });
}
