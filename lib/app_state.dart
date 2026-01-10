import 'renderer.dart';
import 'package:flutter/material.dart';
import 'expression_selection.dart';

/// Represents the state of all cells for app-level undo/redo
class AppState {
  final List<List<MathNode>> expressions;
  final List<String> answers;
  final int activeIndex;

  AppState({
    required this.expressions,
    required this.answers,
    required this.activeIndex,
  });

  /// Capture current state from controllers
  static AppState capture(
    Map<int, MathEditorController> mathControllers,
    Map<int, TextEditingController> textControllers,
    int activeIndex,
  ) {
    List<int> sortedKeys = mathControllers.keys.toList()..sort();

    List<List<MathNode>> expressions = [];
    List<String> answers = [];

    for (int key in sortedKeys) {
      final mathController = mathControllers[key];
      final textController = textControllers[key];

      if (mathController != null) {
        // Deep copy the expression
        expressions.add(MathClipboard.deepCopyNodes(mathController.expression));
        answers.add(textController?.text ?? '');
      }
    }

    return AppState(
      expressions: expressions,
      answers: answers,
      activeIndex: activeIndex,
    );
  }
}
