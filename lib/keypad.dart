import 'package:flutter/material.dart';
import 'package:klator/help.dart';
import 'package:klator/utils.dart';
import 'buttons.dart';
import 'parser.dart';
import 'evaluate_expression.dart';
import 'package:function_tree/function_tree.dart';
import 'settings.dart';
import 'package:provider/provider.dart';
import 'settings_provider.dart';
/// ---------------------------------------------------------------------------
/// CalculatorKeypad
/// ---------------------------------------------------------------------------
/// All keypad UI + behaviour lives here.
/// No business logic is allowed in the parent screen.
/// ---------------------------------------------------------------------------
class CalculatorKeypad extends StatefulWidget {
  final int activeIndex;
  final Map<int, TextEditingController> controllers;
  final Map<int, Widget> displays;
  final double screenWidth;
  final bool isLandscape;
  final bool isWideScreen;

  final void Function(int) onAddDisplay;
  final void Function(int) onRemoveDisplay;
  final int Function(String) countVariables;

  const CalculatorKeypad({
    super.key,
    required this.activeIndex,
    required this.controllers,
    required this.displays,
    required this.screenWidth,
    required this.isLandscape,
    required this.isWideScreen,
    required this.onAddDisplay,
    required this.onRemoveDisplay,
    required this.countVariables,
  });


  @override
  State<CalculatorKeypad> createState() => _CalculatorKeypadState();
}

class _CalculatorKeypadState extends State<CalculatorKeypad> {
  late final PageController _pageController;
  bool isTypingExponent = false;
  
  int pagesPerView = 1;
  double buttonSize = 60;
  double gridHeight = 300;
  late double gridHeightBasic;

  TextEditingController get _ctrl => 
    widget.controllers[widget.activeIndex]!;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _updateGridMetrics();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /* ------------------------------------------------------------------------
   * Core editor helpers
   * --------------------------------------------------------------------- */
  @override
  void didUpdateWidget(covariant CalculatorKeypad oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateGridMetrics();
  }
  
  void _updateGridMetrics() {
    // Determine pages per view
    if (widget.isLandscape) {
      pagesPerView = 3;
    } else if (widget.isWideScreen) {
      pagesPerView = 2;
    } else {
      pagesPerView = 1;
    }

    int crossAxisCount = 5; // Fixed number of columns
    int rowCount = 4; // Number of rows
    double buttonSize = widget.screenWidth / crossAxisCount; // Square buttons
    gridHeight =
        buttonSize * rowCount / pagesPerView; // Total height of grid
    int crossAxisCountBasic =
        (widget.isLandscape) ? 20 : 10; // Fixed number of columns
    double buttonSizeBasic =
        widget.screenWidth / crossAxisCountBasic; // Square buttons
    gridHeightBasic =
        (widget.isLandscape)
            ? buttonSizeBasic * 1
            : buttonSizeBasic * 2; // Total height of grid
  }


  void _insert(String text) {
    expressionInputManager(_ctrl, text);
    setState(() {});
  }

  void _append(String text) {
    _ctrl.text += text;
    setState(() {});
  }

  void _clear() {
    _ctrl.text = '';
    setState(() {});
  }

  void _delete() {
    if (_ctrl.text.isEmpty && widget.displays.length > 1) {
      widget.onRemoveDisplay(widget.activeIndex);
    } else {
      deleteTextAtCursor(_ctrl);
    }
    setState(() {});
  }

  void _enter() {
    if (_ctrl.text.isEmpty) return;

    final text = _ctrl.text;
    if (widget.countVariables(text) > text.split('\n').length) {
      _ctrl.text += '\n';
    } else {
      widget.onAddDisplay(widget.displays.length);
    }
    setState(() {});
  }


  /* ------------------------------------------------------------------------
   * Key definitions
   * --------------------------------------------------------------------- */

  late final List<_KeyDef> _standardKeys = [
    _KeyDef(label: '7', onTap: () => _insert('7')),
    _KeyDef(label: '8', onTap: () => _insert('8')),
    _KeyDef(label: '9', onTap: () => _insert('9')),
    _KeyDef(label: '⌫', onTap: _delete),

    _KeyDef(label: '4', onTap: () => _insert('4')),
    _KeyDef(label: '5', onTap: () => _insert('5')),
    _KeyDef(label: '6', onTap: () => _insert('6')),
    _KeyDef(label: '+', onTap: () => _insert(' + ')),

    _KeyDef(label: '1', onTap: () => _insert('1')),
    _KeyDef(label: '2', onTap: () => _insert('2')),
    _KeyDef(label: '3', onTap: () => _insert('3')),
    _KeyDef(label: '−', onTap: () => _insert(' − ')),

    _KeyDef(label: '0', onTap: () => _insert('0')),
    _KeyDef(label: '.', onTap: () => _insert('.')),
    _KeyDef(label: 'C', onTap: _clear),
    _KeyDef(label: '⏎', onTap: _enter),
  ];

  late final List<_KeyDef> _scientificKeys = [
    _KeyDef(label: 'sin', onTap: () => _insert('sin()')),
    _KeyDef(label: 'cos', onTap: () => _insert('cos()')),
    _KeyDef(label: 'tan', onTap: () => _insert('tan()')),
    _KeyDef(label: 'π', onTap: () => _insert('π')),

    _KeyDef(label: 'ln', onTap: () => _insert('ln()')),
    _KeyDef(label: 'log', onTap: () => _insert('log()')),
    _KeyDef(label: '^', onTap: () => _insert('^()')),
    _KeyDef(label: '√', onTap: () => _insert('√()')),
  ];

  /* ------------------------------------------------------------------------
   * Grid builder
   * --------------------------------------------------------------------- */

  Widget _buildGrid(List<_KeyDef> keys, int columns, double height) {
    return SizedBox(
      height: height,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: 1, // square buttons
        ),
        itemCount: keys.length,
        itemBuilder: (_, i) {
          final k = keys[i];
          return MyButton(
            buttontapped: k.onTap,
            buttonText: k.label,
            color: k.color,
            textColor: k.textColor,
            fontSize: k.fontSize,
          );
        },
      ),
    );
  }

  /* ------------------------------------------------------------------------
   * Widget build
   * --------------------------------------------------------------------- */
  @override
  Widget build(BuildContext context) {
    if (widget.isLandscape) {
      return Row(
        children: [
          SizedBox(
            width: widget.screenWidth / 2,
            height: gridHeightBasic,
            child: _buildGrid(_standardKeys, widget.isLandscape ? 20 : 10, gridHeightBasic),
          ),
          SizedBox(
            width: widget.screenWidth / 2,
            height: gridHeight,
            child: _buildGrid(_scientificKeys, 5, gridHeight),
          ),
        ],
      );
    }

    // Portrait (PageView)
    return SizedBox(
      height: gridHeightBasic + gridHeight, // total height of both pages
      child: PageView(
        controller: _pageController,
        children: [
          _buildGrid(_standardKeys, widget.isLandscape ? 20 : 10, gridHeightBasic),
          _buildGrid(_scientificKeys, 5, gridHeight),
        ],
      ),
    );
  }

  void expressionInputManager(controller, textToInsert) {
    dynamic text = controller.text;
    dynamic cursorPos = controller.selection.baseOffset;
    // print(text);

    // print(cursorPos);

    int selectionStart = controller.selection.start;
    int selectionEnd = controller.selection.end;

    // List of functions that require parentheses
    List<String> functions = [
      'log()',
      'ln()',
      'sin()',
      'cos()',
      'tan()',
      'asin()',
      'acos()',
      'atan()',
      '^()',
      '^(2)',
      '\u207F\u221A()',
      '2\u207F\u221A()',
      '\u00B2',
      'abs',
    ];

    if (cursorPos < 0) {
      // If no cursor is set, append at the end
      controller.text = text + textToInsert;

      // Move cursor to the end of inserted text
      if (textToInsert.contains('()')) {
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length - 1),
        );
      } else {
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      }
    } else {
      // If text is selected, wrap it in parentheses
      if (selectionStart != selectionEnd) {
        String selectedText = text.substring(selectionStart, selectionEnd);
        String newText;

        if (functions.contains(textToInsert)) {
          // If inserting a function, wrap the selection in function parentheses
          newText = text.replaceRange(
            selectionStart,
            selectionEnd,
            "${textToInsert.replaceAll('()', '')}($selectedText)",
          );
        } else if (textToInsert == "()") {
          // If inserting parentheses, wrap the selected text
          newText = text.replaceRange(
            selectionStart,
            selectionEnd,
            "($selectedText)",
          );
        } else {
          // Default insertion
          newText = text.replaceRange(cursorPos, cursorPos, textToInsert);
        }

        controller.text = newText;
        int textLength = textToInsert.length;
        controller.selection = TextSelection.collapsed(
          offset: selectionEnd + textLength,
        );
      } else {
        // Insert text at cursor position
        String newText = text.replaceRange(cursorPos, cursorPos, textToInsert);

        // format text
        if (newText.contains('P') || newText.contains('C')) {
          newText = formatPermutationCombination(newText);
        }
        if (newText.contains('\u207F\u221A')) {
          newText = formatNRoot(newText);
        }
        if (newText.contains('^')) {
          if (isTypingExponent) {
          } else {
            newText = formatExponents(newText);
          }
        }

        controller.text = newText;

        // Move cursor to the end of inserted text
        if (textToInsert.contains('()')) {
          controller.selection = TextSelection.collapsed(
            offset: cursorPos + textToInsert.length - 1,
          );
        } else {
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: cursorPos + textToInsert.length),
          );
        }
      }
    }
  }

  void expressionInputManager_(controller, textToInsert) {
    dynamic text = controller.text;
    dynamic cursorPos = controller.selection.baseOffset;
    // print(text);

    // print(cursorPos);

    int selectionStart = controller.selection.start;
    int selectionEnd = controller.selection.end;

    // List of functions that require parentheses
    List<String> functions = [
      'log()',
      'ln()',
      'sin()',
      'cos()',
      'tan()',
      'asin()',
      'acos()',
      'atan()',
      '^()',
      '^(2)',
      '\u207F\u221A()',
      '2\u207F\u221A()',
      '\u00B2',
      'abs',
    ];

    if (cursorPos < 0) {
      // If no cursor is set, append at the end
      controller.text = text + textToInsert;

      // Move cursor to the end of inserted text
      if (textToInsert.contains('()')) {
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length - 1),
        );
      } else {
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      }
    } else {
      // If text is selected, wrap it in parentheses
      if (selectionStart != selectionEnd) {
        String selectedText = text.substring(selectionStart, selectionEnd);
        String newText;

        if (functions.contains(textToInsert)) {
          // If inserting a function, wrap the selection in function parentheses
          newText = text.replaceRange(
            selectionStart,
            selectionEnd,
            "${textToInsert.replaceAll('()', '')}($selectedText)",
          );
        } else if (textToInsert == "()") {
          // If inserting parentheses, wrap the selected text
          newText = text.replaceRange(
            selectionStart,
            selectionEnd,
            "($selectedText)",
          );
        } else {
          // Default insertion
          newText = text.replaceRange(cursorPos, cursorPos, textToInsert);
        }

        controller.text = newText;
        int textLength = textToInsert.length;
        controller.selection = TextSelection.collapsed(
          offset: selectionEnd + textLength,
        );
      } else {
        // Insert text at cursor position
        String newText = text.replaceRange(cursorPos, cursorPos, textToInsert);

        // format text
        if (newText.contains('P') || newText.contains('C')) {
          newText = formatPermutationCombination(newText);
        }
        if (newText.contains('\u207F\u221A')) {
          newText = formatNRoot(newText);
        }
        if (newText.contains('^')) {
          if (isTypingExponent) {
          } else {
            newText = formatExponents(newText);
          }
        }

        // // wrap expression
        // print('newText $newText');
        //  try {
        // 	controller.text = Parser(tokenize(newText)).parseExpression().toString();
        // 	print('parser text ${Parser(tokenize(newText)).parseExpression().toString()}');
        // } catch (e) {
        // 	controller.text = IncompleteNode(newText).toString();
        // 	print('parser text incin ${IncompleteNode(newText).toString()}');
        // }
        controller.text = wrapNumbers(newText);
        // controller.text = newText;

        // Move cursor to the end of inserted text
        if (textToInsert.contains('()')) {
          controller.selection = TextSelection.collapsed(
            offset: cursorPos + textToInsert.length - 1,
          );
        } else {
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: cursorPos + textToInsert.length),
          );
        }
      }
    }
  }

  int countVariablesInExpressions(String expressions) {
    // Regular expression to match variables (single letters a-z, A-Z)
    RegExp variableRegex = RegExp(
      r'(?<!\w)([a-bd-hj-oq-zA-BD-HJ-OQ-Z])(?!\s*\()',
    );

    // Extract unique variable names from all lines
    Set<String> variables = {};
    for (var line in expressions.split('\n')) {
      for (var match in variableRegex.allMatches(line)) {
        variables.add(match.group(0)!);
      }
    }

    return variables.length;
  }

  void deleteTextAtCursor(
    TextEditingController controller, {
    bool deleteBefore = true,
  }) {
    TextSelection selection = controller.selection;
    String text = controller.text;

    if (!selection.isValid) return; // Ensure the selection is valid

    int cursorPos = selection.baseOffset;
    // print(cursorPos);

    if (cursorPos == -1) return; // No cursor position available

    if (!selection.isCollapsed) {
      String text = controller.text;
      String newText = text.replaceRange(selection.start, selection.end, "");
      controller.text = newText;

      // Reset selection to avoid retaining old highlight
      controller.selection = TextSelection.collapsed(offset: selection.start);
    } else {
      if (deleteBefore) {
        // Delete character before cursor
        if (cursorPos > 0) {
          int shiftPos = 1;
          int forwardDeleteCount = 0;
          String textToDelete = text.substring(cursorPos - 1, cursorPos);
          String bracketString = '';

          if (textToDelete == ' ') {
            if (text.length > 3 && cursorPos > 2) {
              shiftPos = 3;
            }
          } else if (textToDelete == '(') {
            // Get index of corresponding right bracket
            String restSubstring = text.substring(cursorPos);

            forwardDeleteCount = 0;
            int detectClosingBracket = 1;
            for (int i = 0; i < restSubstring.length; i++) {
              if (restSubstring[i] == '(') {
                detectClosingBracket += 1;
              } else if (restSubstring[i] == ')') {
                detectClosingBracket -= 1;
              }
              forwardDeleteCount += 1;
              if (detectClosingBracket == 0) {
                break;
              }
            }
          }
          if (forwardDeleteCount > 0) {
            bracketString = text.substring(
              cursorPos,
              cursorPos + forwardDeleteCount - 1,
            );
          }
          controller.text =
              text.substring(0, cursorPos - shiftPos) +
              bracketString +
              text.substring(cursorPos + forwardDeleteCount);

          cursorPos -= shiftPos;
          if (bracketString == '') {
            controller.selection = TextSelection.collapsed(offset: cursorPos);
          } else {
            controller.selection = TextSelection(
              baseOffset: cursorPos,
              extentOffset: cursorPos + forwardDeleteCount - 1,
            );
          }
        } else {
          cursorPos = 0;
          controller.selection = TextSelection.collapsed(offset: cursorPos);
        }
      } else {
        // // Delete character after cursor
        // if (cursorPos < text.length) {
        //   controller.text = text.substring(0, cursorPos) + text.substring(cursorPos + 1);
        //   controller.selection = TextSelection.collapsed(offset: cursorPos-1);
        // }
      }
    }

    // print(controller.text);
  }

  void updateAnswer(TextEditingController controller, double ans) {
    setState(() {});
  }

  // // function to calculate the input operation
  // void evaluateExpression(int precision) {
  //   String finalUserInput = textEditingControllers[activeIndex]!.text;
  //   finalUserInput = finalUserInput.replaceAll(' ', '');
  //   // decode input text
  //   finalUserInput = decodeFromDisplay(finalUserInput);

  //   // // update rawText
  //   // rawText = finalUserInput;

  //   finalUserInput = replaceMultiple(
  //     finalUserInput,
  //     replacements,
  //   ).replaceFirst(RegExp(r'^\*+\s*'), '');

  //   // replace answer it if exists
  //   if (activeIndex > 0) {
  //     String ans = textDisplayControllers[activeIndex - 1]!.text;
  //     finalUserInput = finalUserInput.replaceAll('ans', ans);
  //   }

  //   finalUserInput = parseExpression(finalUserInput);
  //   try {
  //     // check if permutation and combination in expression
  //     if (finalUserInput.contains('C')) {
  //       finalUserInput = processCombination(finalUserInput);
  //     }

  //     if (finalUserInput.contains('P')) {
  //       finalUserInput = processPermutation(finalUserInput);
  //     }

  //     // check for powers
  //     if (containsSuperscripts(finalUserInput)) {
  //       finalUserInput = processExponents(finalUserInput);
  //     }
  //     // check for nth root
  //     if (finalUserInput.contains('\u221A')) {
  //       finalUserInput = processNRoot(finalUserInput);
  //     }
  //     // check if expression is regular, singleVariable or multiVariable
  //     if ([
  //       'x',
  //       'y',
  //       'z',
  //       '=',
  //     ].every((parameter) => finalUserInput.contains(parameter))) {
  //       dynamic eval = EquationSolver.solveLinearSystem(finalUserInput);
  //       _updateAnswer(eval.toString());
  //     } else if ([
  //       'x',
  //       'y',
  //       '=',
  //     ].every((parameter) => finalUserInput.contains(parameter))) {
  //       dynamic eval = EquationSolver.solveLinearSystem(finalUserInput);
  //       _updateAnswer(eval.toString());
  //     } else if ([
  //       'x',
  //       'y',
  //       'z',
  //       '=',
  //     ].any((parameter) => finalUserInput.contains(parameter))) {
  //       dynamic eval = EquationSolver.solveEquation(finalUserInput);
  //       _updateAnswer(eval.toString());
  //     } else {
  //       final expression = finalUserInput;
  //       dynamic eval = expression.interpret();
  //       _updateAnswer(properFormat(eval, precision).toString());
  //     }

  //     // answer = eval.toString();
  //   } catch (e) {
  //     textDisplayControllers[activeIndex]!.text = '';
  //   }
  // }

  // String encodeForDisplay(String inputText) {
  //   // check for powers
  //   if (containsSuperscripts(inputText)) {
  //     inputText = processExponents(inputText);
  //   }
  //   // check for nth root
  //   if (inputText.contains('\u221A')) {
  //     inputText = processNRoot(inputText);
  //   }

  //   return inputText;
  // }

  // String decodeFromDisplay(String inputText) {
  //   // check for powers
  //   if (containsSuperscripts(inputText)) {
  //     inputText = processExponents(inputText);
  //   }
  //   // check for nth root
  //   if (inputText.contains('\u221A')) {
  //     inputText = processNRoot(inputText);
  //   }
  //   return inputText;
  // }

  // String replaceMultiple(String text, Map<String, String> replacements) {
  //   replacements.forEach((key, value) {
  //     text = text.replaceAll(key, value);
  //   });
  //   return text;
  // }


}


/* ------------------------------------------------------------------------
  * Key model
  * --------------------------------------------------------------------- */

class _KeyDef {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;
  final double fontSize;

  const _KeyDef({
    required this.label,
    required this.onTap,
    this.color = Colors.white,
    this.textColor = Colors.black,
    this.fontSize = 20.0,
  });
}

class KeyPage {
  final List<String> buttons;
  final int crossAxisCount;
  final double height;
  final Map<int, void Function()> specialHandlers;

  KeyPage({
    required this.buttons,
    required this.crossAxisCount,
    required this.height,
    this.specialHandlers = const {},
  });
}
