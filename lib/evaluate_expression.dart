import 'dart:math';
import 'constants.dart';

class EquationSolver {
	/// Solves a quadratic equation given as a string in the form "ax^2 + bx + c = 0"
	static String? solveEquation(String equation) {
	// Remove spaces for consistent matching
		equation = equation.replaceAll(' ', '');

		// Detect the variable used in the equation
		RegExp variableRegEx = RegExp(r'[a-zA-Z]');
		String variable = equation.contains(variableRegEx) ? equation[variableRegEx.firstMatch(equation)!.start] : 'x';

		List<String> parts = equation.split('=');

		// Get LHS and RHS
		String equationLHS = parts[0].trim();
		String equationRHS = parts[1].trim();

		List <double> coeffsLHS = getCoeff(equationLHS, variable);
		List <double> coeffsRHS = getCoeff(equationRHS, variable);
		
		double a = coeffsLHS[0] - coeffsRHS[0];
		double b = coeffsLHS[1] - coeffsRHS[1];
		double c = coeffsLHS[2] - coeffsRHS[2];

		// check if a = 0
		if (a == 0) {
			return 'x = ${properFormat(-c/b)}';
		}
		// check if c = 0
		if (c == 0) {
			return 'x = 0\nx = ${properFormat(-b/a)}';
		}

		double discriminant = b * b - 4 * a * c;
		if (discriminant < 0) {
			// No real solutions
			double rootReal = -b/(2*a);
			double rootImag = sqrt(-discriminant)/(2*a);
			return 'x = ${properFormat(rootReal, 4)} \u00B1 ${properFormat(rootImag, 4)}i';
		}

		double root1 = 2*c/(-b + sqrt(discriminant));
		double root2 = 2*c/(-b - sqrt(discriminant));
		
		return 'x = ${properFormat(root1, 6)}\nx = ${properFormat(root2)}';
	}

	static List<double> getCoeff(String expression, String variable) {
		// Regular expression to match terms, using the variable dynamically
		final regex = RegExp(
			r'([+-]?\d*\.?\d*)' + variable + r'\^\(2\)|([+-]?\d*)' + variable + r'(?!\^)|([+-]?\d+)|'
		);
		var matches = regex.allMatches(expression);
			double a = 0, b = 0, c = 0;
			for (var match in matches) {
				if (match.group(1) != null) {
					// Handle missing coefficient (e.g., `a` → `1a`, `-a` → `-1a`)
					if (match.group(1)!.isEmpty || match.group(1) == "+" || match.group(1) == "-") {
						a += double.parse("${match.group(1)}1");
					} else {
						a += double.parse(match.group(1)!);
					}
				} else if (match.group(2) != null) {
					// Handle missing coefficient (e.g., `a` → `1a`, `-a` → `-1a`)
					if (match.group(2)!.isEmpty || match.group(2) == "+" || match.group(2) == "-") {
						b += double.parse("${match.group(2)}1");
					} else {
						b += double.parse(match.group(2)!);
					}
				} else if (match.group(3) != null) {
					c += double.parse(match.group(3)!);
				}
			}
		return [a, b, c];
	}

	static String? solveLinearSystem(String equationsString) {
		List<String> equations = equationsString.replaceAll(' ', '').split('\n');
		if (equations.length > 3) return null; // Supports up to 3 equations

		List<List<double>> coefficients = [];
		List<double> constants = [];
		Set<String> variableSet = {}; // Store unique variables found

		RegExp termRegex = RegExp(r'([+-]?[\d.]*)([a-zA-Z]*)');
		RegExp equationRegex = RegExp(r'(.+)=([^=]+)');

		List<Map<String, double>> equationCoefficients = [];

		for (var eq in equations) {
			final match = equationRegex.firstMatch(eq);
			if (match == null) return null; // Invalid equation format

			String leftSide = match.group(1)!;
			String rightSide = match.group(2)!;

			Map<String, double> equationMap = {};
			double constant = 0.0;

			// Function to process both sides of the equation
			void processSide(String side, int sign) {
			final matches = termRegex.allMatches(side);
			for (var m in matches) {
				String coeffString = m.group(1)!; // Coefficient part
				String varName = m.group(2)!; // Variable part

				if (varName.isNotEmpty) {
				// Handle implicit coefficients (e.g., "-x" → "-1x", "+y" → "+1y")
				if (coeffString.isEmpty || coeffString == "+" || coeffString == "-") {
					coeffString += "1";
				}
				double coeff = double.parse(coeffString) * sign;

				equationMap[varName] = (equationMap[varName] ?? 0) + coeff;
				variableSet.add(varName);
				} else if (coeffString.isNotEmpty) {
				// It's a constant term
				try {
					constant += sign * double.parse(coeffString);
				} catch (e) {
					return; // Skip invalid parsing
				}
				}
			}
			}

			processSide(leftSide, 1);  // Left side of equation (keeps original sign)
			processSide(rightSide, -1); // Right side (negates terms to move them left)

			constants.add(-constant); // Move aggregated constants to right-hand side
			equationCoefficients.add(equationMap);
		}

		List<String> variables = variableSet.toList()..sort();
		if (variables.length != equations.length) return null; // Ensure square system

		// Construct coefficient matrix
		for (var equationMap in equationCoefficients) {
			List<double> row = List.filled(variables.length, 0.0);
			for (int i = 0; i < variables.length; i++) {
			row[i] = equationMap[variables[i]] ?? 0.0; // Assign 0 if missing
			}
			coefficients.add(row);
		}

		// Solve using Cramer's rule
		double determinant(List<List<double>> matrix) {
			if (matrix.length == 1) return matrix[0][0];
			if (matrix.length == 2) {
				return matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0];
			}
			double det = 0;
			for (int i = 0; i < matrix.length; i++) {
				List<List<double>> subMatrix = [];
				for (int j = 1; j < matrix.length; j++) {
					subMatrix.add([...matrix[j]]..removeAt(i));
				}
				det += (i % 2 == 0 ? 1 : -1) * matrix[0][i] * determinant(subMatrix);
			}
			return det;
		}

		double mainDet = determinant(coefficients);
		if (mainDet == 0) return null; // No unique solution

		String solution = '';
		for (int i = 0; i < variables.length; i++) {
			List<List<double>> tempMatrix = [];
			for (int j = 0; j < coefficients.length; j++) {
			tempMatrix.add([...coefficients[j]]);
			tempMatrix[j][i] = constants[j];
			}
			solution += '${variables[i]} = ${pF(determinant(tempMatrix) / mainDet)}\n';
		}
		return solution.trim();
	}
}

double properFormat(double num, [int dp = PRECISION]) {
		String formatted = num.toStringAsFixed(dp);
		// Check if the number already has enough decimals
		if (formatted.length > num.toString().length) {
			// If there are extra zeros added (i.e., the number had fewer decimals)
			return num;
		} else {
			return double.parse(formatted);
		}
	}

double pF(double num, [int dp = PRECISION]) {
		String formatted = num.toStringAsFixed(dp);
		// Check if the number already has enough decimals
		if (formatted.length > num.toString().length) {
			// If there are extra zeros added (i.e., the number had fewer decimals)
			return num;
		} else {
			return double.parse(formatted);
		}
	}

String processPermutation(String expression) {
	// Regular expression to match 'nPm' where n and m are numbers (normal, superscript, or subscript)
	RegExp permRegex = RegExp(r'([\d⁰¹²³⁴⁵⁶⁷⁸⁹]+)\s*P\s*([\d₀₁₂₃₄₅₆₇₈₉]+)');

	// Replace each match with its evaluated result
	String evaluatedExpression = expression.replaceAllMapped(permRegex, (match) {
		int n = parseUnicodeNumber(match.group(1)!);
		int m = parseUnicodeNumber(match.group(2)!);

		// Check if r > n
		if (m > n) {
			return "null"; // Or return match.group(0)! to keep it unchanged
		}
		// Calculate permutation P(n, m) = n! / (n-m)!
		int permutation = factorial(n) ~/ factorial(n - m);

		return permutation.toString();
	});

	return evaluatedExpression;
}

String processCombination(String expression) {
	// Regular expression to match 'nPm' where n and m are numbers (normal, superscript, or subscript)
	RegExp permRegex = RegExp(r'([\d⁰¹²³⁴⁵⁶⁷⁸⁹]+)\s*C\s*([\d₀₁₂₃₄₅₆₇₈₉]+)');

	// Replace each match with its evaluated result
	String evaluatedExpression = expression.replaceAllMapped(permRegex, (match) {
		int n = parseUnicodeNumber(match.group(1)!);
		int m = parseUnicodeNumber(match.group(2)!);

		// Check if r > n
		if (m > n) {
			return "null"; // Or return match.group(0)! to keep it unchanged
		}
		// Calculate permutation P(n, m) = n! / (n-m)!
		int combination = factorial(n) ~/ (factorial(n - m) * factorial(m));

		return combination.toString();
	});

	return evaluatedExpression;
}

// Function to convert Unicode superscript/subscript numbers to normal digits
int parseUnicodeNumber(String numStr) {
	const Map<String, String> unicodeMap = {
		'⁰': '0', '¹': '1', '²': '2', '³': '3', '⁴': '4',
		'⁵': '5', '⁶': '6', '⁷': '7', '⁸': '8', '⁹': '9',
		'₀': '0', '₁': '1', '₂': '2', '₃': '3', '₄': '4',
		'₅': '5', '₆': '6', '₇': '7', '₈': '8', '₉': '9'
	};

	String normalNum = numStr.split('').map((char) => unicodeMap[char] ?? char).join('');
	return int.parse(normalNum);
}

// Function to convert Unicode superscript/subscript numbers to normal digits
double parseUnicodeNumberDouble(String numStr) {
	const Map<String, String> unicodeMap = {
		'⁰': '0', '¹': '1', '²': '2', '³': '3', '⁴': '4',
		'⁵': '5', '⁶': '6', '⁷': '7', '⁸': '8', '⁹': '9',
		'₀': '0', '₁': '1', '₂': '2', '₃': '3', '₄': '4',
		'₅': '5', '₆': '6', '₇': '7', '₈': '8', '₉': '9'
	};

	String normalNum = numStr.split('').map((char) => unicodeMap[char] ?? char).join('');
	return double.parse(normalNum);
}

int factorial(int num) {
	if (num <= 1) return 1;
	return List.generate(num, (i) => i + 1).reduce((a, b) => a * b);
}

String formatPermutationCombination(String expression) {
  // Regular expression to match 'nPm' and 'nCm' where n and m are numbers
  RegExp permCombRegex = RegExp(r'([\d⁰¹²³⁴⁵⁶⁷⁸⁹]+)\s*(P|C|)\s*([\d₀₁₂₃₄₅₆₇₈₉]+)');

  // Replace each match with the formatted version using superscript and subscript
  String formattedExpression = expression.replaceAllMapped(permCombRegex, (match) {
    String n = match.group(1)!; // n
    String type = match.group(2)!; // 'P' or 'C'
    String m = match.group(3)!; // m

    // Convert to superscript and subscript
    String nSup = toSuperscript(n);
    String mSub = toSubscript(m);

    return "$nSup$type$mSub";
  });

  return formattedExpression;
}

String processNRoot(String expression) {
  // Regular expression to match 'nPm' where n and m are numbers (normal, superscript, or subscript)
  RegExp permRegex = RegExp(r'([\d⁰¹²³⁴⁵⁶⁷⁸⁹]+)\s*\u221A\(\s*([^)]*?)\s*\)');

  // Replace each match with its evaluated result
  String evaluatedExpression = expression.replaceAllMapped(permRegex, (match) {
    String n = match.group(1)!;
    String m = match.group(2)!;

    return '($m)^(1/${parseUnicodeNumberDouble(n)})';
  });

  return evaluatedExpression;
}

String formatNRoot(String expression) {
  // Regular expression to match 'nPm' and 'nCm' where n and m are numbers
  RegExp permCombRegex = RegExp(r'([\d⁰¹²³⁴⁵⁶⁷⁸⁹]+)\s*(\u207F\u221A)\s*\(([\d₀₁₂₃₄₅₆₇₈₉]+)\)');

  // Replace each match with the formatted version using superscript and subscript
  String formattedExpression = expression.replaceAllMapped(permCombRegex, (match) {
    String n = match.group(1)!; // n
    String m = match.group(3)!; // m

    // Convert to superscript and subscript
    String nSup = toSuperscript(n);

    return "$nSup\u221A($m)";
  });

  return formattedExpression;
}

// Converts a number string to superscript format
String toSuperscript(String number) {
  const Map<String, String> superscripts = {
    '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', 
    '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹'
  };
  return number.split('').map((char) => superscripts[char] ?? char).join('');
}

// Converts a number string to subscript format
String toSubscript(String number) {
  const Map<String, String> subscripts = {
    '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄', 
    '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉'
  };
  return number.split('').map((char) => subscripts[char] ?? char).join('');
}

String formatExponents(String expression) {
  // Mapping numbers and signs to superscript characters
  const Map<String, String> superscriptMap = {
    '-': '\u207B', '+': '\u207A', '0': '\u2070', '1': '\u00B9', '2': '\u00B2', '3': '\u00B3',
    '4': '\u2074', '5': '\u2075', '6': '\u2076', '7': '\u2077',
    '8': '\u2078', '9': '\u2079', '(': '\u207D', ')': '\u207E' // Superscript brackets
  };

  // Regular expression to match ^(content), allowing any characters inside
  RegExp exponentRegex = RegExp(r'\^\(([^)]+)\)');

  return expression.replaceAllMapped(exponentRegex, (match) {
    String exponent = match.group(1)!;
    // Convert each character inside to superscript if it exists in the map, otherwise keep it
    String superscript = exponent.split('').map((char) => superscriptMap[char] ?? char).join('');
    return superscript;
  });
}

String processExponents(String expression) {
  // Mapping superscript characters to normal numbers and signs
  const Map<String, String> superscriptMap = {
    '⁰': '0',
    '¹': '1',
    '²': '2',
    '³': '3',
    '⁴': '4',
    '⁵': '5',
    '⁶': '6',
    '⁷': '7',
    '⁸': '8',
    '⁹': '9',
    '⁻': '-',
    '⁺': '+',
  };

  // Regex to match a base number (with optional space) followed by a superscript sequence
  final RegExp regex = RegExp(
    r'(?<=[0-9)])\s*['
    r'⁰¹²³⁴⁵⁶⁷⁸⁹⁻⁺]+(\s*['
    r'⁰¹²³⁴⁵⁶⁷⁸⁹⁻⁺]+)*',
  );

  return expression.replaceAllMapped(regex, (match) {
    String superscript = match.group(0)!;

    // Convert superscript sequence to normal numbers/signs while preserving spaces
    String normalExponent = superscript
        .split('')
        .map((ch) {
          return superscriptMap[ch] ?? ch; // Preserve spaces
        })
        .join('');

    return '^($normalExponent)';
  });
}


bool containsSuperscripts(String expression) {
  // Regular expression to match superscript numbers
  RegExp superscriptRegex = RegExp(r'[\u00B2\u00B3\u2070-\u2079]');
  return superscriptRegex.hasMatch(expression);
}

void main() {
// 	// print(EquationSolver.solveEquation('0 = x^(2) + 5x+1'));
// 	// print(EquationSolver.solveLinearSystem('2x=+3y+x-3\n-5y-3y+2x+3x-9=7x+32y'));
	
// 	// print('$a, $b, $c');
// 			// solution += '${variables[i]} = ${pF(determinant(tempMatrix) / mainDet)}\n';
	
//   print(processPermutation("2+3 + 8P8")); // Output: "2+3-6 + 8"
//   print(processCombination("4 - 5 - 9C6 - 3P2")); // Output: "4 - 5 + 20 - 6"
//   print(formatPermutationCombination("2+3-3P2 + 8")); // Output: "2+3-³P₂ + 8"
//   print(formatPermutationCombination("4 - 5 + 5P2 - 3C2")); // Output: "4 - 5 + ⁵P₂ - ³C₂"
	// print(processNRoot('42\u221A(9)'));
  // print(formatNRoot('4\u207F\u221A(9)'));
  print(processNRoot('²√(4 + 3)'));
  print(processNRoot('²√(4 + 3)'));
  print(processNRoot('²√(4 +3)'));
  print(processNRoot('²√(4 -3)'));
  print(processNRoot('²√(4 - 3)'));
  print(processNRoot('²√(4 -3)'));
	// print(processExponents("2+ 5² + 3³-5÷ 3 "));  // Output: "5^(2) + 3^(3)"
	// print(processExponents("x⁷ - y⁹"));  // Output: "x^(7) - y^(9)"
	// print(processExponents("+² - ⁵"));   // Output: "+² - ⁵" (No replacement)
	// print(processExponents("4+ (2+3)²"));   // Output: "(2+3)^(2)"
	// print(processExponents("5⁻²⁺⁸"));   // Output: "(2+3)^(2)"
  // print(processExponents("2 + 6 ⁴ ⁻ ¹")); // Output: "(2+3)^(2)"
	// print(processExponents("3* 8² ⁺  ⁸+4"));   // Output: "(2+3)^(2)"
	// print(formatExponents("5^(-2+8+9) + 3^(3)"));     // Output: "5² + 3³"
	// print(formatExponents("x^(7) - y^(9)"));     // Output: "x⁷ - y⁹"
	// print(formatExponents("(2+3)^(2)"));         // Output: "(2+3)²"
	// print(formatExponents("[4+5]^(+3)"));         // Output: "[4+5]³"
	// print(formatExponents("{7+8}^(6)"));         // Output: "{7+8}⁶"
	// print(formatExponents("2+(3^(2))"));         // Output: "2+(3²)"
	// print(formatExponents("(2+3)^(2) + [4]^(3)"));// Output: "(2+3)² + [4]³"
}