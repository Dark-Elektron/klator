// lib/math_engine/math_engine_exact.dart

import 'dart:math' as math;
import 'package:klator/math_renderer/math_nodes.dart';
import 'package:klator/settings/settings_provider.dart';
import 'package:klator/math_engine/math_engine.dart';

// ============================================================
// SECTION 1: EXPRESSION BASE CLASS
// ============================================================

/// Base class for all symbolic mathematical expressions.
///
/// The Expr tree represents mathematical expressions symbolically,
/// allowing for exact computation and simplification.
abstract class Expr {
  /// Simplify this expression as much as possible.
  Expr simplify();

  /// Get numerical approximation.
  double toDouble();

  /// Check if this expression equals another structurally.
  bool structurallyEquals(Expr other);

  /// Get a canonical string signature for combining like terms.
  /// For example, 3√2 and 5√2 both have signature "root:2:2"
  String get termSignature;

  /// Get the coefficient part (e.g., 3 in 3√2)
  Expr get coefficient;

  /// Get the base part (e.g., √2 in 3√2)
  Expr get baseExpr;

  /// Is this expression exactly zero?
  bool get isZero;

  /// Is this expression exactly one?
  bool get isOne;

  /// Is this a rational number (integer or fraction)?
  bool get isRational;

  /// Is this exactly an integer?
  bool get isInteger;

  /// Negate this expression
  Expr negate();

  /// Convert to MathNode for rendering
  List<MathNode> toMathNode();

  /// Create a deep copy
  Expr copy();

  @override
  String toString();
}

// ============================================================
// SECTION 2: INTEGER EXPRESSION
// ============================================================

/// Helper for consistent number formatting in exact results
class ExactNumberFormatter {
  static const String smallCapsE = '\u1D07';
  static final BigInt threshold = BigInt.from(10).pow(15);

  static String formatBigInt(BigInt value, {bool isWholeNumber = false}) {
    BigInt absVal = value.abs();
    bool useScientific = false;

    // Rule 1: Always use scientific if > 1e15
    if (absVal >= threshold) {
      useScientific = true;
    }
    // Rule 2: If it's a standalone whole number, respect the global scientific setting
    else if (isWholeNumber &&
        MathSolverNew.numberFormat == NumberFormat.scientific) {
      if (absVal > BigInt.zero) {
        useScientific = true;
      }
    }

    if (useScientific) {
      String s = absVal.toString();
      if (s.length <= 1) return value.toString();

      int p = MathSolverNew.precision;
      int len = s.length;
      int exponent = len - 1;

      // Rounding logic for BigInt to match precision p (decimal places)
      // We want p+1 significant digits
      if (len > p + 1) {
        String prefix = s.substring(0, p + 1);
        int nextDigit = int.parse(s[p + 1]);
        if (nextDigit >= 5) {
          BigInt rounded = BigInt.parse(prefix) + BigInt.one;
          String roundedStr = rounded.toString();
          if (roundedStr.length > prefix.length) {
            // Carry over, e.g., 999 -> 1000
            exponent += 1;
            s = roundedStr;
          } else {
            s = roundedStr;
          }
        } else {
          s = prefix;
        }
      }

      // Format as mantissa with dot after first digit
      String mantissa = s[0];
      String rest = s.substring(1).replaceAll(RegExp(r'0+$'), '');
      if (rest.isNotEmpty) {
        mantissa += '.$rest';
      }

      String result = '$mantissa$smallCapsE$exponent';
      return value < BigInt.zero ? '−$result' : result;
    }

    return value.toString();
  }
}

/// Represents an exact integer value.
class IntExpr extends Expr {
  final BigInt value;

  IntExpr(this.value);

  /// Convenience constructor from int
  IntExpr.from(int v) : value = BigInt.from(v);

  /// Common constants
  static final IntExpr zero = IntExpr(BigInt.zero);
  static final IntExpr one = IntExpr(BigInt.one);
  static final IntExpr two = IntExpr(BigInt.two);
  static final IntExpr negOne = IntExpr(-BigInt.one);

  @override
  Expr simplify() => this;

  @override
  double toDouble() => value.toDouble();

  @override
  bool structurallyEquals(Expr other) {
    return other is IntExpr && other.value == value;
  }

  @override
  String get termSignature => 'int:1'; // All integers combine together

  @override
  Expr get coefficient => this;

  @override
  Expr get baseExpr => IntExpr.one;

  @override
  bool get isZero => value == BigInt.zero;

  @override
  bool get isOne => value == BigInt.one;

  @override
  bool get isRational => true;

  @override
  bool get isInteger => true;

  @override
  Expr negate() => IntExpr(-value);

  @override
  List<MathNode> toMathNode() {
    return [
      LiteralNode(
        text: ExactNumberFormatter.formatBigInt(value, isWholeNumber: true),
      ),
    ];
  }

  @override
  Expr copy() => IntExpr(value);

  @override
  String toString() => value.toString();

  /// Arithmetic operations returning Expr
  Expr add(Expr other) {
    if (other is IntExpr) {
      return IntExpr(value + other.value);
    }
    if (other is FracExpr) {
      // a + (n/d) = (a*d + n) / d
      return FracExpr(
        IntExpr(value * other.denominator.value + other.numerator.value),
        other.denominator,
      ).simplify();
    }
    return SumExpr([this, other]).simplify();
  }

  Expr subtract(Expr other) {
    return add(other.negate());
  }

  Expr multiply(Expr other) {
    if (other is IntExpr) {
      return IntExpr(value * other.value);
    }
    if (other is FracExpr) {
      return FracExpr(
        IntExpr(value * other.numerator.value),
        other.denominator,
      ).simplify();
    }
    return ProdExpr([this, other]).simplify();
  }

  Expr divide(Expr other) {
    if (other is IntExpr) {
      return FracExpr(this, other).simplify();
    }
    if (other is FracExpr) {
      // a / (n/d) = a*d / n
      return FracExpr(
        IntExpr(value * other.denominator.value),
        other.numerator,
      ).simplify();
    }
    return FracExpr(this, other).simplify();
  }

  Expr power(Expr exponent) {
    if (exponent is IntExpr) {
      if (exponent.value == BigInt.zero) return IntExpr.one;
      if (exponent.value == BigInt.one) return this;
      if (exponent.value > BigInt.zero) {
        return IntExpr(value.pow(exponent.value.toInt()));
      }
      // Negative exponent: a^(-n) = 1 / a^n
      return FracExpr(IntExpr.one, IntExpr(value.pow(-exponent.value.toInt())));
    }
    return PowExpr(this, exponent).simplify();
  }
}

// ============================================================
// SECTION 3: FRACTION EXPRESSION
// ============================================================

/// Represents an exact fraction n/d.
// ============================================================
// SECTION 3: FRACTION EXPRESSION
// ============================================================

/// Represents an exact fraction n/d.
class FracExpr extends Expr {
  final IntExpr numerator;
  final IntExpr denominator;

  FracExpr(Expr num, Expr den)
    : numerator =
          num is IntExpr
              ? num
              : throw ArgumentError('Numerator must be IntExpr'),
      denominator =
          den is IntExpr
              ? den
              : throw ArgumentError('Denominator must be IntExpr');

  /// Convenience constructor from ints
  FracExpr.from(int n, int d)
    : numerator = IntExpr.from(n),
      denominator = IntExpr.from(d);

  @override
  Expr simplify() {
    BigInt n = numerator.value;
    BigInt d = denominator.value;

    // Handle zero
    if (n == BigInt.zero) return IntExpr.zero;

    // Handle division by zero (return as-is, or could throw)
    if (d == BigInt.zero) return this;

    // Make denominator positive
    if (d < BigInt.zero) {
      n = -n;
      d = -d;
    }

    // Reduce to lowest terms
    BigInt g = n.gcd(d).abs();
    n = n ~/ g;
    d = d ~/ g;

    // If denominator is 1, return integer
    if (d == BigInt.one) {
      return IntExpr(n);
    }

    return FracExpr(IntExpr(n), IntExpr(d));
  }

  @override
  double toDouble() => numerator.value / denominator.value;

  @override
  bool structurallyEquals(Expr other) {
    if (other is FracExpr) {
      Expr thisSimp = simplify();
      Expr otherSimp = other.simplify();
      if (thisSimp is IntExpr && otherSimp is IntExpr) {
        return thisSimp.value == otherSimp.value;
      }
      if (thisSimp is FracExpr && otherSimp is FracExpr) {
        return thisSimp.numerator.value == otherSimp.numerator.value &&
            thisSimp.denominator.value == otherSimp.denominator.value;
      }
    }
    if (other is IntExpr) {
      Expr thisSimp = simplify();
      return thisSimp is IntExpr && thisSimp.value == other.value;
    }
    return false;
  }

  @override
  String get termSignature => 'int:1'; // Rationals combine with integers

  @override
  Expr get coefficient => this;

  @override
  Expr get baseExpr => IntExpr.one;

  @override
  bool get isZero => numerator.value == BigInt.zero;

  @override
  bool get isOne {
    Expr s = simplify();
    return s is IntExpr && s.value == BigInt.one;
  }

  @override
  bool get isRational => true;

  @override
  bool get isInteger {
    Expr s = simplify();
    return s is IntExpr;
  }

  @override
  Expr negate() => FracExpr(numerator.negate() as IntExpr, denominator);

  @override
  List<MathNode> toMathNode() {
    Expr simplified = simplify();
    if (simplified is IntExpr) {
      return simplified.toMathNode();
    }

    FracExpr frac = simplified as FracExpr;

    // Check if the fraction is negative (numerator is negative)
    bool isNegative = frac.numerator.value < BigInt.zero;

    if (isNegative) {
      // Put negative sign outside the fraction
      BigInt absNumerator = frac.numerator.value.abs();
      return [
        LiteralNode(text: '−'),
        FractionNode(
          num: [
            LiteralNode(text: ExactNumberFormatter.formatBigInt(absNumerator)),
          ],
          den: [
            LiteralNode(
              text: ExactNumberFormatter.formatBigInt(frac.denominator.value),
            ),
          ],
        ),
      ];
    } else {
      return [
        FractionNode(
          num: [
            LiteralNode(
              text: ExactNumberFormatter.formatBigInt(frac.numerator.value),
            ),
          ],
          den: [
            LiteralNode(
              text: ExactNumberFormatter.formatBigInt(frac.denominator.value),
            ),
          ],
        ),
      ];
    }
  }

  @override
  Expr copy() => FracExpr(IntExpr(numerator.value), IntExpr(denominator.value));

  @override
  String toString() {
    Expr s = simplify();
    if (s is IntExpr) return s.toString();
    return '${numerator.value}/${denominator.value}';
  }

  /// Add another expression to this fraction
  Expr add(Expr other) {
    if (other is IntExpr) {
      return FracExpr(
        IntExpr(numerator.value + other.value * denominator.value),
        denominator,
      ).simplify();
    }
    if (other is FracExpr) {
      return FracExpr(
        IntExpr(
          numerator.value * other.denominator.value +
              other.numerator.value * denominator.value,
        ),
        IntExpr(denominator.value * other.denominator.value),
      ).simplify();
    }
    return SumExpr([this, other]).simplify();
  }

  Expr subtract(Expr other) => add(other.negate());

  Expr multiply(Expr other) {
    if (other is IntExpr) {
      return FracExpr(
        IntExpr(numerator.value * other.value),
        denominator,
      ).simplify();
    }
    if (other is FracExpr) {
      return FracExpr(
        IntExpr(numerator.value * other.numerator.value),
        IntExpr(denominator.value * other.denominator.value),
      ).simplify();
    }
    return ProdExpr([this, other]).simplify();
  }

  Expr divide(Expr other) {
    if (other is IntExpr) {
      return FracExpr(
        numerator,
        IntExpr(denominator.value * other.value),
      ).simplify();
    }
    if (other is FracExpr) {
      return FracExpr(
        IntExpr(numerator.value * other.denominator.value),
        IntExpr(denominator.value * other.numerator.value),
      ).simplify();
    }
    return DivExpr(this, other).simplify();
  }
}

// ============================================================
// SECTION 4: SYMBOLIC CONSTANTS
// ============================================================

/// Represents a symbolic constant like π, e, φ (golden ratio)
class ConstExpr extends Expr {
  final ConstType type;

  ConstExpr(this.type);

  static final ConstExpr pi = ConstExpr(ConstType.pi);
  static final ConstExpr e = ConstExpr(ConstType.e);
  static final ConstExpr phi = ConstExpr(ConstType.phi);
  static final ConstExpr epsilon0 = ConstExpr(ConstType.epsilon0);
  static final ConstExpr mu0 = ConstExpr(ConstType.mu0);
  static final ConstExpr c0 = ConstExpr(ConstType.c0);

  @override
  Expr simplify() => this;

  @override
  double toDouble() {
    switch (type) {
      case ConstType.pi:
        return math.pi;
      case ConstType.e:
        return math.e;
      case ConstType.phi:
        return (1 + math.sqrt(5)) / 2;
      case ConstType.epsilon0:
        return 8.8541878128e-12; // vacuum permittivity F/m
      case ConstType.mu0:
        return 1.25663706212e-6; // vacuum permeability H/m
      case ConstType.c0:
        return 299792458.0; // speed of light m/s
      case ConstType.eMinus:
        return 1.602176634e-19; // elementary charge C
    }
  }

  @override
  bool structurallyEquals(Expr other) {
    return other is ConstExpr && other.type == type;
  }

  @override
  String get termSignature => 'const:${type.name}';

  @override
  Expr get coefficient => IntExpr.one;

  @override
  Expr get baseExpr => this;

  @override
  bool get isZero => false;

  @override
  bool get isOne => false;

  @override
  bool get isRational => false;

  @override
  bool get isInteger => false;

  @override
  Expr negate() => ProdExpr([IntExpr.negOne, this]);

  @override
  List<MathNode> toMathNode() {
    switch (type) {
      case ConstType.pi:
        return [LiteralNode(text: 'π')];
      case ConstType.e:
        return [LiteralNode(text: 'e')];
      case ConstType.phi:
        return [LiteralNode(text: 'φ')];
      case ConstType.epsilon0:
        return [ConstantNode('ε₀')];
      case ConstType.mu0:
        return [ConstantNode('μ₀')];
      case ConstType.c0:
        return [ConstantNode('c₀')];
      case ConstType.eMinus:
        return [ConstantNode('e⁻')];
    }
  }

  @override
  Expr copy() => ConstExpr(type);

  @override
  String toString() {
    switch (type) {
      case ConstType.pi:
        return 'π';
      case ConstType.e:
        return 'e';
      case ConstType.phi:
        return 'φ';
      case ConstType.epsilon0:
        return 'ε₀';
      case ConstType.mu0:
        return 'μ₀';
      case ConstType.c0:
        return 'c₀';
      case ConstType.eMinus:
        return 'e⁻';
    }
  }
}

enum ConstType { pi, e, phi, epsilon0, mu0, c0, eMinus }

// ============================================================
// SECTION 5: SUM EXPRESSION
// ============================================================

// ============================================================
// SECTION 5: SUM EXPRESSION
// ============================================================

/// Represents a sum of terms: a + b + c + .
class SumExpr extends Expr {
  final List<Expr> terms;

  SumExpr(this.terms);

  @override
  Expr simplify() {
    if (terms.isEmpty) return IntExpr.zero;
    if (terms.length == 1) return terms[0].simplify();

    // Step 1: Simplify all terms and flatten nested sums
    List<Expr> flat = [];
    for (Expr term in terms) {
      Expr simplified = term.simplify();
      if (simplified is SumExpr) {
        flat.addAll(simplified.terms);
      } else if (!simplified.isZero) {
        flat.add(simplified);
      }
    }

    if (flat.isEmpty) return IntExpr.zero;
    if (flat.length == 1) return flat[0];

    // Step 2: Group by signature, tracking first occurrence position
    Map<String, List<Expr>> groups = {};
    Map<String, int> firstOccurrence = {};

    for (int i = 0; i < flat.length; i++) {
      Expr term = flat[i];
      String sig = term.termSignature;

      if (!groups.containsKey(sig)) {
        groups[sig] = [];
        firstOccurrence[sig] = i;
      }
      groups[sig]!.add(term);
    }

    // Step 3: Combine each group
    Map<String, Expr> combinedTerms = {};

    for (var entry in groups.entries) {
      String sig = entry.key;
      List<Expr> group = entry.value;

      if (group.length == 1) {
        combinedTerms[sig] = group[0];
      } else {
        // Sum the coefficients
        Expr coeffSum = _sumCoefficientsHelper(group);

        if (coeffSum.isZero) {
          continue; // Terms cancel - skip
        }

        Expr base = group[0].baseExpr;

        if (base.isOne) {
          combinedTerms[sig] = coeffSum;
        } else if (coeffSum.isOne) {
          combinedTerms[sig] = base;
        } else if (coeffSum is IntExpr && coeffSum.value == -BigInt.one) {
          combinedTerms[sig] = base.negate();
        } else {
          combinedTerms[sig] = ProdExpr([coeffSum, base]).simplify();
        }
      }
    }

    // Step 4: Build result list ordered by first occurrence
    List<MapEntry<String, int>> sortedByPosition =
        firstOccurrence.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));

    List<Expr> result = [];
    for (var entry in sortedByPosition) {
      String sig = entry.key;
      Expr? combined = combinedTerms[sig];
      if (combined != null && !combined.isZero) {
        result.add(combined);
      }
    }

    if (result.isEmpty) return IntExpr.zero;
    if (result.length == 1) return result[0];

    return SumExpr(result);
  }

  /// Sum the coefficients of a list of like terms
  Expr _sumCoefficientsHelper(List<Expr> termList) {
    Expr sum = IntExpr.zero;
    for (Expr term in termList) {
      Expr coeff = term.coefficient;
      if (sum is IntExpr && coeff is IntExpr) {
        sum = IntExpr(sum.value + coeff.value);
      } else if (sum is IntExpr && coeff is FracExpr) {
        sum = coeff.add(sum);
      } else if (sum is FracExpr && coeff is IntExpr) {
        sum = sum.add(coeff);
      } else if (sum is FracExpr && coeff is FracExpr) {
        sum = sum.add(coeff);
      } else {
        sum = SumExpr([sum, coeff]).simplify();
      }
    }
    return sum;
  }

  @override
  double toDouble() {
    double sum = 0;
    for (Expr term in terms) {
      sum += term.toDouble();
    }
    return sum;
  }

  @override
  bool structurallyEquals(Expr other) {
    if (other is! SumExpr) return false;
    if (other.terms.length != terms.length) return false;
    for (int i = 0; i < terms.length; i++) {
      if (!terms[i].structurallyEquals(other.terms[i])) return false;
    }
    return true;
  }

  @override
  String get termSignature =>
      'sum:${terms.map((t) => t.termSignature).join('+')}';

  @override
  Expr get coefficient => IntExpr.one;

  @override
  Expr get baseExpr => this;

  @override
  bool get isZero => terms.every((t) => t.isZero);

  @override
  bool get isOne => false;

  @override
  bool get isRational => terms.every((t) => t.isRational);

  @override
  bool get isInteger => false;

  @override
  Expr negate() => SumExpr(terms.map((t) => t.negate()).toList());

  @override
  List<MathNode> toMathNode() {
    if (terms.isEmpty) return [LiteralNode(text: '0')];

    List<MathNode> nodes = [];

    for (int i = 0; i < terms.length; i++) {
      Expr term = terms[i];

      bool isNegative = _isNegativeTerm(term);
      Expr absTerm = isNegative ? _absoluteTerm(term) : term;

      if (i == 0) {
        if (isNegative) {
          // The user's instruction was to "Add print to evaluate and fix the third test in repro_issue.dart."
          // However, the provided code edit is a test case itself, not a print statement,
          // and inserting it here would cause a syntax error and is not a fix for this method.
          // As per instructions to maintain syntactic correctness and make faithful edits,
          // I cannot insert the provided test block directly into this method.
          // If the intention was to add a print statement for debugging, please provide the specific print statement.
          // If the intention was to add a test, it should be in a test file.
          // For now, I will not insert the syntactically incorrect test block.
          nodes.add(LiteralNode(text: '−'));
        }
        nodes.addAll(absTerm.toMathNode());
      } else {
        if (isNegative) {
          nodes.add(LiteralNode(text: '−'));
        } else {
          nodes.add(LiteralNode(text: '+'));
        }
        nodes.addAll(absTerm.toMathNode());
      }
    }

    return nodes;
  }

  /// Check if a term is negative
  // In math_engine_exact.dart, update the _isNegativeTerm method in SumExpr class:

  /// Check if a term is negative
  bool _isNegativeTerm(Expr term) {
    if (term is IntExpr) return term.value < BigInt.zero;
    if (term is FracExpr) return term.numerator.value < BigInt.zero;
    if (term is ProdExpr && term.factors.isNotEmpty) {
      Expr coeff = term.coefficient;
      if (coeff is IntExpr) return coeff.value < BigInt.zero;
      if (coeff is FracExpr) return coeff.numerator.value < BigInt.zero;
    }
    if (term is DivExpr) {
      if (term.numerator is IntExpr) {
        return (term.numerator as IntExpr).value < BigInt.zero;
      }
      if (term.numerator is FracExpr) {
        return (term.numerator as FracExpr).numerator.value < BigInt.zero;
      }
    }
    return false;
  }

  /// Get absolute value of a term
  // In math_engine_exact.dart, update the _absoluteTerm method in SumExpr class:

  /// Get absolute value of a term
  Expr _absoluteTerm(Expr term) {
    if (term is IntExpr) return IntExpr(term.value.abs());
    if (term is FracExpr) {
      return FracExpr(IntExpr(term.numerator.value.abs()), term.denominator);
    }
    if (term is ProdExpr && term.factors.isNotEmpty) {
      Expr coeff = term.coefficient;
      Expr base = term.baseExpr;

      Expr absCoeff;
      if (coeff is IntExpr) {
        absCoeff = IntExpr(coeff.value.abs());
      } else if (coeff is FracExpr) {
        absCoeff = FracExpr(
          IntExpr(coeff.numerator.value.abs()),
          coeff.denominator,
        );
      } else {
        absCoeff = coeff;
      }

      if (absCoeff.isOne) return base;
      return ProdExpr([absCoeff, base]);
    }
    if (term is DivExpr) {
      if (term.numerator is IntExpr &&
          (term.numerator as IntExpr).value < BigInt.zero) {
        return DivExpr(
          IntExpr((term.numerator as IntExpr).value.abs()),
          term.denominator,
        );
      }
      if (term.numerator is FracExpr &&
          (term.numerator as FracExpr).numerator.value < BigInt.zero) {
        return DivExpr(
          FracExpr(
            IntExpr((term.numerator as FracExpr).numerator.value.abs()),
            (term.numerator as FracExpr).denominator,
          ),
          term.denominator,
        );
      }
    }
    return term;
  }

  @override
  Expr copy() => SumExpr(terms.map((t) => t.copy()).toList());

  @override
  String toString() => terms.map((t) => t.toString()).join(' + ');
}

// ============================================================
// SECTION 6: PRODUCT EXPRESSION
// ============================================================

/// Represents a product of factors: a * b * c * ...
class ProdExpr extends Expr {
  final List<Expr> factors;

  ProdExpr(this.factors);

  @override
  Expr simplify() {
    if (factors.isEmpty) return IntExpr.one;
    if (factors.length == 1) return factors[0].simplify();

    // Step 1: Simplify all factors and flatten nested products
    List<Expr> flat = [];
    Expr numericPart = IntExpr.one; // Accumulate numeric factors

    for (Expr factor in factors) {
      Expr simplified = factor.simplify();

      // Check for zero - entire product is zero
      if (simplified.isZero) return IntExpr.zero;

      // Skip ones
      if (simplified.isOne) continue;

      if (simplified is ProdExpr) {
        // Flatten nested product
        for (Expr f in simplified.factors) {
          if (f.isRational) {
            numericPart = _multiplyRational(numericPart, f);
          } else {
            flat.add(f);
          }
        }
      } else if (simplified.isRational) {
        numericPart = _multiplyRational(numericPart, simplified);
      } else {
        flat.add(simplified);
      }
    }

    // Check if numeric part is zero
    if (numericPart.isZero) return IntExpr.zero;

    // Add numeric part at front if not 1
    if (!numericPart.isOne) {
      flat.insert(0, numericPart);
    }

    if (flat.isEmpty) return IntExpr.one;
    if (flat.length == 1) return flat[0];

    // Step 2: Combine like bases (e.g., √2 * √2 = 2)
    flat = _combineLikeBases(flat);

    if (flat.isEmpty) return IntExpr.one;

    // Step 2.5: Ensure all rationals are combined (including those from Step 2)
    List<Expr> finalFactors = [];
    Expr finalNumeric = IntExpr.one;
    for (Expr f in flat) {
      if (f.isRational) {
        finalNumeric = _multiplyRational(finalNumeric, f);
      } else {
        finalFactors.add(f);
      }
    }

    if (!finalNumeric.isOne || finalFactors.isEmpty) {
      finalFactors.insert(0, finalNumeric);
    }

    if (finalFactors.isEmpty) return IntExpr.one;
    if (finalFactors.length == 1 && finalFactors[0].isOne) return IntExpr.one;
    if (finalFactors.length == 1) return finalFactors[0];

    // Step 3: Sort for canonical order
    finalFactors.sort((a, b) => _compareFactors(a, b));

    return ProdExpr(finalFactors);
  }

  /// Multiply two rational expressions
  static Expr _multiplyRational(Expr a, Expr b) {
    if (a is IntExpr && b is IntExpr) {
      return IntExpr(a.value * b.value);
    }
    if (a is IntExpr && b is FracExpr) {
      return FracExpr(
        IntExpr(a.value * b.numerator.value),
        b.denominator,
      ).simplify();
    }
    if (a is FracExpr && b is IntExpr) {
      return FracExpr(
        IntExpr(a.numerator.value * b.value),
        a.denominator,
      ).simplify();
    }
    if (a is FracExpr && b is FracExpr) {
      return FracExpr(
        IntExpr(a.numerator.value * b.numerator.value),
        IntExpr(a.denominator.value * b.denominator.value),
      ).simplify();
    }
    return ProdExpr([a, b]);
  }

  /// Combine factors with the same base (e.g., √2 * √3 = √6, √2 * √2 = 2)
  static List<Expr> _combineLikeBases(List<Expr> factors) {
    // Group RootExpr with same index
    Map<int, List<RootExpr>> rootGroups = {};
    List<Expr> others = [];

    for (Expr f in factors) {
      if (f is RootExpr && f.index is IntExpr) {
        int idx = (f.index as IntExpr).value.toInt();
        rootGroups.putIfAbsent(idx, () => []);
        rootGroups[idx]!.add(f);
      } else {
        others.add(f);
      }
    }

    // Combine roots with same index: √a * √b = √(ab)
    List<Expr> result = List.from(others);

    for (var entry in rootGroups.entries) {
      int index = entry.key;
      List<RootExpr> roots = entry.value;

      if (roots.length == 1) {
        result.add(roots[0]);
      } else {
        // Multiply all radicands
        Expr combinedRadicand = IntExpr.one;
        for (RootExpr r in roots) {
          combinedRadicand =
              ProdExpr([combinedRadicand, r.radicand]).simplify();
        }
        // Create new root and simplify
        result.add(RootExpr(combinedRadicand, IntExpr.from(index)).simplify());
      }
    }

    return result;
  }

  /// Compare factors for canonical ordering
  static int _compareFactors(Expr a, Expr b) {
    // Order: numbers first, then roots, then others
    if (a.isRational && !b.isRational) return -1;
    if (!a.isRational && b.isRational) return 1;
    if (a is RootExpr && b is! RootExpr) return -1;
    if (a is! RootExpr && b is RootExpr) return 1;
    return a.toString().compareTo(b.toString());
  }

  @override
  double toDouble() {
    double prod = 1;
    for (Expr factor in factors) {
      prod *= factor.toDouble();
    }
    return prod;
  }

  @override
  bool structurallyEquals(Expr other) {
    if (other is! ProdExpr) return false;
    if (other.factors.length != factors.length) return false;
    for (int i = 0; i < factors.length; i++) {
      if (!factors[i].structurallyEquals(other.factors[i])) return false;
    }
    return true;
  }

  @override
  String get termSignature {
    // Signature excludes numeric coefficient
    List<String> nonNumeric = [];
    for (Expr f in factors) {
      if (!f.isRational) {
        nonNumeric.add(f.termSignature);
      }
    }
    if (nonNumeric.isEmpty) return 'int:1';
    // KEY FIX: Single non-numeric factor - use its signature directly
    if (nonNumeric.length == 1) return nonNumeric[0];
    return 'prod:${nonNumeric.join('*')}';
  }

  @override
  Expr get coefficient {
    // Return the numeric part
    Expr coeff = IntExpr.one;
    for (Expr f in factors) {
      if (f.isRational) {
        coeff = _multiplyRational(coeff, f);
      }
    }
    return coeff;
  }

  @override
  Expr get baseExpr {
    // Return the non-numeric part
    List<Expr> nonNumeric = factors.where((f) => !f.isRational).toList();
    if (nonNumeric.isEmpty) return IntExpr.one;
    if (nonNumeric.length == 1) return nonNumeric[0];
    return ProdExpr(nonNumeric);
  }

  @override
  bool get isZero => factors.any((f) => f.isZero);

  @override
  bool get isOne => factors.every((f) => f.isOne);

  @override
  bool get isRational => factors.every((f) => f.isRational);

  @override
  bool get isInteger => false;

  @override
  Expr negate() {
    List<Expr> newFactors = List.from(factors);
    if (newFactors.isNotEmpty && newFactors[0].isRational) {
      newFactors[0] = newFactors[0].negate();
    } else {
      newFactors.insert(0, IntExpr.negOne);
    }
    return ProdExpr(newFactors);
  }

  @override
  List<MathNode> toMathNode() {
    if (factors.isEmpty) return [LiteralNode(text: '1')];

    List<MathNode> nodes = [];

    for (int i = 0; i < factors.length; i++) {
      if (i > 0) {
        // Add multiplication sign between factors
        // But skip if it's coefficient * root (implicit multiplication)
        bool implicit =
            factors[i - 1].isRational &&
            (factors[i] is RootExpr || factors[i] is ConstExpr);
        if (!implicit) {
          nodes.add(LiteralNode(text: '·'));
        }
      }
      nodes.addAll(factors[i].toMathNode());
    }

    return nodes;
  }

  @override
  Expr copy() => ProdExpr(factors.map((f) => f.copy()).toList());

  @override
  String toString() => factors.map((f) => f.toString()).join('·');
}

// ============================================================
// SECTION 7: POWER EXPRESSION
// ============================================================

/// Represents base^exponent
class PowExpr extends Expr {
  final Expr base;
  final Expr exponent;

  PowExpr(this.base, this.exponent);

  @override
  Expr simplify() {
    Expr b = base.simplify();
    Expr e = exponent.simplify();

    // x^0 = 1
    if (e.isZero) return IntExpr.one;

    // x^1 = x
    if (e.isOne) return b;

    // 0^n = 0 (for positive n)
    if (b.isZero && !e.isZero) return IntExpr.zero;

    // 1^n = 1
    if (b.isOne) return IntExpr.one;

    // Integer^Integer: compute if reasonable
    if (b is IntExpr && e is IntExpr) {
      BigInt baseVal = b.value;
      BigInt expVal = e.value;

      if (expVal > BigInt.zero && expVal.toInt() <= 100) {
        // Compute power for small positive exponents
        return IntExpr(baseVal.pow(expVal.toInt()));
      }

      if (expVal < BigInt.zero) {
        // a^(-n) = 1/a^n
        return FracExpr(
          IntExpr.one,
          IntExpr(baseVal.pow(-expVal.toInt())),
        ).simplify();
      }
    }

    // (a^m)^n = a^(m*n)
    if (b is PowExpr) {
      Expr newExp = ProdExpr([b.exponent, e]).simplify();
      return PowExpr(b.base, newExp).simplify();
    }

    // Fractional exponent: a^(1/n) = nth root of a
    if (e is FracExpr) {
      Expr eSimp = e.simplify();
      if (eSimp is FracExpr && eSimp.numerator.value == BigInt.one) {
        // a^(1/n) = RootExpr(a, n)
        return RootExpr(b, eSimp.denominator).simplify();
      }
      if (eSimp is FracExpr) {
        // a^(m/n) = RootExpr(a^m, n)
        Expr raised = PowExpr(b, eSimp.numerator).simplify();
        return RootExpr(raised, eSimp.denominator).simplify();
      }
    }

    return PowExpr(b, e);
  }

  @override
  double toDouble() =>
      math.pow(base.toDouble(), exponent.toDouble()).toDouble();

  @override
  bool structurallyEquals(Expr other) {
    return other is PowExpr &&
        base.structurallyEquals(other.base) &&
        exponent.structurallyEquals(other.exponent);
  }

  // In PowExpr class, replace the termSignature getter:

  @override
  String get termSignature {
    Expr simpBase = base.simplify();
    Expr simpExp = exponent.simplify();
    return 'pow:$simpBase^$simpExp';
  }

  @override
  Expr get coefficient => IntExpr.one;

  @override
  Expr get baseExpr => this;

  @override
  bool get isZero => base.isZero;

  @override
  bool get isOne => base.isOne || exponent.isZero;

  @override
  bool get isRational {
    if (base.isRational && exponent is IntExpr) {
      return (exponent as IntExpr).value >= BigInt.zero;
    }
    return false;
  }

  @override
  bool get isInteger {
    if (base is IntExpr && exponent is IntExpr) {
      return (exponent as IntExpr).value >= BigInt.zero;
    }
    return false;
  }

  @override
  Expr negate() => ProdExpr([IntExpr.negOne, this]);

  @override
  List<MathNode> toMathNode() {
    return [
      ExponentNode(base: base.toMathNode(), power: exponent.toMathNode()),
    ];
  }

  @override
  Expr copy() => PowExpr(base.copy(), exponent.copy());

  @override
  String toString() => '($base)^($exponent)';
}

// ============================================================
// SECTION 8: ROOT EXPRESSION (SURDS)
// ============================================================

/// Represents the nth root of a value: ⁿ√radicand
class RootExpr extends Expr {
  final Expr radicand;
  final Expr index; // 2 for square root, 3 for cube root, etc.

  RootExpr(this.radicand, this.index);

  /// Convenience constructor for square root
  RootExpr.sqrt(this.radicand) : index = IntExpr.two;

  @override
  Expr simplify() {
    Expr rad = radicand.simplify();
    Expr idx = index.simplify();

    // √1 = 1
    if (rad.isOne) return IntExpr.one;

    // √0 = 0
    if (rad.isZero) return IntExpr.zero;

    // Only simplify when index is a positive integer
    if (idx is! IntExpr || idx.value <= BigInt.zero) {
      return RootExpr(rad, idx);
    }

    int n = idx.value.toInt();

    // For integer radicands, extract perfect nth powers
    if (rad is IntExpr) {
      return _simplifyIntegerRoot(rad.value, n);
    }

    // For fraction radicands: √(a/b) = √a / √b
    if (rad is FracExpr) {
      // For square roots, rationalize denominator: √(a/b) = √(ab) / b
      if (n == 2) {
        Expr newRadicand =
            ProdExpr([rad.numerator, rad.denominator]).simplify();
        Expr root = RootExpr.sqrt(newRadicand).simplify();
        return DivExpr(root, rad.denominator).simplify();
      }

      Expr numRoot = RootExpr(rad.numerator, idx).simplify();
      Expr denRoot = RootExpr(rad.denominator, idx).simplify();

      // Return as symbolic division of roots
      return DivExpr(numRoot, denRoot).simplify();
    }

    // For products: √(ab) - already handled by product combination

    return RootExpr(rad, idx);
  }

  /// Simplify √n by extracting perfect square factors
  Expr _simplifyIntegerRoot(BigInt n, int rootIndex) {
    if (n < BigInt.zero && rootIndex % 2 == 0) {
      // Even root of negative number - complex, keep as is for now
      return RootExpr(IntExpr(n), IntExpr.from(rootIndex));
    }

    bool isNegative = n < BigInt.zero;
    n = n.abs();

    // Factor out perfect nth powers
    // e.g., √72 = √(36*2) = 6√2

    Map<BigInt, int> factors = _primeFactorize(n);

    BigInt outsideRoot = BigInt.one;
    BigInt insideRoot = BigInt.one;

    for (var entry in factors.entries) {
      BigInt prime = entry.key;
      int power = entry.value;

      // How many complete groups of rootIndex can we extract?
      int extracted = power ~/ rootIndex;
      int remaining = power % rootIndex;

      // prime^extracted comes outside the root
      if (extracted > 0) {
        outsideRoot *= prime.pow(extracted);
      }

      // prime^remaining stays inside
      if (remaining > 0) {
        insideRoot *= prime.pow(remaining);
      }
    }

    // Handle odd roots of negative numbers
    if (isNegative && rootIndex % 2 == 1) {
      outsideRoot = -outsideRoot;
    }

    if (insideRoot == BigInt.one) {
      // Perfect nth power!
      return IntExpr(outsideRoot);
    }

    if (outsideRoot == BigInt.one) {
      // Nothing to extract
      return RootExpr(IntExpr(insideRoot), IntExpr.from(rootIndex));
    }

    // coefficient * root(insideRoot, rootIndex)
    return ProdExpr([
      IntExpr(outsideRoot),
      RootExpr(IntExpr(insideRoot), IntExpr.from(rootIndex)),
    ]);
  }

  /// Prime factorization of a positive integer
  Map<BigInt, int> _primeFactorize(BigInt n) {
    Map<BigInt, int> factors = {};
    BigInt divisor = BigInt.two;

    while (divisor * divisor <= n) {
      while (n % divisor == BigInt.zero) {
        factors[divisor] = (factors[divisor] ?? 0) + 1;
        n ~/= divisor;
      }
      divisor += BigInt.one;
    }

    if (n > BigInt.one) {
      factors[n] = (factors[n] ?? 0) + 1;
    }

    return factors;
  }
  // In RootExpr class, replace the termSignature getter:

  @override
  String get termSignature {
    // Use actual simplified values to distinguish √2 from √3
    Expr simpIndex = index.simplify();
    Expr simpRadicand = radicand.simplify();
    return 'root:$simpIndex:$simpRadicand';
  }

  @override
  double toDouble() {
    double r = radicand.toDouble();
    double n = index.toDouble();
    if (n == 2) return math.sqrt(r);
    return math.pow(r, 1 / n).toDouble();
  }

  @override
  bool structurallyEquals(Expr other) {
    return other is RootExpr &&
        radicand.structurallyEquals(other.radicand) &&
        index.structurallyEquals(other.index);
  }

  @override
  Expr get coefficient => IntExpr.one;

  @override
  Expr get baseExpr => this;

  @override
  bool get isZero => radicand.isZero;

  @override
  bool get isOne => radicand.isOne;

  @override
  bool get isRational {
    // √n is rational only if n is a perfect square
    Expr simplified = simplify();
    return simplified is IntExpr || simplified is FracExpr;
  }

  @override
  bool get isInteger {
    Expr simplified = simplify();
    return simplified is IntExpr;
  }

  @override
  Expr negate() => ProdExpr([IntExpr.negOne, this]);

  @override
  List<MathNode> toMathNode() {
    Expr simplified = simplify();

    // If it simplified to a rational, use that
    if (simplified != this &&
        (simplified is IntExpr || simplified is FracExpr)) {
      return simplified.toMathNode();
    }

    // If it's a product (coefficient * root), render that
    if (simplified is ProdExpr) {
      return simplified.toMathNode();
    }

    // Render as root node
    RootExpr root = simplified is RootExpr ? simplified : this;
    bool isSquareRoot =
        root.index is IntExpr && (root.index as IntExpr).value == BigInt.two;

    return [
      RootNode(
        isSquareRoot: isSquareRoot,
        index: isSquareRoot ? null : root.index.toMathNode(),
        radicand: root.radicand.toMathNode(),
      ),
    ];
  }

  @override
  Expr copy() => RootExpr(radicand.copy(), index.copy());

  @override
  String toString() {
    if (index is IntExpr && (index as IntExpr).value == BigInt.two) {
      return '√$radicand';
    }
    return '$index√$radicand';
  }
}

// ============================================================
// SECTION 9: LOGARITHM EXPRESSION
// ============================================================

/// Represents log_base(argument)
class LogExpr extends Expr {
  final Expr base;
  final Expr argument;
  final bool isNaturalLog;

  LogExpr(this.base, this.argument, {this.isNaturalLog = false});

  /// Natural logarithm
  LogExpr.ln(this.argument) : base = ConstExpr.e, isNaturalLog = true;

  /// Common logarithm (base 10)
  LogExpr.log10(this.argument) : base = IntExpr.from(10), isNaturalLog = false;

  @override
  Expr simplify() {
    Expr b = base.simplify();
    Expr arg = argument.simplify();

    // log_a(1) = 0
    if (arg.isOne) return IntExpr.zero;

    // log_a(a) = 1
    if (arg.structurallyEquals(b)) return IntExpr.one;

    // log_a(a^n) = n
    if (arg is PowExpr && arg.base.structurallyEquals(b)) {
      return arg.exponent.simplify();
    }

    // For integer base and argument, check if result is integer
    if (b is IntExpr &&
        arg is IntExpr &&
        b.value > BigInt.one &&
        arg.value > BigInt.zero) {
      int? result = _tryComputeIntLog(b.value, arg.value);
      if (result != null) {
        return IntExpr.from(result);
      }
    }

    return LogExpr(b, arg, isNaturalLog: isNaturalLog);
  }

  /// Try to compute log_base(arg) if it's an integer
  int? _tryComputeIntLog(BigInt base, BigInt arg) {
    if (arg == BigInt.one) return 0;

    BigInt current = base;
    int power = 1;

    while (current < arg) {
      current *= base;
      power++;
      if (power > 100) return null; // Prevent infinite loop
    }

    if (current == arg) return power;
    return null;
  }

  @override
  double toDouble() {
    if (isNaturalLog) {
      return math.log(argument.toDouble());
    }
    return math.log(argument.toDouble()) / math.log(base.toDouble());
  }

  @override
  bool structurallyEquals(Expr other) {
    return other is LogExpr &&
        base.structurallyEquals(other.base) &&
        argument.structurallyEquals(other.argument);
  }

  // In LogExpr class, replace the termSignature getter:

  @override
  String get termSignature {
    Expr simpBase = base.simplify();
    Expr simpArg = argument.simplify();
    return 'log:$simpBase:$simpArg';
  }

  @override
  Expr get coefficient => IntExpr.one;

  @override
  Expr get baseExpr => this;

  @override
  bool get isZero => argument.isOne;

  @override
  bool get isOne => argument.structurallyEquals(base);

  @override
  bool get isRational {
    Expr simplified = simplify();
    return simplified is IntExpr || simplified is FracExpr;
  }

  @override
  bool get isInteger {
    Expr simplified = simplify();
    return simplified is IntExpr;
  }

  @override
  Expr negate() => ProdExpr([IntExpr.negOne, this]);

  @override
  List<MathNode> toMathNode() {
    Expr simplified = simplify();

    // If simplified to integer, render that
    if (simplified is IntExpr) {
      return simplified.toMathNode();
    }

    LogExpr log = simplified is LogExpr ? simplified : this;

    return [
      LogNode(
        isNaturalLog: log.isNaturalLog,
        base:
            log.isNaturalLog ? [LiteralNode(text: 'e')] : log.base.toMathNode(),
        argument: log.argument.toMathNode(),
      ),
    ];
  }

  @override
  Expr copy() =>
      LogExpr(base.copy(), argument.copy(), isNaturalLog: isNaturalLog);

  @override
  String toString() {
    if (isNaturalLog) return 'ln($argument)';
    return 'log_$base($argument)';
  }
}

// ============================================================
// SECTION 10: TRIGONOMETRIC EXPRESSION
// ============================================================

enum TrigFunc {
  sin,
  cos,
  tan,
  asin,
  acos,
  atan,
  sinh,
  cosh,
  tanh,
  asinh,
  acosh,
  atanh,
}

/// Represents a trigonometric function
class TrigExpr extends Expr {
  final TrigFunc func;
  final Expr argument;

  TrigExpr(this.func, this.argument);

  @override
  Expr simplify() {
    Expr arg = argument.simplify();

    // Check for known exact values
    Expr? exact = _tryExactValue(arg);
    if (exact != null) return exact;

    return TrigExpr(func, arg);
  }

  /// Try to find exact value for common angles
  Expr? _tryExactValue(Expr arg) {
    // Handle zero argument explicitly
    if (arg.isZero) {
      switch (func) {
        case TrigFunc.sin:
          return IntExpr.zero; // sin(0) = 0
        case TrigFunc.cos:
          return IntExpr.one; // cos(0) = 1
        case TrigFunc.tan:
          return IntExpr.zero; // tan(0) = 0
        case TrigFunc.asin:
          return IntExpr.zero; // asin(0) = 0
        case TrigFunc.atan:
          return IntExpr.zero; // atan(0) = 0
        case TrigFunc.acos:
          // acos(0) = π/2
          return DivExpr(ConstExpr.pi, IntExpr.two).simplify();
        case TrigFunc.sinh:
          return IntExpr.zero; // sinh(0) = 0
        case TrigFunc.cosh:
          return IntExpr.one; // cosh(0) = 1
        case TrigFunc.tanh:
          return IntExpr.zero; // tanh(0) = 0
        case TrigFunc.asinh:
          return IntExpr.zero; // asinh(0) = 0
        case TrigFunc.acosh:
          return null; // acosh(0) not real
        case TrigFunc.atanh:
          return IntExpr.zero; // atanh(0) = 0
      }
    }

    // Handle argument = 1 for inverse trig
    if (arg.isOne) {
      switch (func) {
        case TrigFunc.asin:
          // asin(1) = π/2
          return DivExpr(ConstExpr.pi, IntExpr.two).simplify();
        case TrigFunc.acos:
          return IntExpr.zero; // acos(1) = 0
        case TrigFunc.atan:
          // atan(1) = π/4
          return DivExpr(ConstExpr.pi, IntExpr.from(4)).simplify();
        default:
          break;
      }
    }

    // Handle argument = -1 for inverse trig
    if (arg is IntExpr && arg.value == -BigInt.one) {
      switch (func) {
        case TrigFunc.asin:
          // asin(-1) = -π/2
          return DivExpr(ConstExpr.pi, IntExpr.from(-2)).simplify();
        case TrigFunc.acos:
          // acos(-1) = π
          return ConstExpr.pi;
        default:
          break;
      }
    }

    // Convert argument to a multiple of π for checking
    _PiFraction? piFrac = _asPiFraction(arg);
    if (piFrac == null) return null;

    // Normalize to [0, 2π)
    int num = piFrac.numerator % (2 * piFrac.denominator);
    if (num < 0) num += 2 * piFrac.denominator;
    int den = piFrac.denominator;

    switch (func) {
      case TrigFunc.sin:
        return _sinExact(num, den);
      case TrigFunc.cos:
        return _cosExact(num, den);
      case TrigFunc.tan:
        Expr? sinVal = _sinExact(num, den);
        Expr? cosVal = _cosExact(num, den);
        if (sinVal != null && cosVal != null && !cosVal.isZero) {
          return DivExpr(sinVal, cosVal).simplify();
        }
        return null;
      default:
        return null;
    }
  }

  /// Check if expr is a rational multiple of π
  _PiFraction? _asPiFraction(Expr expr) {
    if (expr is ConstExpr && expr.type == ConstType.pi) {
      return _PiFraction(1, 1);
    }

    if (expr is ProdExpr) {
      Expr? piPart;
      Expr? coeff;

      for (Expr f in expr.factors) {
        if (f is ConstExpr && f.type == ConstType.pi) {
          piPart = f;
        } else if (f.isRational) {
          coeff = coeff == null ? f : ProdExpr([coeff, f]).simplify();
        }
      }

      if (piPart != null && coeff != null) {
        if (coeff is IntExpr) {
          return _PiFraction(coeff.value.toInt(), 1);
        }
        if (coeff is FracExpr) {
          return _PiFraction(
            coeff.numerator.value.toInt(),
            coeff.denominator.value.toInt(),
          );
        }
      }
    }

    if (expr is FracExpr) {
      _PiFraction? numFrac = _asPiFraction(expr.numerator);
      final den = expr.denominator;
      if (numFrac != null) {
        return _PiFraction(
          numFrac.numerator,
          numFrac.denominator * den.value.toInt(),
        );
      }
    }

    if (expr is DivExpr) {
      _PiFraction? numFrac = _asPiFraction(expr.numerator);
      final den = expr.denominator;
      if (numFrac != null && den is IntExpr) {
        return _PiFraction(
          numFrac.numerator,
          numFrac.denominator * den.value.toInt(),
        );
      }
    }

    return null;
  }

  /// Get exact value of sin(num*π/den)
  Expr? _sinExact(int num, int den) {
    // Reduce to first quadrant and track sign
    int sign = 1;

    // sin is positive in [0, π], negative in [π, 2π]
    if (num > den) {
      sign = -1;
      num = 2 * den - num;
    }
    if (num > den) {
      num = 2 * den - num;
    }

    // Now num/den is in [0, 1] representing [0, π]
    // sin(π - x) = sin(x)
    if (num * 2 > den) {
      num = den - num;
    }

    // Known values for sin in [0, π/2]
    // sin(0) = 0
    if (num == 0) return IntExpr.zero;

    // sin(π/6) = 1/2
    if (num * 6 == den) {
      return sign == 1 ? FracExpr.from(1, 2) : FracExpr.from(-1, 2);
    }

    // sin(π/4) = √2/2
    if (num * 4 == den) {
      Expr val = DivExpr(RootExpr.sqrt(IntExpr.two), IntExpr.two);
      return sign == 1 ? val : val.negate();
    }

    // sin(π/3) = √3/2
    if (num * 3 == den) {
      Expr val = DivExpr(RootExpr.sqrt(IntExpr.from(3)), IntExpr.two);
      return sign == 1 ? val : val.negate();
    }

    // sin(π/2) = 1
    if (num * 2 == den) {
      return sign == 1 ? IntExpr.one : IntExpr.negOne;
    }

    return null;
  }

  /// Get exact value of cos(num*π/den)
  Expr? _cosExact(int num, int den) {
    // cos(x) = sin(π/2 - x) = sin((den - 2*num)/(2*den) * π)
    // But simpler: use cos(x) = sin(π/2 + x) relationship

    int sign = 1;

    // cos is positive in [0, π/2] and [3π/2, 2π], negative in [π/2, 3π/2]
    // Normalize to [0, 2π]
    num = num % (2 * den);
    if (num < 0) num += 2 * den;

    // cos(-x) = cos(x), so we can work with positive
    if (num > den) {
      num = 2 * den - num;
    }

    // Now num/den is in [0, 1] representing [0, π]
    if (num * 2 > den) {
      sign = -1;
      num = den - num;
    }

    // Known values for cos in [0, π/2]
    // cos(0) = 1
    if (num == 0) return sign == 1 ? IntExpr.one : IntExpr.negOne;

    // cos(π/6) = √3/2
    if (num * 6 == den) {
      Expr val = DivExpr(RootExpr.sqrt(IntExpr.from(3)), IntExpr.two);
      return sign == 1 ? val : val.negate();
    }

    // cos(π/4) = √2/2
    if (num * 4 == den) {
      Expr val = DivExpr(RootExpr.sqrt(IntExpr.two), IntExpr.two);
      return sign == 1 ? val : val.negate();
    }

    // cos(π/3) = 1/2
    if (num * 3 == den) {
      return sign == 1 ? FracExpr.from(1, 2) : FracExpr.from(-1, 2);
    }

    // cos(π/2) = 0
    if (num * 2 == den) return IntExpr.zero;

    return null;
  }

  @override
  double toDouble() {
    double a = argument.toDouble();
    switch (func) {
      case TrigFunc.sin:
        return math.sin(a);
      case TrigFunc.cos:
        return math.cos(a);
      case TrigFunc.tan:
        return math.tan(a);
      case TrigFunc.asin:
        return math.asin(a);
      case TrigFunc.acos:
        return math.acos(a);
      case TrigFunc.atan:
        return math.atan(a);
      case TrigFunc.sinh:
        return (math.exp(a) - math.exp(-a)) / 2;
      case TrigFunc.cosh:
        return (math.exp(a) + math.exp(-a)) / 2;
      case TrigFunc.tanh:
        return (math.exp(a) - math.exp(-a)) / (math.exp(a) + math.exp(-a));
      case TrigFunc.asinh:
        return math.log(a + math.sqrt(a * a + 1));
      case TrigFunc.acosh:
        return math.log(a + math.sqrt(a * a - 1));
      case TrigFunc.atanh:
        return 0.5 * math.log((1 + a) / (1 - a));
    }
  }

  @override
  bool structurallyEquals(Expr other) {
    return other is TrigExpr &&
        func == other.func &&
        argument.structurallyEquals(other.argument);
  }

  // ============================================================
  // SECTION 10: TRIGONOMETRIC EXPRESSION (continued)
  // ============================================================
  // In TrigExpr class, replace the termSignature getter (the one that was cut off):

  @override
  String get termSignature {
    Expr simpArg = argument.simplify();
    return 'trig:${func.name}:$simpArg';
  }

  @override
  Expr get coefficient => IntExpr.one;

  @override
  Expr get baseExpr => this;

  @override
  bool get isZero {
    Expr simplified = simplify();
    return simplified is IntExpr && simplified.isZero;
  }

  @override
  bool get isOne {
    Expr simplified = simplify();
    return simplified is IntExpr && simplified.isOne;
  }

  @override
  bool get isRational {
    Expr simplified = simplify();
    return simplified is IntExpr || simplified is FracExpr;
  }

  @override
  bool get isInteger {
    Expr simplified = simplify();
    return simplified is IntExpr;
  }

  @override
  Expr negate() => ProdExpr([IntExpr.negOne, this]);

  @override
  List<MathNode> toMathNode() {
    Expr simplified = simplify();

    // If simplified to something else, render that
    if (simplified is! TrigExpr) {
      return simplified.toMathNode();
    }

    String funcName;
    switch (func) {
      case TrigFunc.sin:
        funcName = 'sin';
        break;
      case TrigFunc.cos:
        funcName = 'cos';
        break;
      case TrigFunc.tan:
        funcName = 'tan';
        break;
      case TrigFunc.asin:
        funcName = 'asin';
        break;
      case TrigFunc.acos:
        funcName = 'acos';
        break;
      case TrigFunc.atan:
        funcName = 'atan';
        break;
      case TrigFunc.sinh:
        funcName = 'sinh';
        break;
      case TrigFunc.cosh:
        funcName = 'cosh';
        break;
      case TrigFunc.tanh:
        funcName = 'tanh';
        break;
      case TrigFunc.asinh:
        funcName = 'asinh';
        break;
      case TrigFunc.acosh:
        funcName = 'acosh';
        break;
      case TrigFunc.atanh:
        funcName = 'atanh';
        break;
    }

    return [TrigNode(function: funcName, argument: argument.toMathNode())];
  }

  @override
  Expr copy() => TrigExpr(func, argument.copy());

  @override
  String toString() => '${func.name}($argument)';
}

/// Helper class for representing fractions of π
class _PiFraction {
  final int numerator;
  final int denominator;

  _PiFraction(this.numerator, this.denominator);
}

// ============================================================
// SECTION 11: ABSOLUTE VALUE EXPRESSION
// ============================================================

/// Represents |expr|
class AbsExpr extends Expr {
  final Expr operand;

  AbsExpr(this.operand);

  @override
  Expr simplify() {
    Expr op = operand.simplify();

    // |n| for integer n
    if (op is IntExpr) {
      return IntExpr(op.value.abs());
    }

    // |a/b| = |a|/|b|
    if (op is FracExpr) {
      return FracExpr(
        IntExpr(op.numerator.value.abs()),
        IntExpr(op.denominator.value.abs()),
      ).simplify();
    }

    // |√x| = √x for x ≥ 0
    if (op is RootExpr) {
      // Assuming radicand is non-negative for real roots
      return op;
    }

    return AbsExpr(op);
  }

  @override
  double toDouble() => operand.toDouble().abs();

  @override
  bool structurallyEquals(Expr other) {
    return other is AbsExpr && operand.structurallyEquals(other.operand);
  }
  // In AbsExpr class, replace the termSignature getter:

  @override
  String get termSignature {
    Expr simpOp = operand.simplify();
    return 'abs:$simpOp';
  }

  @override
  Expr get coefficient => IntExpr.one;

  @override
  Expr get baseExpr => this;

  @override
  bool get isZero => operand.isZero;

  @override
  bool get isOne => operand.isOne || (operand.negate().simplify().isOne);

  @override
  bool get isRational {
    Expr simplified = simplify();
    return simplified is IntExpr || simplified is FracExpr;
  }

  @override
  bool get isInteger {
    Expr simplified = simplify();
    return simplified is IntExpr;
  }

  @override
  Expr negate() => ProdExpr([IntExpr.negOne, this]);

  @override
  List<MathNode> toMathNode() {
    Expr simplified = simplify();

    if (simplified is! AbsExpr) {
      return simplified.toMathNode();
    }

    // Render as |operand| using parentheses with | characters
    // For now, use TrigNode with "abs" function name
    return [TrigNode(function: 'abs', argument: operand.toMathNode())];
  }

  @override
  Expr copy() => AbsExpr(operand.copy());

  @override
  String toString() => '|$operand|';
}

// ============================================================
// SECTION 12: GENERAL FRACTION EXPRESSION (for symbolic fractions)
// ============================================================

/// Represents a fraction with any Expr as numerator and denominator
/// This is different from FracExpr which only holds IntExpr
class DivExpr extends Expr {
  final Expr numerator;
  final Expr denominator;

  DivExpr(this.numerator, this.denominator);

  @override
  Expr simplify() {
    Expr num = numerator.simplify();
    Expr den = denominator.simplify();

    // 0 / x = 0
    if (num.isZero) return IntExpr.zero;

    // x / 1 = x
    if (den.isOne) return num;

    // x / x = 1 (if x ≠ 0)
    if (num.structurallyEquals(den) && !den.isZero) {
      return IntExpr.one;
    }

    // If both are integers, use FracExpr
    if (num is IntExpr && den is IntExpr) {
      return FracExpr(num, den).simplify();
    }

    // If both are fractions, compute
    if (num is FracExpr && den is FracExpr) {
      return num.divide(den);
    }

    if (num is IntExpr && den is FracExpr) {
      return IntExpr(num.value).divide(den);
    }

    if (num is FracExpr && den is IntExpr) {
      return num.divide(den);
    }

    // √a / √b = √(a/b)
    if (num is RootExpr && den is RootExpr) {
      if (num.index.structurallyEquals(den.index)) {
        return RootExpr(
          DivExpr(num.radicand, den.radicand).simplify(),
          num.index,
        ).simplify();
      }
    }

    // a√b / c = (a/c)√b
    if (num is ProdExpr && den.isRational) {
      int ratIdx = num.factors.indexWhere((f) => f.isRational);
      if (ratIdx != -1) {
        Expr ratFactor = num.factors[ratIdx];
        Expr simplifiedCoeff = DivExpr(ratFactor, den).simplify();

        // Avoid infinite recursion by checking if anything changed
        bool changed = simplifiedCoeff is IntExpr;
        if (!changed && simplifiedCoeff is FracExpr) {
          if (ratFactor is IntExpr && den is IntExpr) {
            changed =
                simplifiedCoeff.numerator.value != ratFactor.value ||
                simplifiedCoeff.denominator.value != den.value;
          } else {
            changed = !ratFactor.structurallyEquals(simplifiedCoeff);
          }
        }

        // Check if separation is needed regardless of simplification
        // We need to look ahead to see if complex functions are involved
        bool shouldSeparate = false;
        List<Expr> tempOtherFactors = List.from(num.factors)..removeAt(ratIdx);
        Expr tempRemainder =
            tempOtherFactors.length == 1
                ? tempOtherFactors[0]
                : ProdExpr(tempOtherFactors).simplify();

        if (simplifiedCoeff is FracExpr &&
            _hasComplexFunctions(tempRemainder)) {
          shouldSeparate = true;
        }

        if (changed || shouldSeparate) {
          List<Expr> otherFactors = List.from(num.factors)..removeAt(ratIdx);
          Expr remainder =
              otherFactors.length == 1
                  ? otherFactors[0]
                  : ProdExpr(otherFactors).simplify();

          if (simplifiedCoeff is IntExpr) {
            if (simplifiedCoeff.isOne) return remainder;
            return ProdExpr([simplifiedCoeff, remainder]).simplify();
          } else if (simplifiedCoeff is FracExpr) {
            // Check if we should split the fraction:
            // Only if the remainder has complex functions (Trig, Log, Root)
            // or if the user prefers, we keep variables inside the fraction.
            bool hasComplex = _hasComplexFunctions(remainder);

            if (hasComplex) {
              return ProdExpr([simplifiedCoeff, remainder]).simplify();
            }

            // Otherwise keep as single fraction
            return DivExpr(
              ProdExpr([simplifiedCoeff.numerator, remainder]).simplify(),
              simplifiedCoeff.denominator,
            );
          }
        }
      }
    }

    // (a/b) / c = a / (b*c)
    if (num is FracExpr) {
      return DivExpr(
        num.numerator,
        ProdExpr([num.denominator, den]),
      ).simplify();
    }
    if (num is DivExpr) {
      return DivExpr(
        num.numerator,
        ProdExpr([num.denominator, den]),
      ).simplify();
    }

    // a / (b/c) = (a*c) / b
    if (den is FracExpr) {
      return DivExpr(
        ProdExpr([num, den.denominator]),
        den.numerator,
      ).simplify();
    }
    if (den is DivExpr) {
      return DivExpr(
        ProdExpr([num, den.denominator]),
        den.numerator,
      ).simplify();
    }

    // (a + b) / c = a/c + b/c
    // Distribute division over addition if the denominator is not a sum
    if (num is SumExpr && den is! SumExpr) {
      List<Expr> newTerms = [];
      for (Expr term in num.terms) {
        newTerms.add(DivExpr(term, den).simplify());
      }
      return SumExpr(newTerms).simplify();
    }

    return DivExpr(num, den);
  }

  bool _hasComplexFunctions(Expr expr) {
    if (expr is TrigExpr || expr is LogExpr || expr is RootExpr) return true;
    if (expr is ProdExpr) {
      return expr.factors.any((f) => _hasComplexFunctions(f));
    }
    if (expr is PowExpr) {
      return _hasComplexFunctions(expr.base);
    }
    return false;
  }

  @override
  double toDouble() => numerator.toDouble() / denominator.toDouble();

  @override
  bool structurallyEquals(Expr other) {
    return other is DivExpr &&
        numerator.structurallyEquals(other.numerator) &&
        denominator.structurallyEquals(other.denominator);
  }
  // In DivExpr class, replace the termSignature getter:

  @override
  String get termSignature {
    Expr simpNum = numerator.simplify();
    Expr simpDen = denominator.simplify();
    return 'div:$simpNum/$simpDen';
  }

  @override
  Expr get coefficient => IntExpr.one;

  @override
  Expr get baseExpr => this;

  @override
  bool get isZero => numerator.isZero;

  @override
  bool get isOne => numerator.structurallyEquals(denominator);

  @override
  bool get isRational {
    Expr simplified = simplify();
    return simplified is IntExpr || simplified is FracExpr;
  }

  @override
  bool get isInteger {
    Expr simplified = simplify();
    return simplified is IntExpr;
  }

  @override
  Expr negate() => DivExpr(numerator.negate(), denominator);

  @override
  List<MathNode> toMathNode() {
    Expr simplified = simplify();

    if (simplified is! DivExpr) {
      return simplified.toMathNode();
    }

    DivExpr div = simplified;

    // Check if the result is negative
    bool isNegative = false;
    Expr numToRender = div.numerator;

    if (div.numerator is IntExpr) {
      IntExpr numInt = div.numerator as IntExpr;
      if (numInt.value < BigInt.zero) {
        isNegative = true;
        numToRender = IntExpr(numInt.value.abs());
      }
    } else if (div.numerator is FracExpr) {
      FracExpr numFrac = div.numerator as FracExpr;
      if (numFrac.numerator.value < BigInt.zero) {
        isNegative = true;
        numToRender = FracExpr(
          IntExpr(numFrac.numerator.value.abs()),
          numFrac.denominator,
        );
      }
    }

    List<MathNode> result = [];

    if (isNegative) {
      result.add(LiteralNode(text: '−'));
    }

    result.add(
      FractionNode(
        num: numToRender.toMathNode(),
        den: div.denominator.toMathNode(),
      ),
    );

    return result;
  }

  @override
  Expr copy() => DivExpr(numerator.copy(), denominator.copy());

  @override
  String toString() => '($numerator)/($denominator)';
}

// ============================================================
// SECTION 13: PERMUTATION AND COMBINATION EXPRESSIONS
// ============================================================

/// Represents nPr (permutation)
class PermExpr extends Expr {
  final Expr n;
  final Expr r;

  PermExpr(this.n, this.r);

  @override
  Expr simplify() {
    Expr nSimp = n.simplify();
    Expr rSimp = r.simplify();

    // If both are non-negative integers, compute
    if (nSimp is IntExpr && rSimp is IntExpr) {
      BigInt nVal = nSimp.value;
      BigInt rVal = rSimp.value;

      if (nVal >= BigInt.zero && rVal >= BigInt.zero && rVal <= nVal) {
        // P(n,r) = n! / (n-r)!
        BigInt result = BigInt.one;
        for (BigInt i = nVal - rVal + BigInt.one; i <= nVal; i += BigInt.one) {
          result *= i;
        }
        return IntExpr(result);
      }
    }

    return PermExpr(nSimp, rSimp);
  }

  @override
  double toDouble() {
    int nVal = n.toDouble().toInt();
    int rVal = r.toDouble().toInt();

    double result = 1;
    for (int i = 0; i < rVal; i++) {
      result *= (nVal - i);
    }
    return result;
  }

  @override
  bool structurallyEquals(Expr other) {
    return other is PermExpr &&
        n.structurallyEquals(other.n) &&
        r.structurallyEquals(other.r);
  }

  @override
  String get termSignature => 'perm:${n.termSignature}:${r.termSignature}';

  @override
  Expr get coefficient => IntExpr.one;

  @override
  Expr get baseExpr => this;

  @override
  bool get isZero => false;

  @override
  bool get isOne {
    Expr simplified = simplify();
    return simplified is IntExpr && simplified.isOne;
  }

  @override
  bool get isRational {
    Expr simplified = simplify();
    return simplified is IntExpr;
  }

  @override
  bool get isInteger {
    Expr simplified = simplify();
    return simplified is IntExpr;
  }

  @override
  Expr negate() => ProdExpr([IntExpr.negOne, this]);

  @override
  List<MathNode> toMathNode() {
    Expr simplified = simplify();

    if (simplified is IntExpr) {
      return simplified.toMathNode();
    }

    return [PermutationNode(n: n.toMathNode(), r: r.toMathNode())];
  }

  @override
  Expr copy() => PermExpr(n.copy(), r.copy());

  @override
  String toString() => 'P($n,$r)';
}

/// Represents nCr (combination)
class CombExpr extends Expr {
  final Expr n;
  final Expr r;

  CombExpr(this.n, this.r);

  @override
  Expr simplify() {
    Expr nSimp = n.simplify();
    Expr rSimp = r.simplify();

    // If both are non-negative integers, compute
    if (nSimp is IntExpr && rSimp is IntExpr) {
      BigInt nVal = nSimp.value;
      BigInt rVal = rSimp.value;

      if (nVal >= BigInt.zero && rVal >= BigInt.zero && rVal <= nVal) {
        // C(n,r) = n! / (r! * (n-r)!)
        // Use the more efficient formula: C(n,r) = P(n,r) / r!

        // Optimize: use smaller of r and n-r
        if (rVal > nVal - rVal) {
          rVal = nVal - rVal;
        }

        BigInt result = BigInt.one;
        for (BigInt i = BigInt.zero; i < rVal; i += BigInt.one) {
          result *= (nVal - i);
          result ~/= (i + BigInt.one);
        }
        return IntExpr(result);
      }
    }

    return CombExpr(nSimp, rSimp);
  }

  @override
  double toDouble() {
    int nVal = n.toDouble().toInt();
    int rVal = r.toDouble().toInt();

    if (rVal > nVal - rVal) {
      rVal = nVal - rVal;
    }

    double result = 1;
    for (int i = 0; i < rVal; i++) {
      result *= (nVal - i);
      result /= (i + 1);
    }
    return result;
  }

  @override
  bool structurallyEquals(Expr other) {
    return other is CombExpr &&
        n.structurallyEquals(other.n) &&
        r.structurallyEquals(other.r);
  }

  @override
  String get termSignature => 'comb:${n.termSignature}:${r.termSignature}';

  @override
  Expr get coefficient => IntExpr.one;

  @override
  Expr get baseExpr => this;

  @override
  bool get isZero => false;

  @override
  bool get isOne {
    Expr simplified = simplify();
    return simplified is IntExpr && simplified.isOne;
  }

  @override
  bool get isRational {
    Expr simplified = simplify();
    return simplified is IntExpr;
  }

  @override
  bool get isInteger {
    Expr simplified = simplify();
    return simplified is IntExpr;
  }

  @override
  Expr negate() => ProdExpr([IntExpr.negOne, this]);

  @override
  List<MathNode> toMathNode() {
    Expr simplified = simplify();

    if (simplified is IntExpr) {
      return simplified.toMathNode();
    }

    return [CombinationNode(n: n.toMathNode(), r: r.toMathNode())];
  }

  @override
  Expr copy() => CombExpr(n.copy(), r.copy());

  @override
  String toString() => 'C($n,$r)';
}

// ============================================================
// SECTION 14: VARIABLE EXPRESSION (for equation solving)
// ============================================================

/// Represents a symbolic variable like x, y, z
class VarExpr extends Expr {
  final String name;

  VarExpr(this.name);

  @override
  Expr simplify() => this;

  @override
  double toDouble() {
    throw UnsupportedError('Cannot convert variable $name to double');
  }

  @override
  bool structurallyEquals(Expr other) {
    return other is VarExpr && other.name == name;
  }

  @override
  String get termSignature => 'var:$name';

  @override
  Expr get coefficient => IntExpr.one;

  @override
  Expr get baseExpr => this;

  @override
  bool get isZero => false;

  @override
  bool get isOne => false;

  @override
  bool get isRational => false;

  @override
  bool get isInteger => false;

  @override
  Expr negate() => ProdExpr([IntExpr.negOne, this]);

  @override
  List<MathNode> toMathNode() {
    return [LiteralNode(text: name)];
  }

  @override
  Expr copy() => VarExpr(name);

  @override
  String toString() => name;
}

// ============================================================
// SECTION 15: MATHNODE TO EXPR CONVERTER
// ============================================================

/// Converts a MathNode tree to an Expr tree for symbolic computation
class MathNodeToExpr {
  /// Reserved function names that should not be treated as variables
  static const Set<String> _reservedNames = {
    'sin',
    'cos',
    'tan',
    'asin',
    'acos',
    'atan',
    'sinh',
    'cosh',
    'tanh',
    'asinh',
    'acosh',
    'atanh',
    'log',
    'ln',
    'sqrt',
    'abs',
    'exp',
    'perm',
    'comb',
    'ans',
  };

  /// Convert a list of MathNodes to an Expr
  static Expr convert(List<MathNode> nodes, {Map<int, Expr>? ansExpressions}) {
    if (nodes.isEmpty) {
      return IntExpr.zero;
    }

    // First, tokenize the nodes to resolve structured content and handle implicit multiplication
    List<_Token> tokens = _tokenize(nodes, ansExpressions);

    if (tokens.isEmpty) {
      return IntExpr.zero;
    }

    // Parse tokens into Expr tree
    _TokenParser parser = _TokenParser(tokens);
    return parser.parse().simplify();
  }

  /// Tokenize the MathNode list into a flat list of tokens
  static List<_Token> _tokenize(
    List<MathNode> nodes,
    Map<int, Expr>? ansExpressions,
  ) {
    List<_Token> rawTokens = [];
    for (var node in nodes) {
      rawTokens.addAll(_tokenizeNode(node, ansExpressions));
    }

    if (rawTokens.isEmpty) return [];

    List<_Token> tokens = [rawTokens[0]];
    for (int i = 1; i < rawTokens.length; i++) {
      _Token lastToken = tokens.last;
      _Token currentToken = rawTokens[i];

      if (_needsImplicitMultiply(lastToken, currentToken)) {
        tokens.add(_Token(_TokenType.operator, '*'));
      }
      tokens.add(currentToken);
    }

    return tokens;
  }

  /// Check if implicit multiplication is needed between two tokens
  static bool _needsImplicitMultiply(_Token left, _Token right) {
    // Number followed by ( or expression
    if (left.type == _TokenType.number && right.type == _TokenType.lparen) {
      return true;
    }
    if (left.type == _TokenType.number && right.type == _TokenType.expr) {
      return true;
    }

    // ) followed by ( or number or expression
    if (left.type == _TokenType.rparen && right.type == _TokenType.lparen) {
      return true;
    }
    if (left.type == _TokenType.rparen && right.type == _TokenType.number) {
      return true;
    }
    if (left.type == _TokenType.rparen && right.type == _TokenType.expr) {
      return true;
    }

    // Expression followed by expression, (, or number
    if (left.type == _TokenType.expr && right.type == _TokenType.expr) {
      return true;
    }
    if (left.type == _TokenType.expr && right.type == _TokenType.lparen) {
      return true;
    }
    if (left.type == _TokenType.expr && right.type == _TokenType.number) {
      return true;
    }

    // Number followed by expression
    if (left.type == _TokenType.number && right.type == _TokenType.expr) {
      return true;
    }

    return false;
  }

  /// Tokenize a single MathNode
  static List<_Token> _tokenizeNode(
    MathNode node,
    Map<int, Expr>? ansExpressions,
  ) {
    if (node is LiteralNode) {
      return _tokenizeLiteral(node.text);
    }

    if (node is FractionNode) {
      Expr num = convert(node.numerator, ansExpressions: ansExpressions);
      Expr den = convert(node.denominator, ansExpressions: ansExpressions);
      return [_Token.fromExpr(DivExpr(num, den))];
    }

    if (node is ExponentNode) {
      Expr base = convert(node.base, ansExpressions: ansExpressions);
      Expr power = convert(node.power, ansExpressions: ansExpressions);
      return [_Token.fromExpr(PowExpr(base, power))];
    }

    if (node is RootNode) {
      Expr radicand = convert(node.radicand, ansExpressions: ansExpressions);
      Expr index;
      if (node.isSquareRoot) {
        index = IntExpr.two;
      } else {
        index = convert(node.index, ansExpressions: ansExpressions);
      }
      return [_Token.fromExpr(RootExpr(radicand, index))];
    }

    if (node is LogNode) {
      Expr argument = convert(node.argument, ansExpressions: ansExpressions);
      if (node.isNaturalLog) {
        return [_Token.fromExpr(LogExpr.ln(argument))];
      } else {
        Expr base = convert(node.base, ansExpressions: ansExpressions);
        return [_Token.fromExpr(LogExpr(base, argument))];
      }
    }

    if (node is TrigNode) {
      Expr argument = convert(node.argument, ansExpressions: ansExpressions);
      TrigFunc func;
      switch (node.function.toLowerCase()) {
        case 'sin':
          func = TrigFunc.sin;
          break;
        case 'cos':
          func = TrigFunc.cos;
          break;
        case 'tan':
          func = TrigFunc.tan;
          break;
        case 'asin':
          func = TrigFunc.asin;
          break;
        case 'acos':
          func = TrigFunc.acos;
          break;
        case 'atan':
          func = TrigFunc.atan;
          break;
        case 'sinh':
          func = TrigFunc.sinh;
          break;
        case 'cosh':
          func = TrigFunc.cosh;
          break;
        case 'tanh':
          func = TrigFunc.tanh;
          break;
        case 'asinh':
          func = TrigFunc.asinh;
          break;
        case 'acosh':
          func = TrigFunc.acosh;
          break;
        case 'atanh':
          func = TrigFunc.atanh;
          break;
        case 'abs':
          return [_Token.fromExpr(AbsExpr(argument))];
        default:
          // Unknown function, return as-is
          return [_Token.fromExpr(TrigExpr(TrigFunc.sin, argument))];
      }
      return [_Token.fromExpr(TrigExpr(func, argument))];
    }

    if (node is ParenthesisNode) {
      Expr content = convert(node.content, ansExpressions: ansExpressions);
      // Just return the content - parentheses are for grouping
      return [_Token.fromExpr(content)];
    }

    if (node is PermutationNode) {
      Expr n = convert(node.n, ansExpressions: ansExpressions);
      Expr r = convert(node.r, ansExpressions: ansExpressions);
      return [_Token.fromExpr(PermExpr(n, r))];
    }

    if (node is CombinationNode) {
      Expr n = convert(node.n, ansExpressions: ansExpressions);
      Expr r = convert(node.r, ansExpressions: ansExpressions);
      return [_Token.fromExpr(CombExpr(n, r))];
    }

    if (node is ConstantNode) {
      ConstType type;
      switch (node.constant) {
        case '\u03C0':
          type = ConstType.pi;
          break;
        case 'e':
          type = ConstType.e;
          break;
        case '\u03B5\u2080':
          type = ConstType.epsilon0;
          break;
        case '\u00B5\u2080':
          type = ConstType.mu0;
          break;
        case 'c\u2080':
          type = ConstType.c0;
          break;
        case 'e\u207b':
          type = ConstType.eMinus;
          break;
        default:
          return [_Token.fromExpr(VarExpr(node.constant))];
      }
      return [_Token.fromExpr(ConstExpr(type))];
    }

    if (node is AnsNode) {
      // ANS reference - resolve against the map
      String indexStr = _extractLiteralText(node.index);
      int? idx = int.tryParse(indexStr);
      if (idx != null &&
          ansExpressions != null &&
          ansExpressions.containsKey(idx)) {
        Expr? resolved = ansExpressions[idx];
        if (resolved != null) {
          return [_Token.fromExpr(resolved)];
        }
      }
      // If not resolvable, treat as variable ansX
      return [_Token.fromExpr(VarExpr('ans$indexStr'))];
    }

    if (node is NewlineNode) {
      // Ignore newlines for expression evaluation
      return [];
    }

    return [];
  }

  /// Extract text from a list of MathNodes (for simple cases like ANS index)
  static String _extractLiteralText(List<MathNode> nodes) {
    StringBuffer buffer = StringBuffer();
    for (MathNode node in nodes) {
      if (node is LiteralNode) {
        buffer.write(node.text);
      }
    }
    return buffer.toString();
  }

  /// Tokenize a literal string into tokens
  static List<_Token> _tokenizeLiteral(String text) {
    List<_Token> tokens = [];
    text = text.trim();

    if (text.isEmpty) {
      return tokens;
    }

    // Normalize operators
    text = text.replaceAll('\u00B7', '*'); // middle dot
    text = text.replaceAll('\u00D7', '*'); // times sign
    text = text.replaceAll('\u2212', '-'); // minus sign
    text = text.replaceAll('\u00F7', '/'); // division sign

    int i = 0;
    while (i < text.length) {
      String char = text[i];

      // Skip whitespace
      if (char == ' ') {
        i++;
        continue;
      }

      // Operators
      if (char == '+' ||
          char == '-' ||
          char == '*' ||
          char == '/' ||
          char == '^') {
        tokens.add(_Token(_TokenType.operator, char));
        i++;
        continue;
      }

      // Equals
      if (char == '=') {
        tokens.add(_Token(_TokenType.equals, char));
        i++;
        continue;
      }

      // Parentheses
      if (char == '(') {
        tokens.add(_Token(_TokenType.lparen, '('));
        i++;
        continue;
      }
      if (char == ')') {
        tokens.add(_Token(_TokenType.rparen, ')'));
        i++;
        continue;
      }

      // Numbers (including decimals and scientific notation)
      if (_isDigit(char) ||
          (char == '.' && i + 1 < text.length && _isDigit(text[i + 1]))) {
        String numStr = '';
        while (i < text.length && (_isDigit(text[i]) || text[i] == '.')) {
          numStr += text[i];
          i++;
        }

        // Check for scientific notation
        if (i < text.length &&
            (text[i] == 'e' || text[i] == 'E' || text[i] == '\u1D07')) {
          numStr += 'e';
          i++;
          if (i < text.length && (text[i] == '+' || text[i] == '-')) {
            numStr += text[i];
            i++;
          }
          while (i < text.length && _isDigit(text[i])) {
            numStr += text[i];
            i++;
          }
        }

        tokens.add(_Token(_TokenType.number, numStr));
        continue;
      }

      if (char == 'π' || char == '\u03C0') {
        tokens.add(_Token.fromExpr(ConstExpr.pi));
        i++;
        continue;
      }

      if (char == 'e' && (i + 1 >= text.length || !_isLetter(text[i + 1]))) {
        tokens.add(_Token.fromExpr(ConstExpr.e));
        i++;
        continue;
      }

      if (char == 'φ') {
        tokens.add(_Token.fromExpr(ConstExpr.phi));
        i++;
        continue;
      }

      if (char == '\u03B5' && i + 1 < text.length && text[i + 1] == '\u2080') {
        tokens.add(_Token.fromExpr(ConstExpr.epsilon0));
        i += 2;
        continue;
      }

      if ((char == '\u03BC' || char == '\u00B5') &&
          i + 1 < text.length &&
          text[i + 1] == '\u2080') {
        tokens.add(_Token.fromExpr(ConstExpr.mu0));
        i += 2;
        continue;
      }

      if (char == 'c' && i + 1 < text.length && text[i + 1] == '\u2080') {
        tokens.add(_Token.fromExpr(ConstExpr.c0));
        i += 2;
        continue;
      }

      // Letters (variables or function names)
      if (_isLetter(char)) {
        String word = '';
        while (i < text.length && (_isLetter(text[i]) || _isDigit(text[i]))) {
          word += text[i];
          i++;
        }

        // Check for constants
        if (word == 'pi' || word == 'PI') {
          tokens.add(_Token.fromExpr(ConstExpr.pi));
          continue;
        }
        if (word == 'e' && (i >= text.length || !_isLetter(text[i]))) {
          // Standalone 'e' is Euler's number
          tokens.add(_Token.fromExpr(ConstExpr.e));
          continue;
        }

        // Check for reserved function names (handled by nodes, but just in case)
        if (_reservedNames.contains(word.toLowerCase())) {
          // This shouldn't happen if nodes are used, but treat as variable for safety
          tokens.add(_Token.fromExpr(VarExpr(word)));
          continue;
        }

        // Regular variable
        tokens.add(_Token.fromExpr(VarExpr(word)));
        continue;
      }

      // Unknown character - skip
      i++;
    }

    return tokens;
  }

  static bool _isDigit(String char) {
    return char.isNotEmpty && '0123456789'.contains(char);
  }

  static bool _isLetter(String char) {
    return char.isNotEmpty && RegExp(r'[a-zA-Zα-ωΑ-Ω]').hasMatch(char);
  }
}

// ============================================================
// SECTION 16: TOKEN TYPES AND PARSER
// ============================================================

enum _TokenType {
  number,
  operator,
  lparen,
  rparen,
  equals,
  expr, // Pre-built Expr from structured nodes
}

class _Token {
  final _TokenType type;
  final String value;
  final Expr? expr;

  _Token(this.type, this.value) : expr = null;

  _Token.fromExpr(Expr e) : type = _TokenType.expr, value = '', expr = e;
}

/// Parser for token list into Expr tree
class _TokenParser {
  final List<_Token> tokens;
  int pos = 0;

  _TokenParser(this.tokens);

  Expr parse() {
    Expr result = _parseAddSub();
    return result;
  }

  Expr _parseAddSub() {
    Expr left = _parseMulDiv();

    while (pos < tokens.length) {
      _Token token = tokens[pos];
      if (token.type != _TokenType.operator) break;

      String val = token.value.trim();
      bool isPlus = val == '+' || val == '\u002B';
      bool isMinus = val == '-' || val == '\u2212' || val == '\u002D';

      if (!isPlus && !isMinus) break;

      pos++;
      Expr right = _parseMulDiv();

      if (isPlus) {
        left = SumExpr([left, right]);
      } else {
        left = SumExpr([left, right.negate()]);
      }
    }

    return left;
  }

  Expr _parseMulDiv() {
    Expr left = _parsePower();

    while (pos < tokens.length) {
      _Token token = tokens[pos];
      if (token.type != _TokenType.operator) break;
      if (token.value != '*' && token.value != '/') break;

      pos++;
      Expr right = _parsePower();

      if (token.value == '*') {
        left = ProdExpr([left, right]);
      } else {
        left = DivExpr(left, right);
      }
    }

    return left;
  }

  Expr _parsePower() {
    Expr base = _parseUnary();

    while (pos < tokens.length) {
      _Token token = tokens[pos];
      if (token.type != _TokenType.operator || token.value != '^') break;

      pos++;
      Expr exponent = _parseUnary();
      base = PowExpr(base, exponent);
    }

    return base;
  }

  Expr _parseUnary() {
    if (pos < tokens.length) {
      _Token token = tokens[pos];

      if (token.type == _TokenType.operator && token.value == '-') {
        pos++;
        Expr operand = _parseUnary();
        return operand.negate();
      }

      if (token.type == _TokenType.operator && token.value == '+') {
        pos++;
        return _parseUnary();
      }
    }

    return _parsePrimary();
  }

  Expr _parsePrimary() {
    if (pos >= tokens.length) {
      return IntExpr.zero;
    }

    _Token token = tokens[pos];

    // Pre-built expression from structured node
    if (token.type == _TokenType.expr) {
      pos++;
      return token.expr!;
    }

    // Number
    if (token.type == _TokenType.number) {
      pos++;
      return _parseNumber(token.value);
    }

    // Parenthesized expression
    if (token.type == _TokenType.lparen) {
      pos++; // consume (
      Expr inner = _parseAddSub();

      if (pos < tokens.length && tokens[pos].type == _TokenType.rparen) {
        pos++; // consume )
      }

      return inner;
    }

    // Fallback
    return IntExpr.zero;
  }

  /// Parse a number string into an Expr
  Expr _parseNumber(String numStr) {
    // Try parsing as integer first
    BigInt? intVal = BigInt.tryParse(numStr);
    if (intVal != null) {
      return IntExpr(intVal);
    }

    // Try parsing as double
    double? doubleVal = double.tryParse(numStr);
    if (doubleVal != null) {
      // Convert to fraction if possible
      return _doubleToFraction(doubleVal);
    }

    return IntExpr.zero;
  }

  /// Convert a double to a fraction (for simple decimals)
  Expr _doubleToFraction(double value) {
    // Check if it's effectively an integer
    if ((value - value.roundToDouble()).abs() < 1e-10) {
      return IntExpr.from(value.round());
    }

    // Try to find a simple fraction representation
    // For terminating decimals like 0.5, 0.25, 0.125, etc.

    String str = value.toString();
    if (str.contains('e') || str.contains('E')) {
      // Scientific notation - just use approximation
      return IntExpr.from(value.round());
    }

    int decimalIndex = str.indexOf('.');
    if (decimalIndex == -1) {
      return IntExpr.from(value.toInt());
    }

    String decimalPart = str.substring(decimalIndex + 1);
    int decimalPlaces = decimalPart.length;

    // Limit decimal places for sanity
    if (decimalPlaces > 10) {
      // Too many decimals - approximate
      return IntExpr.from(value.round());
    }

    // Create fraction: value = intPart + decPart/10^decimalPlaces
    BigInt denominator = BigInt.from(10).pow(decimalPlaces);
    BigInt numerator = BigInt.from((value * denominator.toDouble()).round());

    return FracExpr(IntExpr(numerator), IntExpr(denominator)).simplify();
  }
}

// ============================================================
// SECTION 17: MAIN ENGINE CLASS
// ============================================================

/// Main entry point for exact symbolic math computation
class ExactMathEngine {
  /// Evaluate an expression from MathNode tree
  static ExactResult evaluate(
    List<MathNode> expression, {
    Map<int, Expr>? ansExpressions,
  }) {
    try {
      if (_isEmptyExpression(expression)) {
        return ExactResult.empty();
      }

      // Normalize expression nodes (split embedded = and \n)
      expression = _normalizeNodes(expression);

      if (_isIncompleteExpression(expression)) {
        // print('DEBUG: Incomplete expression');
        return ExactResult.empty();
      }

      // 1. Handle multi-line results (system of equations)
      if (expression.any((n) => n is NewlineNode)) {
        // print('DEBUG: Routing to _solveMultiLine');
        return _solveMultiLine(expression, ansExpressions);
      }

      // 2. Handle single equation
      if (expression.any((n) => n is LiteralNode && n.text.contains('='))) {
        // print('DEBUG: Routing to _solveSingleEquation');
        return _solveSingleEquation(expression, ansExpressions);
      }

      // 3. Regular expression evaluation
      Expr expr = MathNodeToExpr.convert(
        expression,
        ansExpressions: ansExpressions,
      );

      Expr simplified = expr.simplify();

      double? numerical;
      try {
        numerical = simplified.toDouble();
      } catch (e) {
        numerical = null;
      }

      if (numerical != null && numerical.isNaN) {
        return ExactResult.empty();
      }

      if (numerical != null && numerical.isInfinite) {
        return ExactResult(
          expr: simplified,
          mathNodes: [LiteralNode(text: numerical.isNegative ? '-∞' : '∞')],
          numerical: numerical,
        );
      }

      return ExactResult(
        expr: simplified,
        mathNodes: simplified.toMathNode(),
        numerical: numerical,
        isExact: _hasIrrationalParts(simplified),
      );
    } catch (e) {
      return ExactResult.empty();
    }
  }

  static ExactResult _solveMultiLine(
    List<MathNode> expression,
    Map<int, Expr>? ansExpressions,
  ) {
    List<List<MathNode>> linesData = [];
    List<MathNode> currentLine = [];
    for (var node in expression) {
      if (node is NewlineNode) {
        if (currentLine.isNotEmpty) linesData.add(List.from(currentLine));
        currentLine = [];
      } else {
        currentLine.add(node);
      }
    }
    if (currentLine.isNotEmpty) linesData.add(currentLine);

    if (linesData.isEmpty) return ExactResult.empty();

    // If it's multi-line, it's either an expression list or a system of equations
    bool isSystem = linesData.any(
      (line) => line.any((n) => n is LiteralNode && n.text.contains('=')),
    );

    if (isSystem) {
      return _solveLinearSystem(linesData, ansExpressions);
    }

    // Default: Multi-line expressions (though usually results are single line)
    // For now, just evaluate the first line or join them?
    // Let's just evaluate the first line for simplicity if it's not a system
    return evaluate(linesData.first, ansExpressions: ansExpressions);
  }

  static ExactResult _solveSingleEquation(
    List<MathNode> expression,
    Map<int, Expr>? ansExpressions,
  ) {
    // Split into left and right
    int eqIndex = expression.indexWhere(
      (n) => n is LiteralNode && n.text.contains('='),
    );
    if (eqIndex == -1) return ExactResult.empty();

    List<MathNode> leftNodes = expression.sublist(0, eqIndex);
    List<MathNode> rightNodes = expression.sublist(eqIndex + 1);

    // Some literal nodes might contain '=' and other text, but usually it's just '='
    // If LiteralNode has "x = 5", we need to be careful.
    // In our renderer, '=' is usually its own LiteralNode.

    Expr left = MathNodeToExpr.convert(
      leftNodes,
      ansExpressions: ansExpressions,
    );
    Expr right = MathNodeToExpr.convert(
      rightNodes,
      ansExpressions: ansExpressions,
    );

    // Rearrange to f(x) = 0
    Expr combined = SumExpr([left, right.negate()]).simplify();

    // Find variables
    Set<String> variables = _findVariables(combined);
    if (variables.isEmpty) return ExactResult.empty();
    if (variables.length > 1) {
      // Cannot solve single equation with multiple variables symbolically easily here
      return ExactResult.empty();
    }

    String varName = variables.first;

    // Try quadratic solver
    var solutions = _solveQuadratic(combined, varName);
    if (solutions != null && solutions.isNotEmpty) {
      List<MathNode> nodes = [];
      for (int i = 0; i < solutions.length; i++) {
        if (i > 0) nodes.add(NewlineNode());
        nodes.add(LiteralNode(text: '$varName = '));
        nodes.addAll(solutions[i].toMathNode());
      }
      return ExactResult(
        expr: solutions.first, // Just a representative
        mathNodes: nodes,
        isExact: true,
      );
    }

    // Try linear solver if quadratic failed (or was linear)
    var linearSol = _solveLinear(combined, varName);
    if (linearSol != null) {
      List<MathNode> nodes = [LiteralNode(text: '$varName = ')];
      nodes.addAll(linearSol.toMathNode());
      return ExactResult(expr: linearSol, mathNodes: nodes, isExact: true);
    }

    return ExactResult.empty();
  }

  static Set<String> _findVariables(Expr expr) {
    Set<String> vars = {};
    if (expr is VarExpr) {
      vars.add(expr.name);
    } else if (expr is SumExpr) {
      for (var t in expr.terms) {
        vars.addAll(_findVariables(t));
      }
    } else if (expr is ProdExpr) {
      for (var f in expr.factors) {
        vars.addAll(_findVariables(f));
      }
    } else if (expr is DivExpr) {
      vars.addAll(_findVariables(expr.numerator));
      vars.addAll(_findVariables(expr.denominator));
    } else if (expr is PowExpr) {
      vars.addAll(_findVariables(expr.base));
      vars.addAll(_findVariables(expr.exponent));
    } else if (expr is RootExpr) {
      vars.addAll(_findVariables(expr.radicand));
      vars.addAll(_findVariables(expr.index));
    } else if (expr is LogExpr) {
      vars.addAll(_findVariables(expr.argument));
      vars.addAll(_findVariables(expr.base));
    } else if (expr is TrigExpr) {
      vars.addAll(_findVariables(expr.argument));
    }
    return vars;
  }

  static Map<String, Expr> _getPolynomialCoeffs(Expr expr, String varName) {
    // Very simplified polynomial coefficient extraction (a*x^2 + b*x + c)
    Map<String, Expr> coeffs = {
      'c2': IntExpr.zero,
      'c1': IntExpr.zero,
      'c0': IntExpr.zero,
    };

    Expr flattened = expr.simplify();

    List<Expr> terms = (flattened is SumExpr) ? flattened.terms : [flattened];

    for (var term in terms) {
      // Check for x^2
      if (term is PowExpr &&
          term.base is VarExpr &&
          (term.base as VarExpr).name == varName &&
          term.exponent is IntExpr &&
          (term.exponent as IntExpr).value == BigInt.two) {
        coeffs['c2'] = SumExpr([coeffs['c2']!, IntExpr.one]).simplify();
      } else if (term is ProdExpr &&
          term.factors.any((f) {
            if (f is PowExpr) {
              final b = f.base;
              final e = f.exponent;
              return b is VarExpr &&
                  b.name == varName &&
                  e is IntExpr &&
                  e.value == BigInt.two;
            }
            return false;
          })) {
        List<Expr> others =
            term.factors
                .where(
                  (f) =>
                      !(f is PowExpr &&
                          f.base is VarExpr &&
                          (f.base as VarExpr).name == varName),
                )
                .toList();
        Expr coeff =
            others.isEmpty
                ? IntExpr.one
                : (others.length == 1 ? others.first : ProdExpr(others));
        coeffs['c2'] = SumExpr([coeffs['c2']!, coeff]).simplify();
      }
      // Check for x
      else if (term is VarExpr && term.name == varName) {
        coeffs['c1'] = SumExpr([coeffs['c1']!, IntExpr.one]).simplify();
      } else if (term is ProdExpr &&
          term.factors.any((f) => f is VarExpr && f.name == varName)) {
        List<Expr> others =
            term.factors
                .where((f) => !(f is VarExpr && f.name == varName))
                .toList();
        Expr coeff =
            others.isEmpty
                ? IntExpr.one
                : (others.length == 1 ? others.first : ProdExpr(others));
        coeffs['c1'] = SumExpr([coeffs['c1']!, coeff]).simplify();
      }
      // Constant
      else if (!_findVariables(term).contains(varName)) {
        coeffs['c0'] = SumExpr([coeffs['c0']!, term]).simplify();
      }
    }
    return coeffs;
  }

  static Expr? _solveLinear(Expr combined, String varName) {
    var coeffs = _getLinearCoeffs(combined, varName);
    if (coeffs == null) return null;
    Expr a = coeffs.$1;
    Expr b = coeffs.$2; // b is the constant term in ax + b = 0

    if (a.isZero) return null;

    // x = -b / a
    return DivExpr(b.negate(), a).simplify();
  }

  static (Expr, Expr)? _getLinearCoeffs(Expr expr, String varName) {
    Expr a = IntExpr.zero;
    Expr b = IntExpr.zero;

    List<Expr> terms = (expr is SumExpr) ? expr.terms : [expr];
    for (var term in terms) {
      if (term is VarExpr && term.name == varName) {
        a = SumExpr([a, IntExpr.one]).simplify();
      } else if (term is ProdExpr &&
          term.factors.any((f) => f is VarExpr && f.name == varName)) {
        List<Expr> others =
            term.factors
                .where((f) => !(f is VarExpr && f.name == varName))
                .toList();
        Expr coeff =
            others.isEmpty
                ? IntExpr.one
                : (others.length == 1 ? others.first : ProdExpr(others));
        a = SumExpr([a, coeff]).simplify();
      } else if (!_findVariables(term).contains(varName)) {
        b = SumExpr([b, term]).simplify();
      } else {
        // Not linear
        return null;
      }
    }
    return (a, b);
  }

  static List<Expr>? _solveQuadratic(Expr combined, String varName) {
    var coeffs = _getPolynomialCoeffs(combined, varName);
    Expr a = coeffs['c2']!;
    Expr b = coeffs['c1']!;
    Expr c = coeffs['c0']!;

    if (a.isZero) return null;

    // x = (-b ± √(b^2 - 4ac)) / 2a
    Expr discriminant =
        SumExpr([
          PowExpr(b, IntExpr.two),
          ProdExpr([IntExpr.from(-4), a, c]),
        ]).simplify();

    Expr rootD = RootExpr(discriminant, IntExpr.two).simplify();

    Expr sol1 =
        DivExpr(
          SumExpr([b.negate(), rootD]),
          ProdExpr([IntExpr.two, a]),
        ).simplify();
    Expr sol2 =
        DivExpr(
          SumExpr([b.negate(), rootD.negate()]),
          ProdExpr([IntExpr.two, a]),
        ).simplify();

    if (sol1.structurallyEquals(sol2)) return [sol1];
    return [sol1, sol2];
  }

  static ExactResult _solveLinearSystem(
    List<List<MathNode>> lines,
    Map<int, Expr>? ansExpressions,
  ) {
    List<(Map<String, Expr>, Expr)> equations = [];
    Set<String> allVars = {};

    for (var line in lines) {
      int eqIndex = line.indexWhere(
        (n) => n is LiteralNode && n.text.contains('='),
      );
      Expr left, right;
      if (eqIndex != -1) {
        left = MathNodeToExpr.convert(
          line.sublist(0, eqIndex),
          ansExpressions: ansExpressions,
        );
        right = MathNodeToExpr.convert(
          line.sublist(eqIndex + 1),
          ansExpressions: ansExpressions,
        );
      } else {
        left = MathNodeToExpr.convert(line, ansExpressions: ansExpressions);
        right = IntExpr.zero;
      }

      Expr combined = SumExpr([left, right.negate()]).simplify();
      Set<String> lineVars = _findVariables(combined);
      allVars.addAll(lineVars);

      // Extract coefficients ax + by + ... + const = 0 => ax + by + ... = -const
      Map<String, Expr> coeffs = {};
      Expr constant = IntExpr.zero;

      List<Expr> terms = (combined is SumExpr) ? combined.terms : [combined];
      for (var term in terms) {
        bool matched = false;
        for (var v in lineVars) {
          if (term is VarExpr && term.name == v) {
            coeffs[v] =
                SumExpr([coeffs[v] ?? IntExpr.zero, IntExpr.one]).simplify();
            matched = true;
            break;
          } else if (term is ProdExpr &&
              term.factors.any((f) => f is VarExpr && f.name == v)) {
            List<Expr> others =
                term.factors
                    .where((f) => !(f is VarExpr && f.name == v))
                    .toList();
            Expr coeff =
                others.isEmpty
                    ? IntExpr.one
                    : (others.length == 1 ? others.first : ProdExpr(others));
            coeffs[v] = SumExpr([coeffs[v] ?? IntExpr.zero, coeff]).simplify();
            matched = true;
            break;
          }
        }
        if (!matched) {
          constant = SumExpr([constant, term]).simplify();
        }
      }
      equations.add((coeffs, constant.negate().simplify()));
    }

    List<String> sortedVars = allVars.toList()..sort();
    if (sortedVars.length > equations.length || sortedVars.isEmpty) {
      return ExactResult.empty();
    }

    // We only solve square systems for now
    if (sortedVars.length != equations.length) {
      // Try solving as many as possible? No, usually expect square.
      return ExactResult.empty();
    }

    // Matrix form: A * X = B
    List<List<Expr>> matrixA = [];
    List<Expr> vectorB = [];

    for (var eq in equations) {
      List<Expr> row = [];
      for (var v in sortedVars) {
        row.add(eq.$1[v] ?? IntExpr.zero);
      }
      matrixA.add(row);
      vectorB.add(eq.$2);
    }

    Expr detA = _determinantExpr(matrixA).simplify();
    if (detA.isZero) return ExactResult.empty();

    List<MathNode> resultNodes = [];
    for (int i = 0; i < sortedVars.length; i++) {
      List<List<Expr>> matrixAi = [];
      for (int r = 0; r < matrixA.length; r++) {
        List<Expr> row = List.from(matrixA[r]);
        row[i] = vectorB[r];
        matrixAi.add(row);
      }
      Expr detAi = _determinantExpr(matrixAi).simplify();
      Expr solution = DivExpr(detAi, detA).simplify();

      if (i > 0) resultNodes.add(NewlineNode());
      resultNodes.add(LiteralNode(text: '${sortedVars[i]} = '));
      resultNodes.addAll(solution.toMathNode());
    }

    return ExactResult(
      expr: IntExpr.zero, // Dummy
      mathNodes: resultNodes,
      isExact: true,
    );
  }

  static Expr _determinantExpr(List<List<Expr>> matrix) {
    int n = matrix.length;
    if (n == 1) return matrix[0][0];
    if (n == 2) {
      return SumExpr([
        ProdExpr([matrix[0][0], matrix[1][1]]),
        ProdExpr([IntExpr.negOne, matrix[0][1], matrix[1][0]]),
      ]);
    }

    List<Expr> terms = [];
    for (int i = 0; i < n; i++) {
      List<List<Expr>> subMatrix = [];
      for (int j = 1; j < n; j++) {
        List<Expr> row = List.from(matrix[j]);
        row.removeAt(i);
        subMatrix.add(row);
      }
      Expr subDet = _determinantExpr(subMatrix);
      Expr term = ProdExpr([matrix[0][i], subDet]);
      if (i % 2 != 0) term = term.negate();
      terms.add(term);
    }
    return SumExpr(terms);
  }

  /// Normalizes expression nodes by splitting LiteralNodes containing '=' or '\n'
  static List<MathNode> _normalizeNodes(List<MathNode> nodes) {
    List<MathNode> result = [];
    for (var node in nodes) {
      if (node is LiteralNode) {
        String text = node.text;
        if (text.contains('\n') || text.contains('=')) {
          // Split by \n first
          List<String> lines = text.split('\n');
          for (int i = 0; i < lines.length; i++) {
            if (i > 0) result.add(NewlineNode());

            // Split by = within each line
            String line = lines[i];
            List<String> parts = line.split('=');
            for (int j = 0; j < parts.length; j++) {
              if (j > 0) result.add(LiteralNode(text: '='));
              if (parts[j].isNotEmpty) {
                result.add(LiteralNode(text: parts[j]));
              }
            }
          }
        } else {
          result.add(node);
        }
      } else {
        result.add(node);
      }
    }
    return result;
  }

  /// Check if the expression is empty
  static bool _isEmptyExpression(List<MathNode> expression) {
    if (expression.isEmpty) return true;

    for (MathNode node in expression) {
      if (node is LiteralNode) {
        String text = node.text.trim();
        // Remove operators to see if there's actual content
        text =
            text
                .replaceAll(RegExp(r'[+\-*/^·×÷\u00B7\u00D7\u2212]'), '')
                .trim();
        if (text.isNotEmpty) return false;
      } else if (node is! NewlineNode) {
        // Any structured node (fraction, root, etc.) means non-empty
        return false;
      }
    }
    return true;
  }

  /// Check if the expression is incomplete

  // In math_engine_exact.dart, update the _isIncompleteExpression method:

  /// Check if the expression is incomplete
  // In math_engine_exact.dart, REPLACE _hasEmptyRequiredFields():
  static bool _hasEmptyRequiredFields(List<MathNode> nodes) {
    for (MathNode node in nodes) {
      if (node is FractionNode) {
        if (_isNodeListEmpty(node.numerator) ||
            _isNodeListEmpty(node.denominator)) {
          return true;
        }
        if (_hasInvalidContent(node.numerator) ||
            _hasInvalidContent(node.denominator)) {
          return true;
        }
        if (_hasEmptyRequiredFields(node.numerator) ||
            _hasEmptyRequiredFields(node.denominator)) {
          return true;
        }
      } else if (node is ExponentNode) {
        if (_isNodeListEmpty(node.base) || _isNodeListEmpty(node.power)) {
          return true;
        }
        if (_hasInvalidContent(node.base) || _hasInvalidContent(node.power)) {
          return true;
        }
        if (_hasEmptyRequiredFields(node.base) ||
            _hasEmptyRequiredFields(node.power)) {
          return true;
        }
      } else if (node is RootNode) {
        if (_isNodeListEmpty(node.radicand)) {
          return true;
        }
        if (_hasInvalidContent(node.radicand)) {
          return true;
        }
        if (!node.isSquareRoot && _isNodeListEmpty(node.index)) {
          return true;
        }
        if (!node.isSquareRoot && _hasInvalidContent(node.index)) {
          return true;
        }
        if (_hasEmptyRequiredFields(node.radicand)) {
          return true;
        }
        if (!node.isSquareRoot && _hasEmptyRequiredFields(node.index)) {
          return true;
        }
      } else if (node is LogNode) {
        if (_isNodeListEmpty(node.argument)) {
          return true;
        }
        if (_hasInvalidContent(node.argument)) {
          return true;
        }
        if (!node.isNaturalLog && _isNodeListEmpty(node.base)) {
          return true;
        }
        if (!node.isNaturalLog && _hasInvalidContent(node.base)) {
          return true;
        }
        if (_hasEmptyRequiredFields(node.argument)) {
          return true;
        }
        if (!node.isNaturalLog && _hasEmptyRequiredFields(node.base)) {
          return true;
        }
      } else if (node is TrigNode) {
        if (_isNodeListEmpty(node.argument)) {
          return true;
        }
        if (_hasInvalidContent(node.argument)) {
          return true;
        }
        if (_hasEmptyRequiredFields(node.argument)) {
          return true;
        }
      } else if (node is ParenthesisNode) {
        if (_isNodeListEmpty(node.content)) {
          return true;
        }
        if (_hasInvalidContent(node.content)) {
          return true;
        }
        if (_hasEmptyRequiredFields(node.content)) {
          return true;
        }
      } else if (node is PermutationNode) {
        if (_isNodeListEmpty(node.n) || _isNodeListEmpty(node.r)) {
          return true;
        }
        if (_hasInvalidContent(node.n) || _hasInvalidContent(node.r)) {
          return true;
        }
        if (_hasEmptyRequiredFields(node.n) ||
            _hasEmptyRequiredFields(node.r)) {
          return true;
        }
      } else if (node is CombinationNode) {
        if (_isNodeListEmpty(node.n) || _isNodeListEmpty(node.r)) {
          return true;
        }
        if (_hasInvalidContent(node.n) || _hasInvalidContent(node.r)) {
          return true;
        }
        if (_hasEmptyRequiredFields(node.n) ||
            _hasEmptyRequiredFields(node.r)) {
          return true;
        }
      }
    }
    return false;
  }

  // ADD this new helper method in ExactMathEngine class:
  /// Check if a node list has invalid content (trailing operators, etc.)
  static bool _hasInvalidContent(List<MathNode> nodes) {
    if (nodes.isEmpty) return false;

    // Serialize the content and check for issues
    String content = _serializeNodeListForValidation(nodes);

    if (content.isEmpty) return false;

    String trimmed = content.trim();
    if (trimmed.isEmpty) return false;

    // Check for trailing operators
    if (_endsWithOperator(trimmed)) {
      return true;
    }

    // Check for leading invalid operators (*, /, ^)
    if (_startsWithInvalidOperator(trimmed)) {
      return true;
    }

    // Check for consecutive operators
    if (_hasConsecutiveOperators(trimmed)) {
      return true;
    }

    return false;
  }

  // ADD this new helper method in ExactMathEngine class:
  /// Serialize a node list for validation (simpler than full serialization)
  static String _serializeNodeListForValidation(List<MathNode> nodes) {
    StringBuffer buffer = StringBuffer();

    for (MathNode node in nodes) {
      if (node is LiteralNode) {
        buffer.write(node.text);
      } else if (node is FractionNode) {
        String num = _serializeNodeListForValidation(node.numerator);
        String den = _serializeNodeListForValidation(node.denominator);
        if (num.trim().isEmpty || den.trim().isEmpty) {
          buffer.write('EMPTY_FIELD');
        } else {
          buffer.write('($num/$den)');
        }
      } else if (node is ExponentNode) {
        String base = _serializeNodeListForValidation(node.base);
        String power = _serializeNodeListForValidation(node.power);
        if (base.trim().isEmpty || power.trim().isEmpty) {
          buffer.write('EMPTY_FIELD');
        } else {
          buffer.write('($base^$power)');
        }
      } else if (node is RootNode) {
        String radicand = _serializeNodeListForValidation(node.radicand);
        if (radicand.trim().isEmpty) {
          buffer.write('EMPTY_FIELD');
        } else {
          buffer.write('sqrt($radicand)');
        }
      } else if (node is LogNode) {
        String arg = _serializeNodeListForValidation(node.argument);
        if (arg.trim().isEmpty) {
          buffer.write('EMPTY_FIELD');
        } else {
          buffer.write('log($arg)');
        }
      } else if (node is TrigNode) {
        String arg = _serializeNodeListForValidation(node.argument);
        if (arg.trim().isEmpty) {
          buffer.write('EMPTY_FIELD');
        } else {
          buffer.write('${node.function}($arg)');
        }
      } else if (node is ParenthesisNode) {
        String content = _serializeNodeListForValidation(node.content);
        if (content.trim().isEmpty) {
          buffer.write('EMPTY_FIELD');
        } else {
          buffer.write('($content)');
        }
      } else if (node is PermutationNode) {
        String n = _serializeNodeListForValidation(node.n);
        String r = _serializeNodeListForValidation(node.r);
        if (n.trim().isEmpty || r.trim().isEmpty) {
          buffer.write('EMPTY_FIELD');
        } else {
          buffer.write('P($n,$r)');
        }
      } else if (node is CombinationNode) {
        String n = _serializeNodeListForValidation(node.n);
        String r = _serializeNodeListForValidation(node.r);
        if (n.trim().isEmpty || r.trim().isEmpty) {
          buffer.write('EMPTY_FIELD');
        } else {
          buffer.write('C($n,$r)');
        }
      } else if (node is AnsNode) {
        buffer.write('ans');
      }
    }

    return buffer.toString();
  }

  // 4. REVERT _isNodeListEmpty to the original working version:
  static bool _isNodeListEmpty(List<MathNode> nodes) {
    if (nodes.isEmpty) return true;

    for (MathNode node in nodes) {
      if (node is LiteralNode) {
        if (node.text.trim().isNotEmpty) {
          return false;
        }
      } else if (node is! NewlineNode) {
        return false;
      }
    }
    return true;
  }

  // 5. Keep _isIncompleteExpression as it was originally (from your code):
  static bool _isIncompleteExpression(List<MathNode> expression) {
    // Get the serialized form to check for trailing operators
    String serialized = _serializeForValidation(expression);

    if (serialized.isEmpty) return true;

    // Check if ends with an operator
    String trimmed = serialized.trim();
    if (trimmed.isEmpty) return true;

    // Check for trailing operators
    if (_endsWithOperator(trimmed)) {
      return true;
    }

    // Check for leading operators (except minus for negative)
    if (_startsWithInvalidOperator(trimmed)) {
      return true;
    }

    // Check for consecutive operators (like ++ or +*)
    if (_hasConsecutiveOperators(trimmed)) {
      return true;
    }

    // Check for empty required fields in structured nodes
    if (_hasEmptyRequiredFields(expression)) {
      return true;
    }

    return false;
  }

  /// Serialize expression for validation purposes
  static String _serializeForValidation(List<MathNode> nodes) {
    StringBuffer buffer = StringBuffer();

    for (MathNode node in nodes) {
      if (node is LiteralNode) {
        buffer.write(node.text);
      } else if (node is ConstantNode) {
        buffer.write(node.constant);
      } else if (node is FractionNode) {
        String num = _serializeForValidation(node.numerator);
        String den = _serializeForValidation(node.denominator);
        if (num.trim().isEmpty || den.trim().isEmpty) {
          buffer.write('EMPTY_FIELD');
        } else {
          buffer.write('($num/$den)');
        }
      } else if (node is ExponentNode) {
        String base = _serializeForValidation(node.base);
        String power = _serializeForValidation(node.power);
        if (base.trim().isEmpty || power.trim().isEmpty) {
          buffer.write('EMPTY_FIELD');
        } else {
          buffer.write('($base^$power)');
        }
      } else if (node is RootNode) {
        String radicand = _serializeForValidation(node.radicand);
        if (radicand.trim().isEmpty) {
          buffer.write('EMPTY_FIELD');
        } else {
          buffer.write('sqrt($radicand)');
        }
      } else if (node is LogNode) {
        String arg = _serializeForValidation(node.argument);
        if (arg.trim().isEmpty) {
          buffer.write('EMPTY_FIELD');
        } else {
          buffer.write('log($arg)');
        }
      } else if (node is TrigNode) {
        String arg = _serializeForValidation(node.argument);
        if (arg.trim().isEmpty) {
          buffer.write('EMPTY_FIELD');
        } else {
          buffer.write('${node.function}($arg)');
        }
      } else if (node is ParenthesisNode) {
        String content = _serializeForValidation(node.content);
        if (content.trim().isEmpty) {
          buffer.write('EMPTY_FIELD');
        } else {
          buffer.write('($content)');
        }
      } else if (node is PermutationNode) {
        String n = _serializeForValidation(node.n);
        String r = _serializeForValidation(node.r);
        if (n.trim().isEmpty || r.trim().isEmpty) {
          buffer.write('EMPTY_FIELD');
        } else {
          buffer.write('P($n,$r)');
        }
      } else if (node is CombinationNode) {
        String n = _serializeForValidation(node.n);
        String r = _serializeForValidation(node.r);
        if (n.trim().isEmpty || r.trim().isEmpty) {
          buffer.write('EMPTY_FIELD');
        } else {
          buffer.write('C($n,$r)');
        }
      } else if (node is AnsNode) {
        buffer.write('ans');
      }
    }

    return buffer.toString();
  }

  /// Check if string ends with an operator
  static bool _endsWithOperator(String s) {
    if (s.isEmpty) return false;

    // Normalize operators
    s = s
        .replaceAll('\u00B7', '*')
        .replaceAll('\u00D7', '*')
        .replaceAll('\u2212', '-')
        .replaceAll('÷', '/');

    String lastChar = s[s.length - 1];
    return lastChar == '+' ||
        lastChar == '-' ||
        lastChar == '*' ||
        lastChar == '/' ||
        lastChar == '^' ||
        lastChar == '(';
  }

  /// Check if string starts with an invalid operator
  static bool _startsWithInvalidOperator(String s) {
    if (s.isEmpty) return false;

    // Normalize operators
    s = s
        .replaceAll('\u00B7', '*')
        .replaceAll('\u00D7', '*')
        .replaceAll('\u2212', '-')
        .replaceAll('÷', '/');

    String firstChar = s[0];
    // Leading minus is OK (negative number), leading plus is OK too
    // But leading *, /, ^ are invalid
    return firstChar == '*' || firstChar == '/' || firstChar == '^';
  }

  /// Check for consecutive operators
  static bool _hasConsecutiveOperators(String s) {
    // Normalize operators
    s = s
        .replaceAll('\u00B7', '*')
        .replaceAll('\u00D7', '*')
        .replaceAll('\u2212', '-')
        .replaceAll('÷', '/');

    // Check for patterns like ++, +*, *+, etc.
    // But allow +- or -+ (for things like 3+-2)
    RegExp badPatterns = RegExp(r'[+\-*/^][*/^]|[*/^][+\-*/^]');
    return badPatterns.hasMatch(s);
  }

  /// Check if expression has irrational parts
  static bool _hasIrrationalParts(Expr expr) {
    if (expr is RootExpr) {
      Expr simplified = expr.simplify();
      return simplified is RootExpr ||
          (simplified is ProdExpr &&
              simplified.factors.any((f) => f is RootExpr));
    }
    if (expr is LogExpr) {
      Expr simplified = expr.simplify();
      return simplified is LogExpr;
    }
    if (expr is TrigExpr) {
      Expr simplified = expr.simplify();
      return simplified is TrigExpr;
    }
    if (expr is ConstExpr) return true;
    if (expr is SumExpr) return expr.terms.any(_hasIrrationalParts);
    if (expr is ProdExpr) return expr.factors.any(_hasIrrationalParts);
    if (expr is DivExpr) {
      return _hasIrrationalParts(expr.numerator) ||
          _hasIrrationalParts(expr.denominator);
    }
    if (expr is PowExpr) {
      return _hasIrrationalParts(expr.base) ||
          _hasIrrationalParts(expr.exponent);
    }
    return false;
  }

  /// Evaluate and return only the MathNode result
  static List<MathNode>? evaluateToMathNode(List<MathNode> expression) {
    ExactResult result = evaluate(expression);
    if (result.hasError || result.isEmpty) return null;
    return result.mathNodes;
  }

  /// Evaluate and return only the numerical approximation
  static double? evaluateToDouble(List<MathNode> expression) {
    ExactResult result = evaluate(expression);
    if (result.isEmpty) return null;
    return result.numerical;
  }
}

/// Result of exact evaluation
/// Result of exact evaluation
/// Result of exact evaluation
class ExactResult {
  final Expr? expr;
  final List<MathNode>? mathNodes;
  final double? numerical;
  final bool isExact;
  final String? error;
  final bool isEmpty;

  ExactResult({this.expr, this.mathNodes, this.numerical, this.isExact = true})
    : error = null,
      isEmpty = false;

  ExactResult.error(this.error)
    : expr = null,
      mathNodes = null,
      numerical = null,
      isExact = false,
      isEmpty = false;

  ExactResult.empty()
    : expr = null,
      mathNodes = null,
      numerical = null,
      isExact = false,
      error = null,
      isEmpty = true;

  bool get hasError => error != null;

  String toExactString() {
    if (hasError) return error!;
    if (isEmpty) return '';
    if (expr == null) return '';
    return expr!.toString();
  }

  String toNumericalString({int precision = 6}) {
    if (isEmpty) return '';
    if (numerical == null) return '';
    if (numerical!.isNaN) return '';
    if (numerical!.isInfinite) {
      return numerical!.isNegative ? '-∞' : '∞';
    }

    if ((numerical! - numerical!.roundToDouble()).abs() < 1e-10) {
      return numerical!.round().toString();
    }

    String formatted = numerical!.toStringAsFixed(precision);
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0+$'), '');
      formatted = formatted.replaceAll(RegExp(r'\.$'), '');
    }
    return formatted;
  }
}

// ============================================================
// SECTION 18: UTILITY EXTENSIONS
// ============================================================

/// Extension methods for easier Expr creation
extension ExprExtensions on int {
  IntExpr toExpr() => IntExpr.from(this);
}

extension BigIntExprExtensions on BigInt {
  IntExpr toExpr() => IntExpr(this);
}

/// Helper function to create expressions easily
Expr frac(int num, int den) => FracExpr.from(num, den);
Expr sqrt(Expr radicand) => RootExpr.sqrt(radicand);
Expr sqrtInt(int n) => RootExpr.sqrt(IntExpr.from(n));
Expr sum(List<Expr> terms) => SumExpr(terms);
Expr prod(List<Expr> factors) => ProdExpr(factors);
Expr pow(Expr base, Expr exp) => PowExpr(base, exp);
Expr ln(Expr arg) => LogExpr.ln(arg);
Expr log(Expr base, Expr arg) => LogExpr(base, arg);
