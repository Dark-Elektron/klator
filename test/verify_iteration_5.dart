import 'package:klator/math_renderer/math_nodes.dart';
import 'package:klator/math_engine/math_engine_exact.dart';
import 'dart:math' as math;

void main() {
  print('--- Testing 1/mu0 in Exact Engine ---');

  // Expression: 1 / mu0
  final nodes = [
    LiteralNode(text: '1'),
    LiteralNode(text: '/'),
    ConstantNode('\u03BC\u2080'), // mu0
  ];

  final result = ExactMathEngine.evaluate(nodes);
  print('Exact result string: ${result.toExactString()}');
  print('Numerical result: ${result.numerical}');

  if (result.numerical != null && !result.numerical!.isInfinite) {
    print('SUCCESS: Result is not Infinity');
  } else {
    print('FAILURE: Result is Infinity or Null');
  }

  print('\n--- Testing Implicit Multiplication in Exact Engine ---');
  // Expression: 2 epsilon0
  final nodes2 = [
    LiteralNode(text: '2'),
    ConstantNode('\u03B5\u2080'), // epsilon0
  ];

  final result2 = ExactMathEngine.evaluate(nodes2);
  print('Exact result string: ${result2.toExactString()}');
  print('Numerical result: ${result2.numerical}');

  final expected = 2 * 8.8541878128e-12;
  if ((result2.numerical! - expected).abs() < 1e-20) {
    print('SUCCESS: Implicit multiplication works');
  } else {
    print('FAILURE: Implicit multiplication failed');
  }
}
