import 'package:flutter/material.dart';
import 'package:klator/help.dart';
import 'package:klator/utils.dart';
import 'buttons.dart';
import 'settings.dart';
import 'settings_provider.dart';
import 'renderer.dart';
import 'app_colors.dart';
import 'dart:async';

class CalculatorKeypad extends StatefulWidget {
  final double screenWidth;
  final bool isLandscape;
  final AppColors colors;
  final int activeIndex;
  final Map<int, MathEditorController?> mathEditorControllers;
  final Map<int, TextEditingController?> textDisplayControllers;
  final SettingsProvider settingsProvider;
  final VoidCallback onUpdateMathEditor;
  final VoidCallback onAddDisplay;
  final void Function(int index) onRemoveDisplay;
  final VoidCallback onClearAllDisplays;
  final int Function(String text) countVariablesInExpressions;
  final VoidCallback onSetState; // For forcing parent rebuild when needed

  const CalculatorKeypad({
    super.key,
    required this.screenWidth,
    required this.isLandscape,
    required this.colors,
    required this.activeIndex,
    required this.mathEditorControllers,
    required this.textDisplayControllers,
    required this.settingsProvider,
    required this.onUpdateMathEditor,
    required this.onAddDisplay,
    required this.onRemoveDisplay,
    required this.onClearAllDisplays,
    required this.countVariablesInExpressions,
    required this.onSetState,
  });

  @override
  State<CalculatorKeypad> createState() => _CalculatorKeypadState();
}

class _CalculatorKeypadState extends State<CalculatorKeypad> {
  // Sizing state - exactly as original
  int? _lastPagesPerView;

  bool _isBasicKeypadExpanded = false;
  final double _collapsedHeight = 21.0;

  // Controllers
  late PageController _keypadController;
  late PageController _pgViewController;

  bool _isInitialized = false; // Add this flag

  // Delete timer
  Timer? _deleteTimer;
  bool _isDeleting = false;
  int _deleteSpeed = 150;

  // Button lists - exactly as original
  final List<String> _buttonsBasic = [
    '5',
    '6',
    '7',
    '8',
    '9',
    '()',
    '+',
    '-',
    '\u1D07',
    '\u2318',
    '0',
    '1',
    '2',
    '3',
    '4',
    '.',
    'x',
    '/',
    'C',
    '\u232B',
  ];

  final List<String> _buttons = [
    '7',
    '8',
    '9',
    '()',
    '<-',
    '4',
    '5',
    '6',
    '+',
    '-',
    '1',
    '2',
    '3',
    'x',
    '/',
    '0',
    '.',
    '\u1D07',
    'C',
    'EN',
  ];

  final List<String> _buttonsSci = [
    '=',
    'x^2',
    'x^n',
    'SQR',
    'nSQR',
    'x',
    'PI',
    'sin',
    'cos',
    'tan',
    'y',
    '\u00B0',
    'asin',
    'acos',
    'atan',
    'z',
    'e',
    'ln',
    'log',
    'logn',
  ];

  final List<String> _buttonsR = [
    '',
    '',
    '\u238F',
    '\u238C',
    '\u27F2',
    'i',
    'x!',
    'nPr',
    'nCr',
    'ans',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '\u24D8',
    '',
  ];

  // Add a new list for landscape layout
  final List<String> _buttonsBasicLandscape = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '0',
    '.',
    '+',
    '-',
    'x',
    '/',
    '()',
    '\u1D07',
    'C',
    '\u2318',
    '\u232B',
  ];

  @override
  void initState() {
    super.initState();
    // Temporary controllers - will be replaced in first build
    // _keypadController = PageController();
    _pgViewController = PageController();
  }

  @override
  void dispose() {
    _deleteTimer?.cancel();
    _keypadController.dispose();
    _pgViewController.dispose();
    super.dispose();
  }

  void _initializeControllers(int pagesPerView) {
    // Dispose old controllers if they exist and were properly initialized
    if (_isInitialized) {
      _keypadController.dispose();
    }

    _keypadController = PageController(
      initialPage: pagesPerView >= 2 ? 0 : 1,
      viewportFraction: 1 / pagesPerView,
    );
  }
  // ============== HELPER GETTERS ==============

  MathEditorController? get _activeController =>
      widget.mathEditorControllers[widget.activeIndex];

  bool isOperator(String text) {
    const operators = [
      '+',
      '-',
      'x',
      '/',
      '=',
      '\u002B',
      '\u2212',
      '\u00B7',
      '\u00D7',
      '\u00F7',
    ];
    return operators.contains(text);
  }

  // ============== SIZING METHODS ==============
  // Add this new method:
  void _toggleBasicKeypad() {
    setState(() {
      _isBasicKeypadExpanded = !_isBasicKeypadExpanded;
    });
  }

  void _updatePagesPerView(int pagesPerView) {
    _keypadController.dispose();
    _keypadController = PageController(
      initialPage: pagesPerView >= 2 ? 0 : 1,
      viewportFraction: 1 / pagesPerView,
    );
  }

  // ============== DELETE METHODS ==============

  void _startContinuousDelete() {
    _isDeleting = true;
    _deleteSpeed = 150;
    _performDelete();
    _scheduleNextDelete();
  }

  void _scheduleNextDelete() {
    _deleteTimer = Timer(Duration(milliseconds: _deleteSpeed), () {
      if (_isDeleting) {
        _performDelete();
        _deleteSpeed = (_deleteSpeed * 0.85).clamp(30, 150).toInt();
        _scheduleNextDelete();
      }
    });
  }

  void _stopContinuousDelete() {
    _isDeleting = false;
    _deleteTimer?.cancel();
    _deleteTimer = null;
  }

  void _performDelete() {
    if (_activeController?.expr == '') {
      widget.onRemoveDisplay(widget.activeIndex);
      _stopContinuousDelete();
      return;
    }
    _activeController?.deleteChar();
    widget.onUpdateMathEditor();
    widget.onSetState();
  }

  // ============== BUTTON HANDLERS ==============

  void _handleEnter() {
    if (_activeController?.expr != '') {
      String text = _activeController!.expr;
      if (widget.countVariablesInExpressions(text) > text.split('\n').length) {
        _activeController!.insertNewline();
      } else {
        widget.onAddDisplay();
      }
    }
    widget.onUpdateMathEditor();
    widget.onSetState();
  }

  // ============== BUILD METHOD ==============

  @override
  Widget build(BuildContext context) {
    bool isWideScreen = widget.screenWidth > 600;
    int pagesPerView;

    if (widget.isLandscape) {
      pagesPerView = 2;
    } else if (isWideScreen) {
      pagesPerView = 2;
    } else {
      pagesPerView = 1;
    }

    // Initialize or update controllers when pagesPerView changes
    if (!_isInitialized || _lastPagesPerView != pagesPerView) {
      _initializeControllers(pagesPerView);
      _lastPagesPerView = pagesPerView;
      _isInitialized = true;
    }

    int crossAxisCount = 5;
    int rowCount = 4;
    double buttonSize = widget.screenWidth / crossAxisCount;

    // Calculate grid height
    double gridHeight;
    if (widget.isLandscape) {
      double buttonHeightRatio = 0.65;
      gridHeight = (buttonSize * buttonHeightRatio * rowCount) / pagesPerView;
    } else {
      gridHeight = buttonSize * rowCount / pagesPerView;
    }

    int crossAxisCountBasic = (widget.isLandscape) ? 20 : 10;
    double buttonSizeBasic = widget.screenWidth / crossAxisCountBasic;

    // Calculate expanded height for basic keypad
    double basicKeypadExpandedHeight;
    if (widget.isLandscape) {
      double buttonHeightRatio = 0.65;
      basicKeypadExpandedHeight = buttonSizeBasic * buttonHeightRatio * 1;
    } else {
      basicKeypadExpandedHeight = buttonSizeBasic * 2;
    }

    // Determine current height based on expanded state
    double basicKeypadHeight =
        _isBasicKeypadExpanded
            ? basicKeypadExpandedHeight + _collapsedHeight
            : _collapsedHeight;

    if (_lastPagesPerView != pagesPerView) {
      _updatePagesPerView(pagesPerView);
      _lastPagesPerView = pagesPerView;
    }

    return Column(
      children: [
        // Tappable Handle & Basic Keypad
        // Tappable Handle & Basic Keypad
        GestureDetector(
          onTap: _toggleBasicKeypad,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: basicKeypadHeight,
            width: double.infinity,
            clipBehavior: Clip.hardEdge, // Add this to clip overflow
            decoration: const BoxDecoration(), // Required for clipBehavior
            child: Column(
              children: [
                // Tap Handle indicator
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.colors.containerBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Always keep the grid in the tree, let clipping handle visibility
                Expanded(
                  child: PageView(
                    physics: const NeverScrollableScrollPhysics(),
                    padEnds: false,
                    controller: _pgViewController,
                    children: [
                      _buildBasicGrid(crossAxisCountBasic, widget.isLandscape),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Main Keypad
        SizedBox(
          height: gridHeight,
          child: PageView(
            key: ValueKey('keypad_$pagesPerView'),
            padEnds: false,
            controller: PageController(
              initialPage: pagesPerView >= 2 ? 0 : 1,
              viewportFraction: 1 / pagesPerView,
            ),
            children: [
              _buildScientificGrid(widget.isLandscape),
              _buildNumberGrid(widget.isLandscape),
              _buildExtrasGrid(widget.isLandscape),
            ],
          ),
        ),
      ],
    );
  }

  // ============== GRID BUILDERS ==============

  Widget _buildBasicGrid(int crossAxisCount, bool isLandscape) {
    // Choose the correct button list based on orientation
    final List<String> buttons =
        isLandscape ? _buttonsBasicLandscape : _buttonsBasic;

    // Map button text to indices for special handling
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: buttons.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: isLandscape ? 1.5 : 1.0,
      ),
      itemBuilder: (context, index) {
        String buttonText = buttons[index];

        // Addition Button
        if (buttonText == '+') {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('+');
              widget.onUpdateMathEditor();
            },
            buttonText: '\u002B',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Subtraction Button
        else if (buttonText == '-') {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('-');
              widget.onUpdateMathEditor();
            },
            buttonText: '\u2212',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Multiplication Button
        else if (buttonText == 'x') {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter(
                widget.settingsProvider.multiplicationSign,
              );
              widget.onUpdateMathEditor();
            },
            buttonText: '\u00D7',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Division Button
        else if (buttonText == '/') {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('/');
              widget.onUpdateMathEditor();
            },
            buttonText: '\u00F7',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Enter/Command Button
        else if (buttonText == '\u2318') {
          return MyButton(
            buttontapped: _handleEnter,
            buttonText: '\u2318',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Delete Button
        else if (buttonText == '\u232B') {
          return GestureDetector(
            onLongPressStart: (_) => _startContinuousDelete(),
            onLongPressEnd: (_) => _stopContinuousDelete(),
            onLongPressCancel: _stopContinuousDelete,
            child: MyButton(
              buttontapped: () {
                _activeController?.deleteChar();
                widget.onUpdateMathEditor();
                if (_activeController?.expr == '') {
                  widget.onRemoveDisplay(widget.activeIndex);
                }
                widget.onSetState();
              },
              buttonText: '\u232B',
              color: const Color.fromARGB(255, 226, 104, 104),
              textColor: Colors.black,
            ),
          );
        }
        // Clear Button
        else if (buttonText == 'C') {
          return MyButton(
            buttontapped: () {
              _activeController?.clear();
              _activeController?.updateAnswer(
                widget.textDisplayControllers[widget.activeIndex],
              );
              widget.onSetState();
            },
            buttonText: 'C',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Parentheses Button
        else if (buttonText == '()') {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('()');
              widget.onUpdateMathEditor();
            },
            buttonText: '()',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // E (exponent) Button
        else if (buttonText == '\u1D07') {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('\u1D07');
              widget.onUpdateMathEditor();
            },
            buttonText: '\u1D07',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Number and other buttons
        else {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter(buttonText);
              widget.onUpdateMathEditor();
            },
            buttonText: buttonText,
            color: Colors.white,
            textColor: Colors.black,
          );
        }
      },
    );
  }

  Widget _buildScientificGrid(bool isLandscape) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: isLandscape ? 1.5 : 1.0,
      ),
      itemCount: _buttonsSci.length,
      itemBuilder: (context, index) {
        // = button
        if (index == 0) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter(_buttonsSci[index]);
              widget.onUpdateMathEditor();
            },
            buttonText: '=',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // pi button
        if (index == 6) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('\u03C0');
              widget.onUpdateMathEditor();
            },
            buttonText: '\u03C0',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // ^2 Button
        else if (index == 1) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertSquare();
              widget.onUpdateMathEditor();
            },
            buttonText: 'x\u00B2',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // ^ Button
        else if (index == 2) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('^');
              widget.onUpdateMathEditor();
            },
            buttonText: 'x\u207F',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Square root Button
        else if (index == 3) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertSquareRoot();
              widget.onUpdateMathEditor();
            },
            buttonText: '\u221A',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Nth root Button
        else if (index == 4) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertNthRoot();
              widget.onUpdateMathEditor();
            },
            buttonText: '\u207F\u221A',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // sin Button
        else if (index == 7) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertTrig('sin');
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // cos Button
        else if (index == 8) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertTrig('cos');
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // tan Button
        else if (index == 9) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertTrig('tan');
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // asin Button
        else if (index == 12) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertTrig('asin');
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // acos Button
        else if (index == 13) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertTrig('acos');
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // atan Button
        else if (index == 14) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertTrig('atan');
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // ln Button
        else if (index == 17) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertTrig('ln');
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // log Button
        else if (index == 18) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertLog10();
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // logn Button
        else if (index == 19) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertLogN();
              widget.onUpdateMathEditor();
            },
            buttonText: 'log\u1D63',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Degree button
        else if (index == 11) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter(_buttonsSci[index]);
              widget.onUpdateMathEditor();
            },
            buttonText: '\u00B0',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Other buttons
        else {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter(_buttonsSci[index]);
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        }
      },
    );
  }

  Widget _buildNumberGrid(bool isLandscape) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _buttons.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: isLandscape ? 1.5 : 1.0,
      ),
      itemBuilder: (context, index) {
        // () button
        if (index == 3) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter(_buttons[index]);
              widget.onUpdateMathEditor();
            },
            buttonText: '\u0028\u0029',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Delete Button
        else if (index == 4) {
          return GestureDetector(
            onLongPressStart: (_) => _startContinuousDelete(),
            onLongPressEnd: (_) => _stopContinuousDelete(),
            onLongPressCancel: _stopContinuousDelete,
            child: MyButton(
              buttontapped: () {
                _activeController?.deleteChar();
                widget.onUpdateMathEditor();
                if (_activeController?.expr == '') {
                  widget.onRemoveDisplay(widget.activeIndex);
                }
                widget.onSetState();
              },
              buttonText: '\u232B',
              color: const Color.fromARGB(255, 226, 104, 104),
              textColor: Colors.black,
            ),
          );
        }
        // Addition Button
        else if (index == 8) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('\u002B');
              widget.onUpdateMathEditor();
            },
            buttonText: '\u002B',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Subtraction Button
        else if (index == 9) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('\u2212');
              widget.onUpdateMathEditor();
            },
            buttonText: '\u2212',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Multiplication Button
        else if (index == 13) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter(
                widget.settingsProvider.multiplicationSign,
              );
              widget.onUpdateMathEditor();
            },
            buttonText: '\u00D7',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Division Button
        else if (index == 14) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter(_buttons[index]);
              widget.onUpdateMathEditor();
            },
            buttonText: '\u00F7',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // E Button
        else if (index == 17) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter(_buttons[index]);
              widget.onUpdateMathEditor();
            },
            buttonText: _buttons[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Clear Button
        else if (index == 18) {
          return MyButton(
            buttontapped: () {
              _activeController?.clear();
              widget.onUpdateMathEditor();
              widget.onSetState();
            },
            buttonText: _buttons[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Enter Button
        else if (index == 19) {
          return MyButton(
            buttontapped: _handleEnter,
            buttonText: '\u2318',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Other buttons
        else {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter(_buttons[index]);
              widget.onUpdateMathEditor();
            },
            buttonText: _buttons[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        }
      },
    );
  }

  Widget _buildExtrasGrid(bool isLandscape) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _buttonsR.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: isLandscape ? 1.5 : 1.0,
      ),
      itemBuilder: (context, index) {
        // Undo button
        if (index == 3) {
          bool canUndo = _activeController?.canUndo ?? false;
          return MyButton(
            buttontapped: () {
              _activeController?.undo();
              widget.onUpdateMathEditor();
              widget.onSetState();
            },
            buttonText: _buttonsR[index],
            color: canUndo ? Colors.white : Colors.grey[300]!,
            textColor: canUndo ? Colors.black : Colors.grey,
          );
        }
        // Redo button
        if (index == 2) {
          bool canRedo = _activeController?.canRedo ?? false;
          return MyButton(
            buttontapped: () {
              _activeController?.redo();
              widget.onUpdateMathEditor();
              widget.onSetState();
            },
            buttonText: _buttonsR[index],
            color: canRedo ? Colors.white : Colors.grey[300]!,
            textColor: canRedo ? Colors.black : Colors.grey,
          );
        }
        // Clear All Button
        if (index == 4) {
          return MyButton(
            buttontapped: widget.onClearAllDisplays,
            buttonText: _buttonsR[index],
            color: const Color.fromARGB(255, 226, 104, 104),
            textColor: Colors.black,
          );
        }
        // Complex number button
        if (index == 5) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter(_buttonsR[index]);
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsR[index],
            color: Colors.white,
            textColor: Colors.grey,
          );
        }
        // Factorial Button
        else if (index == 6) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('!');
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsR[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Permutation Button
        else if (index == 7) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertPermutation();
              widget.onUpdateMathEditor();
            },
            buttonText: '\u207FP\u1D63',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Combination Button
        else if (index == 8) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCombination();
              widget.onUpdateMathEditor();
            },
            buttonText: '\u207FC\u1D63',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // ANS button
        else if (index == 9) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter(_buttonsR[index]);
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsR[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Help Button
        else if (index == 18) {
          return MyButton(
            buttontapped: () {
              Navigator.push(context, SlidePageRoute(page: HelpPage()));
            },
            buttonText: _buttonsR[index],
            fontSize: 28,
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Settings Button
        else if (index == 19) {
          return MyButton(
            buttontapped: () {
              Navigator.push(context, SlidePageRoute(page: SettingsScreen()));
            },
            buttonText: '\u2699',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Other buttons (empty/disabled)
        else {
          return MyButton(
            buttonText: _buttonsR[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        }
      },
    );
  }
}
