import 'package:flutter/material.dart';
import 'package:klator/help.dart';
import 'package:klator/utils/utils.dart';
import 'buttons.dart';
import 'popup_menu_button.dart';
import '../settings/settings.dart';
import '../settings/settings_provider.dart';
import '../utils/app_colors.dart';
import 'dart:async';
import '../walkthrough/walkthrough_service.dart';
import '../walkthrough/walkthrough_steps.dart';
import '../math_renderer/math_editor_controller.dart';

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

  final VoidCallback? onClearSelectionOverlay;

  final bool canUndoAppState;
  final bool canRedoAppState;
  final VoidCallback? onUndoAppState;
  final VoidCallback? onRedoAppState;

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
    this.onClearSelectionOverlay,
    this.canUndoAppState = false,
    this.canRedoAppState = false,
    this.onUndoAppState,
    this.onRedoAppState,
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
    'CE',
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
    'CE',
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
    '\u238C',
    '\u238C',
    '\u2327',
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
      } else {
        debugPrint('Keypad page changed programmatically: $newIndex');
      }

      _currentKeypadIndex = newIndex;
    }
  }

  void _handleButtonWithSelection({
    required bool Function() wrapAction,
    required VoidCallback normalAction,
  }) {
    final hadSelection = _activeController?.hasSelection ?? false;

    if (hadSelection) {
      if (wrapAction()) {
        widget.onClearSelectionOverlay?.call();
        widget.onUpdateMathEditor();
        widget.onSetState();
      }
    } else {
      normalAction();
      widget.onUpdateMathEditor();
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: 0.2,
                        ), // Shadow color with transparency
                        spreadRadius:
                            2, // How much the shadow grows bigger than the box
                        blurRadius:
                            7, // How soft the edges are (higher = softer)
                        offset: Offset(
                          0,
                          0,
                        ), // X, Y position (0,3 means slightly downwards)
                      ),
                    ],
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
              _handleButtonWithSelection(
                wrapAction:
                    () => _activeController!.selectionWrapper.wrapInFraction(),
                normalAction: () => _activeController?.insertCharacter('/'),
              );
            },
            buttonText: '\u00F7',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (buttonText == '\u2318') {
          return MyButton(
            buttontapped: _handleEnter,
            buttonText: '\u2318',
            color: Colors.blueGrey,
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
        } else if (buttonText == 'CE') {
          return MyButton(
            buttontapped: () {
              _activeController?.clear();
              _activeController?.updateAnswer(
                widget.textDisplayControllers[widget.activeIndex],
              );
              widget.onSetState();
            },
            buttonText: 'CE',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (buttonText == '()') {
          return MyButton(
            buttontapped: () {
              _handleButtonWithSelection(
                wrapAction:
                    () =>
                        _activeController!.selectionWrapper.wrapInParenthesis(),
                normalAction: () => _activeController?.insertCharacter('()'),
              );
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
        // x^2 button
        if (index == 1) {
          return MyButton(
            buttontapped: () {
              _handleButtonWithSelection(
                wrapAction:
                    () => _activeController!.selectionWrapper.wrapInSquare(),
                normalAction: () => _activeController?.insertSquare(),
              );
            },
            buttonText: 'x\u00B2',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // x^n button
        else if (index == 2) {
          return MyButton(
            buttontapped: () {
              _handleButtonWithSelection(
                wrapAction:
                    () => _activeController!.selectionWrapper.wrapInExponent(),
                normalAction: () => _activeController?.insertCharacter('^'),
              );
            },
            buttonText: 'x\u207F',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Square root button
        else if (index == 3) {
          return MyButton(
            buttontapped: () {
              _handleButtonWithSelection(
                wrapAction:
                    () =>
                        _activeController!.selectionWrapper.wrapInSquareRoot(),
                normalAction: () => _activeController?.insertSquareRoot(),
              );
            },
            buttonText: '\u221A',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // Nth root button
        else if (index == 4) {
          return MyButton(
            buttontapped: () {
              _handleButtonWithSelection(
                wrapAction:
                    () => _activeController!.selectionWrapper.wrapInNthRoot(),
                normalAction: () => _activeController?.insertNthRoot(),
              );
            },
            buttonText: '\u207F\u221A',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // sin button with popup for sinh
        else if (index == 7) {
          return PopupMenuCalcButton(
            buttonText: _buttonsSci[index],
            onTap: () {
              _handleButtonWithSelection(
                wrapAction:
                    () => _activeController!.selectionWrapper.wrapInTrig('sin'),
                normalAction: () => _activeController?.insertTrig('sin'),
              );
            },
            menuItems: [
              CalcMenuItem(
                label: 'sinh',
                onTap: () {
                  _activeController?.insertTrig('sinh');
                  widget.onUpdateMathEditor();
                },
              ),
            ],
            indicatorColor: widget.colors.textSecondary,
          );
        }
        // cos button with popup for cosh
        else if (index == 8) {
          return PopupMenuCalcButton(
            buttonText: _buttonsSci[index],
            onTap: () {
              _handleButtonWithSelection(
                wrapAction:
                    () => _activeController!.selectionWrapper.wrapInTrig('cos'),
                normalAction: () => _activeController?.insertTrig('cos'),
              );
            },
            menuItems: [
              CalcMenuItem(
                label: 'cosh',
                onTap: () {
                  _activeController?.insertTrig('cosh');
                  widget.onUpdateMathEditor();
                },
              ),
            ],
            indicatorColor: widget.colors.textSecondary,
          );
        }
        // tan button with popup for tanh
        else if (index == 9) {
          return PopupMenuCalcButton(
            buttonText: _buttonsSci[index],
            onTap: () {
              _handleButtonWithSelection(
                wrapAction:
                    () => _activeController!.selectionWrapper.wrapInTrig('tan'),
                normalAction: () => _activeController?.insertTrig('tan'),
              );
            },
            menuItems: [
              CalcMenuItem(
                label: 'tanh',
                onTap: () {
                  _activeController?.insertTrig('tanh');
                  widget.onUpdateMathEditor();
                },
              ),
            ],
            indicatorColor: widget.colors.textSecondary,
          );
        }
        // asin button with popup for asinh
        else if (index == 12) {
          return PopupMenuCalcButton(
            buttonText: _buttonsSci[index],
            onTap: () {
              _handleButtonWithSelection(
                wrapAction:
                    () =>
                        _activeController!.selectionWrapper.wrapInTrig('asin'),
                normalAction: () => _activeController?.insertTrig('asin'),
              );
            },
            menuItems: [
              CalcMenuItem(
                label: 'asinh',
                onTap: () {
                  _activeController?.insertTrig('asinh');
                  widget.onUpdateMathEditor();
                },
              ),
            ],
            indicatorColor: widget.colors.textSecondary,
          );
        }
        // acos button with popup for acosh
        else if (index == 13) {
          return PopupMenuCalcButton(
            buttonText: _buttonsSci[index],
            onTap: () {
              _handleButtonWithSelection(
                wrapAction:
                    () =>
                        _activeController!.selectionWrapper.wrapInTrig('acos'),
                normalAction: () => _activeController?.insertTrig('acos'),
              );
            },
            menuItems: [
              CalcMenuItem(
                label: 'acosh',
                onTap: () {
                  _activeController?.insertTrig('acosh');
                  widget.onUpdateMathEditor();
                },
              ),
            ],
            indicatorColor: widget.colors.textSecondary,
          );
        }
        // atan button with popup for atanh
        else if (index == 14) {
          return PopupMenuCalcButton(
            buttonText: _buttonsSci[index],
            onTap: () {
              _handleButtonWithSelection(
                wrapAction:
                    () =>
                        _activeController!.selectionWrapper.wrapInTrig('atan'),
                normalAction: () => _activeController?.insertTrig('atan'),
              );
            },
            menuItems: [
              CalcMenuItem(
                label: 'atanh',
                onTap: () {
                  _activeController?.insertTrig('atanh');
                  widget.onUpdateMathEditor();
                },
              ),
            ],
            indicatorColor: widget.colors.textSecondary,
          );
        }
        // ln button
        else if (index == 17) {
          return MyButton(
            buttontapped: () {
              _handleButtonWithSelection(
                wrapAction:
                    () =>
                        _activeController!.selectionWrapper.wrapInNaturalLog(),
                normalAction: () => _activeController?.insertNaturalLog(),
              );
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // log button
        else if (index == 18) {
          return MyButton(
            buttontapped: () {
              _handleButtonWithSelection(
                wrapAction:
                    () => _activeController!.selectionWrapper.wrapInLog10(),
                normalAction: () => _activeController?.insertLog10(),
              );
            },
            buttonText: _buttonsSci[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // logn button
        else if (index == 19) {
          return MyButton(
            buttontapped: () {
              _handleButtonWithSelection(
                wrapAction:
                    () => _activeController!.selectionWrapper.wrapInLogN(),
                normalAction: () => _activeController?.insertLogN(),
              );
            },
            buttonText: 'log\u1D63',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // ... rest of existing cases
        else if (index == 0) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter(_buttonsSci[index]);
              widget.onUpdateMathEditor();
            },
            buttonText: '=',
            color: Colors.white,
            textColor: Colors.black,
          );
        } else if (index == 6) {
          // π button with popup menu for constants
          return PopupMenuCalcButton(
            buttonText: '\u03C0',
            color: Colors.white,
            textColor: Colors.black,
            menuBackgroundColor: Colors.white,
            separatorColor: Colors.black12,

            onTap: () {
              _activeController?.insertCharacter('\u03C0');
              widget.onUpdateMathEditor();
            },
            menuItems: [
              CalcMenuItem(
                label: 'ε₀ (permittivity)',
                onTap: () {
                  _activeController?.insertConstant('\u03B5\u2080');
                  widget.onUpdateMathEditor();
                },
              ),
              CalcMenuItem(
                label: 'μ₀ (permeability)',
                onTap: () {
                  _activeController?.insertConstant('\u03BC\u2080');
                  widget.onUpdateMathEditor();
                },
              ),
              CalcMenuItem(
                label: 'c₀ (speed of light)',
                onTap: () {
                  _activeController?.insertConstant('c\u2080');
                  widget.onUpdateMathEditor();
                },
              ),
            ],
            indicatorColor: widget.colors.textSecondary,
          );
        } else if (index == 7) {
          // sin
          return PopupMenuCalcButton(
            buttonText: 'sin',
            color: widget.colors.keypadButton,
            textColor: widget.colors.keypadButtonText,
            menuBackgroundColor: Colors.white,
            separatorColor: Colors.black12,

            onTap: () {
              _activeController?.insertTrig('sin');
              widget.onUpdateMathEditor();
            },
            menuItems: [
              CalcMenuItem(
                label: 'sinh',
                onTap: () {
                  _activeController?.insertTrig('sinh');
                  widget.onUpdateMathEditor();
                },
              ),
            ],
            indicatorColor: widget.colors.textSecondary,
          );
        } else if (index == 8) {
          // cos
          return PopupMenuCalcButton(
            buttonText: 'cos',
            color: widget.colors.keypadButton,
            textColor: widget.colors.keypadButtonText,
            menuBackgroundColor: Colors.white,
            separatorColor: Colors.black12,

            onTap: () {
              _activeController?.insertTrig('cos');
              widget.onUpdateMathEditor();
            },
            menuItems: [
              CalcMenuItem(
                label: 'cosh',
                onTap: () {
                  _activeController?.insertTrig('cosh');
                  widget.onUpdateMathEditor();
                },
              ),
            ],
            indicatorColor: widget.colors.textSecondary,
          );
        } else if (index == 9) {
          // tan
          return PopupMenuCalcButton(
            buttonText: 'tan',
            color: widget.colors.keypadButton,
            textColor: widget.colors.keypadButtonText,
            menuBackgroundColor: Colors.white,
            separatorColor: Colors.black12,

            onTap: () {
              _activeController?.insertTrig('tan');
              widget.onUpdateMathEditor();
            },
            menuItems: [
              CalcMenuItem(
                label: 'tanh',
                onTap: () {
                  _activeController?.insertTrig('tanh');
                  widget.onUpdateMathEditor();
                },
              ),
            ],
            indicatorColor: widget.colors.textSecondary,
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
        } else if (index == 12) {
          // asin
          return PopupMenuCalcButton(
            buttonText: 'asin',
            color: widget.colors.keypadButton,
            textColor: widget.colors.keypadButtonText,
            menuBackgroundColor: Colors.white,
            separatorColor: Colors.black12,

            onTap: () {
              _activeController?.insertTrig('asin');
              widget.onUpdateMathEditor();
            },
            menuItems: [
              CalcMenuItem(
                label: 'asinh',
                onTap: () {
                  _activeController?.insertTrig('asinh');
                  widget.onUpdateMathEditor();
                },
              ),
            ],
            indicatorColor: widget.colors.textSecondary,
          );
        } else if (index == 13) {
          // acos
          return PopupMenuCalcButton(
            buttonText: 'acos',
            color: widget.colors.keypadButton,
            textColor: widget.colors.keypadButtonText,
            menuBackgroundColor: Colors.white,
            separatorColor: Colors.black12,

            onTap: () {
              _activeController?.insertTrig('acos');
              widget.onUpdateMathEditor();
            },
            menuItems: [
              CalcMenuItem(
                label: 'acosh',
                onTap: () {
                  _activeController?.insertTrig('acosh');
                  widget.onUpdateMathEditor();
                },
              ),
            ],
            indicatorColor: widget.colors.textSecondary,
          );
        } else if (index == 14) {
          // atan
          return PopupMenuCalcButton(
            buttonText: 'atan',
            color: widget.colors.keypadButton,
            textColor: widget.colors.keypadButtonText,
            menuBackgroundColor: Colors.white,
            separatorColor: Colors.black12,

            onTap: () {
              _activeController?.insertTrig('atan');
              widget.onUpdateMathEditor();
            },
            menuItems: [
              CalcMenuItem(
                label: 'atanh',
                onTap: () {
                  _activeController?.insertTrig('atanh');
                  widget.onUpdateMathEditor();
                },
              ),
            ],
            indicatorColor: widget.colors.textSecondary,
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
              _handleButtonWithSelection(
                wrapAction:
                    () =>
                        _activeController!.selectionWrapper.wrapInParenthesis(),
                normalAction:
                    () => _activeController?.insertCharacter(_buttons[index]),
              );
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
            color: const Color.fromARGB(234, 255, 255, 255),
            textColor: Colors.black,
          );
        } else if (index == 9) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('\u2212');
              widget.onUpdateMathEditor();
            },
            buttonText: '\u2212',
            color: const Color.fromARGB(234, 255, 255, 255),
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
            color: const Color.fromARGB(234, 255, 255, 255),
            textColor: Colors.black,
          );
        } // Division button (index 14)
        else if (index == 14) {
          return MyButton(
            buttontapped: () {
              _handleButtonWithSelection(
                wrapAction:
                    () => _activeController!.selectionWrapper.wrapInFraction(),
                normalAction:
                    () => _activeController?.insertCharacter(_buttons[index]),
              );
            },
            buttonText: '\u00F7',
            color: const Color.fromARGB(234, 255, 255, 255),
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
              color: Colors.blueGrey,
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
          // Undo button
          bool canUndo =
              (_activeController?.canUndo ?? false) || widget.canUndoAppState;
          return MyButton(
            buttontapped: () {
              if (_activeController?.canUndo ?? false) {
                // Controller-level undo first
                _activeController?.undo();
                widget.onUpdateMathEditor();
                widget.onSetState();
              } else if (widget.canUndoAppState) {
                // App-level undo (for Clear All, etc.)
                widget.onUndoAppState?.call();
              }
            },
            buttonText: _buttonsR[index],
            color: canUndo ? Colors.white : Colors.grey[300]!,
            textColor: canUndo ? Colors.black : Colors.grey,
          );
        }
        if (index == 2) {
          // Redo button
          bool canRedo =
              (_activeController?.canRedo ?? false) || widget.canRedoAppState;
          return MyButton(
            buttontapped: () {
              if (_activeController?.canRedo ?? false) {
                // Controller-level redo first
                _activeController?.redo();
                widget.onUpdateMathEditor();
                widget.onSetState();
              } else if (widget.canRedoAppState) {
                // App-level redo
                widget.onRedoAppState?.call();
              }
            },
            buttonText: _buttonsR[index],
            color: canRedo ? Colors.white : Colors.grey[300]!,
            textColor: canRedo ? Colors.black : Colors.grey,
            mirror: true,
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
        // if (index == 5) {
        //   return MyButton(
        //     buttontapped: () {
        //       _activeController?.insertCharacter(_buttonsR[index]);
        //       widget.onUpdateMathEditor();
        //     },
        //     buttonText: _buttonsR[index],
        //     color: Colors.white,
        //     textColor: Colors.grey,
        //   );
        // } else
        if (index == 6) {
          return MyButton(
            buttontapped: () {
              _activeController?.insertCharacter('!');
              widget.onUpdateMathEditor();
            },
            buttonText: _buttonsR[index],
            color: Colors.white,
            textColor: Colors.black,
          );
        } // nPr button
        else if (index == 7) {
          return MyButton(
            buttontapped: () {
              _handleButtonWithSelection(
                wrapAction:
                    () =>
                        _activeController!.selectionWrapper.wrapInPermutation(),
                normalAction: () => _activeController?.insertPermutation(),
              );
            },
            buttonText: '\u207FP\u1D63',
            color: Colors.white,
            textColor: Colors.black,
          );
        }
        // nCr button
        else if (index == 8) {
          return MyButton(
            buttontapped: () {
              _handleButtonWithSelection(
                wrapAction:
                    () =>
                        _activeController!.selectionWrapper.wrapInCombination(),
                normalAction: () => _activeController?.insertCombination(),
              );
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
