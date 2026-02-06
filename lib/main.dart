import 'package:flutter/material.dart';
import 'package:klator/utils/constants.dart';
import 'package:provider/provider.dart';
import 'settings/settings_provider.dart';
import 'math_renderer/renderer.dart';
import 'utils/app_colors.dart';
import 'math_renderer/cell_persistence_service.dart';
import 'math_engine/math_expression_serializer.dart';
import 'dart:async';
import 'keypad/keypad.dart';
import 'walkthrough/walkthrough_service.dart';
import 'walkthrough/walkthrough_overlay.dart';
import 'utils/app_state.dart';
import 'math_renderer/expression_selection.dart';
import 'math_renderer/math_editor_controller.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'math_engine/math_engine_exact.dart';
import 'math_renderer/math_result_display.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Precache SVG backgrounds to avoid flash on load
  await Future.wait([
    _precacheSvg('assets/imgs/background_classic.svg'),
    _precacheSvg('assets/imgs/background_dark.svg'),
    _precacheSvg('assets/imgs/background_pink.svg'),
    _precacheSvg('assets/imgs/background_soft_pink.svg'),
    _precacheSvg('assets/imgs/background_sunset_ember.svg'),
    _precacheSvg('assets/imgs/background_desert_sand.svg'),
    _precacheSvg('assets/imgs/background_digital_amber.svg'),
    _precacheSvg('assets/imgs/background_rose_chic.svg'),
    _precacheSvg('assets/imgs/background_honey_mustard.svg'),
  ]);

  final settingsProvider = await SettingsProvider.create();

  runApp(
    ChangeNotifierProvider.value(value: settingsProvider, child: const MyApp()),
  );
}

/// Precache an SVG asset to avoid loading delay
Future<void> _precacheSvg(String assetPath) async {
  try {
    final loader = SvgAssetLoader(assetPath);
    await svg.cache.putIfAbsent(
      loader.cacheKey(null),
      () => loader.loadBytes(null),
    );
  } catch (e) {
    // Ignore errors - SVG will load normally if precaching fails
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: settings.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.blueGrey,
            fontFamily: FONTFAMILY,
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.black,
            ),
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: Colors.black,
              selectionColor: Colors.red.withValues(alpha: 0.4),
              selectionHandleColor: Colors.red,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.blueGrey,
            fontFamily: FONTFAMILY,
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              foregroundColor: Colors.white,
            ),
            cardColor: const Color(0xFF1E1E1E),
            dividerColor: Colors.grey[700],
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: Colors.white,
              selectionColor: Colors.red.withValues(alpha: 0.4),
              selectionHandleColor: Colors.red,
            ),
          ),
          home: const HomePage(),
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int count = 0;
  Map<int, GlobalKey<MathEditorInlineState>> mathEditorKeys = {}; // ADD THIS
  Map<int, TextEditingController> textDisplayControllers = {};
  Map<int, MathEditorController> mathEditorControllers = {};
  Map<int, FocusNode> focusNodes = {};
  Map<int, ScrollController> scrollControllers = {};

  Map<int, List<MathNode>?> exactResultNodes = {};
  Map<int, Expr?> exactResultExprs = {};
  Map<int, PageController> resultPageControllers = {};
  Map<int, int> currentResultPage = {};
  Map<int, ValueNotifier<int>> currentResultPageNotifiers = {};

  Map<int, ValueNotifier<int>> exactResultVersionNotifiers = {};

  Map<int, ValueNotifier<double>> resultPageProgressNotifiers = {};
  int activeIndex = 0;
  PageController pgViewController = PageController(
    initialPage: 1,
    viewportFraction: 1,
  );
  bool isVisible = true;
  bool isTypingExponent = false;
  double plotMaxHeight = 300;
  double plotMinHeight = 21;
  bool _isUpdating = false;
  String _globalClearId = DateTime.now().toIso8601String();
  bool _isLoading = true;
  List<String> answers = [];

  SettingsProvider? _settingsProvider;
  bool _listenerAdded = false;
  Timer? _deleteTimer;

  // Walkthrough
  late WalkthroughService _walkthroughService;
  bool _walkthroughInitialized = false;

  // Walkthrough target keys
  final GlobalKey _expressionKey = GlobalKey();
  final GlobalKey _resultKey = GlobalKey();
  final GlobalKey _ansIndexKey = GlobalKey();
  final GlobalKey _basicKeypadKey = GlobalKey();
  final GlobalKey _basicKeypadHandleKey = GlobalKey();
  final GlobalKey _commandButtonKey = GlobalKey();
  final GlobalKey _scientificKeypadKey = GlobalKey();
  final GlobalKey _numberKeypadKey = GlobalKey();
  final GlobalKey _extrasKeypadKey = GlobalKey();
  final GlobalKey _mainKeypadAreaKey = GlobalKey();
  final GlobalKey _settingsButtonKey = GlobalKey(); // NEW

  // App-level undo/redo for operations like "Clear All"
  final List<AppState> _appUndoStack = [];
  final List<AppState> _appRedoStack = [];
  static const int _maxAppHistorySize = 10;

  // Update the _walkthroughTargets getter:

  Map<String, GlobalKey> get _walkthroughTargets => {
    'expression_area': _expressionKey,
    'result_area': _resultKey,
    'ans_index': _ansIndexKey,
    'basic_keypad': _basicKeypadHandleKey,
    'command_button': _commandButtonKey,
    // Mobile keypad steps
    'number_keypad': _mainKeypadAreaKey,
    'scientific_keypad': _mainKeypadAreaKey,
    'extras_keypad': _mainKeypadAreaKey,
    'swipe_right_scientific': _mainKeypadAreaKey,
    'swipe_left_number': _mainKeypadAreaKey,
    'swipe_left_extras': _mainKeypadAreaKey,
    'swipe_right_back': _mainKeypadAreaKey,
    'settings_button': _settingsButtonKey, // NEW
    // Tablet keypad steps
    'tablet_keypads_visible': _mainKeypadAreaKey,
    'tablet_swipe_left_extras': _mainKeypadAreaKey,
    'tablet_extras_visible': _mainKeypadAreaKey,
    'tablet_swipe_right_back': _mainKeypadAreaKey,
    'tablet_settings_button': _settingsButtonKey, // NEW
    // Common
    'main_keypad_area': _mainKeypadAreaKey,
    'complete': _mainKeypadAreaKey,
  };

  Future<void> _initializeWalkthrough() async {
    if (_walkthroughInitialized) return;
    _walkthroughInitialized = true;

    // Delay to ensure everything is ready
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      // Determine if tablet mode based on screen size
      final mediaQuery = MediaQuery.of(context);
      final screenWidth = mediaQuery.size.width;
      final isLandscape = mediaQuery.orientation == Orientation.landscape;
      final isTablet = screenWidth > 600 || isLandscape;

      // Set device mode BEFORE initializing
      _walkthroughService.setDeviceMode(isTablet: isTablet);

      await _walkthroughService.initialize();
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize walkthrough service
    _walkthroughService = WalkthroughService();
    _walkthroughService.addListener(_onWalkthroughChanged);

    WidgetsBinding.instance.addObserver(this);
    _loadCells();

    if (mathEditorControllers.isEmpty) {
      _createControllers(0);
      count = 1;
      activeIndex = 0;
    }

    // Initialize walkthrough after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWalkthrough();
    });
  }

  void _onWalkthroughChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _createControllers(int index) {
    mathEditorControllers[index] = MathEditorController();

    mathEditorControllers[index]!.onResultChanged = () {
      _cascadeUpdates(index);
    };

    mathEditorControllers[index]!.addListener(() {
      _autoScrollToEnd(index);
    });

    textDisplayControllers[index] = TextEditingController();
    focusNodes[index] = FocusNode();
    mathEditorKeys[index] = GlobalKey<MathEditorInlineState>();
    scrollControllers[index] = ScrollController();

    // Initialize page tracking FIRST
    currentResultPage[index] = 0;
    currentResultPageNotifiers[index] = ValueNotifier<int>(0);
    resultPageProgressNotifiers[index] = ValueNotifier<double>(0.0);
    exactResultVersionNotifiers[index] = ValueNotifier<int>(0);
    exactResultNodes[index] = null;
    exactResultExprs[index] = null;
  }

  void _updateExactResult(int index) {
    final controller = mathEditorControllers[index];
    if (controller == null) return;

    try {
      // Collect valid previous exact results for substitution
      Map<int, Expr> ansExprs = {};
      List<int> sortedKeys = mathEditorControllers.keys.toList()..sort();
      for (int key in sortedKeys) {
        if (key < index) {
          Expr? prevExpr = exactResultExprs[key];
          if (prevExpr != null) {
            ansExprs[key] = prevExpr;
          }
        }
      }

      ExactResult result = ExactMathEngine.evaluate(
        controller.expression,
        ansExpressions: ansExprs,
      );

      if (result.isEmpty || result.hasError) {
        exactResultNodes[index] = null;
        exactResultExprs[index] = null;
      } else if (result.mathNodes != null && result.mathNodes!.isNotEmpty) {
        exactResultNodes[index] = result.mathNodes;
        exactResultExprs[index] = result.expr;
      } else {
        exactResultNodes[index] = null;
        exactResultExprs[index] = null;
      }
    } catch (e) {
      exactResultNodes[index] = null;
      exactResultExprs[index] = null;
    }

    // Notify that exact result changed
    final notifier = exactResultVersionNotifiers[index];
    if (notifier != null) {
      notifier.value = notifier.value + 1;
    }
  }

  Container _buildExpressionDisplay(int index, AppColors colors) {
    final mathEditorController = mathEditorControllers[index];
    final mathEditorKey = mathEditorKeys[index];
    final scrollController = scrollControllers[index];
    final bool isFocused = (activeIndex == index);
    final bool shouldAddKeys = index == activeIndex;

    return Container(
      decoration: BoxDecoration(
        color: colors.containerBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 7,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          // Expression input area
          Container(
            key: shouldAddKeys ? _expressionKey : null,
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            child: AnimatedOpacity(
              curve: Curves.easeIn,
              duration: const Duration(milliseconds: 500),
              opacity: isVisible ? 1.0 : 0.0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Center(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: MathEditorInline(
                        key: mathEditorKey,
                        controller: mathEditorController!,
                        showCursor: isFocused,
                        minWidth: constraints.maxWidth,
                        onFocus: () {
                          if (activeIndex != index) {
                            setState(() {
                              activeIndex = index;
                            });
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Result area with PageView - use StatefulBuilder to isolate rebuilds
          _ResultPageViewWidget(
            key: ValueKey('result_pageview_${index}_$_globalClearId'),
            index: index,
            colors: colors,
            shouldAddKeys: shouldAddKeys,
            isVisible: isVisible,
            exactResultNodes: exactResultNodes,
            currentResultPage: currentResultPage,
            currentResultPageNotifiers: currentResultPageNotifiers,
            resultPageProgressNotifiers: resultPageProgressNotifiers,
            exactResultVersionNotifiers: exactResultVersionNotifiers,
            resultPageControllers: resultPageControllers,
            textDisplayControllers: textDisplayControllers,
            ansIndexKey: _ansIndexKey,
            resultKey: _resultKey,
            calculateDecimalResultHeight: _calculateDecimalResultHeight,
            calculateExactResultHeight: _calculateExactResultHeight,
          ),
        ],
      ),
    );
  }

  double _calculateDecimalResultHeight(int index) {
    final resController = textDisplayControllers[index];
    String text = resController?.text ?? '';

    if (text.isEmpty) return 80.0;

    // Use the same measurement logic as Exact, but handle newlines properly.
    double measuredHeight = MathResultDisplay.calculateTextHeight(
      text,
      FONTSIZE,
    );

    double totalHeight = measuredHeight + 16 + 10;
    return totalHeight.clamp(80.0, 300.0);
  }

  double _calculateExactResultHeight(int index) {
    final exactNodes = exactResultNodes[index];

    if (exactNodes == null || exactNodes.isEmpty) {
      return 80.0;
    }

    // Use the precise measurement from the display widget logic
    double measuredHeight = MathResultDisplay.calculateTotalHeight(
      exactNodes,
      FONTSIZE,
    );

    // Add identical padding and clamping as Decimal
    double totalHeight = measuredHeight + 16 + 10;
    return totalHeight.clamp(80.0, 300.0);
  }

  int _estimateNodesHeight(List<MathNode> nodes) {
    int maxDepth = 0;
    for (var node in nodes) {
      int depth = _estimateNodeDepth(node);
      if (depth > maxDepth) maxDepth = depth;
    }
    return maxDepth;
  }

  int _estimateNodeDepth(MathNode node) {
    if (node is FractionNode) {
      int numDepth = _estimateNodesHeight(node.numerator);
      int denDepth = _estimateNodesHeight(node.denominator);
      return 1 + (numDepth > denDepth ? numDepth : denDepth);
    } else if (node is RootNode) {
      return 1 + _estimateNodesHeight(node.radicand);
    } else if (node is TrigNode) {
      return _estimateNodesHeight(
        node.argument,
      ); // Sin(x) doesn't add much height unless arg is complex
    } else if (node is ParenthesisNode) {
      return _estimateNodesHeight(node.content);
    } else if (node is ExponentNode) {
      // Exponents add a bit of height but less than a full fraction level
      return 1 + _estimateNodesHeight(node.power);
    } else if (node is LogNode) {
      int argDepth = _estimateNodesHeight(node.argument);
      int baseDepth = _estimateNodesHeight(node.base);
      return 1 + (argDepth > baseDepth ? argDepth : baseDepth);
    }
    return 0;
  }

  @override
  void dispose() {
    _deleteTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _saveCells();

    _walkthroughService.removeListener(_onWalkthroughChanged);
    _walkthroughService.dispose();

    for (MathEditorController controller in mathEditorControllers.values) {
      controller.dispose();
    }

    for (TextEditingController resController in textDisplayControllers.values) {
      resController.dispose();
    }

    for (FocusNode focusNode in focusNodes.values) {
      focusNode.dispose();
    }

    for (ScrollController scrollController in scrollControllers.values) {
      scrollController.dispose();
    }

    for (PageController pageController in resultPageControllers.values) {
      pageController.dispose();
    }

    for (ValueNotifier<double> notifier in resultPageProgressNotifiers.values) {
      notifier.dispose();
    }

    for (ValueNotifier<int> notifier in currentResultPageNotifiers.values) {
      notifier.dispose();
    }

    for (ValueNotifier<int> notifier in exactResultVersionNotifiers.values) {
      // ADD THIS
      notifier.dispose();
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _saveCells();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_listenerAdded) {
      _settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      _settingsProvider?.addListener(_onSettingsChanged);
      _listenerAdded = true;
    }
  }

  Future<void> _loadCells() async {
    List<CellData> savedCells = await CellPersistence.loadCells();
    int savedIndex = await CellPersistence.loadActiveIndex();

    if (savedCells.isEmpty) {
      _createControllers(0);
      count = 1;
      activeIndex = 0;
    } else {
      for (int i = 0; i < savedCells.length; i++) {
        _createControllers(i);

        List<MathNode> nodes = MathExpressionSerializer.deserializeFromJson(
          savedCells[i].expressionJson,
        );
        mathEditorControllers[i]?.setExpression(nodes);

        textDisplayControllers[i]?.text = savedCells[i].answer;
      }

      count = savedCells.length;
      activeIndex = savedIndex.clamp(0, count - 1);
    }

    setState(() => _isLoading = false);

    // Update exact results for all cells after loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (int i = 0; i < count; i++) {
        _updateExactResult(i);
      }
    });
  }

  Future<void> _saveCells() async {
    List<int> sortedKeys = mathEditorControllers.keys.toList()..sort();

    List<List<MathNode>> expressions = [];
    List<String> answers = [];

    for (int key in sortedKeys) {
      MathEditorController? mathController = mathEditorControllers[key];
      TextEditingController? textController = textDisplayControllers[key];

      if (mathController != null) {
        expressions.add(mathController.expression);
        answers.add(textController?.text ?? '');
      }
    }

    await CellPersistence.saveCells(expressions, answers);
    await CellPersistence.saveActiveIndex(activeIndex);
  }

  void _onSettingsChanged() {
    updateMathEditor();

    for (final controller in mathEditorControllers.values) {
      controller.refreshDisplay();
    }
  }

  void _cascadeUpdates(int changedIndex) {
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      mathEditorControllers[changedIndex]?.updateAnswer(
        textDisplayControllers[changedIndex],
      );

      // NEW: Update exact result
      _updateExactResult(changedIndex);

      List<int> keys = mathEditorControllers.keys.toList()..sort();

      for (int key in keys) {
        if (key > changedIndex) {
          String expr = mathEditorControllers[key]?.expr ?? '';

          if (expr.contains('ans$changedIndex') || expr.contains('ans')) {
            Map<int, String> ansValues = _getAnsValues();
            mathEditorControllers[key]?.onCalculate(ansValues: ansValues);
            mathEditorControllers[key]?.updateAnswer(
              textDisplayControllers[key],
            );
            // NEW: Update exact result for cascaded cells
            _updateExactResult(key);
          }
        }
      }
    } finally {
      _isUpdating = false;
    }

    setState(() {});
  }

  void focusManager(int index) {
    focusNodes[index]?.requestFocus();
    activeIndex = index;
  }

  void _clearAllSelectionOverlays() {
    for (final key in mathEditorKeys.values) {
      key.currentState?.clearOverlay();
    }
  }

  /// Auto-scroll to the end when expression fills the screen
  /// Only scrolls when cursor is at the end of the expression (not when editing in middle)
  void _autoScrollToEnd(int index) {
    final scrollController = scrollControllers[index];
    final mathController = mathEditorControllers[index];
    if (scrollController == null || !scrollController.hasClients) return;
    if (mathController == null) return;

    // Only auto-scroll if cursor is at the end of the root expression
    final cursor = mathController.cursor;
    final expression = mathController.expression;

    // Check if cursor is at the end: at root level, at last node, at end of text
    bool isAtEnd =
        cursor.parentId == null && cursor.index == expression.length - 1;

    if (isAtEnd && expression.isNotEmpty) {
      final lastNode = expression.last;
      if (lastNode is LiteralNode) {
        isAtEnd = cursor.subIndex >= lastNode.text.length;
      }
    }

    if (!isAtEnd) return; // Don't scroll if not at end

    // Schedule scroll after layout is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        // With reverse: true, position 0 is the RIGHT end (where cursor is)
        if (scrollController.offset != 0) {
          scrollController.jumpTo(0);
        }
      }
    });
  }

  void _addDisplay() {
    int newIndex = count;
    _createControllers(newIndex);
    setState(() {
      count += 1;
      activeIndex = newIndex;
    });
  }

  void _removeDisplay(int indexToRemove) {
    if (count <= 1) return;

    mathEditorControllers[indexToRemove]?.dispose();
    mathEditorControllers.remove(indexToRemove);
    textDisplayControllers[indexToRemove]?.dispose();
    textDisplayControllers.remove(indexToRemove);
    focusNodes[indexToRemove]?.dispose();
    focusNodes.remove(indexToRemove);
    scrollControllers[indexToRemove]?.dispose();
    scrollControllers.remove(indexToRemove);
    mathEditorKeys.remove(indexToRemove);

    resultPageControllers[indexToRemove]?.dispose();
    resultPageControllers.remove(indexToRemove);
    exactResultNodes.remove(indexToRemove);
    currentResultPage.remove(indexToRemove);
    currentResultPageNotifiers[indexToRemove]?.dispose();
    currentResultPageNotifiers.remove(indexToRemove);
    resultPageProgressNotifiers[indexToRemove]?.dispose();
    resultPageProgressNotifiers.remove(indexToRemove);
    exactResultVersionNotifiers[indexToRemove]?.dispose(); // ADD THIS
    exactResultVersionNotifiers.remove(indexToRemove); // ADD THIS

    int newActiveIndex;
    if (activeIndex == indexToRemove) {
      newActiveIndex = indexToRemove > 0 ? indexToRemove - 1 : 0;
    } else if (activeIndex > indexToRemove) {
      newActiveIndex = activeIndex - 1;
    } else {
      newActiveIndex = activeIndex;
    }

    _reindexControllers();

    setState(() {
      count -= 1;
      activeIndex = newActiveIndex;
    });
  }

  void _clearAllDisplays() {
    _saveAppStateForUndo();

    for (var controller in mathEditorControllers.values) {
      controller.dispose();
    }
    for (var controller in textDisplayControllers.values) {
      controller.dispose();
    }
    for (var focusNode in focusNodes.values) {
      focusNode.dispose();
    }
    for (var scrollController in scrollControllers.values) {
      scrollController.dispose();
    }
    // We don't dispose resultPageControllers here because they are owned by the widgets.
    // When the widgets are removed/replaced, they will dispose their own controllers.

    for (var notifier in resultPageProgressNotifiers.values) {
      notifier.dispose();
    }
    for (var notifier in currentResultPageNotifiers.values) {
      notifier.dispose();
    }
    for (var notifier in exactResultVersionNotifiers.values) {
      notifier.dispose();
    }

    mathEditorControllers.clear();
    textDisplayControllers.clear();
    focusNodes.clear();
    mathEditorKeys.clear();
    scrollControllers.clear();
    resultPageControllers.clear();
    exactResultNodes.clear();
    exactResultExprs.clear();
    currentResultPage.clear();
    currentResultPageNotifiers.clear();
    resultPageProgressNotifiers.clear();
    exactResultVersionNotifiers.clear();

    _globalClearId = DateTime.now().toIso8601String();

    _createControllers(0);

    setState(() {
      count = 1;
      activeIndex = 0;
    });
  }

  void _reindexControllers() {
    List<int> oldKeys = mathEditorControllers.keys.toList()..sort();

    Map<int, MathEditorController> newMathControllers = {};
    Map<int, TextEditingController> newDisplayControllers = {};
    Map<int, FocusNode> newFocusNodes = {};
    Map<int, ScrollController> newScrollControllers = {};
    Map<int, GlobalKey<MathEditorInlineState>> newMathEditorKeys = {};
    Map<int, PageController> newResultPageControllers = {};
    Map<int, List<MathNode>?> newExactResultNodes = {};
    Map<int, Expr?> newExactResultExprs = {};
    Map<int, int> newCurrentResultPage = {};
    Map<int, ValueNotifier<int>> newCurrentResultPageNotifiers = {};
    Map<int, ValueNotifier<double>> newResultPageProgressNotifiers = {};
    Map<int, ValueNotifier<int>> newExactResultVersionNotifiers =
        {}; // ADD THIS

    for (int newIndex = 0; newIndex < oldKeys.length; newIndex++) {
      int oldKey = oldKeys[newIndex];
      newMathControllers[newIndex] = mathEditorControllers[oldKey]!;
      newDisplayControllers[newIndex] = textDisplayControllers[oldKey]!;
      newFocusNodes[newIndex] = focusNodes[oldKey]!;
      newScrollControllers[newIndex] = scrollControllers[oldKey]!;
      newMathEditorKeys[newIndex] = mathEditorKeys[oldKey]!;
      newResultPageControllers[newIndex] = resultPageControllers[oldKey]!;
      newExactResultNodes[newIndex] = exactResultNodes[oldKey];
      newExactResultExprs[newIndex] = exactResultExprs[oldKey];
      newCurrentResultPage[newIndex] = currentResultPage[oldKey] ?? 0;
      newCurrentResultPageNotifiers[newIndex] =
          currentResultPageNotifiers[oldKey]!;
      newResultPageProgressNotifiers[newIndex] =
          resultPageProgressNotifiers[oldKey]!;
      newExactResultVersionNotifiers[newIndex] =
          exactResultVersionNotifiers[oldKey]!; // ADD THIS
    }

    mathEditorControllers = newMathControllers;
    textDisplayControllers = newDisplayControllers;
    focusNodes = newFocusNodes;
    scrollControllers = newScrollControllers;
    mathEditorKeys = newMathEditorKeys;
    resultPageControllers = newResultPageControllers;
    exactResultNodes = newExactResultNodes;
    exactResultExprs = newExactResultExprs;
    currentResultPage = newCurrentResultPage;
    currentResultPageNotifiers = newCurrentResultPageNotifiers;
    resultPageProgressNotifiers = newResultPageProgressNotifiers;
    exactResultVersionNotifiers = newExactResultVersionNotifiers; // ADD THIS
  }

  void _restoreAppState(AppState state) {
    for (var controller in mathEditorControllers.values) {
      controller.dispose();
    }
    for (var controller in textDisplayControllers.values) {
      controller.dispose();
    }
    for (var focusNode in focusNodes.values) {
      focusNode.dispose();
    }
    for (var scrollController in scrollControllers.values) {
      scrollController.dispose();
    }
    // We don't dispose resultPageControllers here because they are owned by the widgets.

    for (var notifier in resultPageProgressNotifiers.values) {
      notifier.dispose();
    }
    for (var notifier in currentResultPageNotifiers.values) {
      notifier.dispose();
    }
    for (var notifier in exactResultVersionNotifiers.values) {
      notifier.dispose();
    }

    mathEditorControllers.clear();
    textDisplayControllers.clear();
    focusNodes.clear();
    mathEditorKeys.clear();
    scrollControllers.clear();
    resultPageControllers.clear();
    exactResultNodes.clear();
    exactResultExprs.clear();
    currentResultPage.clear();
    currentResultPageNotifiers.clear();
    resultPageProgressNotifiers.clear();
    exactResultVersionNotifiers.clear();

    _globalClearId = DateTime.now().toIso8601String();

    for (int i = 0; i < state.expressions.length; i++) {
      _createControllers(i);
      mathEditorControllers[i]?.setExpression(
        MathClipboard.deepCopyNodes(state.expressions[i]),
      );
      textDisplayControllers[i]?.text = state.answers[i];
    }

    if (state.expressions.isEmpty) {
      _createControllers(0);
    }

    setState(() {
      count = state.expressions.isEmpty ? 1 : state.expressions.length;
      activeIndex = state.activeIndex.clamp(0, count - 1);
    });

    updateMathEditor();
  }

  /// Save current app state before destructive operations
  void _saveAppStateForUndo() {
    _appUndoStack.add(
      AppState.capture(
        mathEditorControllers,
        textDisplayControllers,
        activeIndex,
      ),
    );

    // Limit stack size
    if (_appUndoStack.length > _maxAppHistorySize) {
      _appUndoStack.removeAt(0);
    }

    // Clear redo stack when new action is performed
    _appRedoStack.clear();
  }

  /// Check if app-level undo is available
  bool get canUndoAppState => _appUndoStack.isNotEmpty;

  /// Check if app-level redo is available
  bool get canRedoAppState => _appRedoStack.isNotEmpty;

  /// Undo app-level action (like Clear All)
  void _undoAppState() {
    if (!canUndoAppState) return;

    // Save current state to redo stack
    _appRedoStack.add(
      AppState.capture(
        mathEditorControllers,
        textDisplayControllers,
        activeIndex,
      ),
    );

    // Get previous state
    AppState previousState = _appUndoStack.removeLast();

    // Restore the state
    _restoreAppState(previousState);
  }

  /// Redo app-level action
  void _redoAppState() {
    if (!canRedoAppState) return;

    // Save current state to undo stack
    _appUndoStack.add(
      AppState.capture(
        mathEditorControllers,
        textDisplayControllers,
        activeIndex,
      ),
    );

    // Get redo state
    AppState redoState = _appRedoStack.removeLast();

    // Restore the state
    _restoreAppState(redoState);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final colors = AppColors.of(context);
      return Scaffold(
        backgroundColor: colors.displayBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final colors = AppColors.of(context);

    return WalkthroughOverlay(
      walkthroughService: _walkthroughService,
      targetKeys: _walkthroughTargets,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 5,
          backgroundColor: colors.displayBackground,
        ),
        backgroundColor: colors.displayBackground,
        body: Stack(
          children: [
            // SVG Background
            Positioned.fill(
              child: SvgPicture.asset(
                colors.backgroundImage,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            SafeArea(
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: ListView.builder(
                      reverse: true,
                      padding: EdgeInsets.zero,
                      itemCount: count,
                      itemBuilder: (context, index) {
                        List<int> keys =
                            mathEditorControllers.keys.toList()..sort();
                        int reversedIndex = keys.length - 1 - index;

                        if (reversedIndex >= 0 && reversedIndex < keys.length) {
                          return Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: _buildExpressionDisplay(
                              keys[reversedIndex],
                              colors,
                            ),
                          );
                        }
                        return SizedBox.shrink();
                      },
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final mediaQuery = MediaQuery.of(context);
                      double screenWidth = mediaQuery.size.width;
                      bool isLandscape =
                          mediaQuery.orientation == Orientation.landscape;

                      return CalculatorKeypad(
                        screenWidth: screenWidth,
                        isLandscape: isLandscape,
                        colors: colors,
                        activeIndex: activeIndex,
                        mathEditorControllers: mathEditorControllers,
                        textDisplayControllers: textDisplayControllers,
                        settingsProvider: _settingsProvider!,
                        onUpdateMathEditor: updateMathEditor,
                        onAddDisplay: _addDisplay,
                        onRemoveDisplay: _removeDisplay,
                        onClearAllDisplays: _clearAllDisplays,
                        countVariablesInExpressions:
                            countVariablesInExpressions,
                        onSetState: () => setState(() {}),
                        onClearSelectionOverlay: _clearAllSelectionOverlays,
                        canUndoAppState: canUndoAppState,
                        canRedoAppState: canRedoAppState,
                        onUndoAppState: _undoAppState,
                        onRedoAppState: _redoAppState,
                        // Walkthrough
                        walkthroughService: _walkthroughService,
                        basicKeypadKey: _basicKeypadKey,
                        basicKeypadHandleKey: _basicKeypadHandleKey,
                        scientificKeypadKey: _scientificKeypadKey,
                        numberKeypadKey: _numberKeypadKey,
                        extrasKeypadKey: _extrasKeypadKey,
                        commandButtonKey: _commandButtonKey,
                        mainKeypadAreaKey: _mainKeypadAreaKey,
                        settingsButtonKey: _settingsButtonKey,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<int, String> _getAnsValues() {
    Map<int, String> ansValues = {};

    List<int> keys = mathEditorControllers.keys.toList()..sort();
    for (int key in keys) {
      String? result = mathEditorControllers[key]?.result;

      if (result != null && result.isNotEmpty) {
        String parseableResult = result.replaceAll('\u1D07', 'E');

        if (double.tryParse(parseableResult) != null) {
          ansValues[key] = parseableResult;
        } else {
          List<String> lines = parseableResult.split('\n');
          if (lines.isNotEmpty) {
            RegExp numRegex = RegExp(r'=\s*(-?\d+\.?\d*(?:[eE][+-]?\d+)?)');
            Match? numMatch = numRegex.firstMatch(lines.first);
            if (numMatch != null) {
              ansValues[key] = numMatch.group(1)!;
            }
          }
        }
      }
    }

    return ansValues;
  }

  void updateMathEditor() {
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      List<int> keys = mathEditorControllers.keys.toList()..sort();

      for (int key in keys) {
        Map<int, String> ansValues = _getAnsValues();
        mathEditorControllers[key]?.onCalculate(ansValues: ansValues);
        mathEditorControllers[key]?.updateAnswer(textDisplayControllers[key]);

        // NEW: Update exact result
        _updateExactResult(key);
      }
    } finally {
      _isUpdating = false;
    }

    setState(() {});
    _saveCells();
  }

  bool isOperator(String x) {
    if (x == '/' || x == 'x' || x == '-' || x == '+' || x == '=') {
      return true;
    }
    return false;
  }

  int countVariablesInExpressions(String expressions) {
    // First, remove all known function names and keywords to avoid false matches
    String cleaned = expressions;

    // List of function names and keywords to remove (order matters - longer first)
    const functionsToRemove = [
      'sqrt',
      'sin',
      'cos',
      'tan',
      'asin',
      'acos',
      'atan',
      'log',
      'ln',
      'abs',
      'perm',
      'comb',
      'ans',
      'exp',
    ];

    for (String func in functionsToRemove) {
      cleaned = cleaned.replaceAll(func, ' ');
    }

    // Also remove 'e' and 'E' that are part of scientific notation (e.g., 1e5, 2E-3)
    // Pattern: digit followed by e/E followed by optional +/- and digits
    cleaned = cleaned.replaceAll(RegExp(r'(\d)[eE]([+-]?\d)'), r'$1 $2');

    // Now find single-letter variables (excluding common constants like 'e' for Euler's number)
    // Match single letters that are actual variables: x, y, z, a, b, c, etc.
    // Exclude: e (Euler's number), i (imaginary unit if you support it)
    RegExp variableRegex = RegExp(
      r'(?<![a-zA-Z])([a-df-hj-zA-DF-HJ-Z])(?![a-zA-Z])',
    );

    Set<String> variables = {};
    for (var line in cleaned.split('\n')) {
      for (var match in variableRegex.allMatches(line)) {
        String varName = match.group(1)!;
        // Additional filter: skip if it's a standalone 'e' (Euler's number)
        // But allow 'e' if it appears to be a variable in context
        variables.add(varName);
      }
    }

    return variables.length;
  }
}

/// Isolated widget for the result PageView to prevent unnecessary rebuilds
class _ResultPageViewWidget extends StatefulWidget {
  final int index;
  final AppColors colors;
  final bool shouldAddKeys;
  final bool isVisible;
  final Map<int, List<MathNode>?> exactResultNodes;
  final Map<int, int> currentResultPage;
  final Map<int, ValueNotifier<int>> currentResultPageNotifiers;
  final Map<int, ValueNotifier<double>> resultPageProgressNotifiers;
  final Map<int, ValueNotifier<int>> exactResultVersionNotifiers;
  final Map<int, PageController> resultPageControllers;
  final Map<int, TextEditingController?> textDisplayControllers;
  final GlobalKey? ansIndexKey;
  final GlobalKey? resultKey;
  final double Function(int) calculateDecimalResultHeight;
  final double Function(int) calculateExactResultHeight;

  const _ResultPageViewWidget({
    super.key,
    required this.index,
    required this.colors,
    required this.shouldAddKeys,
    required this.isVisible,
    required this.exactResultNodes,
    required this.currentResultPage,
    required this.currentResultPageNotifiers,
    required this.resultPageProgressNotifiers,
    required this.exactResultVersionNotifiers,
    required this.resultPageControllers,
    required this.textDisplayControllers,
    required this.ansIndexKey,
    required this.resultKey,
    required this.calculateDecimalResultHeight,
    required this.calculateExactResultHeight,
  });

  @override
  State<_ResultPageViewWidget> createState() => _ResultPageViewWidgetState();
}

class _ResultPageViewWidgetState extends State<_ResultPageViewWidget> {
  late PageController _pageController;
  int _currentPage = 0;
  double _lastDecimalHeight = 70.0;
  double _lastExactHeight = 70.0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.currentResultPage[widget.index] ?? 0;
    _pageController = PageController(initialPage: _currentPage);

    // Store the controller in the parent's map
    widget.resultPageControllers[widget.index] = _pageController;

    // Add scroll listener
    _pageController.addListener(_onPageScroll);

    // Initialize heights
    _lastDecimalHeight = widget.calculateDecimalResultHeight(widget.index);
    _lastExactHeight = widget.calculateExactResultHeight(widget.index);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    if (!_pageController.hasClients) return;

    double? page = _pageController.page;
    if (page != null) {
      widget.resultPageProgressNotifiers[widget.index]?.value = page.clamp(
        0.0,
        1.0,
      );
    }
  }

  void _onPageChanged(int page) {
    _currentPage = page;
    widget.currentResultPage[widget.index] = page;
    widget.currentResultPageNotifiers[widget.index]?.value = page;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable:
          widget.exactResultVersionNotifiers[widget.index] ?? ValueNotifier(0),
      builder: (context, version, _) {
        // Calculate target heights
        double targetDecimalHeight = widget.calculateDecimalResultHeight(
          widget.index,
        );
        double targetExactHeight = widget.calculateExactResultHeight(
          widget.index,
        );

        return _AnimatedHeightContainer(
          targetDecimalHeight: targetDecimalHeight,
          targetExactHeight: targetExactHeight,
          lastDecimalHeight: _lastDecimalHeight,
          lastExactHeight: _lastExactHeight,
          progressNotifier:
              widget.resultPageProgressNotifiers[widget.index] ??
              ValueNotifier(0.0),
          onHeightsAnimated: (decimal, exact) {
            _lastDecimalHeight = decimal;
            _lastExactHeight = exact;
          },
          child: PageView(
            controller: _pageController,
            physics: const ClampingScrollPhysics(),
            onPageChanged: _onPageChanged,
            children: [_buildDecimalResultPage(), _buildExactResultPage()],
          ),
        );
      },
    );
  }

  Widget _buildDecimalResultPage() {
    final resController = widget.textDisplayControllers[widget.index];

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        _buildResultDivider(0, "DECIMAL"),
        Expanded(
          child: Container(
            key: widget.shouldAddKeys ? widget.resultKey : null,
            color: widget.colors.containerBackground,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child: AnimatedOpacity(
              curve: Curves.easeIn,
              duration: const Duration(milliseconds: 500),
              opacity: widget.isVisible ? 1.0 : 0.0,
              child: SingleChildScrollView(
                child: TextField(
                  controller: resController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textAlign: TextAlign.center,
                  autofocus: false,
                  readOnly: true,
                  showCursor: false,
                  style: TextStyle(
                    fontSize: FONTSIZE,
                    color: widget.colors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================
  // In _ResultPageViewWidgetState, REPLACE _buildExactResultPage():
  // ============================================

  Widget _buildExactResultPage() {
    final exactNodes = widget.exactResultNodes[widget.index];
    final bool hasResult = exactNodes != null && exactNodes.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        _buildResultDivider(1, "EXACT"),
        Expanded(
          child: Container(
            color: widget.colors.containerBackground,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            alignment: Alignment.center,
            child: AnimatedOpacity(
              curve: Curves.easeIn,
              duration: const Duration(milliseconds: 500),
              opacity: widget.isVisible ? 1.0 : 0.0,
              child:
                  hasResult
                      ? Builder(
                        builder: (context) {
                          final scope = _AnimatedContentScope.of(context);
                          final animValue = scope?.animationValue ?? 1.0;
                          final isAnimating = scope?.isAnimating ?? false;

                          return AnimatedResultContent(
                            animationValue: animValue,
                            isAnimating: isAnimating,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: MathResultDisplay(
                                  nodes: exactNodes,
                                  fontSize: FONTSIZE,
                                  textColor: widget.colors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        },
                      )
                      : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultDivider(int pageIndex, String label) {
    return Row(
      children: <Widget>[
        Container(
          key:
              (widget.shouldAddKeys && pageIndex == 0)
                  ? widget.ansIndexKey
                  : null,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "${widget.index}",
            style: TextStyle(fontSize: 10, color: widget.colors.textTertiary),
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 0.0, right: 10.0),
            child: Divider(color: widget.colors.divider, height: 6),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    _currentPage == 0
                        ? widget.colors.textSecondary
                        : widget.colors.textSecondary.withValues(alpha: 0.3),
              ),
            ),
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    _currentPage == 1
                        ? widget.colors.textSecondary
                        : widget.colors.textSecondary.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                color:
                    _currentPage == pageIndex
                        ? widget.colors.textSecondary
                        : widget.colors.textSecondary.withValues(alpha: 0.5),
                fontWeight:
                    _currentPage == pageIndex
                        ? FontWeight.bold
                        : FontWeight.normal,
              ),
            ),
          ],
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 10.0, right: 0.0),
            child: Divider(color: widget.colors.divider, height: 6),
          ),
        ),
      ],
    );
  }
}

/// A widget that animates height changes smoothly when content changes,
/// but follows PageView progress instantly during swiping.
class _AnimatedHeightContainer extends StatefulWidget {
  final double targetDecimalHeight;
  final double targetExactHeight;
  final double lastDecimalHeight;
  final double lastExactHeight;
  final ValueNotifier<double> progressNotifier;
  final void Function(double decimal, double exact) onHeightsAnimated;
  final Widget child;

  const _AnimatedHeightContainer({
    required this.targetDecimalHeight,
    required this.targetExactHeight,
    required this.lastDecimalHeight,
    required this.lastExactHeight,
    required this.progressNotifier,
    required this.onHeightsAnimated,
    required this.child,
  });

  @override
  State<_AnimatedHeightContainer> createState() =>
      _AnimatedHeightContainerState();
}

class _AnimatedHeightContainerState extends State<_AnimatedHeightContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _decimalHeightAnimation;
  late Animation<double> _exactHeightAnimation;
  late Animation<double> _contentAnimation; // For content fade/scale

  double _animatedDecimalHeight = 70.0;
  double _animatedExactHeight = 70.0;

  @override
  void initState() {
    super.initState();
    _animatedDecimalHeight = widget.lastDecimalHeight;
    _animatedExactHeight = widget.lastExactHeight;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _setupAnimations();

    _animationController.addListener(() {
      setState(() {
        _animatedDecimalHeight = _decimalHeightAnimation.value;
        _animatedExactHeight = _exactHeightAnimation.value;
      });
    });

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onHeightsAnimated(_animatedDecimalHeight, _animatedExactHeight);
      }
    });
  }

  void _setupAnimations() {
    _decimalHeightAnimation = Tween<double>(
      begin: _animatedDecimalHeight,
      end: widget.targetDecimalHeight,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _exactHeightAnimation = Tween<double>(
      begin: _animatedExactHeight,
      end: widget.targetExactHeight,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _contentAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _AnimatedHeightContainer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if heights actually changed (content change, not swipe)
    bool decimalHeightChanged =
        (widget.targetDecimalHeight - _animatedDecimalHeight).abs() > 0.5;
    bool exactHeightChanged =
        (widget.targetExactHeight - _animatedExactHeight).abs() > 0.5;

    if (decimalHeightChanged || exactHeightChanged) {
      _setupAnimations();
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Expose the content animation value
  double get contentAnimationValue =>
      _animationController.isAnimating ? _contentAnimation.value : 1.0;

  bool get isAnimating => _animationController.isAnimating;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.progressNotifier,
      builder: (context, progress, _) {
        // Use animated heights for interpolation during swipe
        double height =
            _animatedDecimalHeight +
            (_animatedExactHeight - _animatedDecimalHeight) * progress;

        return SizedBox(
          height: height,
          child: _AnimatedContentScope(
            animationValue: contentAnimationValue,
            isAnimating: isAnimating,
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// InheritedWidget to pass animation state down to children
class _AnimatedContentScope extends InheritedWidget {
  final double animationValue;
  final bool isAnimating;

  const _AnimatedContentScope({
    required this.animationValue,
    required this.isAnimating,
    required super.child,
  });

  static _AnimatedContentScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_AnimatedContentScope>();
  }

  @override
  bool updateShouldNotify(_AnimatedContentScope oldWidget) {
    return animationValue != oldWidget.animationValue ||
        isAnimating != oldWidget.isAnimating;
  }
}

/// Widget that animates content appearance in sync with height changes
class AnimatedResultContent extends StatelessWidget {
  final double animationValue;
  final bool isAnimating;
  final Widget child;

  const AnimatedResultContent({
    super.key,
    required this.animationValue,
    required this.isAnimating,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAnimating) {
      return child;
    }

    // Fade and subtle scale animation
    return Opacity(
      opacity: animationValue.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.95 + (0.05 * animationValue), // Scale from 0.95 to 1.0
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
