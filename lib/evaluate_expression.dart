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

		// Regular expression to match terms, using the variable dynamically
		final regex = RegExp(
			r'([+-]?\d*\.?\d*)' + variable + r'\^\(2\)|([+-]?\d*)' + variable + r'(?!\^)|([+-]?\d+)|=\s*([+-]?\d+)'
		);

		var matches = regex.allMatches(equation);

		double a = 0, b = 0, c = 0, rhs = 0;

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
			} else if (match.group(4) != null) {
				rhs = double.parse(match.group(4)!);
			}
		}

		// Move RHS to LHS
		c -= rhs;

	// check if a = 0
	if (a == 0) {
		return 'x = ${properFormat(-c/b)}';
	}
	if (c == 0) {
		return 'x = 0\nx = ${properFormat(-b/a)}';
	}

    double discriminant = b * b - 4 * a * c;
    if (discriminant < 0) return null; // No real solutions

	double root1 = 2*c/(-b + sqrt(discriminant));
	double root2 = 2*c/(-b - sqrt(discriminant));
	
	return 'x = ${properFormat(root1, 6)}\nx = ${properFormat(root2)}';
  }

	static String? solveLinearSystem(String equationsString) {
		List<String> equations = equationsString.replaceAll(' ', '').split('\n');
		if (equations.length > 3) return null; // Support up to 3 equations

		List<List<double>> coefficients = [];
		List<double> constants = [];
		Set<String> variableSet = {}; // Store all unique variables found

		// Improved regex: Ensures proper capturing of signs and coefficients
		RegExp variableRegex = RegExp(r'([+-]?\s*\d*\.?\d*)\s*([a-zA-Z])');
		RegExp constantRegex = RegExp(r'=\s*([-+]?\s*[0-9]*\.?[0-9]+)');

		List<Map<String, double>> equationCoefficients = [];

		for (var eq in equations) {
			final variableMatches = variableRegex.allMatches(eq);
			final constantMatch = constantRegex.firstMatch(eq);
			
			if (constantMatch == null) return null; // Invalid equation format
			double constant = double.parse(constantMatch.group(1)!.replaceAll(' ', ''));
			constants.add(constant);

			Map<String, double> equationMap = {};
			for (var m in variableMatches) {
				String varName = m.group(2)!;
				String coeffString = m.group(1)!.replaceAll(' ', ''); // Remove spaces in the coefficient

				double coeff;
				if (coeffString.isEmpty || coeffString == "+" || coeffString == "-") {
					coeff = double.parse("${coeffString}1"); // Handle cases like `-y` → `-1y`
				} else {
					coeff = double.parse(coeffString);
				}

				if (equationMap.containsKey(varName)) {
					equationMap[varName] = equationMap[varName]! + coeff; // Add to existing coefficient
				} else {
					equationMap[varName] = coeff;
				}

				variableSet.add(varName);
			}
			equationCoefficients.add(equationMap);
		}

		List<String> variables = variableSet.toList()..sort(); // Ensure consistent ordering
		if (variables.length != equations.length) return null; // Ensure square system

		// Construct coefficient matrix dynamically
		for (var equationMap in equationCoefficients) {
			List<double> row = List.filled(variables.length, 0.0);
			for (int i = 0; i < variables.length; i++) {
				row[i] = equationMap[variables[i]] ?? 0.0; // Assign 0 if variable is missing
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

