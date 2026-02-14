import 'package:flutter/material.dart';
import 'package:klator/utils/constants.dart';
import 'package:klator/utils/texture_generator.dart';
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
import 'utils/compute_service.dart';
import 'math_renderer/math_editor_controller.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'math_engine/math_engine_exact.dart';
import 'math_renderer/math_result_display.dart';
import 'math_renderer/decimal_result_nodes.dart';
import 'widgets/textured_container.dart';

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
  static const Duration _cellCreateTransitionDuration = Duration(
    milliseconds: 300,
  );
  static const Duration _cellDeleteTransitionDuration = Duration(
    milliseconds: 250,
  );
  int count = 0;
  Map<int, GlobalKey<MathEditorInlineState>> mathEditorKeys = {};
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
  bool isVisible = true;
  bool isTypingExponent = false;
  bool _isUpdating = false;
  String _globalClearId = DateTime.now().toIso8601String();
  bool _isLoading = true;
  List<String> answers = [];
  final bool _isKeypadVisible = true;
  final Map<int, bool> _plotExpanded = {};
  final Map<int, bool> _cellVisibilityByToken = {};
  final Set<int> _cellsPendingEntry = <int>{};
  final Set<int> _cellsPendingRemoval = <int>{};

  SettingsProvider? _settingsProvider;
  bool _listenerAdded = false;
  Timer? _deleteTimer;

  // Compute service for background isolate computation
  late ComputeService _computeService;

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

    // Initialize compute service
    _computeService = ComputeService(
      debounceDuration: const Duration(milliseconds: 150),
      onResult: _onComputeResult,
    );

    // Initialize walkthrough service
    _walkthroughService = WalkthroughService();
    _walkthroughService.addListener(_onWalkthroughChanged);

    WidgetsBinding.instance.addObserver(this);
    _loadCells();

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

  int? _findControllerIndex(MathEditorController controller) {
    for (final entry in mathEditorControllers.entries) {
      if (identical(entry.value, controller)) {
        return entry.key;
      }
    }
    return null;
  }

  int _cellToken(MathEditorController controller) {
    return identityHashCode(controller);
  }

  void _cancelCellAnimationState() {
    _cellVisibilityByToken.clear();
    _cellsPendingEntry.clear();
    _cellsPendingRemoval.clear();
  }

  void _bindControllerCallbacks(MathEditorController controller) {
    controller.onResultChanged = () {
      final index = _findControllerIndex(controller);
      if (index != null) {
        _requestComputation(index);
      }
    };

    controller.addListener(() {
      final index = _findControllerIndex(controller);
      if (index != null) {
        _autoScrollToEnd(index);
      }
    });
  }

  void _createControllers(int index, {bool animateEntry = false}) {
    final controller = MathEditorController();
    mathEditorControllers[index] = controller;
    _bindControllerCallbacks(controller);
    final int token = _cellToken(controller);
    _cellVisibilityByToken[token] = true;
    if (animateEntry) {
      _cellsPendingEntry.add(token);
    } else {
      _cellsPendingEntry.remove(token);
    }

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

  /// Request computation for a cell via the background ComputeService.
  /// This debounces the request and runs it in a background isolate.
  void _requestComputation(int index) {
    final controller = mathEditorControllers[index];
    if (controller == null) return;

    // Collect ans expressions for exact engine
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

    // Collect ans values for decimal engine
    Map<int, String> ansValues = _getAnsValues();

    _computeService.computeForCell(
      cellIndex: index,
      expression: controller.expression,
      ansValues: ansValues,
      ansExpressions: ansExprs,
    );
  }

  /// Callback invoked when a background computation completes.
  void _onComputeResult(CellComputeResult result) {
    if (!mounted) return;

    final index = result.cellIndex;
    final controller = mathEditorControllers[index];
    if (controller == null) return;

    final oldDecimal = controller.result;
    final oldExactExpr = exactResultExprs[index];

    final newDecimal = result.decimalResult;
    final newExactExpr = result.exactExpr;

    // Check if result effectively changed
    bool decimalChanged = oldDecimal != newDecimal;
    bool exactChanged = false;

    if (oldExactExpr == null && newExactExpr != null) {
      exactChanged = true;
    } else if (oldExactExpr != null && newExactExpr == null) {
      exactChanged = true;
    } else if (oldExactExpr != null && newExactExpr != null) {
      exactChanged = !oldExactExpr.structurallyEquals(newExactExpr);
    }

    bool hasChanged = decimalChanged || exactChanged;
    bool isActiveCell = index == activeIndex;

    // Always update if active cell (user typing) OR if result changed
    if (isActiveCell || hasChanged) {
      // Update decimal result
      controller.result = newDecimal;
      controller.updateAnswer(textDisplayControllers[index]);

      // Update exact result
      if (result.exactNodes != null && result.exactNodes!.isNotEmpty) {
        exactResultNodes[index] = result.exactNodes;
        exactResultExprs[index] = result.exactExpr;
      } else {
        exactResultNodes[index] = null;
        exactResultExprs[index] = null;
      }

      // Notify that exact result changed (triggers animation)
      final notifier = exactResultVersionNotifiers[index];
      if (notifier != null) {
        notifier.value = notifier.value + 1;
      }

      // Only cascade if the result actually changed
      if (hasChanged) {
        _cascadeToDependents(index);
      }

      setState(() {});
    }
  }

  Widget _buildExpressionDisplay(
    int index,
    AppColors colors, {
    double? maxPlotHeight,
    bool forcePlotExpanded = false,
  }) {
    final mathEditorController = mathEditorControllers[index];
    final mathEditorKey = mathEditorKeys[index];
    final scrollController = scrollControllers[index];
    final bool isFocused = (activeIndex == index);
    final bool shouldAddKeys = index == activeIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TexturedContainer(
              baseColor: colors.containerBackground,
              decoration: BoxDecoration(
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
                  // Expression input area - transparent background
                  SizedBox(
                    key: shouldAddKeys ? _expressionKey : null,
                    width: double.infinity,
                    // No color - let texture show through
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: AnimatedOpacity(
                        curve: Curves.easeIn,
                        duration: const Duration(milliseconds: 200),
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
                  ),

                  // Result area - transparent background
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
                    useTransparentBackground: true, // ADD THIS
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

Widget _buildAnimatedCellList(AppColors colors) {
  final List<int> keys = mathEditorControllers.keys.toList()..sort();
  final Map<int, int> tokenToBuilderIndex = <int, int>{};
  for (int i = 0; i < keys.length; i++) {
    final int reversedIndex = keys.length - 1 - i;
    final int cellIndex = keys[reversedIndex];
    final controller = mathEditorControllers[cellIndex];
    if (controller != null) {
      tokenToBuilderIndex[_cellToken(controller)] = i;
    }
  }

  return ListView.builder(
    key: ValueKey('cell_list_$_globalClearId'),
    physics: const ClampingScrollPhysics(),
    reverse: true,
    padding: EdgeInsets.zero,
    itemCount: keys.length,
    findChildIndexCallback: (Key key) {
      if (key is ValueKey<int>) {
        return tokenToBuilderIndex[key.value];
      }
      return null;
    },
    itemBuilder: (context, index) {
      final int reversedIndex = keys.length - 1 - index;
      final int cellIndex = keys[reversedIndex];
      final controller = mathEditorControllers[cellIndex];
      if (controller == null) return const SizedBox.shrink();

      final int token = _cellToken(controller);
      final bool isVisible = _cellVisibilityByToken[token] ?? true;
      final bool isPendingEntry = _cellsPendingEntry.contains(token);
      final bool isPendingRemoval = _cellsPendingRemoval.contains(token);

      final Widget cellBody = Padding(
        padding: const EdgeInsets.only(top: 5),
        child: _buildExpressionDisplay(cellIndex, colors),
      );

      // DELETION ANIMATION
      if (isPendingRemoval) {
        return _AnimatedCellWrapper(
          key: ValueKey<int>(token),
          token: token,
          isEntry: false,
          isVisible: isVisible,
          duration: _cellDeleteTransitionDuration,
          onAnimationComplete: () {
            // Remove the cell after animation completes
            if (mounted) {
              final currentIndex = _findControllerIndex(controller);
              if (currentIndex != null) {
                _removeDisplayNow(currentIndex, token);
              } else {
                // Controller already removed, just clean up state
                setState(() {
                  _cellsPendingRemoval.remove(token);
                  _cellsPendingEntry.remove(token);
                  _cellVisibilityByToken.remove(token);
                });
              }
            }
          },
          child: cellBody,
        );
      }

      // CREATION ANIMATION
      if (isPendingEntry) {
        return _AnimatedCellWrapper(
          key: ValueKey<int>(token),
          token: token,
          isEntry: true,
          isVisible: true,
          duration: _cellCreateTransitionDuration,
          onAnimationComplete: () {
            if (mounted) {
              setState(() {
                _cellsPendingEntry.remove(token);
              });
            }
          },
          child: cellBody,
        );
      }

      // STATIC CELL
      return KeyedSubtree(key: ValueKey<int>(token), child: cellBody);
    },
  );
}

  double _calculateDecimalResultHeight(int index) {
    final resController = textDisplayControllers[index];
    String text = resController?.text ?? '';
    final bool isDecimalEmpty = text.trim().isEmpty;

    if (isDecimalEmpty) {
      final exactNodes = exactResultNodes[index];
      if (!_nodesEffectivelyEmpty(exactNodes)) {
        final decimalNodes = decimalizeExactNodes(exactNodes!);
        if (decimalNodes.isNotEmpty) {
          double measuredHeight = MathResultDisplay.calculateTotalHeight(
            decimalNodes,
            FONTSIZE,
          );
          double totalHeight = measuredHeight + 20 + 15;
          return totalHeight.clamp(80.0, 500.0);
        }
      }
      return 80.0;
    }

    // Use the same measurement logic as Exact, but handle newlines properly.
    double measuredHeight = MathResultDisplay.calculateTextHeight(
      text,
      FONTSIZE,
    );

    double totalHeight = measuredHeight + 20 + 15;
    return totalHeight.clamp(80.0, 500.0);
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
    double totalHeight = measuredHeight + 20 + 15;
    return totalHeight.clamp(80.0, 500.0);
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
    _cancelCellAnimationState();
    _computeService.dispose();
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

    // Result page controllers are owned by _ResultPageViewWidgetState.
    // Each widget disposes its own PageController in its dispose method.

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

    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        for (final controller in mathEditorControllers.values) {
          controller.refreshDisplay();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          mathEditorControllers[activeIndex]?.recalculateCursorRect();
        });
      });
      return;
    }

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
    _computeService.cancelAll();

    List<CellData> savedCells = await CellPersistence.loadCells();
    int savedIndex = await CellPersistence.loadActiveIndex();
    if (!mounted) return;

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
        final mathController = mathEditorControllers[i];
        mathController?.setExpression(nodes);
        mathController?.result = savedCells[i].answer;
        mathController?.updateAnswer(textDisplayControllers[i]);
      }

      count = savedCells.length;
      activeIndex = savedIndex.clamp(0, count - 1);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Update exact results for all cells after loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (int i = 0; i < count; i++) {
        _requestComputation(i);
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

  // In _HomePageState
  void _onSettingsChanged() {
    // Clear texture cache when theme changes
    TextureGenerator.clearCache();
    unawaited(_prewarmCellTexture());

    updateMathEditor();

    for (final controller in mathEditorControllers.values) {
      controller.refreshDisplay();
    }

    // Force rebuild to reload textures
    setState(() {});
  }

  Future<void> _prewarmCellTexture() async {
    if (!mounted) return;

    final colors = AppColors.of(context, listen: false);
    final cached = TextureGenerator.peekCachedTexture(
      colors.containerBackground,
    );
    if (cached != null) return;

    await TextureGenerator.getTexture(
      colors.containerBackground,
      const Size(400, 300),
      intensity: colors.textureIntensity,
      scale: colors.textureScale,
      softness: colors.textureSoftness,
    );
  }

  /// Cascade computation to cells that depend on the changed cell.
  /// Uses immediate (non-debounced) computation since the trigger
  /// has already been debounced.
  void _cascadeToDependents(int changedIndex) {
    List<int> keys = mathEditorControllers.keys.toList()..sort();

    for (int key in keys) {
      if (key > changedIndex) {
        String expr = mathEditorControllers[key]?.expr ?? '';

        if (expr.contains('ans$changedIndex') || expr.contains('ans')) {
          final controller = mathEditorControllers[key];
          if (controller == null) continue;

          // Collect ans expressions for exact engine
          Map<int, Expr> ansExprs = {};
          for (int prevKey in keys) {
            if (prevKey < key) {
              Expr? prevExpr = exactResultExprs[prevKey];
              if (prevExpr != null) {
                ansExprs[prevKey] = prevExpr;
              }
            }
          }

          Map<int, String> ansValues = _getAnsValues();

          _computeService.computeForCellImmediate(
            cellIndex: key,
            expression: controller.expression,
            ansValues: ansValues,
            ansExpressions: ansExprs,
          );
        }
      }
    }
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
      if (!mounted) return;
      if (scrollController.hasClients) {
        // With reverse: true, position 0 is the RIGHT end (where cursor is)
        if (scrollController.offset != 0) {
          scrollController.jumpTo(0);
        }
      }
    });
  }

void _addDisplay({int? insertAt}) async {
  _computeService.cancelAll();
  
  // Get colors first
  final colors = AppColors.of(context, listen: false);
  
  // Ensure texture is FULLY loaded before creating cell
  // This is the key - we wait for the actual texture, not just start loading
  // ignore: unused_local_variable
  final texture = await TextureGenerator.getTexture(
    colors.containerBackground,
    const Size(400, 300),
    intensity: colors.textureIntensity,
    scale: colors.textureScale,
    softness: colors.textureSoftness,
  );
  
  if (!mounted) return;
  
  // Texture is now guaranteed to be in cache
  
  int insertIndex = insertAt ?? (activeIndex + 1);
  insertIndex = insertIndex.clamp(0, count);

  if (insertIndex < count) {
    _shiftControllersUp(insertIndex);
  }

  _createControllers(insertIndex, animateEntry: true);

  setState(() {
    count += 1;
    activeIndex = insertIndex;
  });

  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future<void>.delayed(_cellCreateTransitionDuration, () {
      if (!mounted) return;
      for (int i = insertIndex + 1; i < count; i++) {
        _requestComputation(i);
      }
    });
  });
}

  void _shiftControllersUp(int fromIndex) {
    // NEW: Update ANS indices in all existing controllers
    for (final controller in mathEditorControllers.values) {
      controller.updateAnsReferences(fromIndex, 1);
    }

    // Work backwards from the end to avoid overwriting
    for (int i = count - 1; i >= fromIndex; i--) {
      int newIndex = i + 1;

      // Move all controller references
      mathEditorControllers[newIndex] = mathEditorControllers[i]!;
      textDisplayControllers[newIndex] = textDisplayControllers[i]!;
      focusNodes[newIndex] = focusNodes[i]!;
      scrollControllers[newIndex] = scrollControllers[i]!;
      mathEditorKeys[newIndex] = mathEditorKeys[i]!;
      exactResultNodes[newIndex] = exactResultNodes[i];
      exactResultExprs[newIndex] = exactResultExprs[i];
      currentResultPage[newIndex] = currentResultPage[i] ?? 0;
      currentResultPageNotifiers[newIndex] = currentResultPageNotifiers[i]!;
      resultPageProgressNotifiers[newIndex] = resultPageProgressNotifiers[i]!;
      exactResultVersionNotifiers[newIndex] = exactResultVersionNotifiers[i]!;

      // Move resultPageControllers if it exists
      if (resultPageControllers.containsKey(i)) {
        resultPageControllers[newIndex] = resultPageControllers[i]!;
      }

      // Move plot expanded state
      if (_plotExpanded.containsKey(i)) {
        _plotExpanded[newIndex] = _plotExpanded[i]!;
      }
    }

    // Clear the old references at fromIndex (will be replaced by _createControllers)
    mathEditorControllers.remove(fromIndex);
    textDisplayControllers.remove(fromIndex);
    focusNodes.remove(fromIndex);
    scrollControllers.remove(fromIndex);
    mathEditorKeys.remove(fromIndex);
    resultPageControllers.remove(fromIndex);
    exactResultNodes.remove(fromIndex);
    exactResultExprs.remove(fromIndex);
    currentResultPage.remove(fromIndex);
    currentResultPageNotifiers.remove(fromIndex);
    resultPageProgressNotifiers.remove(fromIndex);
    exactResultVersionNotifiers.remove(fromIndex);
    _plotExpanded.remove(fromIndex);
  }

  void _removeDisplayNow(int indexToRemove, int token) {
    if (count <= 1) {
      _cellsPendingRemoval.remove(token);
      _cellsPendingEntry.remove(token);
      _cellVisibilityByToken.remove(token);
      return;
    }
    _computeService.cancelAll();

    // NEW: Update ANS indices in all remaining controllers
    // Any reference to a cell AFTER the removed one must be decremented
    for (final controller in mathEditorControllers.values) {
      controller.updateAnsReferences(indexToRemove + 1, -1);
    }

    mathEditorControllers[indexToRemove]?.dispose();
    mathEditorControllers.remove(indexToRemove);
    textDisplayControllers[indexToRemove]?.dispose();
    textDisplayControllers.remove(indexToRemove);
    focusNodes[indexToRemove]?.dispose();
    focusNodes.remove(indexToRemove);
    scrollControllers[indexToRemove]?.dispose();
    scrollControllers.remove(indexToRemove);
    mathEditorKeys.remove(indexToRemove);

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
      _cellsPendingRemoval.remove(token);
      _cellsPendingEntry.remove(token);
      _cellVisibilityByToken.remove(token);
    });
  }

void _removeDisplay(int indexToRemove) {
  if (count <= 1) return;
  final controller = mathEditorControllers[indexToRemove];
  if (controller == null) return;

  final int token = _cellToken(controller);
  if (_cellsPendingRemoval.contains(token)) return;

  _computeService.cancelAll();
  
  setState(() {
    _cellsPendingRemoval.add(token);
    _cellVisibilityByToken[token] = false;
  });
  
  // Note: The actual removal now happens via onAnimationComplete callback
  // in _buildAnimatedCellList, not via a timer
}

  void _clearAllDisplays() {
    _computeService.cancelAll();
    _saveAppStateForUndo();
    _cancelCellAnimationState();

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
      if (resultPageControllers.containsKey(oldKey)) {
        newResultPageControllers[newIndex] = resultPageControllers[oldKey]!;
      }
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
    _computeService.cancelAll();
    _cancelCellAnimationState();

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
      final mathController = mathEditorControllers[i];
      mathController?.setExpression(
        MathClipboard.deepCopyNodes(state.expressions[i]),
      );
      mathController?.result = state.answers[i];
      mathController?.updateAnswer(textDisplayControllers[i]);
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
                    child:
                        _isKeypadVisible
                            ? _buildAnimatedCellList(colors)
                            : _buildActiveCellFullscreen(colors),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child:
                        _isKeypadVisible
                            ? Builder(
                              builder: (context) {
                                final mediaQuery = MediaQuery.of(context);
                                double screenWidth = mediaQuery.size.width;
                                bool isLandscape =
                                    mediaQuery.orientation ==
                                    Orientation.landscape;

                                return CalculatorKeypad(
                                  screenWidth: screenWidth,
                                  isLandscape: isLandscape,
                                  colors: colors,
                                  activeIndex: activeIndex,
                                  mathEditorControllers: mathEditorControllers,
                                  textDisplayControllers:
                                      textDisplayControllers,
                                  settingsProvider: _settingsProvider!,
                                  onUpdateMathEditor: updateMathEditor,
                                  onAddDisplay: _addDisplay,
                                  onRemoveDisplay: _removeDisplay,
                                  onClearAllDisplays: _clearAllDisplays,
                                  countVariablesInExpressions:
                                      countVariablesInExpressions,
                                  onSetState: () => setState(() {}),
                                  onClearSelectionOverlay:
                                      _clearAllSelectionOverlays,
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
                            )
                            : const SizedBox.shrink(),
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
        // Trigger the async compute pipeline for each cell
        _requestComputation(key);
      }
    } finally {
      _isUpdating = false;
    }

    _saveCells();
  }

  int _getFullscreenIndex() {
    if (_plotExpanded[activeIndex] ?? false) return activeIndex;
    for (final entry in _plotExpanded.entries) {
      if (entry.value) return entry.key;
    }
    return activeIndex;
  }

  Widget _buildActiveCellFullscreen(AppColors colors) {
    final index = _getFullscreenIndex();
    return LayoutBuilder(
      builder: (context, constraints) {
        final page = currentResultPage[index] ?? 0;
        final resultHeight =
            page == 0
                ? _calculateDecimalResultHeight(index)
                : _calculateExactResultHeight(index);
        final expressionHeight = (FONTSIZE * 1.5) + 20;
        final available = (constraints.maxHeight -
                expressionHeight -
                resultHeight)
            .clamp(120.0, constraints.maxHeight);

        return _buildExpressionDisplay(
          index,
          colors,
          maxPlotHeight: available,
          forcePlotExpanded: true,
        );
      },
    );
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
      'arg',
      're',
      'im',
      'sgn',
      'Re',
      'Im',
      'perm',
      'comb',
      'sum',
      'prod',
      'diff',
      'int',
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

/// Handles smooth entry and exit animations for cells
class _AnimatedCellWrapper extends StatefulWidget {
  final int token;
  final bool isEntry;
  final bool isVisible;
  final Duration duration;
  final Widget child;
  final VoidCallback? onAnimationComplete;

  const _AnimatedCellWrapper({
    super.key,
    required this.token,
    required this.isEntry,
    required this.isVisible,
    required this.duration,
    required this.child,
    this.onAnimationComplete,
  });

  @override
  State<_AnimatedCellWrapper> createState() => _AnimatedCellWrapperState();
}

class _AnimatedCellWrapperState extends State<_AnimatedCellWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _sizeAnimation;
  bool _animationCompleted = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // Listen for animation completion
    _controller.addStatusListener(_onAnimationStatusChanged);

    if (widget.isEntry) {
      // Entry: animate from 0 to 1
      _opacityAnimation = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      );
      _sizeAnimation = CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      );

      // Start entry animation after frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      // Exit: start fully visible, then animate out
      _controller.value = 1.0;
      
      _opacityAnimation = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      );
      _sizeAnimation = CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInCubic,
      );

      // Start exit animation immediately if marked for removal
      if (!widget.isVisible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _controller.reverse();
          }
        });
      }
    }
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (_animationCompleted) return;

    if (widget.isEntry && status == AnimationStatus.completed) {
      _animationCompleted = true;
      widget.onAnimationComplete?.call();
    } else if (!widget.isEntry && status == AnimationStatus.dismissed) {
      _animationCompleted = true;
      widget.onAnimationComplete?.call();
    }
  }

  @override
  void didUpdateWidget(_AnimatedCellWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle visibility change for exit animation (in case it wasn't started in initState)
    if (!widget.isEntry && oldWidget.isVisible && !widget.isVisible) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double sizeValue = _sizeAnimation.value;
        final double opacityValue = _opacityAnimation.value;

        // Fully collapsed - return empty
        if (sizeValue <= 0.001) {
          return const SizedBox.shrink();
        }

        return Opacity(
          opacity: opacityValue.clamp(0.0, 1.0),
          child: ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: sizeValue.clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

bool _nodesEffectivelyEmpty(List<MathNode>? nodes) {
  if (nodes == null || nodes.isEmpty) return true;
  if (nodes.length == 1 && nodes.first is LiteralNode) {
    return (nodes.first as LiteralNode).text.trim().isEmpty;
  }
  return false;
}

const bool _debugDecimalNodes = false;

void _debugLogDecimalNodes(int index, List<MathNode> nodes) {
  assert(() {
    if (!_debugDecimalNodes) return true;

    final summary = _describeMathNodes(nodes);
    debugPrint('DECIMAL[$index] nodes: $summary');
    return true;
  }());
}

String _describeMathNodes(List<MathNode> nodes) {
  if (nodes.isEmpty) return '[]';
  final parts = nodes.map(_describeMathNode).toList();
  return '[${parts.join(', ')}]';
}

String _describeMathNode(MathNode node) {
  if (node is LiteralNode) return 'Literal("${node.text}")';
  if (node is FractionNode) {
    return 'Fraction(num:${_describeMathNodes(node.numerator)}, den:${_describeMathNodes(node.denominator)})';
  }
  if (node is ExponentNode) {
    return 'Exponent(base:${_describeMathNodes(node.base)}, pow:${_describeMathNodes(node.power)})';
  }
  if (node is ParenthesisNode) {
    return 'Paren(${_describeMathNodes(node.content)})';
  }
  if (node is RootNode) {
    return 'Root(idx:${_describeMathNodes(node.index)}, rad:${_describeMathNodes(node.radicand)})';
  }
  if (node is LogNode) {
    return 'Log(base:${_describeMathNodes(node.base)}, arg:${_describeMathNodes(node.argument)})';
  }
  if (node is TrigNode) {
    return 'Trig(${node.function}, arg:${_describeMathNodes(node.argument)})';
  }
  if (node is SummationNode) {
    return 'Sum(var:${_describeMathNodes(node.variable)}, low:${_describeMathNodes(node.lower)}, up:${_describeMathNodes(node.upper)}, body:${_describeMathNodes(node.body)})';
  }
  if (node is ProductNode) {
    return 'Prod(var:${_describeMathNodes(node.variable)}, low:${_describeMathNodes(node.lower)}, up:${_describeMathNodes(node.upper)}, body:${_describeMathNodes(node.body)})';
  }
  if (node is DerivativeNode) {
    return 'Diff(var:${_describeMathNodes(node.variable)}, at:${_describeMathNodes(node.at)}, body:${_describeMathNodes(node.body)})';
  }
  if (node is IntegralNode) {
    return 'Int(var:${_describeMathNodes(node.variable)}, low:${_describeMathNodes(node.lower)}, up:${_describeMathNodes(node.upper)}, body:${_describeMathNodes(node.body)})';
  }
  if (node is AnsNode) {
    return 'Ans(${_describeMathNodes(node.index)})';
  }
  if (node is ConstantNode) return 'Const(${node.constant})';
  if (node is UnitVectorNode) return 'Unit(${node.axis})';
  if (node is NewlineNode) return 'Newline';
  if (node is ComplexNode) {
    return 'Complex(${_describeMathNodes(node.content)})';
  }
  return node.runtimeType.toString();
}

/// Isolated widget for the result PageView to prevent unnecessary rebuilds
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
  final bool useTransparentBackground; // ADD THIS

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
    this.useTransparentBackground = false, // ADD THIS
  });

  @override
  State<_ResultPageViewWidget> createState() => _ResultPageViewWidgetState();
}

class _ResultPageViewWidgetState extends State<_ResultPageViewWidget> {
  late PageController _pageController;
  final ValueNotifier<int> _fallbackVersionNotifier = ValueNotifier<int>(0);
  final ValueNotifier<double> _fallbackProgressNotifier = ValueNotifier<double>(
    0.0,
  );
  int _currentPage = 0;
  double _lastDecimalHeight = 70.0;
  double _lastExactHeight = 70.0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.currentResultPage[widget.index] ?? 0;
    _pageController = PageController(initialPage: _currentPage);

    widget.resultPageControllers[widget.index] = _pageController;
    _pageController.addListener(_onPageScroll);

    _lastDecimalHeight = widget.calculateDecimalResultHeight(widget.index);
    _lastExactHeight = widget.calculateExactResultHeight(widget.index);
  }

  @override
  void dispose() {
    if (widget.resultPageControllers[widget.index] == _pageController) {
      widget.resultPageControllers.remove(widget.index);
    }
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _fallbackVersionNotifier.dispose();
    _fallbackProgressNotifier.dispose();
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

  // Helper to get background color
  Color get _backgroundColor =>
      widget.useTransparentBackground
          ? Colors.transparent
          : widget.colors.containerBackground;

  @override
  Widget build(BuildContext context) {
    final versionNotifier =
        widget.exactResultVersionNotifiers[widget.index] ??
        _fallbackVersionNotifier;
    final progressNotifier =
        widget.resultPageProgressNotifiers[widget.index] ??
        _fallbackProgressNotifier;

    return ValueListenableBuilder<int>(
      valueListenable: versionNotifier,
      builder: (context, version, _) {
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
          resultVersion: version, // Pass version here
          progressNotifier: progressNotifier,
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
    final String decimalText = resController?.text ?? '';
    final bool isDecimalEmpty = decimalText.trim().isEmpty;
    final exactNodes = widget.exactResultNodes[widget.index];
    final bool hasExactFallback = !_nodesEffectivelyEmpty(exactNodes);
    final List<MathNode> decimalNodes =
        (!isDecimalEmpty)
            ? _textToResultNodes(decimalText)
            : (hasExactFallback
                ? decimalizeExactNodes(exactNodes!)
                : const <MathNode>[]);
    final bool hasResult = decimalNodes.isNotEmpty;

    _debugLogDecimalNodes(widget.index, decimalNodes);

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        _buildResultDivider(0, "DECIMAL"),
        Expanded(
          child: Container(
            key: widget.shouldAddKeys ? widget.resultKey : null,
            color: _backgroundColor, // CHANGED
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
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
                                      nodes: decimalNodes,
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
          ),
        ),
      ],
    );
  }

  List<MathNode> _textToResultNodes(String text) {
    if (text.isEmpty) return const <MathNode>[];

    final lines = text.split('\n');
    final nodes = <MathNode>[];

    for (int i = 0; i < lines.length; i++) {
      nodes.add(LiteralNode(text: lines[i]));
      if (i < lines.length - 1) {
        nodes.add(NewlineNode());
      }
    }

    return nodes;
  }

  Widget _buildExactResultPage() {
    final exactNodes = widget.exactResultNodes[widget.index];
    final bool hasResult = exactNodes != null && exactNodes.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        _buildResultDivider(1, "EXACT"),
        Expanded(
          child: Container(
            color: _backgroundColor, // CHANGED
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
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
  final int resultVersion;
  final Widget child;

  const _AnimatedHeightContainer({
    required this.targetDecimalHeight,
    required this.targetExactHeight,
    required this.lastDecimalHeight,
    required this.lastExactHeight,
    required this.resultVersion,
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

    bool versionChanged = widget.resultVersion != oldWidget.resultVersion;

    if (decimalHeightChanged || exactHeightChanged || versionChanged) {
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
