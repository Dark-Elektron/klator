import 'dart:math' as math;

/// Base class for all math expression nodes.
abstract class MathNode {
  final String id;
  MathNode() : id = math.Random().nextInt(1 << 31).toString();
}

/// A literal text node containing numbers, variables, and operators.
class LiteralNode extends MathNode {
  String text;
  LiteralNode({this.text = ""});
}

/// A fraction node with numerator and denominator.
class FractionNode extends MathNode {
  List<MathNode> numerator;
  List<MathNode> denominator;
  FractionNode({List<MathNode>? num, List<MathNode>? den})
    : numerator = num ?? [LiteralNode()],
      denominator = den ?? [LiteralNode()];
}

/// An exponent node with base and power.
class ExponentNode extends MathNode {
  List<MathNode> base;
  List<MathNode> power;
  ExponentNode({List<MathNode>? base, List<MathNode>? power})
    : base = base ?? [LiteralNode()],
      power = power ?? [LiteralNode()];
}

/// A logarithm node supporting natural log and log with custom base.
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

/// A trigonometric function node (sin, cos, tan, etc.).
class TrigNode extends MathNode {
  final String function; // sin, cos, tan, asin, acos, atan, log, ln
  List<MathNode> argument;
  TrigNode({required this.function, List<MathNode>? argument})
    : argument = argument ?? [LiteralNode()];
}

/// A root node supporting square roots and nth roots.
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

/// A permutation node (nPr).
class PermutationNode extends MathNode {
  List<MathNode> n; // Top number
  List<MathNode> r; // Bottom number
  PermutationNode({List<MathNode>? n, List<MathNode>? r})
    : n = n ?? [LiteralNode()],
      r = r ?? [LiteralNode()];
}

/// A combination node (nCr).
class CombinationNode extends MathNode {
  List<MathNode> n; // Top number
  List<MathNode> r; // Bottom number
  CombinationNode({List<MathNode>? n, List<MathNode>? r})
    : n = n ?? [LiteralNode()],
      r = r ?? [LiteralNode()];
}

/// A complex number node (i * content).
class ComplexNode extends MathNode {
  List<MathNode> content; // The coefficient of i
  ComplexNode({List<MathNode>? content}) : content = content ?? [LiteralNode()];
}

/// A newline node for multi-line expressions.
class NewlineNode extends MathNode {
  NewlineNode() : super();
}

/// A parenthesis node wrapping content.
class ParenthesisNode extends MathNode {
  List<MathNode> content;
  ParenthesisNode({List<MathNode>? content})
    : content = content ?? [LiteralNode()];
}

/// An answer reference node (ans0, ans1, etc.).
class AnsNode extends MathNode {
  List<MathNode> index; // The reference number (0, 1, 2, etc.)

  AnsNode({List<MathNode>? index}) : index = index ?? [LiteralNode()];
}

/// A constant node (e.g. ε₀, μ₀) treated as an atomic unit.
class ConstantNode extends MathNode {
  final String constant;
  ConstantNode(this.constant);
}
