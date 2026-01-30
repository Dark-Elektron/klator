import 'package:klator/math_engine/math_engine_exact.dart';
import 'package:klator/math_renderer/math_nodes.dart';

void main() {
  // Test sqrt(56/5)
  final rad = FracExpr.from(56, 5);
  final root = RootExpr.sqrt(rad);
  final simplified = root.simplify();

  // ignore: avoid_print
  // ignore: avoid_print
  print('Simplified: ${simplified.toString()}');
  // ignore: avoid_print
  print('Type: ${simplified.runtimeType}');

  final nodes = simplified.toMathNode();
  // ignore: avoid_print
  print('Nodes: ${_nodesToString(nodes)}');
}

String _nodesToString(List<MathNode> nodes) {
  StringBuffer sb = StringBuffer();
  for (var node in nodes) {
    if (node is LiteralNode) {
      sb.write(node.text);
    } else if (node is FractionNode) {
      sb.write('(');
      sb.write(_nodesToString(node.numerator));
      sb.write('/');
      sb.write(_nodesToString(node.denominator));
      sb.write(')');
    } else if (node is RootNode) {
      sb.write('sqrt(');
      sb.write(_nodesToString(node.radicand));
      sb.write(')');
    }
  }
  return sb.toString();
}
