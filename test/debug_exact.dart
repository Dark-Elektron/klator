import 'package:klator/math_engine/math_engine_exact.dart';
import 'package:klator/math_renderer/math_nodes.dart';

void main() {
  print('--- Testing Hyperbolic ---');
  final node = TrigNode(function: 'sinh', argument: [LiteralNode(text: '1')]);
  final expr = MathNodeToExpr.convert([node]);
  print('Expr type: ${expr.runtimeType}');
  print('Expr string: $expr');
  final backNodes = expr.toMathNode();
  print('BackNodes length: ${backNodes.length}');
  if (backNodes.isNotEmpty) {
    print('BackNode 0 type: ${backNodes[0].runtimeType}');
    if (backNodes[0] is TrigNode) {
      print('BackNode 0 function: ${(backNodes[0] as TrigNode).function}');
    }
  }

  print('\n--- Testing Constant ---');
  final cNode = ConstantNode('\u03B5\u2080'); // ε₀
  final cExpr = MathNodeToExpr.convert([cNode]);
  print('Const Expr string: $cExpr');
  final cBack = cExpr.toMathNode();
  print('Const BackNode count: ${cBack.length}');
  if (cBack.isNotEmpty) {
    print('Const BackNode 0 type: ${cBack[0].runtimeType}');
  }
}
