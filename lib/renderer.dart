import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'math_expression_serializer.dart';
import 'math_engine.dart';
import 'constants.dart';
import 'package:flutter/rendering.dart';

abstract class MathNode {
  final String id;
  MathNode() : id = math.Random().nextInt(1 << 31).toString();
}

class LiteralNode extends MathNode {
  String text;
  LiteralNode({this.text = ""});
}

class FractionNode extends MathNode {
  List<MathNode> numerator;
  List<MathNode> denominator;
  FractionNode({List<MathNode>? num, List<MathNode>? den})
    : numerator = num ?? [LiteralNode()],
      denominator = den ?? [LiteralNode()];
}

class ExponentNode extends MathNode {
  List<MathNode> base;
  List<MathNode> power;
  ExponentNode({List<MathNode>? base, List<MathNode>? power})
    : base = base ?? [LiteralNode()],
      power = power ?? [LiteralNode()];
}

class LogNode extends MathNode {
  List<MathNode> base; // The subscript (n in log_n)
  List<MathNode> argument; // What we're taking log of
  bool isNaturalLog; // If true, it's ln (no base shown)

  LogNode({
    List<MathNode>? base,
    List<MathNode>? argument,
    this.isNaturalLog = false,
  }) : base = base ?? [LiteralNode(text: "10")],
       argument = argument ?? [LiteralNode()];
}

class TrigNode extends MathNode {
  final String function; // sin, cos, tan, asin, acos, atan, log, ln
  List<MathNode> argument;
  TrigNode({required this.function, List<MathNode>? argument})
    : argument = argument ?? [LiteralNode()];
}

class RootNode extends MathNode {
  List<MathNode> index; // The n in ⁿ√
  List<MathNode> radicand; // What's under the root
  final bool isSquareRoot; // If true, don't show index (it's 2)
  RootNode({
    List<MathNode>? index,
    List<MathNode>? radicand,
    this.isSquareRoot = false,
  }) : index = index ?? [LiteralNode(text: isSquareRoot ? "2" : "")],
       radicand = radicand ?? [LiteralNode()];
}

class PermutationNode extends MathNode {
  List<MathNode> n; // Top number
  List<MathNode> r; // Bottom number
  PermutationNode({List<MathNode>? n, List<MathNode>? r})
    : n = n ?? [LiteralNode()],
      r = r ?? [LiteralNode()];
}

class CombinationNode extends MathNode {
  List<MathNode> n; // Top number
  List<MathNode> r; // Bottom number
  CombinationNode({List<MathNode>? n, List<MathNode>? r})
    : n = n ?? [LiteralNode()],
      r = r ?? [LiteralNode()];
}

class NewlineNode extends MathNode {
  NewlineNode() : super();
}

class ParenthesisNode extends MathNode {
  List<MathNode> content;
  ParenthesisNode({List<MathNode>? content})
    : content = content ?? [LiteralNode()];
}

class AnsNode extends MathNode {
  List<MathNode> index; // The reference number (0, 1, 2, etc.)

  AnsNode({List<MathNode>? index}) : index = index ?? [LiteralNode()];
}

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

class NodeLayoutInfo {
  final Rect rect;
  final LiteralNode node;
  final String? parentId;
  final String? path;
  final int index;
  final double fontSize;
  final TextScaler textScaler;

  NodeLayoutInfo({
    required this.rect,
    required this.node,
    required this.parentId,
    required this.path,
    required this.index,
    required this.fontSize,
    required this.textScaler,
  });
}

class MathTextStyle {
  static const String plusSign = '\u002B';
  static const String minusSign = '\u2212';
  static const String equalsSign = '=';

  // Both possible multiplication signs (for padding detection)
  static const String multiplyDot = '\u00B7'; // · (middle dot)
  static const String multiplyTimes = '\u00D7'; // × (times sign)

  // Current user preference (dynamic)
  static String _multiplySign = '\u00D7';

  static String get multiplySign => _multiplySign;

  static void setMultiplySign(String sign) {
    _multiplySign = sign;
  }

  // Include BOTH multiplication signs - they both need padding
  static const Set<String> _allMultiplySigns = {multiplyDot, multiplyTimes};

  static const Set<String> _paddedOperators = {
    plusSign,
    minusSign,
    multiplyDot,
    multiplyTimes,
    equalsSign,
  };

  static bool _isPaddedOperator(String char) {
    return _paddedOperators.contains(char);
  }

  // Helper to check if char is any multiplication sign
  static bool _isMultiplySign(String char) {
    return _allMultiplySigns.contains(char);
  }

  static TextStyle getStyle(double fontSize) {
    return TextStyle(
      fontSize: fontSize,
      height: 1.0,
      fontFamily: FONTFAMILY,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static String toDisplayText(String text) {
    if (text.isEmpty) return text;
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      // Convert multiply sign to user preference
      String displayChar = char;
      if (_isMultiplySign(char)) {
        displayChar = _multiplySign;
      }

      if (_isPaddedOperator(char)) {
        // Don't add leading space if this is the first character
        if (i == 0) {
          buffer.write('$displayChar '); // Only trailing space
        } else {
          buffer.write(' $displayChar '); // Both spaces
        }
      } else {
        buffer.write(displayChar);
      }
    }
    return buffer.toString();
  }

  static double measureText(
    String text,
    double fontSize,
    TextScaler textScaler,
  ) {
    if (text.isEmpty) return 0.0;
    // Use toDisplayText to get consistent measurement
    final displayText = toDisplayText(text);
    final painter = TextPainter(
      text: TextSpan(text: displayText, style: getStyle(fontSize)),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// Converts a logical character index to display text index
  static int _logicalToDisplayIndex(String text, int logicalIndex) {
    int displayIndex = 0;
    final clampedIndex = logicalIndex.clamp(0, text.length);

    for (int i = 0; i < clampedIndex; i++) {
      final char = text[i];
      if (_isPaddedOperator(char)) {
        displayIndex += 3; // space + char + space
      } else {
        displayIndex += 1;
      }
    }

    return displayIndex;
  }

  static double getCursorOffset(
    String text,
    int charIndex,
    double fontSize,
    TextScaler textScaler,
  ) {
    if (text.isEmpty || charIndex <= 0) return 0.0;

    // Convert full text to display format
    final displayText = toDisplayText(text);

    // Convert logical index to display index
    final displayIndex = _logicalToDisplayIndex(
      text,
      charIndex,
    ).clamp(0, displayText.length);

    // Create painter with FULL display text (same as rendered)
    final painter = TextPainter(
      text: TextSpan(text: displayText, style: getStyle(fontSize)),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();

    // Get exact cursor position using Flutter's built-in method
    final offset = painter.getOffsetForCaret(
      TextPosition(offset: displayIndex),
      Rect.zero,
    );

    painter.dispose();
    return offset.dx;
  }

  static int getCharIndexForOffset(
    String text,
    double xOffset,
    double fontSize,
    TextScaler textScaler,
  ) {
    if (text.isEmpty) return 0;

    final displayText = toDisplayText(text);
    final painter = TextPainter(
      text: TextSpan(text: displayText, style: getStyle(fontSize)),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();

    final position = painter.getPositionForOffset(
      Offset(xOffset, fontSize / 2),
    );
    painter.dispose();

    int displayOffset = position.offset.clamp(0, displayText.length);
    return _displayToLogicalIndex(text, displayOffset);
  }

  static int _displayToLogicalIndex(String text, int displayIndex) {
    if (displayIndex <= 0) return 0;

    int displayPos = 0;

    for (int logical = 0; logical < text.length; logical++) {
      final char = text[logical];
      int charWidth;

      if (_isPaddedOperator(char)) {
        charWidth = (logical == 0) ? 2 : 3; // First char has no leading space
      } else {
        charWidth = 1;
      }

      final prevDisplayPos = displayPos;
      displayPos += charWidth;

      if (displayIndex <= displayPos) {
        if (_isPaddedOperator(char)) {
          final midpoint = prevDisplayPos + ((logical == 0) ? 1 : 2);
          if (displayIndex <= midpoint) {
            return logical;
          } else {
            return logical + 1;
          }
        }
        return logical + 1;
      }
    }

    return text.length;
  }

  // In MathTextStyle class
  static int logicalToDisplayIndex(String text, int logicalIndex) {
    if (text.isEmpty || logicalIndex <= 0) return 0;

    int displayIndex = 0;
    final clampedIndex = logicalIndex.clamp(0, text.length);

    for (int i = 0; i < clampedIndex; i++) {
      final char = text[i];
      if (_isPaddedOperator(char)) {
        if (i == 0) {
          displayIndex += 2; // char + trailing space (no leading space)
        } else {
          displayIndex += 3; // leading space + char + trailing space
        }
      } else {
        displayIndex += 1;
      }
    }

    return displayIndex;
  }
}

class _ParentListInfo {
  final List<MathNode> list;
  final int index;
  final String? parentId;
  final String? path;
  _ParentListInfo(this.list, this.index, this.parentId, this.path);
}

class _MultiplicationChainResult {
  final List<MathNode> nodes;
  final int removeFromIndex;
  final String? prefixToKeep;
  final int? prefixNodeIndex;

  _MultiplicationChainResult({
    required this.nodes,
    required this.removeFromIndex,
    this.prefixToKeep,
    this.prefixNodeIndex,
  });
}

class MathEditorController extends ChangeNotifier {
  List<MathNode> expression = [LiteralNode()];
  EditorCursor cursor = const EditorCursor();
  final Map<String, NodeLayoutInfo> _layoutRegistry = {};
  String? result = '';
  String expr = '';
  int _structureVersion = 0;
  int get structureVersion => _structureVersion;
  VoidCallback? onResultChanged;

  // ============== UNDO/REDO ==============
  final List<EditorState> _undoStack = [];
  final List<EditorState> _redoStack = [];
  static const int _maxHistorySize = 50;
  bool _isUndoRedoOperation = false;

  /// Check if undo is available
  bool get canUndo => _undoStack.isNotEmpty;

  /// Check if redo is available
  bool get canRedo => _redoStack.isNotEmpty;

  // Add this method to refresh display when settings change
  void refreshDisplay() {
    _structureVersion++;
    notifyListeners();
  }

  /// Save current state before making changes
  void saveStateForUndo() {
    if (_isUndoRedoOperation) return;

    _undoStack.add(EditorState.capture(expression, cursor));

    // Limit stack size
    if (_undoStack.length > _maxHistorySize) {
      _undoStack.removeAt(0);
    }

    // Clear redo stack when new action is performed
    _redoStack.clear();
  }

  /// Undo the last action
  void undo() {
    if (!canUndo) return;

    _isUndoRedoOperation = true;

    // Save current state to redo stack
    _redoStack.add(EditorState.capture(expression, cursor));

    // Restore previous state
    EditorState previousState = _undoStack.removeLast();
    expression = previousState.expression;
    cursor = previousState.cursor;
    _structureVersion++;

    _isUndoRedoOperation = false;

    notifyListeners();
    onResultChanged?.call();
  }

  /// Redo the last undone action
  void redo() {
    if (!canRedo) return;

    _isUndoRedoOperation = true;

    // Save current state to undo stack
    _undoStack.add(EditorState.capture(expression, cursor));

    // Restore redo state
    EditorState redoState = _redoStack.removeLast();
    expression = redoState.expression;
    cursor = redoState.cursor;
    _structureVersion++;

    _isUndoRedoOperation = false;

    notifyListeners();
    onResultChanged?.call();
  }

  /// Clear undo/redo history
  void clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
  }

  static String _mapToDisplayChar(String char) {
    switch (char) {
      case '+':
        return MathTextStyle.plusSign;
      case '-':
        return MathTextStyle.minusSign;
      case '*':
        return MathTextStyle.multiplySign; // Uses current setting
      default:
        return char;
    }
  }

  // Update _isWordBoundary to check for BOTH multiplication signs
  static bool _isWordBoundary(String char) {
    return char == '+' ||
        char == '-' ||
        char == '*' ||
        char == '/' ||
        char == '=' ||
        char == ' ' ||
        char == MathTextStyle.plusSign ||
        char == MathTextStyle.minusSign ||
        char == MathTextStyle.multiplyDot || // Check both
        char == MathTextStyle.multiplyTimes; // Check both
  }

  static bool _isNonMultiplyWordBoundary(String char) {
    return char == '+' ||
        char == '-' ||
        char == '/' ||
        char == '=' ||
        char == ' ' ||
        char == MathTextStyle.plusSign ||
        char == MathTextStyle.minusSign;
  }

  void clearLayoutRegistry() => _layoutRegistry.clear();
  void registerNodeLayout(NodeLayoutInfo info) =>
      _layoutRegistry[info.node.id] = info;

  static bool _isSerializedDigit(String char) {
    return char.isNotEmpty && '0123456789.'.contains(char);
  }

  void _notifyStructureChanged() {
    _structureVersion++;
    notifyListeners();
  }

  void setCursor(EditorCursor c) {
    cursor = c;
    notifyListeners();
  }

  void tapAt(Offset localPos) {
    if (_layoutRegistry.isEmpty) return;
    double minLeft = double.infinity, maxRight = double.negativeInfinity;
    NodeLayoutInfo? leftmostNode, rightmostNode;

    for (final info in _layoutRegistry.values) {
      if (info.rect.left < minLeft) {
        minLeft = info.rect.left;
        leftmostNode = info;
      }
      if (info.rect.right > maxRight) {
        maxRight = info.rect.right;
        rightmostNode = info;
      }
    }

    if (localPos.dx < minLeft && leftmostNode != null) {
      final firstRootNode = _findFirstRootLiteralNode();
      cursor = EditorCursor(
        parentId: firstRootNode?.parentId ?? leftmostNode.parentId,
        path: firstRootNode?.path ?? leftmostNode.path,
        index: firstRootNode?.index ?? leftmostNode.index,
        subIndex: 0,
      );
      notifyListeners();
      return;
    }

    if (localPos.dx > maxRight && rightmostNode != null) {
      final lastRootNode = _findLastRootLiteralNode();
      cursor = EditorCursor(
        parentId: lastRootNode?.parentId ?? rightmostNode.parentId,
        path: lastRootNode?.path ?? rightmostNode.path,
        index: lastRootNode?.index ?? rightmostNode.index,
        subIndex:
            lastRootNode?.node.text.length ?? rightmostNode.node.text.length,
      );
      notifyListeners();
      return;
    }

    NodeLayoutInfo? closest;
    double minDistance = double.infinity;

    for (final info in _layoutRegistry.values) {
      double dx = 0, dy = 0;
      if (localPos.dx < info.rect.left) {
        dx = info.rect.left - localPos.dx;
      } else if (localPos.dx > info.rect.right)
        dx = localPos.dx - info.rect.right;
      if (localPos.dy < info.rect.top) {
        dy = info.rect.top - localPos.dy;
      } else if (localPos.dy > info.rect.bottom)
        dy = localPos.dy - info.rect.bottom;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance < minDistance) {
        minDistance = distance;
        closest = info;
      }
    }

    if (closest != null) _setCursorInNodeAtOffset(closest, localPos.dx);
  }

  NodeLayoutInfo? _findFirstRootLiteralNode() {
    NodeLayoutInfo? first;
    int minIndex = 999999;
    for (final info in _layoutRegistry.values) {
      if (info.parentId == null && info.index < minIndex) {
        minIndex = info.index;
        first = info;
      }
    }
    return first;
  }

  NodeLayoutInfo? _findLastRootLiteralNode() {
    NodeLayoutInfo? last;
    int maxIndex = -1;
    for (final info in _layoutRegistry.values) {
      if (info.parentId == null && info.index > maxIndex) {
        maxIndex = info.index;
        last = info;
      }
    }
    return last;
  }

  void _setCursorInNodeAtOffset(NodeLayoutInfo info, double globalX) {
    final text = info.node.text;
    final relativeX = globalX - info.rect.left;
    int newSubIndex =
        text.isNotEmpty
            ? MathTextStyle.getCharIndexForOffset(
              text,
              relativeX,
              info.fontSize,
              info.textScaler,
            )
            : 0;
    cursor = EditorCursor(
      parentId: info.parentId,
      path: info.path,
      index: info.index,
      subIndex: newSubIndex,
    );
    notifyListeners();
  }

  void insertCharacter(String char) {
    saveStateForUndo();
    if (char == '/') {
      _wrapIntoFraction();
      return;
    }

    if (char == '^') {
      _wrapIntoExponent();
      return;
    }

    if (char == '(' || char == '()') {
      _insertParenthesis();
      return;
    }

    if (char == ')') {
      _exitParenthesis();
      return;
    }

    if (char == 'ans') {
      insertAns();
      return;
    }

    // === NEW: Exit container nodes when typing operators ===
    if (_isOperator(char)) {
      _exitContainerIfNeeded();
    }
    // === END NEW ===

    final displayChar = _mapToDisplayChar(char);
    _updateLiteralAtCursor((node) {
      node.text =
          node.text.substring(0, cursor.subIndex) +
          displayChar +
          node.text.substring(cursor.subIndex);
      cursor = cursor.copyWith(subIndex: cursor.subIndex + 1);
    });
    _notifyStructureChanged();

    onCalculate();

    // DEBUG: Print structure after each character
    // debugPrintExpression();
  }

  /// Set expression from loaded data
  void setExpression(List<MathNode> nodes) {
    expression = nodes.isNotEmpty ? nodes : [LiteralNode()];
    _structureVersion++;
    // Position cursor at end of root expression
    int lastIndex = expression.length - 1;
    MathNode lastNode = expression[lastIndex];

    int subIndex = 0;
    if (lastNode is LiteralNode) {
      subIndex = lastNode.text.length;
    }

    cursor = EditorCursor(
      parentId: null,
      path: null,
      index: lastIndex,
      subIndex: subIndex,
    );
    notifyListeners();
  }

  // === NEW HELPER METHODS ===

  bool _isOperator(String char) {
    return char == '+' ||
        char == '-' ||
        char == '*' ||
        char == '=' ||
        char == MathTextStyle.plusSign ||
        char == MathTextStyle.minusSign ||
        char == MathTextStyle.multiplySign;
  }

  void _exitContainerIfNeeded() {
    // Keep exiting until we're at root or in a "content" container like ParenthesisNode
    while (cursor.parentId != null) {
      final parent = _findNode(expression, cursor.parentId!);

      // Stay inside parentheses - operators are valid there
      if (parent is ParenthesisNode) {
        break;
      }

      // If parent not found, break
      if (parent == null) break;

      // Stay inside fraction numerator/denominator - operators are valid there
      if (parent is FractionNode) {
        break;
      }

      // Exit AnsNode, TrigNode, RootNode, LogNode, etc.
      if (parent
          is AnsNode //||
      // parent is TrigNode ||
      // parent is RootNode ||
      // parent is LogNode ||
      // parent is PermutationNode ||
      // parent is CombinationNode ||
      // parent is ExponentNode
      ) {
        _moveCursorAfterNode(parent.id);
        continue;
      }

      break;
    }
  }

  void _moveCursorAfterNode(String nodeId) {
    _findAndPositionAfter(expression, nodeId, null, null);
    notifyListeners();
  }

  // ============== TRIG FUNCTIONS ==============
  void insertSquare() {
    saveStateForUndo();

    final siblings = _resolveSiblingList();
    final current = _resolveCursorNode();
    if (current is! LiteralNode) return;

    final String currentId = current.id;
    String text = current.text;
    int cursorClick = cursor.subIndex;

    // Find the operand before cursor (number or variable to square)
    int operandStart = cursorClick;
    while (operandStart > 0 && !_isWordBoundary(text[operandStart - 1])) {
      operandStart--;
    }

    String baseText = text.substring(operandStart, cursorClick);
    int actualIndex = siblings.indexWhere((n) => n.id == currentId);

    // Handle case where base is a previous node (like a fraction or parenthesis)
    if (baseText.isEmpty && operandStart == 0 && actualIndex > 0) {
      final chainResult = _collectMultiplicationChain(
        siblings,
        actualIndex - 1,
      );
      if (chainResult.nodes.isNotEmpty) {
        if (chainResult.prefixToKeep != null &&
            chainResult.prefixNodeIndex != null) {
          (siblings[chainResult.prefixNodeIndex!] as LiteralNode).text =
              chainResult.prefixToKeep!;
        }
        int removeStart =
            chainResult.prefixNodeIndex != null
                ? chainResult.prefixNodeIndex! + 1
                : chainResult.removeFromIndex;
        int removeEnd = actualIndex - 1;
        for (int j = removeEnd; j >= removeStart; j--) {
          siblings.removeAt(j);
        }
        int newCurrentIndex = removeStart;
        current.text = text.substring(cursorClick);

        // Create exponent with power = 2
        final exp = ExponentNode(
          base: chainResult.nodes,
          power: [LiteralNode(text: "2")],
        );
        siblings.insert(newCurrentIndex, exp);

        // Move cursor after the exponent
        cursor = EditorCursor(
          parentId: cursor.parentId,
          path: cursor.path,
          index: newCurrentIndex + 1,
          subIndex: 0,
        );
        _notifyStructureChanged();
        onCalculate();
        return;
      }
    }

    current.text = text.substring(0, operandStart);

    // Create exponent with power = 2
    final exp = ExponentNode(
      base: [LiteralNode(text: baseText)],
      power: [LiteralNode(text: "2")],
    );
    final tail = LiteralNode(text: text.substring(cursorClick));

    if (actualIndex >= 0) {
      siblings.insert(actualIndex + 1, exp);
      siblings.insert(actualIndex + 2, tail);

      // Move cursor after the exponent (not inside power)
      cursor = EditorCursor(
        parentId: cursor.parentId,
        path: cursor.path,
        index: actualIndex + 2,
        subIndex: 0,
      );
    }
    _notifyStructureChanged();
    onCalculate();
  }

  void insertTrig(String function) {
    saveStateForUndo();

    final siblings = _resolveSiblingList();
    final current = _resolveCursorNode();
    if (current is! LiteralNode) return;

    final String currentId = current.id;
    String text = current.text;
    int cursorPos = cursor.subIndex;
    int actualIndex = siblings.indexWhere((n) => n.id == currentId);

    String before = text.substring(0, cursorPos);
    String after = text.substring(cursorPos);

    current.text = before;

    final trig = TrigNode(
      function: function,
      argument: [LiteralNode(text: "")],
    );
    final tail = LiteralNode(text: after);

    if (actualIndex >= 0) {
      siblings.insert(actualIndex + 1, trig);
      siblings.insert(actualIndex + 2, tail);
      cursor = EditorCursor(
        parentId: trig.id,
        path: 'arg',
        index: 0,
        subIndex: 0,
      );
    }
    _notifyStructureChanged();
  }

  // ============== ROOT FUNCTIONS ==============

  void insertSquareRoot() {
    saveStateForUndo();

    final siblings = _resolveSiblingList();
    final current = _resolveCursorNode();
    if (current is! LiteralNode) return;

    final String currentId = current.id;
    String text = current.text;
    int cursorPos = cursor.subIndex;
    int actualIndex = siblings.indexWhere((n) => n.id == currentId);

    String before = text.substring(0, cursorPos);
    String after = text.substring(cursorPos);

    current.text = before;

    final root = RootNode(
      isSquareRoot: true,
      index: [LiteralNode(text: "2")],
      radicand: [LiteralNode(text: "")],
    );
    final tail = LiteralNode(text: after);

    if (actualIndex >= 0) {
      siblings.insert(actualIndex + 1, root);
      siblings.insert(actualIndex + 2, tail);
      cursor = EditorCursor(
        parentId: root.id,
        path: 'radicand',
        index: 0,
        subIndex: 0,
      );
    }
    _notifyStructureChanged();
  }

  void insertNthRoot() {
    saveStateForUndo();
    final siblings = _resolveSiblingList();
    final current = _resolveCursorNode();
    if (current is! LiteralNode) return;

    final String currentId = current.id;
    String text = current.text;
    int cursorPos = cursor.subIndex;
    int actualIndex = siblings.indexWhere((n) => n.id == currentId);

    String before = text.substring(0, cursorPos);
    String after = text.substring(cursorPos);

    current.text = before;

    final root = RootNode(
      isSquareRoot: false,
      index: [LiteralNode(text: "")],
      radicand: [LiteralNode(text: "")],
    );
    final tail = LiteralNode(text: after);

    if (actualIndex >= 0) {
      siblings.insert(actualIndex + 1, root);
      siblings.insert(actualIndex + 2, tail);
      // Start in the index field so user can type the root degree
      cursor = EditorCursor(
        parentId: root.id,
        path: 'index',
        index: 0,
        subIndex: 0,
      );
    }
    _notifyStructureChanged();
  }

  void insertLog10() {
    saveStateForUndo();
    final siblings = _resolveSiblingList();
    final current = _resolveCursorNode();
    if (current is! LiteralNode) return;

    final String currentId = current.id;
    String text = current.text;
    int cursorPos = cursor.subIndex;
    int actualIndex = siblings.indexWhere((n) => n.id == currentId);

    String before = text.substring(0, cursorPos);
    String after = text.substring(cursorPos);

    current.text = before;

    final log = LogNode(
      base: [LiteralNode(text: "10")], // Fixed base 10
      argument: [LiteralNode(text: "")],
      isNaturalLog: false,
    );
    final tail = LiteralNode(text: after);

    if (actualIndex >= 0) {
      siblings.insert(actualIndex + 1, log);
      siblings.insert(actualIndex + 2, tail);
      // Cursor goes to argument, not base
      cursor = EditorCursor(
        parentId: log.id,
        path: 'arg', // <-- Start in argument
        index: 0,
        subIndex: 0,
      );
    }
    _notifyStructureChanged();
  }

  void insertLogN() {
    saveStateForUndo();
    final siblings = _resolveSiblingList();
    final current = _resolveCursorNode();
    if (current is! LiteralNode) return;

    final String currentId = current.id;
    String text = current.text;
    int cursorPos = cursor.subIndex;
    int actualIndex = siblings.indexWhere((n) => n.id == currentId);

    String before = text.substring(0, cursorPos);
    String after = text.substring(cursorPos);

    current.text = before;

    final log = LogNode(
      base: [LiteralNode(text: "")], // Empty base for user to fill
      argument: [LiteralNode(text: "")],
      isNaturalLog: false,
    );
    final tail = LiteralNode(text: after);

    if (actualIndex >= 0) {
      siblings.insert(actualIndex + 1, log);
      siblings.insert(actualIndex + 2, tail);
      // Cursor goes to base first
      cursor = EditorCursor(
        parentId: log.id,
        path: 'base', // <-- Start in base
        index: 0,
        subIndex: 0,
      );
    }
    _notifyStructureChanged();
  }

  void insertNaturalLog() {
    saveStateForUndo();
    final siblings = _resolveSiblingList();
    final current = _resolveCursorNode();
    if (current is! LiteralNode) return;

    final String currentId = current.id;
    String text = current.text;
    int cursorPos = cursor.subIndex;
    int actualIndex = siblings.indexWhere((n) => n.id == currentId);

    String before = text.substring(0, cursorPos);
    String after = text.substring(cursorPos);

    current.text = before;

    final log = LogNode(argument: [LiteralNode(text: "")], isNaturalLog: true);
    final tail = LiteralNode(text: after);

    if (actualIndex >= 0) {
      siblings.insert(actualIndex + 1, log);
      siblings.insert(actualIndex + 2, tail);
      // Go directly to argument
      cursor = EditorCursor(
        parentId: log.id,
        path: 'arg',
        index: 0,
        subIndex: 0,
      );
    }
    _notifyStructureChanged();
  }

  void insertAns() {
    saveStateForUndo();
    final siblings = _resolveSiblingList();
    final current = _resolveCursorNode();
    if (current is! LiteralNode) return;

    final String currentId = current.id;
    String text = current.text;
    int cursorPos = cursor.subIndex;
    int actualIndex = siblings.indexWhere((n) => n.id == currentId);

    String before = text.substring(0, cursorPos);
    String after = text.substring(cursorPos);

    current.text = before;

    final ans = AnsNode(index: [LiteralNode(text: "")]);
    final tail = LiteralNode(text: after);

    if (actualIndex >= 0) {
      siblings.insert(actualIndex + 1, ans);
      siblings.insert(actualIndex + 2, tail);
      // Move cursor to index field so user can type the reference number
      cursor = EditorCursor(
        parentId: ans.id,
        path: 'index',
        index: 0,
        subIndex: 0,
      );
    }
    _notifyStructureChanged();
  }

  // ============== PERMUTATION & COMBINATION ==============

  void insertPermutation() {
    saveStateForUndo();

    // Check if we're inside a container that should be wrapped entirely
    if (cursor.parentId != null) {
      final parent = _findNode(expression, cursor.parentId!);

      // If inside a parenthesis, wrap the entire parenthesis as n
      if (parent is ParenthesisNode) {
        _wrapParenthesisNodeIntoPermutation(parent);
        return;
      }
    }

    // Check if previous node is a parenthesis or complex node
    final siblings = _resolveSiblingList();
    final current = _resolveCursorNode();
    if (current is! LiteralNode) return;

    final String currentId = current.id;
    String text = current.text;
    int cursorPos = cursor.subIndex;
    int actualIndex = siblings.indexWhere((n) => n.id == currentId);

    // If cursor is at start of literal and previous node exists
    if (cursorPos == 0 && actualIndex > 0) {
      final prevNode = siblings[actualIndex - 1];

      // If previous node is a ParenthesisNode, wrap it
      if (prevNode is ParenthesisNode) {
        _wrapPreviousNodeIntoPermutation(
          prevNode,
          actualIndex,
          siblings,
          current,
        );
        return;
      }

      // If previous node is another complex node (fraction, trig, etc.)
      if (prevNode is FractionNode ||
          prevNode is TrigNode ||
          prevNode is RootNode ||
          prevNode is LogNode ||
          prevNode is ExponentNode ||
          prevNode is AnsNode) {
        _wrapPreviousNodeIntoPermutation(
          prevNode,
          actualIndex,
          siblings,
          current,
        );
        return;
      }
    }

    // Check if there's a number before cursor to use as n
    int operandStart = cursorPos;
    while (operandStart > 0 && _isSerializedDigit(text[operandStart - 1])) {
      operandStart--;
    }

    String nText = text.substring(operandStart, cursorPos);
    String before = text.substring(0, operandStart);
    String after = text.substring(cursorPos);

    // If no number but there's a previous complex node
    if (nText.isEmpty && operandStart == 0 && actualIndex > 0) {
      final chainResult = _collectMultiplicationChain(
        siblings,
        actualIndex - 1,
      );
      if (chainResult.nodes.isNotEmpty) {
        if (chainResult.prefixToKeep != null &&
            chainResult.prefixNodeIndex != null) {
          (siblings[chainResult.prefixNodeIndex!] as LiteralNode).text =
              chainResult.prefixToKeep!;
        }

        int removeStart =
            chainResult.prefixNodeIndex != null
                ? chainResult.prefixNodeIndex! + 1
                : chainResult.removeFromIndex;
        int removeEnd = actualIndex - 1;

        for (int j = removeEnd; j >= removeStart; j--) {
          siblings.removeAt(j);
        }

        int newCurrentIndex = removeStart;
        current.text = after;

        final perm = PermutationNode(
          n: chainResult.nodes,
          r: [LiteralNode(text: "")],
        );
        siblings.insert(newCurrentIndex, perm);

        cursor = EditorCursor(
          parentId: perm.id,
          path: 'r',
          index: 0,
          subIndex: 0,
        );
        _notifyStructureChanged();
        return;
      }
    }

    current.text = before;

    final perm = PermutationNode(
      n: [LiteralNode(text: nText)],
      r: [LiteralNode(text: "")],
    );
    final tail = LiteralNode(text: after);

    if (actualIndex >= 0) {
      siblings.insert(actualIndex + 1, perm);
      siblings.insert(actualIndex + 2, tail);

      cursor = EditorCursor(
        parentId: perm.id,
        path: nText.isEmpty ? 'n' : 'r',
        index: 0,
        subIndex: 0,
      );
    }
    _notifyStructureChanged();
  }

  /// Wraps a previous node (parenthesis, fraction, etc.) into permutation's n field
  void _wrapPreviousNodeIntoPermutation(
    MathNode prevNode,
    int currentIndex,
    List<MathNode> siblings,
    LiteralNode currentLiteral,
  ) {
    String afterText = currentLiteral.text;

    // Remove the current literal and previous node
    siblings.removeAt(currentIndex); // Remove current literal
    siblings.removeAt(currentIndex - 1); // Remove previous node

    // Collect any chain before the previous node
    List<MathNode> nNodes = [];
    int insertIndex = currentIndex - 1;

    if (currentIndex - 2 >= 0) {
      final beforePrev = siblings[currentIndex - 2];
      if (beforePrev is LiteralNode &&
          (beforePrev.text.endsWith(MathTextStyle.multiplySign) ||
              (beforePrev.text.isNotEmpty &&
                  _isDigitOrLetter(
                    beforePrev.text[beforePrev.text.length - 1],
                  )))) {
        final chainResult = _collectMultiplicationChain(
          siblings,
          currentIndex - 2,
        );
        if (chainResult.nodes.isNotEmpty) {
          if (chainResult.prefixToKeep != null &&
              chainResult.prefixNodeIndex != null) {
            (siblings[chainResult.prefixNodeIndex!] as LiteralNode).text =
                chainResult.prefixToKeep!;
          }
          insertIndex =
              chainResult.prefixNodeIndex != null
                  ? chainResult.prefixNodeIndex! + 1
                  : chainResult.removeFromIndex;

          // Remove chain nodes
          for (int j = currentIndex - 2; j >= insertIndex; j--) {
            siblings.removeAt(j);
          }

          nNodes.addAll(chainResult.nodes);
        }
      }
    }

    nNodes.add(prevNode);

    final perm = PermutationNode(n: nNodes, r: [LiteralNode(text: "")]);
    final tail = LiteralNode(text: afterText);

    siblings.insert(insertIndex, perm);
    siblings.insert(insertIndex + 1, tail);

    cursor = EditorCursor(parentId: perm.id, path: 'r', index: 0, subIndex: 0);
    _notifyStructureChanged();
  }

  /// Wraps a ParenthesisNode (when cursor is inside) into permutation's n field
  void _wrapParenthesisNodeIntoPermutation(ParenthesisNode paren) {
    final parentInfo = _findParentListOf(paren.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final parenIndex = parentInfo.index;

    // Get text after parenthesis
    String afterText = '';
    if (parenIndex + 1 < parentList.length &&
        parentList[parenIndex + 1] is LiteralNode) {
      afterText = (parentList[parenIndex + 1] as LiteralNode).text;
      parentList.removeAt(parenIndex + 1);
    }

    // Collect multiplication chain before parenthesis
    List<MathNode> nNodes = [];
    int removeStartIndex = parenIndex;

    if (parenIndex > 0) {
      final prevNode = parentList[parenIndex - 1];
      if (prevNode is LiteralNode &&
          (prevNode.text.endsWith(MathTextStyle.multiplySign) ||
              (prevNode.text.isNotEmpty &&
                  _isDigitOrLetter(prevNode.text[prevNode.text.length - 1])))) {
        final chainResult = _collectMultiplicationChain(
          parentList,
          parenIndex - 1,
        );
        if (chainResult.nodes.isNotEmpty) {
          if (chainResult.prefixToKeep != null &&
              chainResult.prefixNodeIndex != null) {
            (parentList[chainResult.prefixNodeIndex!] as LiteralNode).text =
                chainResult.prefixToKeep!;
          }
          removeStartIndex =
              chainResult.prefixNodeIndex != null
                  ? chainResult.prefixNodeIndex! + 1
                  : chainResult.removeFromIndex;
          nNodes.addAll(chainResult.nodes);
        }
      }
    }

    nNodes.add(paren);

    // Remove collected nodes
    for (int j = parenIndex; j >= removeStartIndex; j--) {
      parentList.removeAt(j);
    }

    final perm = PermutationNode(n: nNodes, r: [LiteralNode(text: "")]);
    final tail = LiteralNode(text: afterText);

    parentList.insert(removeStartIndex, perm);
    parentList.insert(removeStartIndex + 1, tail);

    cursor = EditorCursor(parentId: perm.id, path: 'r', index: 0, subIndex: 0);
    _notifyStructureChanged();
  }

  void insertCombination() {
    saveStateForUndo();

    // Check if we're inside a container that should be wrapped entirely
    if (cursor.parentId != null) {
      final parent = _findNode(expression, cursor.parentId!);

      if (parent is ParenthesisNode) {
        _wrapParenthesisNodeIntoCombination(parent);
        return;
      }
    }

    // Check if previous node is a parenthesis or complex node
    final siblings = _resolveSiblingList();
    final current = _resolveCursorNode();
    if (current is! LiteralNode) return;

    final String currentId = current.id;
    String text = current.text;
    int cursorPos = cursor.subIndex;
    int actualIndex = siblings.indexWhere((n) => n.id == currentId);

    // If cursor is at start of literal and previous node exists
    if (cursorPos == 0 && actualIndex > 0) {
      final prevNode = siblings[actualIndex - 1];

      if (prevNode is ParenthesisNode ||
          prevNode is FractionNode ||
          prevNode is TrigNode ||
          prevNode is RootNode ||
          prevNode is LogNode ||
          prevNode is ExponentNode ||
          prevNode is AnsNode) {
        _wrapPreviousNodeIntoCombination(
          prevNode,
          actualIndex,
          siblings,
          current,
        );
        return;
      }
    }

    // Check if there's a number before cursor to use as n
    int operandStart = cursorPos;
    while (operandStart > 0 && _isSerializedDigit(text[operandStart - 1])) {
      operandStart--;
    }

    String nText = text.substring(operandStart, cursorPos);
    String before = text.substring(0, operandStart);
    String after = text.substring(cursorPos);

    if (nText.isEmpty && operandStart == 0 && actualIndex > 0) {
      final chainResult = _collectMultiplicationChain(
        siblings,
        actualIndex - 1,
      );
      if (chainResult.nodes.isNotEmpty) {
        if (chainResult.prefixToKeep != null &&
            chainResult.prefixNodeIndex != null) {
          (siblings[chainResult.prefixNodeIndex!] as LiteralNode).text =
              chainResult.prefixToKeep!;
        }

        int removeStart =
            chainResult.prefixNodeIndex != null
                ? chainResult.prefixNodeIndex! + 1
                : chainResult.removeFromIndex;
        int removeEnd = actualIndex - 1;

        for (int j = removeEnd; j >= removeStart; j--) {
          siblings.removeAt(j);
        }

        int newCurrentIndex = removeStart;
        current.text = after;

        final comb = CombinationNode(
          n: chainResult.nodes,
          r: [LiteralNode(text: "")],
        );
        siblings.insert(newCurrentIndex, comb);

        cursor = EditorCursor(
          parentId: comb.id,
          path: 'r',
          index: 0,
          subIndex: 0,
        );
        _notifyStructureChanged();
        return;
      }
    }

    current.text = before;

    final comb = CombinationNode(
      n: [LiteralNode(text: nText)],
      r: [LiteralNode(text: "")],
    );
    final tail = LiteralNode(text: after);

    if (actualIndex >= 0) {
      siblings.insert(actualIndex + 1, comb);
      siblings.insert(actualIndex + 2, tail);

      cursor = EditorCursor(
        parentId: comb.id,
        path: nText.isEmpty ? 'n' : 'r',
        index: 0,
        subIndex: 0,
      );
    }
    _notifyStructureChanged();
  }

  void _wrapPreviousNodeIntoCombination(
    MathNode prevNode,
    int currentIndex,
    List<MathNode> siblings,
    LiteralNode currentLiteral,
  ) {
    String afterText = currentLiteral.text;

    siblings.removeAt(currentIndex);
    siblings.removeAt(currentIndex - 1);

    List<MathNode> nNodes = [];
    int insertIndex = currentIndex - 1;

    if (currentIndex - 2 >= 0) {
      final beforePrev = siblings[currentIndex - 2];
      if (beforePrev is LiteralNode &&
          (beforePrev.text.endsWith(MathTextStyle.multiplySign) ||
              (beforePrev.text.isNotEmpty &&
                  _isDigitOrLetter(
                    beforePrev.text[beforePrev.text.length - 1],
                  )))) {
        final chainResult = _collectMultiplicationChain(
          siblings,
          currentIndex - 2,
        );
        if (chainResult.nodes.isNotEmpty) {
          if (chainResult.prefixToKeep != null &&
              chainResult.prefixNodeIndex != null) {
            (siblings[chainResult.prefixNodeIndex!] as LiteralNode).text =
                chainResult.prefixToKeep!;
          }
          insertIndex =
              chainResult.prefixNodeIndex != null
                  ? chainResult.prefixNodeIndex! + 1
                  : chainResult.removeFromIndex;

          for (int j = currentIndex - 2; j >= insertIndex; j--) {
            siblings.removeAt(j);
          }

          nNodes.addAll(chainResult.nodes);
        }
      }
    }

    nNodes.add(prevNode);

    final comb = CombinationNode(n: nNodes, r: [LiteralNode(text: "")]);
    final tail = LiteralNode(text: afterText);

    siblings.insert(insertIndex, comb);
    siblings.insert(insertIndex + 1, tail);

    cursor = EditorCursor(parentId: comb.id, path: 'r', index: 0, subIndex: 0);
    _notifyStructureChanged();
  }

  void _wrapParenthesisNodeIntoCombination(ParenthesisNode paren) {
    final parentInfo = _findParentListOf(paren.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final parenIndex = parentInfo.index;

    String afterText = '';
    if (parenIndex + 1 < parentList.length &&
        parentList[parenIndex + 1] is LiteralNode) {
      afterText = (parentList[parenIndex + 1] as LiteralNode).text;
      parentList.removeAt(parenIndex + 1);
    }

    List<MathNode> nNodes = [];
    int removeStartIndex = parenIndex;

    if (parenIndex > 0) {
      final prevNode = parentList[parenIndex - 1];
      if (prevNode is LiteralNode &&
          (prevNode.text.endsWith(MathTextStyle.multiplySign) ||
              (prevNode.text.isNotEmpty &&
                  _isDigitOrLetter(prevNode.text[prevNode.text.length - 1])))) {
        final chainResult = _collectMultiplicationChain(
          parentList,
          parenIndex - 1,
        );
        if (chainResult.nodes.isNotEmpty) {
          if (chainResult.prefixToKeep != null &&
              chainResult.prefixNodeIndex != null) {
            (parentList[chainResult.prefixNodeIndex!] as LiteralNode).text =
                chainResult.prefixToKeep!;
          }
          removeStartIndex =
              chainResult.prefixNodeIndex != null
                  ? chainResult.prefixNodeIndex! + 1
                  : chainResult.removeFromIndex;
          nNodes.addAll(chainResult.nodes);
        }
      }
    }

    nNodes.add(paren);

    for (int j = parenIndex; j >= removeStartIndex; j--) {
      parentList.removeAt(j);
    }

    final comb = CombinationNode(n: nNodes, r: [LiteralNode(text: "")]);
    final tail = LiteralNode(text: afterText);

    parentList.insert(removeStartIndex, comb);
    parentList.insert(removeStartIndex + 1, tail);

    cursor = EditorCursor(parentId: comb.id, path: 'r', index: 0, subIndex: 0);
    _notifyStructureChanged();
  }

  void insertNewline() {
    saveStateForUndo();
    final siblings = _resolveSiblingList();
    final current = _resolveCursorNode();
    if (current is! LiteralNode) return;

    final String currentId = current.id;
    String text = current.text;
    int cursorPos = cursor.subIndex;
    int actualIndex = siblings.indexWhere((n) => n.id == currentId);

    String before = text.substring(0, cursorPos);
    String after = text.substring(cursorPos);

    current.text = before;

    final newline = NewlineNode();
    final tail = LiteralNode(text: after);

    if (actualIndex >= 0) {
      siblings.insert(actualIndex + 1, newline);
      siblings.insert(actualIndex + 2, tail);
      cursor = EditorCursor(
        parentId: cursor.parentId,
        path: cursor.path,
        index: actualIndex + 2,
        subIndex: 0,
      );
    }
    _notifyStructureChanged();
    onCalculate();
  }

  // function to calculate the input operation
  void onCalculate({Map<int, String>? ansValues}) {
    // Get expression from the math editor
    expr = MathExpressionSerializer.serialize(expression);
    // Solve it
    result = MathSolverNew.solve(expr, ansValues: ansValues) ?? '';
    // Notify that result changed (for cascading updates)
    onResultChanged?.call();

    // if (result != null) {
    //   print(result);
    // } else {
    //   print("Could not solve");
    // }
  }

  void updateAnswer(TextEditingController? textDisplayController) {
    if (textDisplayController != null) {
      textDisplayController.text = result ?? '';
    }
  }

  void _updateLiteralAtCursor(void Function(LiteralNode) edit) {
    final node = _resolveCursorNode();
    if (node is LiteralNode) edit(node);
  }

  MathNode? _resolveCursorNode() {
    final list = _resolveSiblingList();
    return cursor.index < list.length ? list[cursor.index] : null;
  }

  List<MathNode> _resolveSiblingList() {
    if (cursor.parentId == null) return expression;
    final parent = _findNode(expression, cursor.parentId!);
    if (parent is FractionNode) {
      return cursor.path == 'num' ? parent.numerator : parent.denominator;
    }
    if (parent is ExponentNode) {
      return cursor.path == 'pow' ? parent.power : parent.base;
    }
    if (parent is ParenthesisNode) {
      return parent.content;
    }
    if (parent is TrigNode) {
      return parent.argument;
    }
    if (parent is RootNode) {
      return cursor.path == 'index' ? parent.index : parent.radicand;
    }
    if (parent is LogNode) {
      return cursor.path == 'base' ? parent.base : parent.argument;
    }
    if (parent is PermutationNode) {
      return cursor.path == 'n' ? parent.n : parent.r;
    }
    if (parent is CombinationNode) {
      return cursor.path == 'n' ? parent.n : parent.r;
    }
    if (parent is AnsNode) {
      return parent.index;
    }
    return expression;
  }

  MathNode? _findNode(List<MathNode> nodes, String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
      if (n is FractionNode) {
        final found =
            _findNode(n.numerator, id) ?? _findNode(n.denominator, id);
        if (found != null) return found;
      }
      if (n is ExponentNode) {
        final found = _findNode(n.base, id) ?? _findNode(n.power, id);
        if (found != null) return found;
      }
      if (n is ParenthesisNode) {
        final found = _findNode(n.content, id);
        if (found != null) return found;
      }
      if (n is TrigNode) {
        final found = _findNode(n.argument, id);
        if (found != null) return found;
      }
      if (n is RootNode) {
        final found = _findNode(n.index, id) ?? _findNode(n.radicand, id);
        if (found != null) return found;
      }
      if (n is LogNode) {
        final found = _findNode(n.base, id) ?? _findNode(n.argument, id);
        if (found != null) return found;
      }
      if (n is PermutationNode) {
        final found = _findNode(n.n, id) ?? _findNode(n.r, id);
        if (found != null) return found;
      }
      if (n is CombinationNode) {
        final found = _findNode(n.n, id) ?? _findNode(n.r, id);
        if (found != null) return found;
      }
      if (n is AnsNode) {
        final found = _findNode(n.index, id);
        if (found != null) return found;
      }
    }
    return null;
  }

  _ParentListInfo? _findParentListOf(String nodeId) =>
      _searchForParent(expression, nodeId, null, null);

  _ParentListInfo? _searchForParent(
    List<MathNode> nodes,
    String targetId,
    String? parentId,
    String? path,
  ) {
    for (int i = 0; i < nodes.length; i++) {
      if (nodes[i].id == targetId) {
        return _ParentListInfo(nodes, i, parentId, path);
      }
      final node = nodes[i];
      if (node is FractionNode) {
        var result = _searchForParent(node.numerator, targetId, node.id, 'num');
        if (result != null) return result;
        result = _searchForParent(node.denominator, targetId, node.id, 'den');
        if (result != null) return result;
      } else if (node is ExponentNode) {
        var result = _searchForParent(node.base, targetId, node.id, 'base');
        if (result != null) return result;
        result = _searchForParent(node.power, targetId, node.id, 'pow');
        if (result != null) return result;
      } else if (node is ParenthesisNode) {
        var result = _searchForParent(
          node.content,
          targetId,
          node.id,
          'content',
        );
        if (result != null) return result;
      } else if (node is TrigNode) {
        // <-- ADD THIS
        var result = _searchForParent(node.argument, targetId, node.id, 'arg');
        if (result != null) return result;
      } else if (node is RootNode) {
        // <-- ADD THIS
        var result = _searchForParent(node.index, targetId, node.id, 'index');
        if (result != null) return result;
        result = _searchForParent(node.radicand, targetId, node.id, 'radicand');
        if (result != null) return result;
      } else if (node is PermutationNode) {
        // <-- ADD THIS
        var result = _searchForParent(node.n, targetId, node.id, 'n');
        if (result != null) return result;
        result = _searchForParent(node.r, targetId, node.id, 'r');
        if (result != null) return result;
      } else if (node is CombinationNode) {
        // <-- ADD THIS
        var result = _searchForParent(node.n, targetId, node.id, 'n');
        if (result != null) return result;
        result = _searchForParent(node.r, targetId, node.id, 'r');
        if (result != null) return result;
      }
      if (node is LogNode) {
        var result = _searchForParent(node.base, targetId, node.id, 'base');
        if (result != null) return result;
        result = _searchForParent(node.argument, targetId, node.id, 'arg');
        if (result != null) return result;
      }
      if (node is AnsNode) {
        var result = _searchForParent(node.index, targetId, node.id, 'index');
        if (result != null) return result;
      }
    }
    return null;
  }

  _MultiplicationChainResult _collectMultiplicationChain(
    List<MathNode> siblings,
    int startIndex,
  ) {
    List<MathNode> collectedNodes = [];
    int removeFromIndex = startIndex;
    String? prefixToKeep;
    int? prefixNodeIndex;

    int i = startIndex;
    while (i >= 0) {
      final node = siblings[i];

      if (node is ExponentNode ||
          node is FractionNode ||
          node is ParenthesisNode ||
          node is TrigNode ||
          node is RootNode ||
          node is AnsNode ||
          node is LogNode ||
          node is PermutationNode || // <-- ADD THIS
          node is CombinationNode) {
        // <-- ADD THIS
        collectedNodes.insert(0, node);
        removeFromIndex = i;

        // Check if we should continue collecting
        if (i > 0) {
          final prevNode = siblings[i - 1];

          // Continue if previous node ends with multiply sign
          if (prevNode is LiteralNode &&
              prevNode.text.endsWith(MathTextStyle.multiplySign)) {
            i--;
            continue;
          }

          // Continue if previous node ends with digit/letter (implicit multiplication)
          if (prevNode is LiteralNode && prevNode.text.isNotEmpty) {
            String lastChar = prevNode.text[prevNode.text.length - 1];
            if (_isDigitOrLetter(lastChar)) {
              i--;
              continue;
            }
          }

          // Continue if previous is a structural node
          if (prevNode is ExponentNode ||
              prevNode is FractionNode ||
              prevNode is ParenthesisNode ||
              prevNode is TrigNode ||
              prevNode is RootNode ||
              prevNode is AnsNode ||
              prevNode is LogNode ||
              prevNode is PermutationNode || // <-- ADD THIS
              prevNode is CombinationNode) {
            // <-- ADD THIS
            if (i > 1) {
              final prevPrevNode = siblings[i - 2];
              if (prevPrevNode is LiteralNode &&
                  (prevPrevNode.text.endsWith(MathTextStyle.multiplySign) ||
                      (prevPrevNode.text.isNotEmpty &&
                          _isDigitOrLetter(
                            prevPrevNode.text[prevPrevNode.text.length - 1],
                          )))) {
                i--;
                continue;
              }
            }
            i--;
            continue;
          }
        }
        break;
      } else if (node is LiteralNode) {
        String text = node.text;
        int operandEnd = text.length;
        int operandStart = operandEnd;

        while (operandStart > 0 &&
            !_isNonMultiplyWordBoundary(text[operandStart - 1])) {
          operandStart--;
        }

        if (operandStart < operandEnd) {
          String operandPart = text.substring(operandStart);

          if (operandPart == MathTextStyle.multiplySign) {
            collectedNodes.insert(0, LiteralNode(text: operandPart));
            removeFromIndex = i;

            if (operandStart > 0) {
              prefixToKeep = text.substring(0, operandStart);
              prefixNodeIndex = i;
              break;
            }

            if (i > 0) {
              i--;
              continue;
            }
            break;
          }

          collectedNodes.insert(0, LiteralNode(text: operandPart));
          removeFromIndex = i;

          if (operandStart > 0) {
            prefixToKeep = text.substring(0, operandStart);
            prefixNodeIndex = i;
            break;
          } else {
            if (i > 0) {
              final prevNode = siblings[i - 1];
              if (prevNode is ExponentNode ||
                  prevNode is FractionNode ||
                  prevNode is ParenthesisNode ||
                  prevNode is TrigNode ||
                  prevNode is RootNode ||
                  prevNode is AnsNode ||
                  prevNode is LogNode ||
                  prevNode is PermutationNode || // <-- ADD THIS
                  prevNode is CombinationNode) {
                // <-- ADD THIS
                i--;
                continue;
              } else if (prevNode is LiteralNode &&
                  (prevNode.text.endsWith(MathTextStyle.multiplySign) ||
                      (prevNode.text.isNotEmpty &&
                          _isDigitOrLetter(
                            prevNode.text[prevNode.text.length - 1],
                          )))) {
                i--;
                continue;
              }
            }
            break;
          }
        } else {
          break;
        }
      } else {
        break;
      }
    }

    return _MultiplicationChainResult(
      nodes: collectedNodes,
      removeFromIndex: removeFromIndex,
      prefixToKeep: prefixToKeep,
      prefixNodeIndex: prefixNodeIndex,
    );
  }

  // Add this helper method
  bool _isDigitOrLetter(String char) {
    if (char.isEmpty) return false;
    int code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) || // 0-9
        (code >= 65 && code <= 90) || // A-Z
        (code >= 97 && code <= 122); // a-z
  }

  void _insertParenthesis() {
    final siblings = _resolveSiblingList();
    final current = _resolveCursorNode();
    if (current is! LiteralNode) return;

    final String currentId = current.id;
    String text = current.text;
    int cursorPos = cursor.subIndex;
    int actualIndex = siblings.indexWhere((n) => n.id == currentId);

    current.text = text.substring(0, cursorPos);
    final paren = ParenthesisNode(content: [LiteralNode(text: "")]);
    final tail = LiteralNode(text: text.substring(cursorPos));

    if (actualIndex >= 0) {
      siblings.insert(actualIndex + 1, paren);
      siblings.insert(actualIndex + 2, tail);
      cursor = EditorCursor(
        parentId: paren.id,
        path: 'content',
        index: 0,
        subIndex: 0,
      );
    }
    _notifyStructureChanged();
  }

  void _exitParenthesis() {
    String? currentParentId = cursor.parentId;
    while (currentParentId != null) {
      final parent = _findNode(expression, currentParentId);
      if (parent is ParenthesisNode) {
        _moveCursorAfterNode(parent.id);
        notifyListeners();
        return;
      }
      final parentInfo = _findParentListOf(currentParentId);
      currentParentId = parentInfo?.parentId;
    }
  }

  void _wrapIntoFraction() {
    if (cursor.parentId != null) {
      final parent = _findNode(expression, cursor.parentId!);

      // === NODES THAT SHOULD ALWAYS WRAP ENTIRELY ===
      // (their fields are just numbers, not expressions)

      if (parent is AnsNode) {
        _wrapAnsNodeIntoFraction(parent);
        return;
      }

      if (parent is PermutationNode) {
        // <-- MOVE HERE
        _wrapPermutationNodeIntoFraction(parent);
        return;
      }

      if (parent is CombinationNode) {
        // <-- MOVE HERE
        _wrapCombinationNodeIntoFraction(parent);
        return;
      }

      // === NODES THAT CAN CONTAIN FRACTIONS INSIDE ===
      // (only wrap entire node if cursor is at start with no content)

      if (!_hasContentForNumerator()) {
        if (parent is LogNode) {
          _wrapLogNodeIntoFraction(parent);
          return;
        }
        if (parent is ExponentNode) {
          _wrapExponentNodeIntoFraction(parent);
          return;
        }
        if (parent is TrigNode) {
          _wrapTrigNodeIntoFraction(parent);
          return;
        }
        if (parent is RootNode) {
          _wrapRootNodeIntoFraction(parent);
          return;
        }
        if (parent is ParenthesisNode) {
          _wrapParenthesisNodeIntoFraction(parent);
          return;
        }
      }
      // If there's content for numerator, fall through to create fraction inside
    }

    final siblings = _resolveSiblingList();
    final current = _resolveCursorNode();
    if (current is! LiteralNode) return;

    final String currentId = current.id;
    String text = current.text;
    int cursorClick = cursor.subIndex;

    int operandStart = cursorClick;
    while (operandStart > 0 &&
        !_isNonMultiplyWordBoundary(text[operandStart - 1])) {
      operandStart--;
    }

    String numeratorText = text.substring(operandStart, cursorClick);
    int actualIndex = siblings.indexWhere((n) => n.id == currentId);

    // === DETERMINE IF WE NEED TO COLLECT A CHAIN ===
    bool shouldCollectChain = false;
    String actualOperand = numeratorText;

    // Case 1: Empty operand at start of node with previous nodes
    if (numeratorText.isEmpty && operandStart == 0 && actualIndex > 0) {
      shouldCollectChain = true;
    }
    // Case 2: Operand preceded by multiply sign in same node
    else if (operandStart > 0 &&
        text[operandStart - 1] == MathTextStyle.multiplySign) {
      shouldCollectChain = true;
    }
    // Case 3: Operand STARTS with multiply sign
    else if (numeratorText.startsWith(MathTextStyle.multiplySign) &&
        actualIndex > 0) {
      shouldCollectChain = true;
      actualOperand = numeratorText.substring(1);
    }

    if (shouldCollectChain && actualIndex > 0) {
      final chainResult = _collectMultiplicationChain(
        siblings,
        actualIndex - 1,
      );

      if (chainResult.nodes.isNotEmpty) {
        if (chainResult.prefixToKeep != null &&
            chainResult.prefixNodeIndex != null) {
          (siblings[chainResult.prefixNodeIndex!] as LiteralNode).text =
              chainResult.prefixToKeep!;
        }

        int removeStart =
            chainResult.prefixNodeIndex != null
                ? chainResult.prefixNodeIndex! + 1
                : chainResult.removeFromIndex;
        int removeEnd = actualIndex - 1;

        for (int j = removeEnd; j >= removeStart; j--) {
          siblings.removeAt(j);
        }

        int newCurrentIndex = removeStart;
        current.text = text.substring(cursorClick);

        List<MathNode> allNumeratorNodes = List.from(chainResult.nodes);
        if (actualOperand.isNotEmpty) {
          allNumeratorNodes.add(
            LiteralNode(text: MathTextStyle.multiplySign + actualOperand),
          );
        }

        final frac = FractionNode(
          num: allNumeratorNodes,
          den: [LiteralNode(text: "")],
        );
        siblings.insert(newCurrentIndex, frac);

        cursor = EditorCursor(
          parentId: frac.id,
          path: 'den',
          index: 0,
          subIndex: 0,
        );
        _notifyStructureChanged();
        return;
      }
    }

    // === DEFAULT BEHAVIOR ===
    if (numeratorText.startsWith(MathTextStyle.multiplySign)) {
      actualOperand = numeratorText.substring(1);
    }

    current.text = text.substring(0, operandStart);
    final frac = FractionNode(
      num: [LiteralNode(text: actualOperand)],
      den: [LiteralNode(text: "")],
    );
    final tail = LiteralNode(text: text.substring(cursorClick));

    if (actualIndex >= 0) {
      siblings.insert(actualIndex + 1, frac);
      siblings.insert(actualIndex + 2, tail);
      cursor = EditorCursor(
        parentId: frac.id,
        path: 'den',
        index: 0,
        subIndex: 0,
      );
    }
    _notifyStructureChanged();
  }

  /// Checks if there's content at cursor position that could become a numerator
  bool _hasContentForNumerator() {
    // final siblings = _resolveSiblingList();
    final current = _resolveCursorNode();

    // If there are previous nodes in the sibling list, there's content
    if (cursor.index > 0) return true;

    // If current node is not a literal, there might be content
    if (current is! LiteralNode) return true;

    String text = current.text;
    int cursorClick = cursor.subIndex;

    // Find operand start
    int operandStart = cursorClick;
    while (operandStart > 0 &&
        !_isNonMultiplyWordBoundary(text[operandStart - 1])) {
      operandStart--;
    }

    String numeratorText = text.substring(operandStart, cursorClick);

    // If there's text that could be numerator, we have content
    if (numeratorText.isNotEmpty) return true;

    return false;
  }

  /// Wraps an entire ParenthesisNode into a fraction's numerator
  void _wrapParenthesisNodeIntoFraction(ParenthesisNode paren) {
    final parentInfo = _findParentListOf(paren.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final parenIndex = parentInfo.index;

    String afterText = '';
    if (parenIndex + 1 < parentList.length &&
        parentList[parenIndex + 1] is LiteralNode) {
      afterText = (parentList[parenIndex + 1] as LiteralNode).text;
      parentList.removeAt(parenIndex + 1);
    }

    List<MathNode> numeratorNodes = [];
    int removeStartIndex = parenIndex;

    if (parenIndex > 0) {
      final prevNode = parentList[parenIndex - 1];
      if (prevNode is LiteralNode &&
          (prevNode.text.endsWith(MathTextStyle.multiplySign) ||
              (prevNode.text.isNotEmpty &&
                  _isDigitOrLetter(prevNode.text[prevNode.text.length - 1])))) {
        final chainResult = _collectMultiplicationChain(
          parentList,
          parenIndex - 1,
        );
        if (chainResult.nodes.isNotEmpty) {
          if (chainResult.prefixToKeep != null &&
              chainResult.prefixNodeIndex != null) {
            (parentList[chainResult.prefixNodeIndex!] as LiteralNode).text =
                chainResult.prefixToKeep!;
          }
          removeStartIndex =
              chainResult.prefixNodeIndex != null
                  ? chainResult.prefixNodeIndex! + 1
                  : chainResult.removeFromIndex;
          numeratorNodes.addAll(chainResult.nodes);
        }
      }
    }

    numeratorNodes.add(paren);

    for (int j = parenIndex; j >= removeStartIndex; j--) {
      parentList.removeAt(j);
    }

    final frac = FractionNode(
      num: numeratorNodes,
      den: [LiteralNode(text: "")],
    );
    final tail = LiteralNode(text: afterText);

    parentList.insert(removeStartIndex, frac);
    parentList.insert(removeStartIndex + 1, tail);

    cursor = EditorCursor(
      parentId: frac.id,
      path: 'den',
      index: 0,
      subIndex: 0,
    );
    _notifyStructureChanged();
  }

  /// Wraps an entire PermutationNode into a fraction's numerator
  void _wrapPermutationNodeIntoFraction(PermutationNode perm) {
    final parentInfo = _findParentListOf(perm.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final permIndex = parentInfo.index;

    String afterText = '';
    if (permIndex + 1 < parentList.length &&
        parentList[permIndex + 1] is LiteralNode) {
      afterText = (parentList[permIndex + 1] as LiteralNode).text;
      parentList.removeAt(permIndex + 1);
    }

    List<MathNode> numeratorNodes = [];
    int removeStartIndex = permIndex;

    if (permIndex > 0) {
      final prevNode = parentList[permIndex - 1];
      if (prevNode is LiteralNode &&
          (prevNode.text.endsWith(MathTextStyle.multiplySign) ||
              (prevNode.text.isNotEmpty &&
                  _isDigitOrLetter(prevNode.text[prevNode.text.length - 1])))) {
        final chainResult = _collectMultiplicationChain(
          parentList,
          permIndex - 1,
        );
        if (chainResult.nodes.isNotEmpty) {
          if (chainResult.prefixToKeep != null &&
              chainResult.prefixNodeIndex != null) {
            (parentList[chainResult.prefixNodeIndex!] as LiteralNode).text =
                chainResult.prefixToKeep!;
          }
          removeStartIndex =
              chainResult.prefixNodeIndex != null
                  ? chainResult.prefixNodeIndex! + 1
                  : chainResult.removeFromIndex;
          numeratorNodes.addAll(chainResult.nodes);
        }
      }
    }

    numeratorNodes.add(perm);

    for (int j = permIndex; j >= removeStartIndex; j--) {
      parentList.removeAt(j);
    }

    final frac = FractionNode(
      num: numeratorNodes,
      den: [LiteralNode(text: "")],
    );
    final tail = LiteralNode(text: afterText);

    parentList.insert(removeStartIndex, frac);
    parentList.insert(removeStartIndex + 1, tail);

    cursor = EditorCursor(
      parentId: frac.id,
      path: 'den',
      index: 0,
      subIndex: 0,
    );
    _notifyStructureChanged();
  }

  /// Wraps an entire CombinationNode into a fraction's numerator
  void _wrapCombinationNodeIntoFraction(CombinationNode comb) {
    final parentInfo = _findParentListOf(comb.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final combIndex = parentInfo.index;

    String afterText = '';
    if (combIndex + 1 < parentList.length &&
        parentList[combIndex + 1] is LiteralNode) {
      afterText = (parentList[combIndex + 1] as LiteralNode).text;
      parentList.removeAt(combIndex + 1);
    }

    List<MathNode> numeratorNodes = [];
    int removeStartIndex = combIndex;

    if (combIndex > 0) {
      final prevNode = parentList[combIndex - 1];
      if (prevNode is LiteralNode &&
          (prevNode.text.endsWith(MathTextStyle.multiplySign) ||
              (prevNode.text.isNotEmpty &&
                  _isDigitOrLetter(prevNode.text[prevNode.text.length - 1])))) {
        final chainResult = _collectMultiplicationChain(
          parentList,
          combIndex - 1,
        );
        if (chainResult.nodes.isNotEmpty) {
          if (chainResult.prefixToKeep != null &&
              chainResult.prefixNodeIndex != null) {
            (parentList[chainResult.prefixNodeIndex!] as LiteralNode).text =
                chainResult.prefixToKeep!;
          }
          removeStartIndex =
              chainResult.prefixNodeIndex != null
                  ? chainResult.prefixNodeIndex! + 1
                  : chainResult.removeFromIndex;
          numeratorNodes.addAll(chainResult.nodes);
        }
      }
    }

    numeratorNodes.add(comb);

    for (int j = combIndex; j >= removeStartIndex; j--) {
      parentList.removeAt(j);
    }

    final frac = FractionNode(
      num: numeratorNodes,
      den: [LiteralNode(text: "")],
    );
    final tail = LiteralNode(text: afterText);

    parentList.insert(removeStartIndex, frac);
    parentList.insert(removeStartIndex + 1, tail);

    cursor = EditorCursor(
      parentId: frac.id,
      path: 'den',
      index: 0,
      subIndex: 0,
    );
    _notifyStructureChanged();
  }

  void _wrapIntoExponent() {
    // Check if we're inside an AnsNode - if so, wrap the whole AnsNode
    if (cursor.parentId != null) {
      final parent = _findNode(expression, cursor.parentId!);
      if (parent is AnsNode) {
        _wrapAnsNodeIntoExponent(parent);
        return;
      }
    }
    final siblings = _resolveSiblingList();
    final current = _resolveCursorNode();
    if (current is! LiteralNode) return;

    final String currentId = current.id;
    String text = current.text;
    int cursorClick = cursor.subIndex;

    int operandStart = cursorClick;
    while (operandStart > 0 && !_isWordBoundary(text[operandStart - 1])) {
      operandStart--;
    }

    String baseText = text.substring(operandStart, cursorClick);
    int actualIndex = siblings.indexWhere((n) => n.id == currentId);

    if (baseText.isEmpty && operandStart == 0 && actualIndex > 0) {
      final chainResult = _collectMultiplicationChain(
        siblings,
        actualIndex - 1,
      );
      if (chainResult.nodes.isNotEmpty) {
        if (chainResult.prefixToKeep != null &&
            chainResult.prefixNodeIndex != null) {
          (siblings[chainResult.prefixNodeIndex!] as LiteralNode).text =
              chainResult.prefixToKeep!;
        }
        int removeStart =
            chainResult.prefixNodeIndex != null
                ? chainResult.prefixNodeIndex! + 1
                : chainResult.removeFromIndex;
        int removeEnd = actualIndex - 1;
        for (int j = removeEnd; j >= removeStart; j--) {
          siblings.removeAt(j);
        }
        int newCurrentIndex = removeStart;
        current.text = text.substring(cursorClick);
        final exp = ExponentNode(
          base: chainResult.nodes,
          power: [LiteralNode(text: "")],
        );
        siblings.insert(newCurrentIndex, exp);
        cursor = EditorCursor(
          parentId: exp.id,
          path: 'pow',
          index: 0,
          subIndex: 0,
        );
        _notifyStructureChanged();
        return;
      }
    }

    current.text = text.substring(0, operandStart);
    final exp = ExponentNode(
      base: [LiteralNode(text: baseText)],
      power: [LiteralNode(text: "")],
    );
    final tail = LiteralNode(text: text.substring(cursorClick));

    if (actualIndex >= 0) {
      siblings.insert(actualIndex + 1, exp);
      siblings.insert(actualIndex + 2, tail);
      cursor = EditorCursor(
        parentId: exp.id,
        path: 'pow',
        index: 0,
        subIndex: 0,
      );
    }
    _notifyStructureChanged();
  }

  /// Wraps an entire AnsNode into a fraction's numerator
  void _wrapAnsNodeIntoFraction(AnsNode ans) {
    final parentInfo = _findParentListOf(ans.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final ansIndex = parentInfo.index;

    // Get the node after AnsNode (if exists) to preserve text after
    String afterText = '';
    if (ansIndex + 1 < parentList.length &&
        parentList[ansIndex + 1] is LiteralNode) {
      afterText = (parentList[ansIndex + 1] as LiteralNode).text;
      parentList.removeAt(ansIndex + 1);
    }

    // ========== NEW: Collect multiplication chain before this AnsNode ==========
    List<MathNode> numeratorNodes = [];
    int removeStartIndex = ansIndex;

    if (ansIndex > 0) {
      // Check if there's a multiply sign before this AnsNode
      final prevNode = parentList[ansIndex - 1];
      if (prevNode is LiteralNode &&
          prevNode.text.endsWith(MathTextStyle.multiplySign)) {
        // Collect the chain
        final chainResult = _collectMultiplicationChain(
          parentList,
          ansIndex - 1,
        );
        if (chainResult.nodes.isNotEmpty) {
          // Handle prefix
          if (chainResult.prefixToKeep != null &&
              chainResult.prefixNodeIndex != null) {
            (parentList[chainResult.prefixNodeIndex!] as LiteralNode).text =
                chainResult.prefixToKeep!;
          }

          removeStartIndex =
              chainResult.prefixNodeIndex != null
                  ? chainResult.prefixNodeIndex! + 1
                  : chainResult.removeFromIndex;

          // Add chain nodes to numerator
          numeratorNodes.addAll(chainResult.nodes);
        }
      }
    }

    // Add the current AnsNode to numerator
    numeratorNodes.add(ans);

    // Remove all collected nodes (from chain start to ansIndex)
    for (int j = ansIndex; j >= removeStartIndex; j--) {
      parentList.removeAt(j);
    }
    // ========== END NEW ==========

    // Create fraction with collected nodes as numerator
    final frac = FractionNode(
      num: numeratorNodes, // ← Now includes the whole chain!
      den: [LiteralNode(text: "")],
    );

    final tail = LiteralNode(text: afterText);

    parentList.insert(removeStartIndex, frac);
    parentList.insert(removeStartIndex + 1, tail);

    cursor = EditorCursor(
      parentId: frac.id,
      path: 'den',
      index: 0,
      subIndex: 0,
    );
    _notifyStructureChanged();
  }

  /// Wraps an entire LogNode into a fraction's numerator
  void _wrapLogNodeIntoFraction(LogNode log) {
    final parentInfo = _findParentListOf(log.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final logIndex = parentInfo.index;

    String afterText = '';
    if (logIndex + 1 < parentList.length &&
        parentList[logIndex + 1] is LiteralNode) {
      afterText = (parentList[logIndex + 1] as LiteralNode).text;
      parentList.removeAt(logIndex + 1);
    }

    // Collect multiplication chain before this LogNode
    List<MathNode> numeratorNodes = [];
    int removeStartIndex = logIndex;

    if (logIndex > 0) {
      final prevNode = parentList[logIndex - 1];
      if (prevNode is LiteralNode &&
          prevNode.text.endsWith(MathTextStyle.multiplySign)) {
        final chainResult = _collectMultiplicationChain(
          parentList,
          logIndex - 1,
        );
        if (chainResult.nodes.isNotEmpty) {
          if (chainResult.prefixToKeep != null &&
              chainResult.prefixNodeIndex != null) {
            (parentList[chainResult.prefixNodeIndex!] as LiteralNode).text =
                chainResult.prefixToKeep!;
          }
          removeStartIndex =
              chainResult.prefixNodeIndex != null
                  ? chainResult.prefixNodeIndex! + 1
                  : chainResult.removeFromIndex;
          numeratorNodes.addAll(chainResult.nodes);
        }
      }
    }

    numeratorNodes.add(log);

    for (int j = logIndex; j >= removeStartIndex; j--) {
      parentList.removeAt(j);
    }

    final frac = FractionNode(
      num: numeratorNodes,
      den: [LiteralNode(text: "")],
    );
    final tail = LiteralNode(text: afterText);

    parentList.insert(removeStartIndex, frac);
    parentList.insert(removeStartIndex + 1, tail);

    cursor = EditorCursor(
      parentId: frac.id,
      path: 'den',
      index: 0,
      subIndex: 0,
    );
    _notifyStructureChanged();
  }

  /// Wraps an entire ExponentNode into a fraction's numerator
  void _wrapExponentNodeIntoFraction(ExponentNode exp) {
    final parentInfo = _findParentListOf(exp.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final expIndex = parentInfo.index;

    String afterText = '';
    if (expIndex + 1 < parentList.length &&
        parentList[expIndex + 1] is LiteralNode) {
      afterText = (parentList[expIndex + 1] as LiteralNode).text;
      parentList.removeAt(expIndex + 1);
    }

    List<MathNode> numeratorNodes = [];
    int removeStartIndex = expIndex;

    if (expIndex > 0) {
      final prevNode = parentList[expIndex - 1];
      if (prevNode is LiteralNode &&
          prevNode.text.endsWith(MathTextStyle.multiplySign)) {
        final chainResult = _collectMultiplicationChain(
          parentList,
          expIndex - 1,
        );
        if (chainResult.nodes.isNotEmpty) {
          if (chainResult.prefixToKeep != null &&
              chainResult.prefixNodeIndex != null) {
            (parentList[chainResult.prefixNodeIndex!] as LiteralNode).text =
                chainResult.prefixToKeep!;
          }
          removeStartIndex =
              chainResult.prefixNodeIndex != null
                  ? chainResult.prefixNodeIndex! + 1
                  : chainResult.removeFromIndex;
          numeratorNodes.addAll(chainResult.nodes);
        }
      }
    }

    numeratorNodes.add(exp);

    for (int j = expIndex; j >= removeStartIndex; j--) {
      parentList.removeAt(j);
    }

    final frac = FractionNode(
      num: numeratorNodes,
      den: [LiteralNode(text: "")],
    );
    final tail = LiteralNode(text: afterText);

    parentList.insert(removeStartIndex, frac);
    parentList.insert(removeStartIndex + 1, tail);

    cursor = EditorCursor(
      parentId: frac.id,
      path: 'den',
      index: 0,
      subIndex: 0,
    );
    _notifyStructureChanged();
  }

  /// Wraps an entire TrigNode into a fraction's numerator
  void _wrapTrigNodeIntoFraction(TrigNode trig) {
    final parentInfo = _findParentListOf(trig.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final trigIndex = parentInfo.index;

    String afterText = '';
    if (trigIndex + 1 < parentList.length &&
        parentList[trigIndex + 1] is LiteralNode) {
      afterText = (parentList[trigIndex + 1] as LiteralNode).text;
      parentList.removeAt(trigIndex + 1);
    }

    List<MathNode> numeratorNodes = [];
    int removeStartIndex = trigIndex;

    if (trigIndex > 0) {
      final prevNode = parentList[trigIndex - 1];
      if (prevNode is LiteralNode &&
          prevNode.text.endsWith(MathTextStyle.multiplySign)) {
        final chainResult = _collectMultiplicationChain(
          parentList,
          trigIndex - 1,
        );
        if (chainResult.nodes.isNotEmpty) {
          if (chainResult.prefixToKeep != null &&
              chainResult.prefixNodeIndex != null) {
            (parentList[chainResult.prefixNodeIndex!] as LiteralNode).text =
                chainResult.prefixToKeep!;
          }
          removeStartIndex =
              chainResult.prefixNodeIndex != null
                  ? chainResult.prefixNodeIndex! + 1
                  : chainResult.removeFromIndex;
          numeratorNodes.addAll(chainResult.nodes);
        }
      }
    }

    numeratorNodes.add(trig);

    for (int j = trigIndex; j >= removeStartIndex; j--) {
      parentList.removeAt(j);
    }

    final frac = FractionNode(
      num: numeratorNodes,
      den: [LiteralNode(text: "")],
    );
    final tail = LiteralNode(text: afterText);

    parentList.insert(removeStartIndex, frac);
    parentList.insert(removeStartIndex + 1, tail);

    cursor = EditorCursor(
      parentId: frac.id,
      path: 'den',
      index: 0,
      subIndex: 0,
    );
    _notifyStructureChanged();
  }

  /// Wraps an entire RootNode into a fraction's numerator
  void _wrapRootNodeIntoFraction(RootNode root) {
    final parentInfo = _findParentListOf(root.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final rootIndex = parentInfo.index;

    String afterText = '';
    if (rootIndex + 1 < parentList.length &&
        parentList[rootIndex + 1] is LiteralNode) {
      afterText = (parentList[rootIndex + 1] as LiteralNode).text;
      parentList.removeAt(rootIndex + 1);
    }

    List<MathNode> numeratorNodes = [];
    int removeStartIndex = rootIndex;

    if (rootIndex > 0) {
      final prevNode = parentList[rootIndex - 1];
      if (prevNode is LiteralNode &&
          prevNode.text.endsWith(MathTextStyle.multiplySign)) {
        final chainResult = _collectMultiplicationChain(
          parentList,
          rootIndex - 1,
        );
        if (chainResult.nodes.isNotEmpty) {
          if (chainResult.prefixToKeep != null &&
              chainResult.prefixNodeIndex != null) {
            (parentList[chainResult.prefixNodeIndex!] as LiteralNode).text =
                chainResult.prefixToKeep!;
          }
          removeStartIndex =
              chainResult.prefixNodeIndex != null
                  ? chainResult.prefixNodeIndex! + 1
                  : chainResult.removeFromIndex;
          numeratorNodes.addAll(chainResult.nodes);
        }
      }
    }

    numeratorNodes.add(root);

    for (int j = rootIndex; j >= removeStartIndex; j--) {
      parentList.removeAt(j);
    }

    final frac = FractionNode(
      num: numeratorNodes,
      den: [LiteralNode(text: "")],
    );
    final tail = LiteralNode(text: afterText);

    parentList.insert(removeStartIndex, frac);
    parentList.insert(removeStartIndex + 1, tail);

    cursor = EditorCursor(
      parentId: frac.id,
      path: 'den',
      index: 0,
      subIndex: 0,
    );
    _notifyStructureChanged();
  }

  /// Wraps an entire AnsNode into an exponent's base
  void _wrapAnsNodeIntoExponent(AnsNode ans) {
    final parentInfo = _findParentListOf(ans.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final ansIndex = parentInfo.index;

    String afterText = '';
    if (ansIndex + 1 < parentList.length &&
        parentList[ansIndex + 1] is LiteralNode) {
      afterText = (parentList[ansIndex + 1] as LiteralNode).text;
      parentList.removeAt(ansIndex + 1);
    }

    // ========== NEW: Collect multiplication chain ==========
    List<MathNode> baseNodes = [];
    int removeStartIndex = ansIndex;

    if (ansIndex > 0) {
      final prevNode = parentList[ansIndex - 1];
      if (prevNode is LiteralNode &&
          prevNode.text.endsWith(MathTextStyle.multiplySign)) {
        final chainResult = _collectMultiplicationChain(
          parentList,
          ansIndex - 1,
        );
        if (chainResult.nodes.isNotEmpty) {
          if (chainResult.prefixToKeep != null &&
              chainResult.prefixNodeIndex != null) {
            (parentList[chainResult.prefixNodeIndex!] as LiteralNode).text =
                chainResult.prefixToKeep!;
          }

          removeStartIndex =
              chainResult.prefixNodeIndex != null
                  ? chainResult.prefixNodeIndex! + 1
                  : chainResult.removeFromIndex;

          baseNodes.addAll(chainResult.nodes);
        }
      }
    }

    baseNodes.add(ans);

    for (int j = ansIndex; j >= removeStartIndex; j--) {
      parentList.removeAt(j);
    }
    // ========== END NEW ==========

    final exp = ExponentNode(
      base: baseNodes, // ← Now includes the whole chain!
      power: [LiteralNode(text: "")],
    );

    final tail = LiteralNode(text: afterText);

    parentList.insert(removeStartIndex, exp);
    parentList.insert(removeStartIndex + 1, tail);

    cursor = EditorCursor(parentId: exp.id, path: 'pow', index: 0, subIndex: 0);
    _notifyStructureChanged();
  }

  void deleteChar() {
    saveStateForUndo();
    final node = _resolveCursorNode();
    if (node is! LiteralNode) return;

    if (cursor.subIndex > 0) {
      node.text =
          node.text.substring(0, cursor.subIndex - 1) +
          node.text.substring(cursor.subIndex);
      cursor = cursor.copyWith(subIndex: cursor.subIndex - 1);
      _notifyStructureChanged();
      return;
    }
    if (cursor.index > 0) {
      _deleteIntoPreviousNode();
      return;
    }
    if (cursor.parentId == null) return;
    _handleDeleteAtStructureStart();
  }

  void clear() {
    saveStateForUndo();
    expression = [LiteralNode()];
    result = '';
    cursor = const EditorCursor(); // Reset cursor to initial state
    _notifyStructureChanged();
  }

  void _deleteIntoPreviousNode() {
    final siblings = _resolveSiblingList();
    final prevNode = siblings[cursor.index - 1];

    if (prevNode is LiteralNode) {
      if (prevNode.text.isNotEmpty) {
        prevNode.text = prevNode.text.substring(0, prevNode.text.length - 1);
        cursor = cursor.copyWith(
          index: cursor.index - 1,
          subIndex: prevNode.text.length,
        );
        _notifyStructureChanged();
      } else {
        cursor = cursor.copyWith(index: cursor.index - 1, subIndex: 0);
        notifyListeners();
      }
    } else if (prevNode is NewlineNode) {
      // Delete the newline and merge with previous line
      _removeNewline(prevNode);
    } else if (prevNode is FractionNode) {
      _moveCursorToEndOfList(prevNode.denominator, prevNode.id, 'den');
      notifyListeners();
    } else if (prevNode is ExponentNode) {
      _moveCursorToEndOfList(prevNode.power, prevNode.id, 'pow');
      notifyListeners();
    } else if (prevNode is ParenthesisNode) {
      _moveCursorToEndOfList(prevNode.content, prevNode.id, 'content');
      notifyListeners();
    } else if (prevNode is TrigNode) {
      _moveCursorToEndOfList(prevNode.argument, prevNode.id, 'arg');
      notifyListeners();
    } else if (prevNode is RootNode) {
      _moveCursorToEndOfList(prevNode.radicand, prevNode.id, 'radicand');
      notifyListeners();
    } else if (prevNode is LogNode) {
      _moveCursorToEndOfList(prevNode.argument, prevNode.id, 'arg');
      notifyListeners();
    } else if (prevNode is PermutationNode) {
      _moveCursorToEndOfList(prevNode.r, prevNode.id, 'r');
      notifyListeners();
    } else if (prevNode is CombinationNode) {
      _moveCursorToEndOfList(prevNode.r, prevNode.id, 'r');
      notifyListeners();
    } else if (prevNode is AnsNode) {
      _moveCursorToEndOfList(prevNode.index, prevNode.id, 'index');
      notifyListeners();
    }
  }

  void _handleDeleteAtStructureStart() {
    final parent = _findNode(expression, cursor.parentId!);
    if (parent is FractionNode) {
      _handleDeleteInFraction(parent);
    } else if (parent is ExponentNode) {
      _handleDeleteInExponent(parent);
    } else if (parent is ParenthesisNode) {
      _handleDeleteInParenthesis(parent);
    } else if (parent is TrigNode) {
      _handleDeleteInTrig(parent);
    } else if (parent is RootNode) {
      _handleDeleteInRoot(parent);
    } else if (parent is LogNode) {
      _handleDeleteInLog(parent);
    } else if (parent is PermutationNode) {
      _handleDeleteInPermutation(parent);
    } else if (parent is CombinationNode) {
      _handleDeleteInCombination(parent);
    } else if (parent is AnsNode) {
      _handleDeleteInAns(parent);
    }
  }

  void _handleDeleteInFraction(FractionNode frac) {
    if (cursor.path == 'den') {
      if (_isListEffectivelyEmpty(frac.denominator)) {
        _unwrapFraction(frac);
      } else {
        _moveCursorToEndOfList(frac.numerator, frac.id, 'num');
        notifyListeners();
      }
    } else if (cursor.path == 'num') {
      if (_isListEffectivelyEmpty(frac.numerator) &&
          _isListEffectivelyEmpty(frac.denominator)) {
        _removeFraction(frac);
      } else {
        _moveCursorBeforeNode(frac.id);
        notifyListeners();
      }
    }
  }

  void _handleDeleteInExponent(ExponentNode exp) {
    if (cursor.path == 'pow') {
      if (_isListEffectivelyEmpty(exp.power)) {
        _unwrapExponent(exp);
      } else {
        _moveCursorToEndOfList(exp.base, exp.id, 'base');
        notifyListeners();
      }
    } else if (cursor.path == 'base') {
      if (_isListEffectivelyEmpty(exp.base) &&
          _isListEffectivelyEmpty(exp.power)) {
        _removeExponent(exp);
      } else {
        _moveCursorBeforeNode(exp.id);
        notifyListeners();
      }
    }
  }

  void _handleDeleteInParenthesis(ParenthesisNode paren) {
    if (_isListEffectivelyEmpty(paren.content)) {
      _removeParenthesis(paren);
    } else {
      _moveCursorBeforeNode(paren.id);
      notifyListeners();
    }
  }

  void _handleDeleteInLog(LogNode log) {
    if (cursor.path == 'arg') {
      if (_isListEffectivelyEmpty(log.argument)) {
        _removeLog(log);
      } else if (!log.isNaturalLog) {
        _moveCursorToEndOfList(log.base, log.id, 'base');
        notifyListeners();
      } else {
        _moveCursorBeforeNode(log.id);
        notifyListeners();
      }
    } else if (cursor.path == 'base') {
      if (_isListEffectivelyEmpty(log.base) &&
          _isListEffectivelyEmpty(log.argument)) {
        _removeLog(log);
      } else {
        _moveCursorBeforeNode(log.id);
        notifyListeners();
      }
    }
  }

  void _handleDeleteInAns(AnsNode ans) {
    // When deleting at start of index, delete the whole ANS node
    if (_isListEffectivelyEmpty(ans.index)) {
      _removeAns(ans);
    } else {
      _moveCursorBeforeNode(ans.id);
      notifyListeners();
    }
  }

  // ============== DELETE HANDLERS FOR NEW NODES ==============

  void _handleDeleteInTrig(TrigNode trig) {
    if (_isListEffectivelyEmpty(trig.argument)) {
      _removeTrig(trig);
    } else {
      _moveCursorBeforeNode(trig.id);
      notifyListeners();
    }
  }

  void _handleDeleteInRoot(RootNode root) {
    if (cursor.path == 'radicand') {
      if (_isListEffectivelyEmpty(root.radicand)) {
        _removeRoot(root);
      } else if (!root.isSquareRoot) {
        _moveCursorToEndOfList(root.index, root.id, 'index');
        notifyListeners();
      } else {
        _moveCursorBeforeNode(root.id);
        notifyListeners();
      }
    } else if (cursor.path == 'index') {
      if (_isListEffectivelyEmpty(root.index) &&
          _isListEffectivelyEmpty(root.radicand)) {
        _removeRoot(root);
      } else {
        _moveCursorBeforeNode(root.id);
        notifyListeners();
      }
    }
  }

  void _handleDeleteInPermutation(PermutationNode perm) {
    if (cursor.path == 'r') {
      if (_isListEffectivelyEmpty(perm.r)) {
        _moveCursorToEndOfList(perm.n, perm.id, 'n');
        notifyListeners();
      } else {
        _moveCursorToEndOfList(perm.n, perm.id, 'n');
        notifyListeners();
      }
    } else if (cursor.path == 'n') {
      if (_isListEffectivelyEmpty(perm.n) && _isListEffectivelyEmpty(perm.r)) {
        _removePermutation(perm);
      } else {
        _moveCursorBeforeNode(perm.id);
        notifyListeners();
      }
    }
  }

  void _handleDeleteInCombination(CombinationNode comb) {
    if (cursor.path == 'r') {
      if (_isListEffectivelyEmpty(comb.r)) {
        _moveCursorToEndOfList(comb.n, comb.id, 'n');
        notifyListeners();
      } else {
        _moveCursorToEndOfList(comb.n, comb.id, 'n');
        notifyListeners();
      }
    } else if (cursor.path == 'n') {
      if (_isListEffectivelyEmpty(comb.n) && _isListEffectivelyEmpty(comb.r)) {
        _removeCombination(comb);
      } else {
        _moveCursorBeforeNode(comb.id);
        notifyListeners();
      }
    }
  }

  bool _isListEffectivelyEmpty(List<MathNode> nodes) {
    for (final node in nodes) {
      if (node is LiteralNode && node.text.isNotEmpty) return false;
      if (node is! LiteralNode) return false;
    }
    return true;
  }

  // int _getTextLengthOfList(List<MathNode> nodes) {
  //   int total = 0;
  //   for (final node in nodes) {
  //     if (node is LiteralNode) total += node.text.length;
  //   }
  //   return total;
  // }

  void _moveCursorToEndOfList(
    List<MathNode> nodes,
    String parentId,
    String path,
  ) {
    if (nodes.isEmpty) return;
    final lastIndex = nodes.length - 1;
    final lastNode = nodes[lastIndex];

    if (lastNode is LiteralNode) {
      cursor = EditorCursor(
        parentId: parentId,
        path: path,
        index: lastIndex,
        subIndex: lastNode.text.length,
      );
    } else if (lastNode is FractionNode) {
      _moveCursorToEndOfList(lastNode.denominator, lastNode.id, 'den');
    } else if (lastNode is ExponentNode) {
      _moveCursorToEndOfList(lastNode.power, lastNode.id, 'pow');
    } else if (lastNode is ParenthesisNode) {
      _moveCursorToEndOfList(lastNode.content, lastNode.id, 'content');
    } else if (lastNode is TrigNode) {
      _moveCursorToEndOfList(lastNode.argument, lastNode.id, 'arg');
    } else if (lastNode is RootNode) {
      _moveCursorToEndOfList(lastNode.radicand, lastNode.id, 'radicand');
    } else if (lastNode is LogNode) {
      _moveCursorToEndOfList(lastNode.argument, lastNode.id, 'arg');
    } else if (lastNode is PermutationNode) {
      _moveCursorToEndOfList(lastNode.r, lastNode.id, 'r');
    } else if (lastNode is CombinationNode) {
      _moveCursorToEndOfList(lastNode.r, lastNode.id, 'r');
    } else if (lastNode is AnsNode) {
      _moveCursorToEndOfList(lastNode.index, lastNode.id, 'index');
    }
  }

  void _moveCursorToStartOfList(
    List<MathNode> nodes,
    String parentId,
    String path,
  ) {
    if (nodes.isEmpty) return;
    final firstNode = nodes[0];

    if (firstNode is LiteralNode) {
      cursor = EditorCursor(
        parentId: parentId,
        path: path,
        index: 0,
        subIndex: 0,
      );
    } else if (firstNode is FractionNode) {
      _moveCursorToStartOfList(firstNode.numerator, firstNode.id, 'num');
    } else if (firstNode is ExponentNode) {
      _moveCursorToStartOfList(firstNode.base, firstNode.id, 'base');
    } else if (firstNode is ParenthesisNode) {
      _moveCursorToStartOfList(firstNode.content, firstNode.id, 'content');
    } else if (firstNode is TrigNode) {
      _moveCursorToStartOfList(firstNode.argument, firstNode.id, 'arg');
    } else if (firstNode is RootNode) {
      if (firstNode.isSquareRoot) {
        _moveCursorToStartOfList(firstNode.radicand, firstNode.id, 'radicand');
      } else {
        _moveCursorToStartOfList(firstNode.index, firstNode.id, 'index');
      }
    } else if (firstNode is LogNode) {
      if (firstNode.isNaturalLog) {
        _moveCursorToStartOfList(firstNode.argument, firstNode.id, 'arg');
      } else {
        _moveCursorToStartOfList(firstNode.base, firstNode.id, 'base');
      }
    } else if (firstNode is PermutationNode) {
      _moveCursorToStartOfList(firstNode.n, firstNode.id, 'n');
    } else if (firstNode is CombinationNode) {
      _moveCursorToStartOfList(firstNode.n, firstNode.id, 'n');
    } else if (firstNode is AnsNode) {
      _moveCursorToStartOfList(firstNode.index, firstNode.id, 'index');
    }
  }

  void _moveCursorBeforeNode(String nodeId) =>
      _findAndPositionBefore(expression, nodeId, null, null);

  void moveCursorToStart() {
    cursor = const EditorCursor(
      parentId: null,
      path: null,
      index: 0,
      subIndex: 0,
    );
    notifyListeners();
  }

  void moveCursorToEnd() {
    if (expression.isEmpty) {
      cursor = const EditorCursor(index: 0, subIndex: 0);
    } else {
      int lastIndex = expression.length - 1;
      MathNode lastNode = expression[lastIndex];

      cursor = EditorCursor(
        parentId: null,
        path: null,
        index: lastIndex,
        subIndex: lastNode is LiteralNode ? lastNode.text.length : 0,
      );
    }
    notifyListeners();
  }

  bool _findAndPositionBefore(
    List<MathNode> nodes,
    String targetId,
    String? grandParentId,
    String? path,
  ) {
    for (int i = 0; i < nodes.length; i++) {
      if (nodes[i].id == targetId) {
        if (i > 0) {
          final prevNode = nodes[i - 1];
          if (prevNode is LiteralNode) {
            cursor = EditorCursor(
              parentId: grandParentId,
              path: path,
              index: i - 1,
              subIndex: prevNode.text.length,
            );
          } else if (prevNode is FractionNode) {
            _moveCursorToEndOfList(prevNode.denominator, prevNode.id, 'den');
          } else if (prevNode is ExponentNode) {
            _moveCursorToEndOfList(prevNode.power, prevNode.id, 'pow');
          } else if (prevNode is ParenthesisNode) {
            _moveCursorToEndOfList(prevNode.content, prevNode.id, 'content');
          } else if (prevNode is AnsNode) {
            _moveCursorToEndOfList(prevNode.index, prevNode.id, 'index');
          }
        } else {
          cursor = EditorCursor(
            parentId: grandParentId,
            path: path,
            index: 0,
            subIndex: 0,
          );
        }
        return true;
      }
      final node = nodes[i];
      if (node is FractionNode) {
        if (_findAndPositionBefore(node.numerator, targetId, node.id, 'num')) {
          return true;
        }
        if (_findAndPositionBefore(node.denominator, targetId, node.id, 'den')) {
          return true;
        }
      } else if (node is ExponentNode) {
        if (_findAndPositionBefore(node.base, targetId, node.id, 'base')) {
          return true;
        }
        if (_findAndPositionBefore(node.power, targetId, node.id, 'pow')) {
          return true;
        }
      } else if (node is ParenthesisNode) {
        if (_findAndPositionBefore(node.content, targetId, node.id, 'content')) {
          return true;
        }
      } else if (node is AnsNode) {
        if (_findAndPositionBefore(node.index, targetId, node.id, 'index')) {
          return true;
        }
      }
    }
    return false;
  }

  bool _findAndPositionAfter(
    List<MathNode> nodes,
    String targetId,
    String? grandParentId,
    String? path,
  ) {
    for (int i = 0; i < nodes.length; i++) {
      if (nodes[i].id == targetId) {
        if (i < nodes.length - 1) {
          final nextNode = nodes[i + 1];
          if (nextNode is LiteralNode) {
            cursor = EditorCursor(
              parentId: grandParentId,
              path: path,
              index: i + 1,
              subIndex: 0,
            );
          } else if (nextNode is FractionNode) {
            _moveCursorToStartOfList(nextNode.numerator, nextNode.id, 'num');
          } else if (nextNode is ExponentNode) {
            _moveCursorToStartOfList(nextNode.base, nextNode.id, 'base');
          } else if (nextNode is ParenthesisNode) {
            _moveCursorToStartOfList(nextNode.content, nextNode.id, 'content');
          } else if (nextNode is AnsNode) {
            _moveCursorToStartOfList(nextNode.index, nextNode.id, 'index');
          }
        } else if (grandParentId != null) {
          final grandParent = _findNode(expression, grandParentId);
          if (grandParent is FractionNode) {
            if (path == 'num') {
              _moveCursorToStartOfList(
                grandParent.denominator,
                grandParent.id,
                'den',
              );
            } else {
              _moveCursorAfterNode(grandParent.id);
            }
          } else if (grandParent is ExponentNode) {
            if (path == 'base') {
              _moveCursorToStartOfList(
                grandParent.power,
                grandParent.id,
                'pow',
              );
            } else {
              _moveCursorAfterNode(grandParent.id);
            }
          } else if (grandParent is ParenthesisNode) {
            _moveCursorAfterNode(grandParent.id);
          } else if (grandParent is AnsNode) {
            _moveCursorAfterNode(grandParent.id);
          }
        }
        return true;
      }
      final node = nodes[i];
      if (node is FractionNode) {
        if (_findAndPositionAfter(node.numerator, targetId, node.id, 'num')) {
          return true;
        }
        if (_findAndPositionAfter(node.denominator, targetId, node.id, 'den')) {
          return true;
        }
      } else if (node is ExponentNode) {
        if (_findAndPositionAfter(node.base, targetId, node.id, 'base')) {
          return true;
        }
        if (_findAndPositionAfter(node.power, targetId, node.id, 'pow')) {
          return true;
        }
      } else if (node is ParenthesisNode) {
        if (_findAndPositionAfter(node.content, targetId, node.id, 'content')) {
          return true;
        }
      } else if (node is AnsNode) {
        if (_findAndPositionAfter(node.index, targetId, node.id, 'index')) {
          return true;
        }
      }
    }
    return false;
  }

  void _mergeAdjacentLiteralsFrom(List<MathNode> list, int startIndex) {
    if (startIndex < 0) startIndex = 0;
    int i = startIndex;
    while (i < list.length - 1) {
      final current = list[i];
      final next = list[i + 1];
      if (current is LiteralNode && next is LiteralNode) {
        current.text += next.text;
        list.removeAt(i + 1);
      } else {
        i++;
      }
    }
  }

  void _unwrapFraction(FractionNode frac) {
    final parentInfo = _findParentListOf(frac.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final fracIndex = parentInfo.index;

    List<MathNode> replacement =
        _isListEffectivelyEmpty(frac.numerator)
            ? []
            : List<MathNode>.from(frac.numerator);

    parentList.removeAt(fracIndex);
    if (replacement.isNotEmpty) {
      parentList.insertAll(fracIndex, replacement);
    }

    if (parentList.isEmpty) {
      parentList.add(LiteralNode());
      cursor = EditorCursor(
        parentId: parentInfo.parentId,
        path: parentInfo.path,
        index: 0,
        subIndex: 0,
      );
      _notifyStructureChanged();
      return;
    }

    int mergeStartIndex = (fracIndex > 0) ? fracIndex - 1 : 0;
    _mergeAdjacentLiteralsFrom(parentList, mergeStartIndex);

    // Position cursor at end of numerator content
    if (replacement.isEmpty) {
      // No content was inserted
      if (mergeStartIndex < parentList.length) {
        final node = parentList[mergeStartIndex];
        if (node is LiteralNode) {
          cursor = EditorCursor(
            parentId: parentInfo.parentId,
            path: parentInfo.path,
            index: mergeStartIndex,
            subIndex: node.text.length,
          );
        } else {
          cursor = EditorCursor(
            parentId: parentInfo.parentId,
            path: parentInfo.path,
            index: mergeStartIndex,
            subIndex: 0,
          );
        }
      } else {
        cursor = EditorCursor(
          parentId: parentInfo.parentId,
          path: parentInfo.path,
          index: 0,
          subIndex: 0,
        );
      }
    } else {
      // Find the last node of the numerator by its ID
      MathNode lastNumeratorNode = replacement.last;

      int foundIndex = -1;
      for (int i = 0; i < parentList.length; i++) {
        if (parentList[i].id == lastNumeratorNode.id) {
          foundIndex = i;
          break;
        }
      }

      if (foundIndex != -1) {
        // Found the node, position at its end
        final node = parentList[foundIndex];
        if (node is LiteralNode) {
          cursor = EditorCursor(
            parentId: parentInfo.parentId,
            path: parentInfo.path,
            index: foundIndex,
            subIndex: node.text.length,
          );
        } else if (node is ParenthesisNode) {
          _moveCursorToEndOfList(node.content, node.id, 'content');
        } else if (node is FractionNode) {
          _moveCursorToEndOfList(node.denominator, node.id, 'den');
        } else if (node is ExponentNode) {
          _moveCursorToEndOfList(node.power, node.id, 'pow');
        } else if (node is AnsNode) {
          // <== ADD THIS
          _moveCursorToEndOfList(node.index, node.id, 'index');
        } else if (node is TrigNode) {
          // <== ADD THIS TOO
          _moveCursorToEndOfList(node.argument, node.id, 'arg');
        } else if (node is RootNode) {
          // <== AND THIS
          _moveCursorToEndOfList(node.radicand, node.id, 'radicand');
        } else if (node is LogNode) {
          // <== AND THIS
          _moveCursorToEndOfList(node.argument, node.id, 'arg');
        } else if (node is PermutationNode) {
          // <-- ADD THIS
          _moveCursorToEndOfList(node.r, node.id, 'r');
        } else if (node is CombinationNode) {
          // <-- ADD THIS
          _moveCursorToEndOfList(node.r, node.id, 'r');
        }
      } else {
        // The last node was a LiteralNode that got merged
        final mergedNode = parentList[mergeStartIndex];
        if (mergedNode is LiteralNode) {
          cursor = EditorCursor(
            parentId: parentInfo.parentId,
            path: parentInfo.path,
            index: mergeStartIndex,
            subIndex: mergedNode.text.length,
          );
        } else {
          cursor = EditorCursor(
            parentId: parentInfo.parentId,
            path: parentInfo.path,
            index: mergeStartIndex,
            subIndex: 0,
          );
        }
      }
    }

    _notifyStructureChanged();
  }

  void _removeFraction(FractionNode frac) {
    final parentInfo = _findParentListOf(frac.id);
    if (parentInfo == null) return;
    final parentList = parentInfo.list;
    final fracIndex = parentInfo.index;

    int textLengthBefore = 0;
    if (fracIndex > 0 && parentList[fracIndex - 1] is LiteralNode) {
      textLengthBefore = (parentList[fracIndex - 1] as LiteralNode).text.length;
    }

    parentList.removeAt(fracIndex);
    if (parentList.isEmpty) {
      parentList.add(LiteralNode());
      cursor = EditorCursor(
        parentId: parentInfo.parentId,
        path: parentInfo.path,
        index: 0,
        subIndex: 0,
      );
      _notifyStructureChanged();
      return;
    }

    int mergeStartIndex = (fracIndex > 0) ? fracIndex - 1 : 0;
    _mergeAdjacentLiteralsFrom(parentList, mergeStartIndex);
    _positionCursorAtOffset(
      parentList,
      mergeStartIndex,
      textLengthBefore,
      parentInfo.parentId,
      parentInfo.path,
    );
    _notifyStructureChanged();
  }

  void _unwrapExponent(ExponentNode exp) {
    final parentInfo = _findParentListOf(exp.id);
    if (parentInfo == null) return;
    final parentList = parentInfo.list;
    final expIndex = parentInfo.index;

    List<MathNode> replacement =
        _isListEffectivelyEmpty(exp.base) ? [] : List<MathNode>.from(exp.base);

    parentList.removeAt(expIndex);
    if (replacement.isNotEmpty) {
      parentList.insertAll(expIndex, replacement);
    }

    if (parentList.isEmpty) {
      parentList.add(LiteralNode());
      cursor = EditorCursor(
        parentId: parentInfo.parentId,
        path: parentInfo.path,
        index: 0,
        subIndex: 0,
      );
      _notifyStructureChanged();
      return;
    }

    int mergeStartIndex = (expIndex > 0) ? expIndex - 1 : 0;
    _mergeAdjacentLiteralsFrom(parentList, mergeStartIndex);

    // Position cursor at end of base content
    if (replacement.isEmpty) {
      // No content was inserted
      if (mergeStartIndex < parentList.length) {
        final node = parentList[mergeStartIndex];
        if (node is LiteralNode) {
          cursor = EditorCursor(
            parentId: parentInfo.parentId,
            path: parentInfo.path,
            index: mergeStartIndex,
            subIndex: node.text.length,
          );
        } else {
          cursor = EditorCursor(
            parentId: parentInfo.parentId,
            path: parentInfo.path,
            index: mergeStartIndex,
            subIndex: 0,
          );
        }
      } else {
        cursor = EditorCursor(
          parentId: parentInfo.parentId,
          path: parentInfo.path,
          index: 0,
          subIndex: 0,
        );
      }
    } else {
      // Find the last node of the base by its ID
      MathNode lastBaseNode = replacement.last;

      int foundIndex = -1;
      for (int i = 0; i < parentList.length; i++) {
        if (parentList[i].id == lastBaseNode.id) {
          foundIndex = i;
          break;
        }
      }

      if (foundIndex != -1) {
        // Found the node, position at its end
        final node = parentList[foundIndex];
        if (node is LiteralNode) {
          cursor = EditorCursor(
            parentId: parentInfo.parentId,
            path: parentInfo.path,
            index: foundIndex,
            subIndex: node.text.length,
          );
        } else if (node is ParenthesisNode) {
          _moveCursorToEndOfList(node.content, node.id, 'content');
        } else if (node is FractionNode) {
          _moveCursorToEndOfList(node.denominator, node.id, 'den');
        } else if (node is ExponentNode) {
          _moveCursorToEndOfList(node.power, node.id, 'pow');
        } else if (node is AnsNode) {
          _moveCursorToEndOfList(node.index, node.id, 'index');
        } else if (node is TrigNode) {
          _moveCursorToEndOfList(node.argument, node.id, 'arg');
        } else if (node is RootNode) {
          _moveCursorToEndOfList(node.radicand, node.id, 'radicand');
        } else if (node is LogNode) {
          _moveCursorToEndOfList(node.argument, node.id, 'arg');
        } else if (node is PermutationNode) {
          // <-- ADD THIS
          _moveCursorToEndOfList(node.r, node.id, 'r');
        } else if (node is CombinationNode) {
          // <-- ADD THIS
          _moveCursorToEndOfList(node.r, node.id, 'r');
        }
      } else {
        // The last node was a LiteralNode that got merged
        final mergedNode = parentList[mergeStartIndex];
        if (mergedNode is LiteralNode) {
          cursor = EditorCursor(
            parentId: parentInfo.parentId,
            path: parentInfo.path,
            index: mergeStartIndex,
            subIndex: mergedNode.text.length,
          );
        } else {
          cursor = EditorCursor(
            parentId: parentInfo.parentId,
            path: parentInfo.path,
            index: mergeStartIndex,
            subIndex: 0,
          );
        }
      }
    }

    _notifyStructureChanged();
  }

  void _removeExponent(ExponentNode exp) {
    final parentInfo = _findParentListOf(exp.id);
    if (parentInfo == null) return;
    final parentList = parentInfo.list;
    final expIndex = parentInfo.index;

    int textLengthBefore = 0;
    if (expIndex > 0 && parentList[expIndex - 1] is LiteralNode) {
      textLengthBefore = (parentList[expIndex - 1] as LiteralNode).text.length;
    }

    parentList.removeAt(expIndex);
    if (parentList.isEmpty) {
      parentList.add(LiteralNode());
      cursor = EditorCursor(
        parentId: parentInfo.parentId,
        path: parentInfo.path,
        index: 0,
        subIndex: 0,
      );
      _notifyStructureChanged();
      return;
    }

    int mergeStartIndex = (expIndex > 0) ? expIndex - 1 : 0;
    _mergeAdjacentLiteralsFrom(parentList, mergeStartIndex);
    _positionCursorAtOffset(
      parentList,
      mergeStartIndex,
      textLengthBefore,
      parentInfo.parentId,
      parentInfo.path,
    );
    _notifyStructureChanged();
  }

  void _removeParenthesis(ParenthesisNode paren) {
    final parentInfo = _findParentListOf(paren.id);
    if (parentInfo == null) return;
    final parentList = parentInfo.list;
    final parenIndex = parentInfo.index;

    int textLengthBefore = 0;
    if (parenIndex > 0 && parentList[parenIndex - 1] is LiteralNode) {
      textLengthBefore =
          (parentList[parenIndex - 1] as LiteralNode).text.length;
    }

    parentList.removeAt(parenIndex);
    if (parentList.isEmpty) {
      parentList.add(LiteralNode());
      cursor = EditorCursor(
        parentId: parentInfo.parentId,
        path: parentInfo.path,
        index: 0,
        subIndex: 0,
      );
      _notifyStructureChanged();
      return;
    }

    int mergeStartIndex = (parenIndex > 0) ? parenIndex - 1 : 0;
    _mergeAdjacentLiteralsFrom(parentList, mergeStartIndex);
    _positionCursorAtOffset(
      parentList,
      mergeStartIndex,
      textLengthBefore,
      parentInfo.parentId,
      parentInfo.path,
    );
    _notifyStructureChanged();
  }

  void _removeNewline(NewlineNode newline) {
    final parentInfo = _findParentListOf(newline.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final newlineIndex = parentInfo.index;

    int textLengthBefore = 0;
    if (newlineIndex > 0 && parentList[newlineIndex - 1] is LiteralNode) {
      textLengthBefore =
          (parentList[newlineIndex - 1] as LiteralNode).text.length;
    }

    parentList.removeAt(newlineIndex);

    if (parentList.isEmpty) {
      parentList.add(LiteralNode());
      cursor = EditorCursor(
        parentId: parentInfo.parentId,
        path: parentInfo.path,
        index: 0,
        subIndex: 0,
      );
      _notifyStructureChanged();
      return;
    }

    int mergeStartIndex = (newlineIndex > 0) ? newlineIndex - 1 : 0;
    _mergeAdjacentLiteralsFrom(parentList, mergeStartIndex);
    _positionCursorAtOffset(
      parentList,
      mergeStartIndex,
      textLengthBefore,
      parentInfo.parentId,
      parentInfo.path,
    );
    _notifyStructureChanged();
  }

  // ============== REMOVE METHODS ==============
  void _removeTrig(TrigNode trig) {
    final parentInfo = _findParentListOf(trig.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final trigIndex = parentInfo.index;

    int textLengthBefore = 0;
    if (trigIndex > 0 && parentList[trigIndex - 1] is LiteralNode) {
      textLengthBefore = (parentList[trigIndex - 1] as LiteralNode).text.length;
    }

    parentList.removeAt(trigIndex);

    if (parentList.isEmpty) {
      parentList.add(LiteralNode());
      cursor = EditorCursor(
        parentId: parentInfo.parentId,
        path: parentInfo.path,
        index: 0,
        subIndex: 0,
      );
      _notifyStructureChanged();
      return;
    }

    int mergeStartIndex = (trigIndex > 0) ? trigIndex - 1 : 0;
    _mergeAdjacentLiteralsFrom(parentList, mergeStartIndex);
    _positionCursorAtOffset(
      parentList,
      mergeStartIndex,
      textLengthBefore,
      parentInfo.parentId,
      parentInfo.path,
    );
    _notifyStructureChanged();
  }

  void _removeRoot(RootNode root) {
    final parentInfo = _findParentListOf(root.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final rootIndex = parentInfo.index;

    int textLengthBefore = 0;
    if (rootIndex > 0 && parentList[rootIndex - 1] is LiteralNode) {
      textLengthBefore = (parentList[rootIndex - 1] as LiteralNode).text.length;
    }

    parentList.removeAt(rootIndex);

    if (parentList.isEmpty) {
      parentList.add(LiteralNode());
      cursor = EditorCursor(
        parentId: parentInfo.parentId,
        path: parentInfo.path,
        index: 0,
        subIndex: 0,
      );
      _notifyStructureChanged();
      return;
    }

    int mergeStartIndex = (rootIndex > 0) ? rootIndex - 1 : 0;
    _mergeAdjacentLiteralsFrom(parentList, mergeStartIndex);
    _positionCursorAtOffset(
      parentList,
      mergeStartIndex,
      textLengthBefore,
      parentInfo.parentId,
      parentInfo.path,
    );
    _notifyStructureChanged();
  }

  void _removePermutation(PermutationNode perm) {
    final parentInfo = _findParentListOf(perm.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final permIndex = parentInfo.index;

    int textLengthBefore = 0;
    if (permIndex > 0 && parentList[permIndex - 1] is LiteralNode) {
      textLengthBefore = (parentList[permIndex - 1] as LiteralNode).text.length;
    }

    parentList.removeAt(permIndex);

    if (parentList.isEmpty) {
      parentList.add(LiteralNode());
      cursor = EditorCursor(
        parentId: parentInfo.parentId,
        path: parentInfo.path,
        index: 0,
        subIndex: 0,
      );
      _notifyStructureChanged();
      return;
    }

    int mergeStartIndex = (permIndex > 0) ? permIndex - 1 : 0;
    _mergeAdjacentLiteralsFrom(parentList, mergeStartIndex);
    _positionCursorAtOffset(
      parentList,
      mergeStartIndex,
      textLengthBefore,
      parentInfo.parentId,
      parentInfo.path,
    );
    _notifyStructureChanged();
  }

  void _removeCombination(CombinationNode comb) {
    final parentInfo = _findParentListOf(comb.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final combIndex = parentInfo.index;

    int textLengthBefore = 0;
    if (combIndex > 0 && parentList[combIndex - 1] is LiteralNode) {
      textLengthBefore = (parentList[combIndex - 1] as LiteralNode).text.length;
    }

    parentList.removeAt(combIndex);

    if (parentList.isEmpty) {
      parentList.add(LiteralNode());
      cursor = EditorCursor(
        parentId: parentInfo.parentId,
        path: parentInfo.path,
        index: 0,
        subIndex: 0,
      );
      _notifyStructureChanged();
      return;
    }

    int mergeStartIndex = (combIndex > 0) ? combIndex - 1 : 0;
    _mergeAdjacentLiteralsFrom(parentList, mergeStartIndex);
    _positionCursorAtOffset(
      parentList,
      mergeStartIndex,
      textLengthBefore,
      parentInfo.parentId,
      parentInfo.path,
    );
    _notifyStructureChanged();
  }

  void _removeAns(AnsNode ans) {
    final parentInfo = _findParentListOf(ans.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final ansIndex = parentInfo.index;

    int textLengthBefore = 0;
    if (ansIndex > 0 && parentList[ansIndex - 1] is LiteralNode) {
      textLengthBefore = (parentList[ansIndex - 1] as LiteralNode).text.length;
    }

    parentList.removeAt(ansIndex);

    if (parentList.isEmpty) {
      parentList.add(LiteralNode());
      cursor = EditorCursor(
        parentId: parentInfo.parentId,
        path: parentInfo.path,
        index: 0,
        subIndex: 0,
      );
      _notifyStructureChanged();
      return;
    }

    int mergeStartIndex = (ansIndex > 0) ? ansIndex - 1 : 0;
    _mergeAdjacentLiteralsFrom(parentList, mergeStartIndex);
    _positionCursorAtOffset(
      parentList,
      mergeStartIndex,
      textLengthBefore,
      parentInfo.parentId,
      parentInfo.path,
    );
    _notifyStructureChanged();
  }

  void _removeLog(LogNode log) {
    final parentInfo = _findParentListOf(log.id);
    if (parentInfo == null) return;

    final parentList = parentInfo.list;
    final logIndex = parentInfo.index;

    int textLengthBefore = 0;
    if (logIndex > 0 && parentList[logIndex - 1] is LiteralNode) {
      textLengthBefore = (parentList[logIndex - 1] as LiteralNode).text.length;
    }

    parentList.removeAt(logIndex);

    if (parentList.isEmpty) {
      parentList.add(LiteralNode());
      cursor = EditorCursor(
        parentId: parentInfo.parentId,
        path: parentInfo.path,
        index: 0,
        subIndex: 0,
      );
      _notifyStructureChanged();
      return;
    }

    int mergeStartIndex = (logIndex > 0) ? logIndex - 1 : 0;
    _mergeAdjacentLiteralsFrom(parentList, mergeStartIndex);
    _positionCursorAtOffset(
      parentList,
      mergeStartIndex,
      textLengthBefore,
      parentInfo.parentId,
      parentInfo.path,
    );
    _notifyStructureChanged();
  }

  void _positionCursorAtOffset(
    List<MathNode> list,
    int nodeIndex,
    int targetOffset,
    String? parentId,
    String? path,
  ) {
    if (nodeIndex >= list.length) nodeIndex = list.length - 1;
    if (nodeIndex < 0) nodeIndex = 0;
    final node = list[nodeIndex];
    if (node is LiteralNode) {
      cursor = EditorCursor(
        parentId: parentId,
        path: path,
        index: nodeIndex,
        subIndex: targetOffset.clamp(0, node.text.length),
      );
    } else {
      cursor = EditorCursor(
        parentId: parentId,
        path: path,
        index: nodeIndex,
        subIndex: 0,
      );
    }
  }

  void moveRight() {
    final siblings = _resolveSiblingList();
    final node = _resolveCursorNode();

    if (node is LiteralNode) {
      if (cursor.subIndex < node.text.length) {
        cursor = cursor.copyWith(subIndex: cursor.subIndex + 1);
      } else if (cursor.index < siblings.length - 1) {
        final nextNode = siblings[cursor.index + 1];
        if (nextNode is LiteralNode) {
          cursor = cursor.copyWith(index: cursor.index + 1, subIndex: 0);
        } else if (nextNode is FractionNode) {
          _moveCursorToStartOfList(nextNode.numerator, nextNode.id, 'num');
        } else if (nextNode is ExponentNode) {
          _moveCursorToStartOfList(nextNode.base, nextNode.id, 'base');
        } else if (nextNode is ParenthesisNode) {
          _moveCursorToStartOfList(nextNode.content, nextNode.id, 'content');
        } else if (nextNode is AnsNode) {
          _moveCursorToStartOfList(nextNode.index, nextNode.id, 'index');
        } else if (nextNode is NewlineNode) {
          if (cursor.index + 2 < siblings.length) {
            cursor = cursor.copyWith(index: cursor.index + 2, subIndex: 0);
          }
        }
        // ... other node types
      } else if (cursor.parentId != null) {
        _exitNestedStructureRight();
      }
      notifyListeners();
    }
  }

  // void _moveCursorAfterNode(String nodeId) =>
  //     _findAndPositionAfter(expression, nodeId, null, null);

  void moveLeft() {
    if (cursor.subIndex > 0) {
      cursor = cursor.copyWith(subIndex: cursor.subIndex - 1);
      notifyListeners();
      return;
    }

    final siblings = _resolveSiblingList();
    if (cursor.index > 0) {
      final prevNode = siblings[cursor.index - 1];
      if (prevNode is LiteralNode) {
        cursor = cursor.copyWith(
          index: cursor.index - 1,
          subIndex: prevNode.text.length,
        );
      } else if (prevNode is FractionNode) {
        _moveCursorToEndOfList(prevNode.denominator, prevNode.id, 'den');
      } else if (prevNode is ExponentNode) {
        _moveCursorToEndOfList(prevNode.power, prevNode.id, 'pow');
      } else if (prevNode is ParenthesisNode) {
        _moveCursorToEndOfList(prevNode.content, prevNode.id, 'content');
      } else if (prevNode is AnsNode) {
        _moveCursorToEndOfList(prevNode.index, prevNode.id, 'index');
      } else if (prevNode is NewlineNode) {
        if (cursor.index - 2 >= 0) {
          final beforeNewline = siblings[cursor.index - 2];
          if (beforeNewline is LiteralNode) {
            cursor = cursor.copyWith(
              index: cursor.index - 2,
              subIndex: beforeNewline.text.length,
            );
          }
        }
      }
      // ... other node types
      notifyListeners();
      return;
    }

    if (cursor.parentId != null) {
      _exitNestedStructureLeft();
      notifyListeners();
    }
  }

  void _exitNestedStructureRight() {
    final parent = _findNode(expression, cursor.parentId!);

    if (parent is FractionNode) {
      if (cursor.path == 'num') {
        _moveCursorToStartOfList(parent.denominator, parent.id, 'den');
      } else {
        _moveCursorAfterNode(parent.id);
      }
    } else if (parent is ExponentNode) {
      if (cursor.path == 'base') {
        _moveCursorToStartOfList(parent.power, parent.id, 'pow');
      } else {
        _moveCursorAfterNode(parent.id);
      }
    } else if (parent is ParenthesisNode) {
      _moveCursorAfterNode(parent.id);
    } else if (parent is TrigNode) {
      _moveCursorAfterNode(parent.id);
    } else if (parent is RootNode) {
      if (cursor.path == 'index') {
        _moveCursorToStartOfList(parent.radicand, parent.id, 'radicand');
      } else {
        _moveCursorAfterNode(parent.id);
      }
    } else if (parent is LogNode) {
      if (cursor.path == 'base') {
        _moveCursorToStartOfList(parent.argument, parent.id, 'arg');
      } else {
        _moveCursorAfterNode(parent.id);
      }
    } else if (parent is PermutationNode) {
      if (cursor.path == 'n') {
        _moveCursorToStartOfList(parent.r, parent.id, 'r');
      } else {
        _moveCursorAfterNode(parent.id);
      }
    } else if (parent is CombinationNode) {
      if (cursor.path == 'n') {
        _moveCursorToStartOfList(parent.r, parent.id, 'r');
      } else {
        _moveCursorAfterNode(parent.id);
      }
    } else if (parent is AnsNode) {
      _moveCursorAfterNode(parent.id);
    }
  }

  void _exitNestedStructureLeft() {
    final parent = _findNode(expression, cursor.parentId!);

    if (parent is FractionNode) {
      if (cursor.path == 'den') {
        _moveCursorToEndOfList(parent.numerator, parent.id, 'num');
      } else {
        _moveCursorBeforeNode(parent.id);
      }
    } else if (parent is ExponentNode) {
      if (cursor.path == 'pow') {
        _moveCursorToEndOfList(parent.base, parent.id, 'base');
      } else {
        _moveCursorBeforeNode(parent.id);
      }
    } else if (parent is ParenthesisNode) {
      _moveCursorBeforeNode(parent.id);
    } else if (parent is TrigNode) {
      _moveCursorBeforeNode(parent.id);
    } else if (parent is RootNode) {
      if (cursor.path == 'radicand') {
        if (!parent.isSquareRoot) {
          _moveCursorToEndOfList(parent.index, parent.id, 'index');
        } else {
          _moveCursorBeforeNode(parent.id);
        }
      } else {
        _moveCursorBeforeNode(parent.id);
      }
    } else if (parent is LogNode) {
      if (cursor.path == 'arg') {
        if (!parent.isNaturalLog) {
          _moveCursorToEndOfList(parent.base, parent.id, 'base');
        } else {
          _moveCursorBeforeNode(parent.id);
        }
      } else {
        _moveCursorBeforeNode(parent.id);
      }
    } else if (parent is PermutationNode) {
      if (cursor.path == 'r') {
        _moveCursorToEndOfList(parent.n, parent.id, 'n');
      } else {
        _moveCursorBeforeNode(parent.id);
      }
    } else if (parent is CombinationNode) {
      if (cursor.path == 'r') {
        _moveCursorToEndOfList(parent.n, parent.id, 'n');
      } else {
        _moveCursorBeforeNode(parent.id);
      }
    } else if (parent is AnsNode) {
      _moveCursorBeforeNode(parent.id);
    }
  }

  /// Gets the serialized expression string for solving
  String getExpression() {
    return MathExpressionSerializer.serialize(expression);
  }

  /// Gets variables used in the expression
  Set<String> getVariables() {
    return MathExpressionSerializer.extractVariables(expression);
  }

  /// Checks if current expression is an equation
  bool isEquation() {
    return MathExpressionSerializer.isEquation(expression);
  }

  // Add this to MathEditorController
  void navigateTo({
    required String? parentId,
    required String? path,
    required int index,
    required int subIndex,
  }) {
    cursor = EditorCursor(
      parentId: parentId,
      path: path,
      index: index,
      subIndex: subIndex,
    );
    notifyListeners();
  }
}

class MathEditorInline extends StatefulWidget {
  final MathEditorController controller;
  final bool showCursor;
  final VoidCallback? onFocus; // <-- Add this

  const MathEditorInline({
    super.key,
    required this.controller,
    this.showCursor = true,
    this.onFocus, // <-- Add this
  });

  @override
  State<MathEditorInline> createState() => _MathEditorInlineState();
}

class _MathEditorInlineState extends State<MathEditorInline>
    with SingleTickerProviderStateMixin {
  late AnimationController _cursorBlinkController;
  late Animation<double> _cursorBlinkAnimation;
  final GlobalKey _containerKey = GlobalKey();
  int _lastStructureVersion = -1;

  @override
  void initState() {
    super.initState();
    _cursorBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _cursorBlinkAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_cursorBlinkController);
  }

  @override
  void dispose() {
    _cursorBlinkController.dispose();
    super.dispose();
  }

  void _handleTap(TapDownDetails details) {
    // Call onFocus to notify parent that this editor was tapped
    widget.onFocus?.call(); // <-- Add this line at the beginning

    final RenderBox? containerBox =
        _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (containerBox == null) {
      widget.controller.tapAt(details.localPosition);
      return;
    }
    final RenderBox? gestureBox = context.findRenderObject() as RenderBox?;
    if (gestureBox == null) {
      widget.controller.tapAt(details.localPosition);
      return;
    }
    final Offset globalTapPos = gestureBox.localToGlobal(details.localPosition);
    final Offset localToContainer = containerBox.globalToLocal(globalTapPos);
    widget.controller.tapAt(localToContainer);
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (_lastStructureVersion != widget.controller.structureVersion) {
          _lastStructureVersion = widget.controller.structureVersion;
          widget.controller.clearLayoutRegistry();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: _handleTap,
              child: Container(
                width:
                    constraints.maxWidth.isFinite ? constraints.maxWidth : null,
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: KeyedSubtree(
                    key: _containerKey,
                    child: AnimatedBuilder(
                      animation: _cursorBlinkAnimation,
                      builder: (context, _) {
                        return MathRenderer(
                          expression: widget.controller.expression,
                          cursor: widget.controller.cursor,
                          cursorOpacity:
                              widget.showCursor
                                  ? _cursorBlinkAnimation.value
                                  : 0.0,
                          rootKey: _containerKey,
                          controller: widget.controller,
                          structureVersion: widget.controller.structureVersion,
                          textScaler: textScaler,
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class MathRenderer extends StatelessWidget {
  final List<MathNode> expression;
  final EditorCursor cursor;
  final double cursorOpacity;
  final GlobalKey rootKey;
  final MathEditorController controller;
  final int structureVersion;
  final TextScaler textScaler;

  const MathRenderer({
    super.key,
    required this.expression,
    required this.cursor,
    required this.cursorOpacity,
    required this.rootKey,
    required this.controller,
    required this.structureVersion,
    required this.textScaler,
  });

  static const double _nodePadding = 0.0;

  @override
  Widget build(BuildContext context) {
    // Split expression into lines
    List<_LineInfo> lines = _splitIntoLines(expression);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children:
          lines.asMap().entries.map((entry) {
            // int lineIndex = entry.key;
            _LineInfo lineInfo = entry.value;

            return Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children:
                    lineInfo.nodes.asMap().entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: _renderNode(
                          e.value,
                          lineInfo.startIndex + e.key, // Use global index
                          expression, // Pass full expression for sibling reference
                          null,
                          null,
                          FONTSIZE,
                        ),
                      );
                    }).toList(),
              ),
            );
          }).toList(),
    );
  }

  /// Splits expression into lines at NewlineNode boundaries
  List<_LineInfo> _splitIntoLines(List<MathNode> nodes) {
    List<_LineInfo> lines = [];
    List<MathNode> currentLine = [];
    int startIndex = 0;

    for (int i = 0; i < nodes.length; i++) {
      if (nodes[i] is NewlineNode) {
        // End current line
        if (currentLine.isEmpty) {
          currentLine.add(LiteralNode(text: ''));
        }
        lines.add(
          _LineInfo(nodes: List.from(currentLine), startIndex: startIndex),
        );
        currentLine = [];
        startIndex = i + 1;
      } else {
        currentLine.add(nodes[i]);
      }
    }

    // Add last line
    if (currentLine.isEmpty) {
      currentLine.add(LiteralNode(text: ''));
    }
    lines.add(_LineInfo(nodes: currentLine, startIndex: startIndex));

    return lines;
  }

  Widget _renderNode(
    MathNode node,
    int index,
    List<MathNode> siblings,
    String? parentId,
    String? path,
    double fontSize,
  ) {
    // Skip rendering NewlineNode (it's handled by line splitting)
    if (node is NewlineNode) {
      return const SizedBox.shrink();
    }

    if (node is LiteralNode) {
      final active =
          cursor.parentId == parentId &&
          cursor.path == path &&
          cursor.index == index;
      return LiteralWidget(
        key: ValueKey('${node.id}_$structureVersion'),
        node: node,
        active: active,
        cursorOpacity: cursorOpacity,
        subIndex: cursor.subIndex,
        fontSize: fontSize,
        isLast: index == siblings.length - 1,
        parentId: parentId,
        path: path,
        index: index,
        rootKey: rootKey,
        controller: controller,
        structureVersion: structureVersion,
        textScaler: textScaler,
      );
    }

    if (node is FractionNode) {
      final bool numEmpty = _isContentEmpty(node.numerator);
      final bool denEmpty = _isContentEmpty(node.denominator);

      return Padding(
        padding: const EdgeInsets.only(right: _nodePadding),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Numerator
              numEmpty
                  ? GestureDetector(
                    onTap:
                        () => controller.navigateTo(
                          parentId: node.id,
                          path: 'num',
                          index: 0,
                          subIndex: 0,
                        ),
                    child: PlaceholderBox(
                      fontSize: fontSize,
                      minWidth: fontSize * 1.0,
                      minHeight: fontSize * 0.8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children:
                            node.numerator
                                .asMap()
                                .entries
                                .map(
                                  (e) => _renderNode(
                                    e.value,
                                    e.key,
                                    node.numerator,
                                    node.id,
                                    'num',
                                    fontSize,
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  )
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        node.numerator
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.numerator,
                                node.id,
                                'num',
                                fontSize,
                              ),
                            )
                            .toList(),
                  ),

              // Fraction line
              Container(
                height: math.max(1.5, fontSize * 0.06),
                width: double.infinity,
                color: Colors.white,
                margin: EdgeInsets.symmetric(vertical: fontSize * 0.15),
              ),

              // Denominator
              denEmpty
                  ? GestureDetector(
                    onTap:
                        () => controller.navigateTo(
                          parentId: node.id,
                          path: 'den',
                          index: 0,
                          subIndex: 0,
                        ),
                    child: PlaceholderBox(
                      fontSize: fontSize,
                      minWidth: fontSize * 1.0,
                      minHeight: fontSize * 0.8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children:
                            node.denominator
                                .asMap()
                                .entries
                                .map(
                                  (e) => _renderNode(
                                    e.value,
                                    e.key,
                                    node.denominator,
                                    node.id,
                                    'den',
                                    fontSize,
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  )
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        node.denominator
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.denominator,
                                node.id,
                                'den',
                                fontSize,
                              ),
                            )
                            .toList(),
                  ),
            ],
          ),
        ),
      );
    }

    if (node is ExponentNode) {
      final double powerSize = fontSize * 0.8;
      final double powerRaise = fontSize * 0.35;

      final bool baseEmpty = _isContentEmpty(node.base);
      final bool powerEmpty = _isContentEmpty(node.power);

      // Build base widget
      Widget baseWidget =
          baseEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'base',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: fontSize,
                  minWidth: fontSize * 0.7,
                  minHeight: fontSize * 0.9,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children:
                        node.base
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.base,
                                node.id,
                                'base',
                                fontSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children:
                    node.base
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.base,
                            node.id,
                            'base',
                            fontSize,
                          ),
                        )
                        .toList(),
              );

      // Build power widget
      Widget powerWidget =
          powerEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'pow',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: powerSize,
                  minWidth: powerSize * 0.6,
                  minHeight: powerSize * 0.7,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        node.power
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.power,
                                node.id,
                                'pow',
                                powerSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    node.power
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.power,
                            node.id,
                            'pow',
                            powerSize,
                          ),
                        )
                        .toList(),
              );

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Base
          baseWidget,
          // Power - raised using Transform
          Transform.translate(
            offset: Offset(0, -powerRaise),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: fontSize * 0.15,
                vertical: fontSize * 0.1,
              ),
              child: powerWidget,
            ),
          ),
        ],
      );
    }

    if (node is ParenthesisNode) {
      final bool contentEmpty = _isContentEmpty(node.content);

      Widget contentWidget =
          contentEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'content',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: fontSize,
                  minWidth: fontSize * 0.8,
                  minHeight: fontSize * 0.9,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children:
                        node.content
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.content,
                                node.id,
                                'content',
                                fontSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children:
                    node.content
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.content,
                            node.id,
                            'content',
                            fontSize,
                          ),
                        )
                        .toList(),
              );

      return IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScalableParenthesis(
              isOpening: true,
              fontSize: fontSize,
              color: Colors.white,
              textScaler: textScaler,
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: fontSize * 0.15,
                vertical: fontSize * 0.1,
              ),
              child: contentWidget,
            ),
            ScalableParenthesis(
              isOpening: false,
              fontSize: fontSize,
              color: Colors.white,
              textScaler: textScaler,
            ),
          ],
        ),
      );
    }

    if (node is TrigNode) {
      final bool argEmpty = _isContentEmpty(node.argument);

      // Build argument widget
      Widget argWidget =
          argEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'arg',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: fontSize,
                  minWidth: fontSize * 0.8,
                  minHeight: fontSize * 0.9,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children:
                        node.argument
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.argument,
                                node.id,
                                'arg',
                                fontSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children:
                    node.argument
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.argument,
                            node.id,
                            'arg',
                            fontSize,
                          ),
                        )
                        .toList(),
              );

      return Padding(
        padding: const EdgeInsets.only(right: _nodePadding),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Function name (sin, cos, etc.)
              Text(
                node.function,
                style: MathTextStyle.getStyle(
                  fontSize,
                ).copyWith(color: Colors.white),
                textScaler: textScaler,
              ),
              // Parentheses with content
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScalableParenthesis(
                      isOpening: true,
                      fontSize: fontSize,
                      color: Colors.white,
                      textScaler: textScaler,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: fontSize * 0.25,
                        vertical: fontSize * 0.1,
                      ),
                      child: argWidget,
                    ),
                    ScalableParenthesis(
                      isOpening: false,
                      fontSize: fontSize,
                      color: Colors.white,
                      textScaler: textScaler,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (node is RootNode) {
      final double indexSize = fontSize * 0.7;
      final double minRadicandHeight = fontSize * 1.2;

      final bool radicandEmpty = _isContentEmpty(node.radicand);
      final bool indexEmpty = !node.isSquareRoot && _isContentEmpty(node.index);

      // Build radicand widget
      Widget radicandWidget =
          radicandEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'radicand',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: fontSize,
                  minWidth: fontSize * 0.9,
                  minHeight: fontSize * 0.9,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        node.radicand
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.radicand,
                                node.id,
                                'radicand',
                                fontSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    node.radicand
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.radicand,
                            node.id,
                            'radicand',
                            fontSize,
                          ),
                        )
                        .toList(),
              );

      // Build index widget for nth roots
      Widget? indexWidget;
      if (!node.isSquareRoot) {
        indexWidget =
            indexEmpty
                ? GestureDetector(
                  onTap:
                      () => controller.navigateTo(
                        parentId: node.id,
                        path: 'index',
                        index: 0,
                        subIndex: 0,
                      ),
                  child: PlaceholderBox(
                    fontSize: indexSize,
                    minWidth: indexSize * 0.7,
                    minHeight: indexSize * 0.7,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children:
                          node.index
                              .asMap()
                              .entries
                              .map(
                                (e) => _renderNode(
                                  e.value,
                                  e.key,
                                  node.index,
                                  node.id,
                                  'index',
                                  indexSize,
                                ),
                              )
                              .toList(),
                    ),
                  ),
                )
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      node.index
                          .asMap()
                          .entries
                          .map(
                            (e) => _renderNode(
                              e.value,
                              e.key,
                              node.index,
                              node.id,
                              'index',
                              indexSize,
                            ),
                          )
                          .toList(),
                );
      }

      return Padding(
        padding: const EdgeInsets.only(right: _nodePadding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Index for nth root
            if (indexWidget != null)
              Padding(
                padding: const EdgeInsets.only(right: 1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [indexWidget, SizedBox(height: fontSize * 0.35)],
                ),
              ),

            // Radical symbol + radicand
            IntrinsicHeight(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minRadicandHeight),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: fontSize * 0.6,
                      child: CustomPaint(
                        painter: RadicalSymbolPainter(
                          color: Colors.white,
                          strokeWidth: math.max(1.5, fontSize * 0.06),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white,
                            width: math.max(1.5, fontSize * 0.06),
                          ),
                        ),
                      ),
                      padding: EdgeInsets.only(
                        left: 3,
                        right: 4,
                        top: fontSize * 0.08,
                        bottom: 2,
                      ),
                      child: Center(child: radicandWidget),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

if (node is LogNode) {
  final double baseSize = fontSize * 0.8;
  
  final bool baseEmpty = !node.isNaturalLog && _isContentEmpty(node.base);
  final bool argEmpty = _isContentEmpty(node.argument);

  // Build base widget (only for non-natural log)
  Widget? baseWidget;
  if (!node.isNaturalLog) {
    baseWidget = baseEmpty
        ? GestureDetector(
            onTap: () => controller.navigateTo(
              parentId: node.id,
              path: 'base',
              index: 0,
              subIndex: 0,
            ),
            child: PlaceholderBox(
              fontSize: baseSize,
              minWidth: baseSize * 0.6,
              minHeight: baseSize * 0.7,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: node.base.asMap().entries.map(
                  (e) => _renderNode(e.value, e.key, node.base, node.id, 'base', baseSize),
                ).toList(),
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: node.base.asMap().entries.map(
              (e) => _renderNode(e.value, e.key, node.base, node.id, 'base', baseSize),
            ).toList(),
          );
  }

  // Build argument widget
  Widget argWidget = argEmpty
      ? GestureDetector(
          onTap: () => controller.navigateTo(
            parentId: node.id,
            path: 'arg',
            index: 0,
            subIndex: 0,
          ),
          child: PlaceholderBox(
            fontSize: fontSize,
            minWidth: fontSize * 0.8,
            minHeight: fontSize * 0.9,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: node.argument.asMap().entries.map(
                (e) => _renderNode(e.value, e.key, node.argument, node.id, 'arg', fontSize),
              ).toList(),
            ),
          ),
        )
      : Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: node.argument.asMap().entries.map(
            (e) => _renderNode(e.value, e.key, node.argument, node.id, 'arg', fontSize),
          ).toList(),
        );

  return Padding(
    padding: const EdgeInsets.only(right: _nodePadding),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // "log" or "ln" text
        Text(
          node.isNaturalLog ? 'ln' : 'log',
          style: MathTextStyle.getStyle(fontSize).copyWith(color: Colors.white),
          textScaler: textScaler,
        ),
        
        // Subscript base - uses Transform for vertical offset only
        // Width is still part of layout flow
        if (!node.isNaturalLog && baseWidget != null)
          Transform.translate(
            offset: Offset(0, fontSize * 0.6), // Vertical subscript offset
            child: Padding(
              padding: EdgeInsets.only(
                left: fontSize * 0.02,  // Small gap after "log"
                right: fontSize * 0.08, // Gap before parentheses
              ),
              child: baseWidget,
            ),
          ),
        
        // Small gap for natural log
        if (node.isNaturalLog)
          SizedBox(width: fontSize * 0.05),
        
        // Parentheses with argument
        IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScalableParenthesis(
                isOpening: true,
                fontSize: fontSize,
                color: Colors.white,
                textScaler: textScaler,
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: fontSize * 0.08,
                  vertical: fontSize * 0.1,
                ),
                child: argWidget,
              ),
              ScalableParenthesis(
                isOpening: false,
                fontSize: fontSize,
                color: Colors.white,
                textScaler: textScaler,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

    if (node is PermutationNode) {
      final double smallSize = fontSize * 0.8;

      final bool nEmpty = _isContentEmpty(node.n);
      final bool rEmpty = _isContentEmpty(node.r);

      // Build n widget (top/superscript)
      Widget nWidget =
          nEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'n',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: smallSize,
                  minWidth: smallSize * 0.6,
                  minHeight: smallSize * 0.7,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        node.n
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.n,
                                node.id,
                                'n',
                                smallSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    node.n
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.n,
                            node.id,
                            'n',
                            smallSize,
                          ),
                        )
                        .toList(),
              );

      // Build r widget (bottom/subscript)
      Widget rWidget =
          rEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'r',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: smallSize,
                  minWidth: smallSize * 0.6,
                  minHeight: smallSize * 0.7,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        node.r
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.r,
                                node.id,
                                'r',
                                smallSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    node.r
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.r,
                            node.id,
                            'r',
                            smallSize,
                          ),
                        )
                        .toList(),
              );

      return Padding(
        padding: const EdgeInsets.only(right: _nodePadding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // n (superscript position)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [nWidget, SizedBox(height: fontSize * 0.8)],
            ),
            // P symbol
            Text(
              'P',
              style: MathTextStyle.getStyle(
                fontSize,
              ).copyWith(color: Colors.white),
              textScaler: textScaler,
            ),
            // r (subscript position)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [SizedBox(height: fontSize * 0.8), rWidget],
            ),
          ],
        ),
      );
    }

    if (node is CombinationNode) {
      final double smallSize = fontSize * 0.8;

      final bool nEmpty = _isContentEmpty(node.n);
      final bool rEmpty = _isContentEmpty(node.r);

      // Build n widget (top/superscript)
      Widget nWidget =
          nEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'n',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: smallSize,
                  minWidth: smallSize * 0.6,
                  minHeight: smallSize * 0.7,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        node.n
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.n,
                                node.id,
                                'n',
                                smallSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    node.n
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.n,
                            node.id,
                            'n',
                            smallSize,
                          ),
                        )
                        .toList(),
              );

      // Build r widget (bottom/subscript)
      Widget rWidget =
          rEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'r',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: smallSize,
                  minWidth: smallSize * 0.6,
                  minHeight: smallSize * 0.7,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        node.r
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.r,
                                node.id,
                                'r',
                                smallSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    node.r
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.r,
                            node.id,
                            'r',
                            smallSize,
                          ),
                        )
                        .toList(),
              );

      return Padding(
        padding: const EdgeInsets.only(right: _nodePadding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // n (superscript position)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [nWidget, SizedBox(height: fontSize * 1)],
            ),
            // C symbol
            Text(
              'C',
              style: MathTextStyle.getStyle(
                fontSize,
              ).copyWith(color: Colors.white),
              textScaler: textScaler,
            ),
            // r (subscript position)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [SizedBox(height: fontSize * 0.8), rWidget],
            ),
          ],
        ),
      );
    }

    if (node is AnsNode) {
      return Padding(
        padding: const EdgeInsets.only(right: _nodePadding),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // "ANS" text
              Text(
                'ans',
                style: MathTextStyle.getStyle(
                  fontSize,
                ).copyWith(color: Colors.orangeAccent),
                textScaler: textScaler,
              ),

              // Index - same size as regular text
              Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    node.index
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.index,
                            node.id,
                            'index',
                            fontSize, // <-- Same size, not smaller
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// Check if a list of nodes is effectively empty
  bool _isContentEmpty(List<MathNode> nodes) {
    if (nodes.isEmpty) return true;
    if (nodes.length == 1 && nodes.first is LiteralNode) {
      return (nodes.first as LiteralNode).text.isEmpty;
    }
    return false;
  }

  // /// Build content with placeholder if empty
  // Widget _buildContentWithPlaceholder({
  //   required List<MathNode> nodes,
  //   required String nodeId,
  //   required String path,
  //   required double fontSize,
  //   double? minWidth,
  //   double? minHeight,
  // }) {
  //   final isEmpty = _isContentEmpty(nodes);

  //   Widget content = Row(
  //     mainAxisSize: MainAxisSize.min,
  //     children:
  //         nodes
  //             .asMap()
  //             .entries
  //             .map(
  //               (e) =>
  //                   _renderNode(e.value, e.key, nodes, nodeId, path, fontSize),
  //             )
  //             .toList(),
  //   );

  //   if (isEmpty) {
  //     return GestureDetector(
  //       onTap: () {
  //         // Navigate cursor to this empty content
  //         controller.navigateTo(
  //           parentId: nodeId,
  //           path: path,
  //           index: 0,
  //           subIndex: 0,
  //         );
  //       },
  //       child: PlaceholderBox(
  //         fontSize: fontSize,
  //         minWidth: minWidth ?? fontSize * 0.8,
  //         minHeight: minHeight ?? fontSize * 0.9,
  //         child: content,
  //       ),
  //     );
  //   }

  //   return content;
  // }
}

class LiteralWidget extends StatefulWidget {
  final LiteralNode node;
  final bool active;
  final double cursorOpacity;
  final int subIndex;
  final double fontSize;
  final bool isLast;
  final String? parentId;
  final String? path;
  final int index;
  final GlobalKey rootKey;
  final MathEditorController controller;
  final int structureVersion;
  final TextScaler textScaler;

  const LiteralWidget({
    super.key,
    required this.node,
    required this.active,
    required this.cursorOpacity,
    required this.subIndex,
    required this.fontSize,
    required this.isLast,
    required this.parentId,
    required this.path,
    required this.index,
    required this.rootKey,
    required this.controller,
    required this.structureVersion,
    required this.textScaler,
  });

  @override
  State<LiteralWidget> createState() => _LiteralWidgetState();
}

class _LiteralWidgetState extends State<LiteralWidget> {
  int _lastReportedVersion = -1;
  final GlobalKey _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reportLayoutIfNeeded(),
    );
  }

  @override
  void didUpdateWidget(covariant LiteralWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.structureVersion != widget.structureVersion ||
        oldWidget.node.id != widget.node.id ||
        oldWidget.node.text != widget.node.text ||
        oldWidget.parentId != widget.parentId ||
        oldWidget.path != widget.path ||
        oldWidget.index != widget.index ||
        oldWidget.fontSize != widget.fontSize) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reportLayoutIfNeeded(),
      );
    }
  }

  void _reportLayoutIfNeeded() {
    if (!mounted) return;
    if (_lastReportedVersion == widget.structureVersion) return;
    _lastReportedVersion = widget.structureVersion;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    final RenderBox? rootBox =
        widget.rootKey.currentContext?.findRenderObject() as RenderBox?;
    if (rootBox == null) return;

    final Offset globalPos = box.localToGlobal(Offset.zero);
    final Offset relativePos = rootBox.globalToLocal(globalPos);
    final rect = relativePos & box.size;

    widget.controller.registerNodeLayout(
      NodeLayoutInfo(
        rect: rect,
        node: widget.node,
        parentId: widget.parentId,
        path: widget.path,
        index: widget.index,
        fontSize: widget.fontSize,
        textScaler: widget.textScaler,
      ),
    );
  }

  double _getCursorOffsetFromRenderParagraph(
    String logicalText,
    String displayText,
  ) {
    if (logicalText.isEmpty || widget.subIndex <= 0) return 0.0;

    final displayIndex = MathTextStyle.logicalToDisplayIndex(
      logicalText,
      widget.subIndex,
    ).clamp(0, displayText.length);

    // Try to get RenderParagraph from the Text widget
    final renderObject = _textKey.currentContext?.findRenderObject();
    if (renderObject is RenderParagraph) {
      final offset = renderObject.getOffsetForCaret(
        TextPosition(offset: displayIndex),
        Rect.zero,
      );
      return offset.dx;
    }

    // Fallback to TextPainter
    final painter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: MathTextStyle.getStyle(
          widget.fontSize,
        ).copyWith(color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
      textScaler: widget.textScaler,
    )..layout();

    final offset = painter.getOffsetForCaret(
      TextPosition(offset: displayIndex),
      Rect.zero,
    );
    painter.dispose();
    return offset.dx;
  }

  @override
  Widget build(BuildContext context) {
    final logicalText = widget.node.text;
    final showCursor = widget.active && widget.cursorOpacity > 0.5;

    final isEmpty = logicalText.isEmpty;

    // Only hide if empty and not active
    final shouldRenderMinimal = isEmpty && !widget.active;

    final displayText = isEmpty ? "" : MathTextStyle.toDisplayText(logicalText);

    double cursorOffset = 0.0;

    return StatefulBuilder(
      builder: (context, setInnerState) {
        if (showCursor && !isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final newOffset = _getCursorOffsetFromRenderParagraph(
              logicalText,
              displayText,
            );
            if (newOffset != cursorOffset && mounted) {
              setInnerState(() {
                cursorOffset = newOffset;
              });
            }
          });
        }

        // Render nothing visible for empty non-active literals
        if (shouldRenderMinimal) {
          return const SizedBox.shrink();
        }

        // For empty but active (cursor here), render minimal width container
        if (isEmpty && widget.active) {
          return SizedBox(
            width: widget.fontSize * 0.5,
            height: widget.fontSize, // Add height constraint
            child:
                showCursor
                    ? Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: math.max(2.0, widget.fontSize * 0.06),
                        height: widget.fontSize,
                        color: Colors.yellowAccent,
                      ),
                    )
                    : null,
          );
        }

        // Normal rendering for non-empty text
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              key: _textKey,
              displayText,
              style: MathTextStyle.getStyle(
                widget.fontSize,
              ).copyWith(color: Colors.white),
              textScaler: widget.textScaler,
            ),
            if (showCursor)
              Positioned(
                left: _getCursorOffsetFromRenderParagraph(
                  logicalText,
                  displayText,
                ),
                top: 0,
                bottom: 0,
                child: Container(
                  width: math.max(2.0, widget.fontSize * 0.06),
                  color: Colors.yellowAccent,
                ),
              ),
          ],
        );
      },
    );
  }
}

class RadicalSymbolPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  RadicalSymbolPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final path = Path();

    double width = size.width;
    double height = size.height;

    // Small horizontal tick at start
    double tickStartX = 0;
    double tickStartY = height * 0.55;
    double tickEndX = width * 0.25;
    double tickEndY = height * 0.6;

    // V bottom point
    double vBottomX = width * 0.5;
    double vBottomY = height - (strokeWidth / 2);

    // Top right of V (connects to vinculum)
    double vTopX = width;
    double vTopY = strokeWidth / 2;

    path.moveTo(tickStartX, tickStartY);
    path.lineTo(tickEndX, tickEndY);
    path.lineTo(vBottomX, vBottomY);
    path.lineTo(vTopX, vTopY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant RadicalSymbolPainter oldDelegate) {
    return color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
  }
}

/// Helper class to track line info
class _LineInfo {
  final List<MathNode> nodes;
  final int startIndex;

  _LineInfo({required this.nodes, required this.startIndex});
}

class ScalableParenthesis extends StatelessWidget {
  final bool isOpening;
  final double fontSize;
  final Color color;
  final TextScaler textScaler;

  const ScalableParenthesis({
    super.key,
    required this.isOpening,
    required this.fontSize,
    this.color = Colors.white,
    required this.textScaler,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: fontSize * 1),
      child: CustomPaint(
        size: Size(fontSize * 0.2, double.infinity), // Reduced from 0.35
        painter: ParenthesisPainter(
          isOpening: isOpening,
          color: color,
          strokeWidth: math.max(1.5, fontSize * 0.06),
        ),
      ),
    );
  }
}

class ParenthesisPainter extends CustomPainter {
  final bool isOpening;
  final Color color;
  final double strokeWidth;

  ParenthesisPainter({
    required this.isOpening,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final path = Path();

    double padding = size.height * 0.05;

    // Control the bow amount here (lower = less bow)
    // Original was -size.width for opening and 2 * size.width for closing
    double bowAmount =
        size.width * 0.3; // Adjust this value (0.0 = straight, 1.0 = more bow)

    if (isOpening) {
      path.moveTo(size.width, padding);
      path.quadraticBezierTo(
        -bowAmount, // Changed from -size.width
        size.height / 2,
        size.width,
        size.height - padding,
      );
    } else {
      path.moveTo(0, padding);
      path.quadraticBezierTo(
        size.width + bowAmount, // Changed from 2 * size.width
        size.height / 2,
        0,
        size.height - padding,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ParenthesisPainter oldDelegate) {
    return oldDelegate.isOpening != isOpening ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
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

class PlaceholderBox extends StatelessWidget {
  final double fontSize;
  final Color color;
  final double? minWidth;
  final double? minHeight;
  final Widget? child;
  final VoidCallback? onTap;

  const PlaceholderBox({
    super.key,
    required this.fontSize,
    this.color = Colors.white,
    this.minWidth,
    this.minHeight,
    this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final boxWidth = minWidth ?? fontSize * 0.8;
    final boxHeight = minHeight ?? fontSize * 0.9;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: CornerBracketPainter(
          color: color,
          strokeWidth: math.max(1.5, fontSize * 0.06),
          cornerLength: fontSize * 0.2,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: boxWidth, minHeight: boxHeight),
          child: Center(
            child: child ?? SizedBox(width: boxWidth, height: boxHeight),
          ),
        ),
      ),
    );
  }
}

class CornerBracketPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;

  CornerBracketPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final double padding = strokeWidth;
    final double len = cornerLength;

    // Top-left corner
    canvas.drawLine(
      Offset(padding, padding + len),
      Offset(padding, padding),
      paint,
    );
    canvas.drawLine(
      Offset(padding, padding),
      Offset(padding + len, padding),
      paint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(size.width - padding - len, padding),
      Offset(size.width - padding, padding),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - padding, padding),
      Offset(size.width - padding, padding + len),
      paint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(padding, size.height - padding - len),
      Offset(padding, size.height - padding),
      paint,
    );
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(padding + len, size.height - padding),
      paint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(size.width - padding - len, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - padding, size.height - padding - len),
      Offset(size.width - padding, size.height - padding),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CornerBracketPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cornerLength != cornerLength;
  }
}
