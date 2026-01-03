import 'package:flutter/material.dart';
import 'package:klator/constants.dart';
import 'package:provider/provider.dart';
import 'settings_provider.dart';
import 'renderer.dart';
import 'app_colors.dart';
import 'cell_persistence_service.dart';
import 'math_expression_serializer.dart';
import 'dart:async';
import 'keypad.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load settings BEFORE running app
  final settingsProvider = await SettingsProvider.create();
  // SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  runApp(
    ChangeNotifierProvider.value(value: settingsProvider, child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,

          // Add themeMode to toggle between themes
          themeMode: settings.isDarkTheme ? ThemeMode.dark : ThemeMode.light,

          // Light theme
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

          // Dark theme
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
            // Text defaults to white in dark mode automatically
          ),

          home: HomePage(),
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
  Map<int, TextEditingController> textDisplayControllers = {};
  Map<int, MathEditorController> mathEditorControllers = {};
  Map<int, FocusNode> focusNodes = {};
  int activeIndex = 0; // Tracks the active container
  PageController pgViewController = PageController(
    initialPage: 1,
    viewportFraction: 1,
  );
  bool isVisible = true;
  bool isTypingExponent = false;
  double plotMaxHeight = 300; // Initial height
  double plotMinHeight = 21; // Initial height
  // double _plotHeight = 100.0; // Initial height when collapsed
  bool _isUpdating = false;
  bool _isLoading = true; // Add loading state
  List<String> answers = []; // Store answers for persistence

  SettingsProvider? _settingsProvider;
  bool _listenerAdded = false;
  Timer? _deleteTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _loadCells();

    if (mathEditorControllers.isEmpty) {
      _createControllers(0);
      count = 1;
      activeIndex = 0;
    }
  }

  @override
  void dispose() {
    _deleteTimer?.cancel(); // <-- Add this
    WidgetsBinding.instance.removeObserver(this);
    _saveCells();

    // Clean up the controller when the widget is disposed.
    // for (TextEditingController controller in textEditingControllers.values) {
    //   controller.dispose();
    // }
    for (MathEditorController controller in mathEditorControllers.values) {
      controller.dispose();
    }

    for (TextEditingController resController in textDisplayControllers.values) {
      resController.dispose();
    }

    for (FocusNode focusNode in focusNodes.values) {
      focusNode.dispose();
    }

    // Dispose all controllers
    mathEditorControllers.values.forEach((c) => c.dispose());
    textDisplayControllers.values.forEach((c) => c.dispose());

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Save when app goes to background or is paused
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _saveCells();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Add listener only once
    if (!_listenerAdded) {
      _settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      _settingsProvider?.addListener(_onSettingsChanged);
      _listenerAdded = true;
    }
  }

  /// Load cells from persistence
  Future<void> _loadCells() async {
    List<CellData> savedCells = await CellPersistence.loadCells();
    int savedIndex = await CellPersistence.loadActiveIndex();

    if (savedCells.isEmpty) {
      // Use existing method
      _createControllers(0);
      count = 1;
      activeIndex = 0;
    } else {
      // Load each saved cell
      for (int i = 0; i < savedCells.length; i++) {
        // Use existing method to create controllers with proper callbacks
        _createControllers(i);

        // Deserialize and set the expression
        List<MathNode> nodes = MathExpressionSerializer.deserializeFromJson(
          savedCells[i].expressionJson,
        );
        mathEditorControllers[i]?.setExpression(nodes);

        // Set the answer
        textDisplayControllers[i]?.text = savedCells[i].answer;
      }

      count = savedCells.length;
      activeIndex = savedIndex.clamp(0, count - 1);
    }

    setState(() => _isLoading = false);
  }

  /// Save all cells to persistence
  Future<void> _saveCells() async {
    // Get sorted keys to maintain order
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

  /// Called whenever any setting changes
  void _onSettingsChanged() {
    // Recalculate all answers with new settings (precision, radians, etc.)
    updateMathEditor();

    // Refresh display for all math editors (to show new multiply symbol)
    for (final controller in mathEditorControllers.values) {
      controller.refreshDisplay();
    }
  }

  void _createControllers(int index) {
    mathEditorControllers[index] = MathEditorController();

    // Set up cascading update callback
    mathEditorControllers[index]!.onResultChanged = () {
      _cascadeUpdates(index);
    };

    textDisplayControllers[index] = TextEditingController();

    focusNodes[index] = FocusNode();
  }

  /// Cascading update for displays that reference the changed one
  void _cascadeUpdates(int changedIndex) {
    if (_isUpdating) return; // Prevent recursion
    _isUpdating = true;

    try {
      List<int> keys = mathEditorControllers.keys.toList()..sort();

      for (int key in keys) {
        if (key > changedIndex) {
          String expr = mathEditorControllers[key]?.expr ?? '';

          // Check if this display references the changed one
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

  void focusManager(index) {
    focusNodes[index]?.requestFocus();
    activeIndex = index;
  }

  Container _buildExpressionDisplay(int index, AppColors colors) {
    final mathEditorController = mathEditorControllers[index];
    final resController = textDisplayControllers[index];
    final bool isFocused = (activeIndex == index);

    // // Get app colors
    // final colors = AppColors.of(context);

    return Container(
      color: colors.containerBackground,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(10),
            child: AnimatedOpacity(
              curve: Curves.easeIn,
              duration: Duration(milliseconds: 500),
              opacity: isVisible ? 1.0 : 0.0,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) {
                  setState(() {
                    activeIndex = index;
                  });

                  final box = context.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final width = box.size.width;
                    final tapX = details.localPosition.dx;

                    // Wider zones - left 40% and right 40%
                    if (tapX < width * 0.4) {
                      mathEditorController.moveCursorToStart();
                    } else if (tapX > width * 0.6) {
                      mathEditorController.moveCursorToEnd();
                    }
                  }
                },
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true, // This keeps cursor visible on the right
                    child: MathEditorInline(
                      controller: mathEditorController!,
                      showCursor: isFocused,
                      onFocus: () {
                        setState(() {
                          activeIndex = index;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: <Widget>[
              Text(
                "$index",
                style: TextStyle(fontSize: 10, color: colors.textTertiary),
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
            color: colors.containerBackground,
            padding: EdgeInsets.all(0),
            alignment: Alignment.centerRight,
            child: AnimatedOpacity(
              curve: Curves.easeIn,
              duration: Duration(milliseconds: 500),
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
                decoration: InputDecoration(border: InputBorder.none),
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
      activeIndex = newIndex; // <-- Focus the new editor
    });
  }

  void _removeDisplay(int indexToRemove) {
    if (count <= 1) return; // Don't remove the last one

    // Dispose controllers at the index being removed
    mathEditorControllers[indexToRemove]?.dispose();
    mathEditorControllers.remove(indexToRemove);
    textDisplayControllers[indexToRemove]?.dispose();
    textDisplayControllers.remove(indexToRemove);
    focusNodes[indexToRemove]?.dispose();
    focusNodes.remove(indexToRemove);

    // Calculate new activeIndex before reindexing
    int newActiveIndex;
    if (activeIndex == indexToRemove) {
      // Deleted the active one - move to previous, or 0 if first
      newActiveIndex = indexToRemove > 0 ? indexToRemove - 1 : 0;
    } else if (activeIndex > indexToRemove) {
      // Active was after deleted one - shift down by 1
      newActiveIndex = activeIndex - 1;
    } else {
      // Active was before deleted one - stays the same
      newActiveIndex = activeIndex;
    }

    // Reindex all controllers to be sequential (0, 1, 2, ...)
    _reindexControllers();

    setState(() {
      count -= 1;
      activeIndex = newActiveIndex;
    });
  }

  void _clearAllDisplays() {
    // Dispose all existing controllers
    for (var controller in mathEditorControllers.values) {
      controller.dispose();
    }
    for (var controller in textDisplayControllers.values) {
      controller.dispose();
    }
    for (var focusNode in focusNodes.values) {
      focusNode.dispose();
    }

    // Clear all maps
    mathEditorControllers.clear();
    textDisplayControllers.clear();
    focusNodes.clear();

    // Create fresh controller at index 0
    _createControllers(0);

    setState(() {
      count = 1;
      activeIndex = 0;
    });
  }

  void _reindexControllers() {
    // Get all current keys sorted
    List<int> oldKeys = mathEditorControllers.keys.toList()..sort();

    // Create new maps with sequential indices starting from 0
    Map<int, MathEditorController> newMathControllers = {};
    Map<int, TextEditingController> newDisplayControllers = {};
    Map<int, FocusNode> newFocusNodes = {};

    for (int newIndex = 0; newIndex < oldKeys.length; newIndex++) {
      int oldKey = oldKeys[newIndex];
      newMathControllers[newIndex] = mathEditorControllers[oldKey]!;
      newDisplayControllers[newIndex] = textDisplayControllers[oldKey]!;
      newFocusNodes[newIndex] = focusNodes[oldKey]!;
    }

    // Replace the old maps with reindexed ones
    mathEditorControllers = newMathControllers;
    textDisplayControllers = newDisplayControllers;
    focusNodes = newFocusNodes;
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while restoring cells
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Get app colors
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 5,
        backgroundColor: colors.displayBackground,
      ), //AppBar
      backgroundColor: colors.displayBackground,
      body: SafeArea(
        // Keeps content away from system UI (status bar + navigation bar)
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: EdgeInsets.zero,
                itemCount: count,
                itemBuilder: (context, index) {
                  List<int> keys = mathEditorControllers.keys.toList()..sort();
                  // Reverse the index to maintain correct order when reversed
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

            // In your build method:
            // Replace the LayoutBuilder with:
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
                  countVariablesInExpressions: countVariablesInExpressions,
                  onSetState: () => setState(() {}),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Gets all ANS values from all displays
  Map<int, String> _getAnsValues() {
    Map<int, String> ansValues = {};

    List<int> keys = mathEditorControllers.keys.toList()..sort();
    for (int key in keys) {
      String? result = mathEditorControllers[key]?.result;

      // Only include valid numeric results
      if (result != null && result.isNotEmpty) {
        // Convert Unicode scientific notation to standard format for parsing
        String parseableResult = result.replaceAll('\u1D07', 'E');

        // Check if it's a simple number
        if (double.tryParse(parseableResult) != null) {
          // Store the converted version so it can be parsed later
          ansValues[key] = parseableResult;
        } else {
          // For multiline results (like simultaneous equations),
          // try to extract first value
          List<String> lines = parseableResult.split('\n');
          if (lines.isNotEmpty) {
            // Updated regex to handle scientific notation
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

  /// Recalculates all displays (useful when a referenced result changes)
  void updateMathEditor() {
    if (_isUpdating) return; // Prevent recursion
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

    _saveCells(); // Save after update
  }

  bool isOperator(String x) {
    if (x == '/' || x == 'x' || x == '-' || x == '+' || x == '=') {
      return true;
    }
    return false;
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
}
