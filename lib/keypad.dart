import 'package:flutter/material.dart';
import 'package:klator/help.dart';
import 'package:klator/utils.dart';
import 'buttons.dart';
import 'settings.dart';
import 'settings_provider.dart';
import 'renderer.dart';
import 'app_colors.dart';
import 'dart:async';
import 'walkthrough/walkthrough_service.dart';
import 'walkthrough/walkthrough_steps.dart';

/// Custom ScrollPhysics that restricts swipe direction
class DirectionalScrollPhysics extends ScrollPhysics {
  final bool allowLeftSwipe;
  final bool allowRightSwipe;

  const DirectionalScrollPhysics({
    super.parent,
    this.allowLeftSwipe = true,
    this.allowRightSwipe = true,
  });

  @override
  DirectionalScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return DirectionalScrollPhysics(
      parent: buildParent(ancestor),
      allowLeftSwipe: allowLeftSwipe,
      allowRightSwipe: allowRightSwipe,
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // value > position.pixels means scrolling left (moving to higher index)
    // value < position.pixels means scrolling right (moving to lower index)

    if (!allowLeftSwipe && value > position.pixels) {
      // Trying to swipe left but not allowed - prevent it
      return value - position.pixels;
    }

    if (!allowRightSwipe && value < position.pixels) {
      // Trying to swipe right but not allowed - prevent it
      return value - position.pixels;
    }

    return super.applyBoundaryConditions(position, value);
  }
}

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
  final VoidCallback onSetState;

  // Walkthrough parameters
  final WalkthroughService walkthroughService;
  final GlobalKey basicKeypadKey;
  final GlobalKey basicKeypadHandleKey;
  final GlobalKey scientificKeypadKey;
  final GlobalKey numberKeypadKey;
  final GlobalKey extrasKeypadKey;
  final GlobalKey commandButtonKey;
  final GlobalKey mainKeypadAreaKey;
  final GlobalKey settingsButtonKey;

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
    required this.walkthroughService,
    required this.basicKeypadKey,
    required this.basicKeypadHandleKey,
    required this.scientificKeypadKey,
    required this.numberKeypadKey,
    required this.extrasKeypadKey,
    required this.commandButtonKey,
    required this.mainKeypadAreaKey,
    required this.settingsButtonKey,
  });

  @override
  State<CalculatorKeypad> createState() => _CalculatorKeypadState();
}

class _CalculatorKeypadState extends State<CalculatorKeypad> {
  int? _lastPagesPerView;
  bool _isBasicKeypadExpanded = false;
  final double _collapsedHeight = 21.0;

  PageController? _keypadController;
  late PageController _pgViewController;

  Timer? _deleteTimer;
  bool _isDeleting = false;
  int _deleteSpeed = 150;

  int _currentKeypadIndex = 1;

  bool _isNavigatingProgrammatically = false;

  // Button lists
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
    _pgViewController = PageController();
    widget.walkthroughService.onResetKeypad = _resetToNumberKeypad;
    widget.walkthroughService.onNavigateToKeypadPage = _navigateToKeypadPage;
  }

  @override
  void dispose() {
    _deleteTimer?.cancel();
    _keypadController?.dispose();
    _pgViewController.dispose();
    widget.walkthroughService.onResetKeypad = null;
    widget.walkthroughService.onNavigateToKeypadPage = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CalculatorKeypad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.walkthroughService != oldWidget.walkthroughService) {
      oldWidget.walkthroughService.onResetKeypad = null;
      oldWidget.walkthroughService.onNavigateToKeypadPage = null;
      widget.walkthroughService.onResetKeypad = _resetToNumberKeypad;
      widget.walkthroughService.onNavigateToKeypadPage = _navigateToKeypadPage;
    }
  }

  /// Navigate keypad to a specific page (used by walkthrough back button)
  void _navigateToKeypadPage(int page) {
    debugPrint('=== _navigateToKeypadPage called with page: $page ===');
    debugPrint('Current keypad index before: $_currentKeypadIndex');

    if (_keypadController != null && _keypadController!.hasClients) {
      // Set flag to bypass directional physics during programmatic navigation
      setState(() {
        _isNavigatingProgrammatically = true;
      });

      _keypadController!
          .animateToPage(
            page,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          )
          .then((_) {
            // Reset flag after animation completes
            if (mounted) {
              setState(() {
                _isNavigatingProgrammatically = false;
              });
            }
          });

      _currentKeypadIndex = page;
      debugPrint('Navigating to page: $page');
    } else {
      debugPrint('Could not navigate - controller null or no clients');
    }
  }

  void _resetToNumberKeypad() {
    final int targetPage;
    if (_lastPagesPerView != null && _lastPagesPerView! >= 2) {
      targetPage = 0;
    } else {
      targetPage = 1;
    }

    debugPrint(
      'Resetting keypad to page $targetPage (pagesPerView: $_lastPagesPerView)',
    );

    if (_keypadController != null && _keypadController!.hasClients) {
      // Set flag to bypass directional physics during programmatic navigation
      setState(() {
        _isNavigatingProgrammatically = true;
      });

      _keypadController!
          .animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          )
          .then((_) {
            if (mounted) {
              setState(() {
                _isNavigatingProgrammatically = false;
              });
            }
          });
    }

    _currentKeypadIndex = targetPage;
  }

  void _initializeKeypadController(int pagesPerView) {
    final initialPage = pagesPerView >= 2 ? 0 : 1;
    _currentKeypadIndex = initialPage;

    _keypadController?.dispose();
    _keypadController = PageController(
      initialPage: initialPage,
      viewportFraction: 1 / pagesPerView,
    );
  }

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

  void _toggleBasicKeypad() {
    setState(() {
      _isBasicKeypadExpanded = !_isBasicKeypadExpanded;
    });
  }

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

  void _onKeypadPageChanged(int newIndex) {
    if (newIndex != _currentKeypadIndex) {
      // Don't trigger walkthrough action if navigating programmatically
      if (!_isNavigatingProgrammatically) {
        final WalkthroughAction direction;
        if (newIndex > _currentKeypadIndex) {
          direction = WalkthroughAction.swipeLeft;
        } else {
          direction = WalkthroughAction.swipeRight;
        }
        widget.walkthroughService.onUserAction(direction);
        debugPrint(
          'Keypad page changed by user: $newIndex, Direction: $direction',
        );
      } else {
        debugPrint('Keypad page changed programmatically: $newIndex');
      }

      _currentKeypadIndex = newIndex;
    }
  }

  /// Get the appropriate scroll physics based on walkthrough state
  ScrollPhysics _getKeypadPhysics() {
    // IMPORTANT: Allow normal scrolling during programmatic navigation
    if (_isNavigatingProgrammatically) {
      return const PageScrollPhysics();
    }

    final service = widget.walkthroughService;

    // If walkthrough is not active, allow normal scrolling
    if (!service.isActive || !service.isInitialized) {
      return const PageScrollPhysics();
    }

    final step = service.currentStepData;

    // Only restrict if it's a swipe-required step
    if (!step.requiresAction || step.requiredAction == null) {
      return const PageScrollPhysics();
    }

    // Restrict based on required action
    if (step.requiredAction == WalkthroughAction.swipeLeft) {
      return const DirectionalScrollPhysics(
        allowLeftSwipe: true,
        allowRightSwipe: false,
      );
    } else if (step.requiredAction == WalkthroughAction.swipeRight) {
      return const DirectionalScrollPhysics(
        allowLeftSwipe: false,
        allowRightSwipe: true,
      );
    }

    return const PageScrollPhysics();
  }

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

    final isTablet = pagesPerView >= 2;
    if (widget.walkthroughService.isTabletMode != isTablet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.walkthroughService.setDeviceMode(isTablet: isTablet);
      });
    }

    if (_lastPagesPerView != pagesPerView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initializeKeypadController(pagesPerView);
          setState(() {});
        }
      });

      if (_keypadController == null) {
        _initializeKeypadController(pagesPerView);
      }

      _lastPagesPerView = pagesPerView;
    }

    int crossAxisCount = 5;
    int rowCount = 4;
    double buttonSize = widget.screenWidth / crossAxisCount;

    double gridHeight;
    if (widget.isLandscape) {
      double buttonHeightRatio = 0.65;
      gridHeight = (buttonSize * buttonHeightRatio * rowCount) / pagesPerView;
    } else {
      gridHeight = buttonSize * rowCount / pagesPerView;
    }

    int crossAxisCountBasic = widget.isLandscape ? 20 : 10;
    double buttonSizeBasic = widget.screenWidth / crossAxisCountBasic;

    double basicKeypadExpandedHeight;
    if (widget.isLandscape) {
      double buttonHeightRatio = 0.65;
      basicKeypadExpandedHeight = buttonSizeBasic * buttonHeightRatio * 1;
    } else {
      basicKeypadExpandedHeight = buttonSizeBasic * 2;
    }

    double basicKeypadHeight =
        _isBasicKeypadExpanded
            ? basicKeypadExpandedHeight + _collapsedHeight
            : _collapsedHeight;

    return Column(
      children: [
        // Basic Keypad
        GestureDetector(
          onTap: _toggleBasicKeypad,
          child: AnimatedContainer(
            key: widget.basicKeypadKey,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: basicKeypadHeight,
            width: double.infinity,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: Column(
              children: [
                Container(
                  key: widget.basicKeypadHandleKey,
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.colors.containerBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
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

        // Main Keypad with directional physics
        SizedBox(
          key: widget.mainKeypadAreaKey,
          height: gridHeight,
          width: double.infinity, // ← Add this to match Container behavior
          child:
              _keypadController != null
                  ? ListenableBuilder(
                    listenable: widget.walkthroughService,
                    builder: (context, _) {
                      return PageView(
                        padEnds: false,
                        controller: _keypadController!,
                        physics: _getKeypadPhysics(),
                        onPageChanged: _onKeypadPageChanged,
                        children: [
                          // Use SizedBox.expand() for children that need to fill space
                          SizedBox.expand(
                            key: widget.scientificKeypadKey,
                            child: _buildScientificGrid(widget.isLandscape),
                          ),
                          SizedBox.expand(
                            key: widget.numberKeypadKey,
                            child: _buildNumberGrid(widget.isLandscape),
                          ),
                          SizedBox.expand(
                            key: widget.extrasKeypadKey,
                            child: _buildExtrasGrid(widget.isLandscape),
                          ),
                        ],
                      );
                    },
                  )
                  : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ... rest of your existing methods (_buildBasicGrid, _buildScientificGrid, etc.) remain the same

  Widget _buildBasicGrid(int crossAxisCount, bool isLandscape) {
    final List<String> buttons =
        isLandscape ? _buttonsBasicLandscape : _buttonsBasic;

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
        } else if (buttonText == '-') {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('-');
              widget.onUpdateMathEditor();
            },
            buttonText: '\u2212',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (buttonText == 'x') {
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
        } else if (buttonText == '/') {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('/');
              widget.onUpdateMathEditor();
            },
            buttonText: '\u00F7',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (buttonText == '\u2318') {
          return MyButton(
            buttontapped: _handleEnter,
            buttonText: '\u2318',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (buttonText == '\u232B') {
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
        } else if (buttonText == 'C') {
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
        } else if (buttonText == '()') {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('()');
              widget.onUpdateMathEditor();
            },
            buttonText: '()',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (buttonText == '\u1D07') {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('\u1D07');
              widget.onUpdateMathEditor();
            },
            buttonText: '\u1D07',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else {
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
        } else if (index == 1) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertSquare();
              widget.onUpdateMathEditor();
            },
            buttonText: 'x\u00B2',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 2) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('^');
              widget.onUpdateMathEditor();
            },
            buttonText: 'x\u207F',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 3) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertSquareRoot();
              widget.onUpdateMathEditor();
            },
            buttonText: '\u221A',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 4) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertNthRoot();
              widget.onUpdateMathEditor();
            },
            buttonText: '\u207F\u221A',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 7) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertTrig('sin');
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 8) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertTrig('cos');
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 9) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertTrig('tan');
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 12) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertTrig('asin');
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 13) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertTrig('acos');
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 14) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertTrig('atan');
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 17) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertTrig('ln');
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 18) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertLog10();
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 19) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertLogN();
              widget.onUpdateMathEditor();
            },
            buttonText: 'log\u1D63',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 11) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter(_buttonsSci[index]);
              widget.onUpdateMathEditor();
            },
            buttonText: '\u00B0',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else {
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
        } else if (index == 4) {
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
        } else if (index == 8) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('\u002B');
              widget.onUpdateMathEditor();
            },
            buttonText: '\u002B',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 9) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('\u2212');
              widget.onUpdateMathEditor();
            },
            buttonText: '\u2212',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 13) {
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
        } else if (index == 14) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter(_buttons[index]);
              widget.onUpdateMathEditor();
            },
            buttonText: '\u00F7',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 17) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter(_buttons[index]);
              widget.onUpdateMathEditor();
            },
            buttonText: _buttons[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 18) {
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
        } else if (index == 19) {
          return Container(
            key: widget.commandButtonKey,
            child: MyButton(
              buttontapped: _handleEnter,
              buttonText: '\u2318',
              color: Colors.white,
              textColor: Colors.black,
            ),
          );
        } else {
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
        if (index == 4) {
          return MyButton(
            buttontapped: widget.onClearAllDisplays,
            buttonText: _buttonsR[index],
            color: const Color.fromARGB(255, 226, 104, 104),
            textColor: Colors.black,
          );
        }
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
        } else if (index == 6) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('!');
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsR[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 7) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertPermutation();
              widget.onUpdateMathEditor();
            },
            buttonText: '\u207FP\u1D63',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 8) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCombination();
              widget.onUpdateMathEditor();
            },
            buttonText: '\u207FC\u1D63',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 9) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter(_buttonsR[index]);
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsR[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 18) {
          return MyButton(
            buttontapped: () {
              Navigator.push(context, SlidePageRoute(page: HelpPage()));
            },
            buttonText: _buttonsR[index],
            fontSize: 28,
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 19) {
          return Container(
            key: widget.settingsButtonKey,
            child: MyButton(
              buttontapped: () {
                Navigator.push(
                  context,
                  SlidePageRoute(
                    page: SettingsScreen(
                      onShowTutorial: () {
                        Navigator.pop(context);
                        widget.walkthroughService.resetWalkthrough();
                      },
                    ),
                  ),
                );
              },
              buttonText: '\u2699',
              color: Colors.white,
              textColor: Colors.black,
            ),
          );
        } else {
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
