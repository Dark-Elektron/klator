String parseExpression(String expression) {
  // Handle implicit multiplication before brackets
  expression = expression.replaceAllMapped(
    RegExp(r'(\d)\('), // Matches a digit before an opening bracket
    (match) => '${match[1]}*(',
  );

  // Handle scientific notation with 'E'
  expression = expression.replaceAllMapped(
    RegExp(r'(\d+(?:\.\d*)?|\.\d+)E([+-]?\d+)'),
    (match) => '${match[1]}*10^(${match[2]})',
  );

  return expression;
}

// void main() {
//   // Test cases
//   List<String> testCases = [
//     "7(9+4)", // Implicit multiplication
//     "3E50",   // Scientific notation
//     "3E+50",  // Scientific notation with +
//     "3E-50",  // Scientific notation with -
//     "5.2E3",  // Decimal in scientific notation
//     "4(2+3)E2", // Combination of both
//   ];

//   for (var expr in testCases) {
//     print('$expr -> ${parseExpression(expr)}');
//   }
// }
