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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Precache SVG backgrounds to avoid flash on load
  await Future.wait([
    _precacheSvg('assets/imgs/background_light.svg'),
    _precacheSvg('assets/imgs/background_dark.svg'),
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

  void _createControllers(int index) {
    mathEditorControllers[index] = MathEditorController();

    mathEditorControllers[index]!.onResultChanged = () {
      _cascadeUpdates(index);
    };

    textDisplayControllers[index] = TextEditingController();
    focusNodes[index] = FocusNode();
    mathEditorKeys[index] = GlobalKey<MathEditorInlineState>(); // ADD THIS
  }

  void _cascadeUpdates(int changedIndex) {
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      // ADD THIS LINE - Update the current cell's display first!
      mathEditorControllers[changedIndex]?.updateAnswer(
        textDisplayControllers[changedIndex],
      );

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

  Container _buildExpressionDisplay(int index, AppColors colors) {
    final mathEditorController = mathEditorControllers[index];
    final resController = textDisplayControllers[index];
    final mathEditorKey = mathEditorKeys[index];
    final bool isFocused = (activeIndex == index);
    final bool shouldAddKeys = index == activeIndex;

    // Add scroll controller to track scroll position
    final scrollController = ScrollController();

    return Container(
      // color: colors.containerBackground,
      decoration: BoxDecoration(
        color: colors.containerBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:
              0.2,
            ), // Shadow color with transparency
            spreadRadius: 2, // How much the shadow grows bigger than the box
            blurRadius: 7, // How soft the edges are (higher = softer)
            offset: Offset(0, 0,), // X, Y position (0,3 means slightly downwards)
          ),
        ],
      ),      
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
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
                  return Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (event) {
                      // Handle focus
                      if (activeIndex != index) {
                        setState(() {
                          activeIndex = index;
                        });
                      }
                      // Clear selection
                      if (mathEditorController.hasSelection) {
                        mathEditorController.clearSelection(notify: false);
                        mathEditorKey?.currentState?.clearOverlay();
                      }

                      // Get content bounds from controller
                      final bounds = mathEditorController.getContentBounds();
                      if (bounds == null) return; // Let inner widget handle

                      final tapX = event.localPosition.dx;
                      final width = constraints.maxWidth;

                      // Calculate where content is positioned on screen
                      // Content is centered, so find the offset
                      final contentWidth = bounds.width;
                      final contentStartX = (width - contentWidth) / 2;
                      final contentEndX = contentStartX + contentWidth;

                      const padding = 10.0; // Small buffer zone

                      // Tap to the LEFT of content
                      if (tapX < contentStartX - padding) {
                        mathEditorController.moveCursorToStartWithRect();
                        return;
                      }

                      // Tap to the RIGHT of content
                      if (tapX > contentEndX + padding) {
                        mathEditorController.moveCursorToEndWithRect();
                        return;
                      }
                    },
                    child: Center(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: MathEditorInline(
                          key: mathEditorKey,
                          controller: mathEditorController!,
                          showCursor: isFocused,
                          onFocus: () {
                            if (activeIndex != index) {
                              setState(() {
                                activeIndex = index;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Row(
            children: <Widget>[
              Container(
                key: shouldAddKeys ? _ansIndexKey : null,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  "$index",
                  style: TextStyle(fontSize: 10, color: colors.textTertiary),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 0.0, right: 10.0),
                  child: Divider(color: colors.divider, height: 6),
                ),
              ),
              Text(
                "DECIMAL",
                style: TextStyle(fontSize: 8, color: colors.textSecondary),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 10.0, right: 0.0),
                  child: Divider(color: colors.divider, height: 6),
                ),
              ),
            ],
          ),
          Container(
            key: shouldAddKeys ? _resultKey : null,
            color: colors.containerBackground,
            padding: const EdgeInsets.all(0),
            alignment: Alignment.centerRight,
            child: AnimatedOpacity(
              curve: Curves.easeIn,
              duration: const Duration(milliseconds: 500),
              opacity: isVisible ? 1.0 : 0.0,
              child: TextField(
                controller: resController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textAlign: TextAlign.center,
                focusNode: focusNodes[index],
                autofocus: false,
                readOnly: true,
                showCursor: false,
                style: TextStyle(fontSize: FONTSIZE, color: colors.textPrimary),
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
          ),
        ],
      ),
    );
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

    mathEditorKeys.remove(indexToRemove); // ADD THIS

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
    // Save state before clearing
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

    mathEditorControllers.clear();
    textDisplayControllers.clear();
    focusNodes.clear();
    mathEditorKeys.clear();

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
    Map<int, GlobalKey<MathEditorInlineState>> newMathEditorKeys =
        {}; // ADD THIS

    for (int newIndex = 0; newIndex < oldKeys.length; newIndex++) {
      int oldKey = oldKeys[newIndex];
      newMathControllers[newIndex] = mathEditorControllers[oldKey]!;
      newDisplayControllers[newIndex] = textDisplayControllers[oldKey]!;
      newFocusNodes[newIndex] = focusNodes[oldKey]!;
      newMathEditorKeys[newIndex] = mathEditorKeys[oldKey]!; // ADD THIS
    }

    mathEditorControllers = newMathControllers;
    textDisplayControllers = newDisplayControllers;
    focusNodes = newFocusNodes;
    mathEditorKeys = newMathEditorKeys; // ADD THIS
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

  /// Restore app to a previous state
  void _restoreAppState(AppState state) {
    // Dispose existing controllers
    for (var controller in mathEditorControllers.values) {
      controller.dispose();
    }
    for (var controller in textDisplayControllers.values) {
      controller.dispose();
    }
    for (var focusNode in focusNodes.values) {
      focusNode.dispose();
    }

    mathEditorControllers.clear();
    textDisplayControllers.clear();
    focusNodes.clear();
    mathEditorKeys.clear();

    // Recreate controllers with saved state
    for (int i = 0; i < state.expressions.length; i++) {
      _createControllers(i);

      // Restore expression (deep copy to avoid reference issues)
      mathEditorControllers[i]?.setExpression(
        MathClipboard.deepCopyNodes(state.expressions[i]),
      );

      // Restore answer
      textDisplayControllers[i]?.text = state.answers[i];
    }

    // Handle edge case of empty state
    if (state.expressions.isEmpty) {
      _createControllers(0);
    }

    setState(() {
      count = state.expressions.isEmpty ? 1 : state.expressions.length;
      activeIndex = state.activeIndex.clamp(0, count - 1);
    });

    // Recalculate all cells
    updateMathEditor();
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
    RegExp variableRegex = RegExp(
      r'(?<!\w)([a-bd-hj-oq-zA-BD-HJ-OQ-Z])(?!\s*\()',
    );

    Set<String> variables = {};
    for (var line in expressions.split('\n')) {
      for (var match in variableRegex.allMatches(line)) {
        variables.add(match.group(0)!);
      }
    }

    return variables.length;
  }
}
