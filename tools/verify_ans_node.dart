// Verification script for AnsNode support in ExactMathEngine

// Mocking necessary classes
abstract class Expr {
  Expr simplify();
}

class IntExpr extends Expr {
  final int value;
  IntExpr(this.value);
  @override
  Expr simplify() => this;
  @override
  String toString() => value.toString();
}

class VarExpr extends Expr {
  final String name;
  VarExpr(this.name);
  @override
  Expr simplify() => this;
  @override
  String toString() => name;
}

class ProdExpr extends Expr {
  final List<Expr> factors;
  ProdExpr(this.factors);
  @override
  Expr simplify() => this;
  @override
  String toString() => factors.join('*');
}

abstract class MathNode {}

class LiteralNode extends MathNode {
  final String text;
  LiteralNode(this.text);
}

class AnsNode extends MathNode {
  final List<MathNode> index;
  AnsNode(this.index);
}

// Mocking conversion logic with AnsNode support
class MathNodeToExprMock {
  static Expr convert(List<MathNode> nodes, {Map<int, Expr>? ansExpressions}) {
    if (nodes.isEmpty) return IntExpr(0);

    List<Expr> converged = [];
    for (var node in nodes) {
      if (node is LiteralNode) {
        if (node.text == '*') continue; // simplified mock
        converged.add(IntExpr(int.parse(node.text)));
      } else if (node is AnsNode) {
        int index = int.parse((node.index.first as LiteralNode).text);
        if (ansExpressions != null && ansExpressions.containsKey(index)) {
          converged.add(ansExpressions[index]!);
        } else {
          converged.add(VarExpr('ans$index'));
        }
      }
    }

    if (converged.length == 1) return converged.first;
    return ProdExpr(converged);
  }
}

void main() {
  // Mock exactResultExprs from main.dart
  Map<int, Expr> exactResultExprs = {
    0: IntExpr(3), // Result of cell 0 is 3
  };

  // Expression in cell 1: ans0 * 2
  List<MathNode> expression1 = [
    AnsNode([LiteralNode('0')]),
    LiteralNode('*'),
    LiteralNode('2'),
  ];

  // ignore: avoid_print
  print('Evaluation without ansExpressions:');
  Expr resultNoAns = MathNodeToExprMock.convert(expression1);
  // ignore: avoid_print
  print(resultNoAns); // Expected: ans0*2

  // ignore: avoid_print
  print('\nEvaluation with ansExpressions:');
  Expr resultWithAns = MathNodeToExprMock.convert(
    expression1,
    ansExpressions: exactResultExprs,
  );
  // ignore: avoid_print
  print(resultWithAns); // Expected: 3*2
}
