import 'renderer.dart';

class EditorCursor {
  final String? parentId;
  final String? path;
  final int index;
  final int subIndex;

  const EditorCursor({
    this.parentId,
    this.path,
    this.index = 0,
    this.subIndex = 0,
  });

  EditorCursor copyWith({
    String? parentId,
    String? path,
    int? index,
    int? subIndex,
  }) {
    return EditorCursor(
      parentId: parentId ?? this.parentId,
      path: path ?? this.path,
      index: index ?? this.index,
      subIndex: subIndex ?? this.subIndex,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EditorCursor &&
        other.parentId == parentId &&
        other.path == path &&
        other.index == index &&
        other.subIndex == subIndex;
  }

  @override
  int get hashCode =>
      parentId.hashCode ^ path.hashCode ^ index.hashCode ^ subIndex.hashCode;
}

/// Snapshot of editor state for undo/redo
class EditorState {
  final List<MathNode> expression;
  final EditorCursor cursor;

  EditorState({required this.expression, required this.cursor});

  /// Deep copy the expression tree
  static List<MathNode> _deepCopyNodes(List<MathNode> nodes) {
    return nodes.map((node) => _deepCopyNode(node)).toList();
  }

  static MathNode _deepCopyNode(MathNode node) {
    if (node is LiteralNode) {
      return LiteralNode(text: node.text);
    }
    if (node is FractionNode) {
      return FractionNode(
        num: _deepCopyNodes(node.numerator),
        den: _deepCopyNodes(node.denominator),
      );
    }
    if (node is ExponentNode) {
      return ExponentNode(
        base: _deepCopyNodes(node.base),
        power: _deepCopyNodes(node.power),
      );
    }
    if (node is ParenthesisNode) {
      return ParenthesisNode(content: _deepCopyNodes(node.content));
    }
    if (node is TrigNode) {
      return TrigNode(
        function: node.function,
        argument: _deepCopyNodes(node.argument),
      );
    }
    if (node is RootNode) {
      return RootNode(
        isSquareRoot: node.isSquareRoot,
        index: _deepCopyNodes(node.index),
        radicand: _deepCopyNodes(node.radicand),
      );
    }
    if (node is LogNode) {
      return LogNode(
        isNaturalLog: node.isNaturalLog,
        base: _deepCopyNodes(node.base),
        argument: _deepCopyNodes(node.argument),
      );
    }
    if (node is PermutationNode) {
      return PermutationNode(
        n: _deepCopyNodes(node.n),
        r: _deepCopyNodes(node.r),
      );
    }
    if (node is CombinationNode) {
      return CombinationNode(
        n: _deepCopyNodes(node.n),
        r: _deepCopyNodes(node.r),
      );
    }
    if (node is AnsNode) {
      return AnsNode(index: _deepCopyNodes(node.index));
    }
    if (node is ConstantNode) {
      return ConstantNode(node.constant);
    }
    if (node is ComplexNode) {
      return ComplexNode(content: _deepCopyNodes(node.content));
    }
    if (node is NewlineNode) {
      return NewlineNode();
    }
    return LiteralNode();
  }

  /// Create a snapshot from current state
  factory EditorState.capture(List<MathNode> expression, EditorCursor cursor) {
    return EditorState(
      expression: _deepCopyNodes(expression),
      cursor: cursor.copyWith(),
    );
  }
}
