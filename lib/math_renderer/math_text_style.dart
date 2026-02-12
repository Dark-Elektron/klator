import 'package:flutter/rendering.dart';
import '../utils/constants.dart';

/// Handles text styling, display conversion, and cursor positioning for math text.
class MathTextStyle {
  static const String plusSign = '\u002B';
  static const String minusSign = '\u2212';
  static const String equalsSign = '=';

  static const String multiplyDot = '\u00B7';
  static const String multiplyTimes = '\u00D7';

  static String _multiplySign = '\u00D7';

  static String get multiplySign => _multiplySign;

  static void setMultiplySign(String sign) {
    _multiplySign = sign;
  }

  static const Set<String> _allMultiplySigns = {multiplyDot, multiplyTimes};

  static const Set<String> _paddedOperators = {
    plusSign,
    minusSign,
    multiplyDot,
    multiplyTimes,
    '*', // Add standard asterisk
    equalsSign,
  };

  /// Scientific E character (small caps E) used for notation like 1ᴇ-17
  static const String scientificE = '\u1D07';

  /// Checks if a character at the given position should have padding.
  /// Minus signs following scientific E do NOT get padding.
  static bool _isPaddedOperatorAt(String text, int index) {
    final char = text[index];

    if (!_paddedOperators.contains(char)) {
      return false;
    }

    // Unary +/− should stick to the following value (e.g., -23, (+3), (-x))
    if ((char == plusSign || char == '-' || char == minusSign) &&
        _isUnarySignAt(text, index)) {
      return false;
    }

    // Special case: minus sign after scientific E should NOT be padded
    if ((char == '-' || char == minusSign) && index > 0) {
      final prevChar = text[index - 1];
      if (prevChar == scientificE || prevChar == 'E' || prevChar == 'e') {
        return false;
      }
    }

    return true;
  }

  static bool _isUnarySignAt(String text, int index) {
    if (index <= 0) return true;
    final prevChar = text[index - 1];
    // If sign follows an operator or opening bracket, treat as unary.
    const unaryPreceders = {
      '(',
      '[',
      '{',
      ',',
      plusSign,
      minusSign,
      '-',
      multiplyDot,
      multiplyTimes,
      '*',
      '/',
      '÷',
      '^',
      '=',
    };
    return unaryPreceders.contains(prevChar);
  }

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

      String displayChar = char;
      if (_isMultiplySign(char) || char == '*') {
        displayChar = _multiplySign;
      }

      if (_isPaddedOperatorAt(text, i)) {
        // Only add leading space if not the first character in the literal
        if (i > 0) {
          buffer.write(' ');
        }
        buffer.write(displayChar);
        // Always add a trailing space for operators in literals
        buffer.write(' ');
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
    final displayText = toDisplayText(text);

    final textSpan = TextSpan(text: displayText, style: getStyle(fontSize));
    final renderParagraph = RenderParagraph(
      textSpan,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    );
    renderParagraph.layout(const BoxConstraints());

    final width = renderParagraph.size.width;
    renderParagraph.dispose();
    return width;
  }

  static int _logicalToDisplayIndex(String text, int logicalIndex) {
    int displayIndex = 0;
    final clampedIndex = logicalIndex.clamp(0, text.length);

    for (int i = 0; i < clampedIndex; i++) {
      if (_isPaddedOperatorAt(text, i)) {
        if (i == 0) {
          displayIndex += 2; // char + trailing space
        } else {
          displayIndex += 3; // space + char + space
        }
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

    final displayText = toDisplayText(text);
    final displayIndex = _logicalToDisplayIndex(
      text,
      charIndex,
    ).clamp(0, displayText.length);

    final textSpan = TextSpan(text: displayText, style: getStyle(fontSize));
    final renderParagraph = RenderParagraph(
      textSpan,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    );

    renderParagraph.layout(const BoxConstraints());

    final offset = renderParagraph.getOffsetForCaret(
      TextPosition(offset: displayIndex),
      Rect.zero,
    );

    renderParagraph.dispose();
    return offset.dx;
  }

  static int getCharIndexForOffset(
    String text,
    double xOffset,
    double fontSize,
    TextScaler textScaler,
  ) {
    if (text.isEmpty) return 0;

    final displayText = toDisplayText(text); // String allocation

    // Creates TextPainter - EXPENSIVE
    final textSpan = TextSpan(text: displayText, style: getStyle(fontSize));
    final renderParagraph = RenderParagraph(
      textSpan,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    );

    renderParagraph.layout(const BoxConstraints()); // Layout calculation

    final position = renderParagraph.getPositionForOffset(
      Offset(xOffset, fontSize / 2),
    );

    renderParagraph.dispose(); // Cleanup

    return displayToLogicalIndex(
      text,
      position.offset.clamp(0, displayText.length),
    );
  }

  static int displayToLogicalIndex(String text, int displayIndex) {
    if (displayIndex <= 0) return 0;

    int displayPos = 0;

    for (int logical = 0; logical < text.length; logical++) {
      final isPadded = _isPaddedOperatorAt(text, logical);
      int charWidth;

      if (isPadded) {
        charWidth = (logical == 0) ? 2 : 3;
      } else {
        charWidth = 1;
      }

      final prevDisplayPos = displayPos;
      displayPos += charWidth;

      if (displayIndex <= displayPos) {
        if (isPadded) {
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

  static int logicalToDisplayIndex(String text, int logicalIndex) {
    return _logicalToDisplayIndex(text, logicalIndex);
  }
}
