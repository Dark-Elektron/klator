import 'package:flutter/material.dart';
import 'package:klator/constants.dart';
import 'package:klator/help.dart';
import 'package:klator/utils.dart';
import 'buttons.dart';
import 'settings.dart';
import 'package:provider/provider.dart';
import 'settings_provider.dart';
import 'renderer.dart';
import 'app_colors.dart';

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

class _HomePageState extends State<HomePage> {
  // Map<String, String> replacements = {
  //   "\u2212": "-",
  //   "\u002B": "+",
  //   "\u00B7": "*",
  //   "\u00F7": "/",
  //   "\u03C0": "*(\u03C0)",
  //   // "\u00B2": "^(2)",
  //   // "\u221A": "sqrt",
  //   "\u00B0": '*(\u03C0/180)',
  //   "rad": '*(1/\u03C0)*180',
  //   "sin": "*sin",
  //   "cos": "*cos",
  //   "tan": "*tan",
  //   "asin": "*asin",
  //   "acos": "*acos",
  //   "atan": "*atan",
  //   "a*sin": "*asin",
  //   "a*cos": "*acos",
  //   "a*tan": "*atan",
  //   "ln": "*ln",
  //   "log": "*log",
  //   "e": "*e",
  //   "**": "*",
  //   "*+": "*",
  //   "-*": "- 1*",
  //   "+*": "+ 1*",
  //   "/*": "/",
  //   "(*": "(",
  // };

  int count = 0;
  // Map<int, TextEditingController> textEditingControllers = {};
  Map<int, TextEditingController> textDisplayControllers = {};
  // Map<int, TextEditingController> customTextEditingControllers = {};
  Map<int, MathEditorController> mathEditorControllers = {};
  // late final MathEditorController mathEditor = MathEditorController();
  // Map<int, Container> displays = {};
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
  late PageController _keypadController;
  int? _lastPagesPerView;
  bool _isUpdating = false;
  
  SettingsProvider? _settingsProvider;
  bool _listenerAdded = false;

  @override
  void initState() {
    super.initState();

    if (mathEditorControllers.isEmpty) {
      _createControllers(0);
      count = 1;
      activeIndex = 0;
    }

    _keypadController = PageController(initialPage: 1);
  }
  
  @override
  void dispose() {
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
    super.dispose();
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

  /// Called whenever any setting changes
  void _onSettingsChanged() {
    // Recalculate all answers with new settings (precision, radians, etc.)
    updateMathEditor();
  }

  void _createControllers(int index) {
    mathEditorControllers[index] = MathEditorController();

    // Set up cascading update callback
    mathEditorControllers[index]!.onResultChanged = () {
      _cascadeUpdates(index);
    };

    textDisplayControllers[index] = TextEditingController();
    // textDisplayControllers[index]!.addListener(() {
    //   _updateAnswer('');
    // });
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
          if (expr.toUpperCase().contains('ANS$changedIndex') ||
              expr.toUpperCase().contains('ANS')) {
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

  void _updatePagesPerView(int pagesPerView) {
    _keypadController.dispose();
    _keypadController = PageController(
      initialPage: 1,
      viewportFraction: 1 / pagesPerView,
    );
  }

  void focusManager(index) {
    focusNodes[index]?.requestFocus();
    activeIndex = index;
  }

  //   void _updatePlotHeight(DragUpdateDetails details, double maxHeight) {
  //     setState(() {
  //         _plotHeight -= details.primaryDelta!; // Adjust height based on drag
  //         _plotHeight = _plotHeight.clamp(plotMinHeight, maxHeight + plotMinHeight,
  //       ); // Keep within bounds
  //     });
  //     // print(_plotHeight);
  //   }
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
              child: Center(
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

  double _boxHeight = 21.0; // Initial height when collapsed
  final double _minHeight = 21.0; // Minimum height (collapsed)

  void _updateHeight(DragUpdateDetails details, double maxHeight) {
    setState(() {
      _boxHeight -= details.primaryDelta!; // Adjust height based on drag
      _boxHeight = _boxHeight.clamp(
        _minHeight,
        maxHeight + _minHeight,
      ); // Keep within bounds
    });
  }

  @override
  Widget build(BuildContext context) {
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
            OrientationBuilder(
              builder: (context, orientation) {
                // // screen stuff
                double screenWidth = MediaQuery.of(context).size.width;
                bool isLandscape =
                    MediaQuery.of(context).orientation == Orientation.landscape;
                return _buildKeypad(
                  screenWidth: screenWidth,
                  isLandscape: isLandscape,
                  colors: colors,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad({
    required double screenWidth,
    required bool isLandscape,
    required AppColors colors,
  }) {
    final List<String> buttonsBasic = [
      '5',
      '6',
      '7',
      '8',
      '9',
      '()',
      '+',
      '-',
      'E',
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
    final List<String> buttons = [
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
      'E',
      'C',
      'EN',
    ];
    final List<String> buttonsSci = [
      '=',
      'x^2',
      'x^n',
      'SQR',
      'nSQR',
      'x',
      'PI',
      'SIN',
      'COS',
      'TAN',
      'y',
      '\u00B0',
      'ASIN',
      'ACOS',
      'ATAN',
      'z',
      'e',
      'LN',
      'LOG',
      'LOGn',
    ];
    final List<String> buttonsR = [
      '',
      'i',
      'x!',
      'nPr',
      '\u27F2',
      '',
      '',
      '',
      'nCr',
      'ANS',
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

    bool isWideScreen = screenWidth > 600; // Adjust threshold if needed
    int pagesPerView;

    if (isLandscape) {
      pagesPerView = 3;
    } else if (isWideScreen) {
      pagesPerView = 2;
    } else {
      pagesPerView = 1;
    }

    int crossAxisCount = 5; // Fixed number of columns
    int rowCount = 4; // Number of rows
    double buttonSize = screenWidth / crossAxisCount; // Square buttons
    double gridHeight =
        buttonSize * rowCount / pagesPerView; // Total height of grid
    int crossAxisCountBasic =
        (isLandscape) ? 20 : 10; // Fixed number of columns
    double buttonSizeBasic =
        screenWidth / crossAxisCountBasic; // Square buttons
    double gridHeightBasic =
        (isLandscape)
            ? buttonSizeBasic * 1
            : buttonSizeBasic * 2; // Total height of grid

    if (_lastPagesPerView != pagesPerView) {
      _updatePagesPerView(pagesPerView);
    }

    return Column(
      children: [
        // Draggable Handle & SizedBox
        GestureDetector(
          onVerticalDragUpdate:
              (details) =>
                  _updateHeight(details, gridHeightBasic), // Handles dragging
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            height: _boxHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              // color: Colors.blueGrey,
            ),
            child: Column(
              children: [
                // Drag Handle
                Container(
                  width: 40,
                  height: 5,
                  margin: EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.containerBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Expanded(
                  child: PageView(
                    physics: const NeverScrollableScrollPhysics(),
                    padEnds: false,
                    controller: pgViewController,
                    children: [
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: buttonsBasic.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCountBasic,
                        ),
                        itemBuilder: (BuildContext context, int index) {
                          // Addition Button
                          if (index == 6) {
                            return MyButton(
                              buttontapped: () {
                                mathEditorControllers[activeIndex]
                                    ?.insertCharacter(buttonsBasic[index]);
                              },
                              buttonText: '\u002B',
                              color: Colors.white,
                              textColor: Colors.black,
                            );
                          }
                          // Subtraction Button
                          else if (index == 7) {
                            return MyButton(
                              buttontapped: () {
                                mathEditorControllers[activeIndex]
                                    ?.insertCharacter(buttonsBasic[index]);
                              },
                              buttonText: '\u2212',
                              color: Colors.white,
                              textColor: Colors.black,
                            );
                          }
                          // Multiplication Button
                          else if (index == 16) {
                            return MyButton(
                              buttontapped: () {
                                mathEditorControllers[activeIndex]
                                    ?.insertCharacter('\u00B7');
                              },
                              buttonText: '\u00D7',
                              color: Colors.white,
                              textColor: Colors.black,
                            );
                          }
                          // Division Button
                          else if (index == 17) {
                            return MyButton(
                              buttontapped: () {
                                mathEditorControllers[activeIndex]
                                    ?.insertCharacter(buttonsBasic[index]);
                              },
                              buttonText: '\u00F7',
                              color: Colors.white,
                              textColor: Colors.black,
                            );
                          }
                          // Enter button Button
                          else if (index == 19) {
                            return MyButton(
                              buttontapped: () {
                                setState(() {
                                  if (mathEditorControllers[activeIndex]!
                                          .expr !=
                                      '') {
                                    // check if more than one variable in expression
                                    String text =
                                        mathEditorControllers[activeIndex]!
                                            .expr;
                                    if (countVariablesInExpressions(text) >
                                        text.split('\n').length) {
                                      // Need more equations - add new line in same editor
                                      mathEditorControllers[activeIndex]!
                                          .insertNewline();
                                      // mathEditorControllers[activeIndex]!
                                      //     .expr += '\n';
                                    } else {
                                      _addDisplay();
                                    }
                                  }
                                  updateMathEditor();
                                });
                              },
                              buttonText: '\u2318',
                              color: Colors.white,
                              textColor: Colors.black,
                            );
                          }
                          // Delete Button
                          else if (index == 9) {
                            return MyButton(
                              buttontapped: () {
                                mathEditorControllers[activeIndex]
                                    ?.deleteChar();
                                updateMathEditor();
                                setState(() {
                                  if (mathEditorControllers[activeIndex]
                                          ?.expr ==
                                      '') {
                                    //   if (textEditingControllers[activeIndex]!
                                    //           .text ==
                                    //       '') {
                                    //     // if (customTextEditingControllers[activeIndex]!.text == '') {
                                    //     if (displays.length > 1) {
                                    //       // delete the currently active display
                                    _removeDisplay(activeIndex);
                                  }
                                });
                              },
                              buttonText: '\u232B',
                              color: const Color.fromARGB(255, 226, 104, 104),
                              textColor: Colors.black,
                            );
                          }
                          // Clear Button
                          else if (index == 18) {
                            return MyButton(
                              buttontapped: () {
                                setState(() {
                                  mathEditorControllers[activeIndex]?.clear();
                                  mathEditorControllers[activeIndex]
                                      ?.updateAnswer(
                                        textDisplayControllers[activeIndex],
                                      );
                                  //   textEditingControllers[activeIndex]!.text =
                                  //       '';
                                  //   // customTextEditingControllers[activeIndex]!.text = '';
                                });
                              },
                              buttonText: buttonsBasic[index],
                              color: Colors.white,
                              textColor: Colors.black,
                            );
                          }
                          //  other buttons
                          else {
                            return MyButton(
                              buttontapped: () {
                                mathEditorControllers[activeIndex]
                                    ?.insertCharacter(buttonsBasic[index]);
                                updateMathEditor();
                                // setState(() {
                                //   expressionInputManager(
                                //     textEditingControllers[activeIndex],
                                //     buttonsBasic[index],
                                //   );
                                //   // expressionInputManager(customTextEditingControllers[activeIndex], buttonsBasic[index]);
                                // });
                              },
                              buttonText: buttonsBasic[index],
                              color:
                                  isOperator(buttonsBasic[index])
                                      ? Colors.white
                                      : Colors.white,
                              textColor:
                                  isOperator(buttonsBasic[index])
                                      ? Colors.black
                                      : Colors.black,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: gridHeight,
          child: PageView(
            padEnds: false,
            controller: _keypadController, // pgViewController(pagesPerView),
            children: [
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                ),
                itemCount: buttonsSci.length,
                itemBuilder: (BuildContext context, int index) {
                  // = button
                  if (index == 0) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers?[activeIndex]?.insertCharacter(
                          buttonsSci[index],
                        );
                        updateMathEditor();
                        // setState(() {
                        //   // mathEditorControllers?[activeIndex].updateAnswer(textDisplayControllers[activeIndex]);
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     ' = ',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], ' = ');
                        // });
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
                        mathEditorControllers[activeIndex]?.insertCharacter(
                          '\u03C0',
                        );
                        updateMathEditor();
                        // mathEditorControllers[activeIndex]?.moveLeft();
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     '\u03C0',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], '\u03C0');
                        // });
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
                        mathEditorControllers[activeIndex]?.insertSquare();
                        updateMathEditor();
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     '\u00B2',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], '\u00B2');
                        // });
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
                        mathEditorControllers[activeIndex]?.insertCharacter(
                          '^',
                        );
                        updateMathEditor();
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     '^()',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], '^()');
                        //   isTypingExponent = true;
                        // });
                      },
                      buttonText: 'x\u207F',
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  // square root Button
                  else if (index == 3) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertSquareRoot();
                        updateMathEditor();
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     '2\u207F\u221A()',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], '\u221A()');
                        // });
                      },
                      buttonText: '\u221A',
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  // nth root Button
                  else if (index == 4) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertNthRoot();
                        updateMathEditor();
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     '\u207F\u221A()',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], '\u207F\u221A()');
                        // });
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
                        mathEditorControllers[activeIndex]?.insertTrig('sin');
                        updateMathEditor();
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     'sin()',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], 'sin()');
                        // });
                      },
                      buttonText: buttonsSci[index],
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  // cos Button
                  else if (index == 8) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertTrig('cos');
                        updateMathEditor();
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     'cos()',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], 'cos()');
                        // });
                      },
                      buttonText: buttonsSci[index],
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  // tan Button
                  else if (index == 9) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertTrig('tan');
                        updateMathEditor();
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     'tan()',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], 'tan()');
                        // });
                      },
                      buttonText: buttonsSci[index],
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  // asin Button
                  else if (index == 12) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertTrig('asin');
                        updateMathEditor();
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     'asin()',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], 'asin()');
                        // });
                      },
                      buttonText: buttonsSci[index],
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  // acos Button
                  else if (index == 13) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertTrig('acos');
                        updateMathEditor();
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     'acos()',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], 'acos()');
                        // });
                      },
                      buttonText: buttonsSci[index],
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  // atan Button
                  else if (index == 14) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertTrig('atan');
                        updateMathEditor();
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     'atan()',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], 'atan()');
                        // });
                      },
                      buttonText: buttonsSci[index],
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  // ln Button
                  else if (index == 17) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertTrig('ln');
                        updateMathEditor();
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     'ln()',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], 'ln()');
                        // });
                      },
                      buttonText: buttonsSci[index],
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  // log Button
                  else if (index == 18) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertLog10();
                        updateMathEditor();
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     'log()',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], 'log()');
                        // });
                      },
                      buttonText: buttonsSci[index],
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  // logn Button
                  else if (index == 19) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertLogN();
                        updateMathEditor();
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     'logn()',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], 'logn()');
                        // });
                      },
                      buttonText: 'LOG\u1D63',
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  } else if (index == 11) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertCharacter(
                          buttonsSci[index],
                        );
                        updateMathEditor();
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     buttonsSci[index].toLowerCase(),
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], buttonsSci[index].toLowerCase());
                        // });
                      },
                      buttonText: '\u00B0',
                      color:
                          isOperator(buttonsSci[index])
                              ? Colors.white
                              : Colors.white,
                      textColor:
                          isOperator(buttonsSci[index])
                              ? Colors.black
                              : Colors.black,
                    );
                  }
                  //  other buttons
                  else {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertCharacter(
                          buttonsSci[index],
                        );
                        updateMathEditor();
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     buttonsSci[index].toLowerCase(),
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], buttonsSci[index].toLowerCase());
                        // });
                      },
                      buttonText: buttonsSci[index],
                      color:
                          isOperator(buttonsSci[index])
                              ? Colors.white
                              : Colors.white,
                      textColor:
                          isOperator(buttonsSci[index])
                              ? Colors.black
                              : Colors.black,
                    );
                  }
                },
              ),
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: buttons.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                ),
                itemBuilder: (BuildContext context, int index) {
                  // () button
                  if (index == 3) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertCharacter(
                          buttons[index],
                        );
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     '\u0028\u0029',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], '\u0028\u0029');
                        //   textEditingControllers[activeIndex]!.text += '()';
                        // });
                      },
                      buttonText: '\u0028\u0029',
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  // Delete Button
                  else if (index == 4) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.deleteChar();
                        updateMathEditor();
                        setState(() {
                          if (mathEditorControllers[activeIndex]?.expr == '') {
                            //   if (textEditingControllers[activeIndex]!.text == '') {
                            //     // if (customTextEditingControllers[activeIndex]!.text == '') {
                            //     if (displays.length > 1) {
                            //       // delete the currently active display
                            _removeDisplay(activeIndex);
                            //     }
                            //   } else {
                            //     deleteTextAtCursor(
                            //       textEditingControllers[activeIndex]!,
                            //     );
                            //     // deleteTextAtCursor(customTextEditingControllers[activeIndex]!);
                            //   }
                          }
                        });
                      },
                      buttonText: '\u232B',
                      color: const Color.fromARGB(255, 226, 104, 104),
                      textColor: Colors.black,
                    );
                  }
                  // Addition Button
                  else if (index == 8) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertCharacter(
                          '\u002B',
                        );
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     ' \u002B ',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], '\u002B');
                        //   textEditingControllers[activeIndex]!.text +=
                        //       ' \u00B7 ';
                        // });
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
                        mathEditorControllers[activeIndex]?.insertCharacter(
                          '\u2212',
                        );
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     ' \u2212 ',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], '\u2212');
                        //   textEditingControllers[activeIndex]!.text +=
                        //       ' \u2212 ';
                        // });
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
                        mathEditorControllers[activeIndex]?.insertCharacter(
                          '\u00B7',
                        );
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     ' \u00B7 ',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], '\u00B7');
                        //   textEditingControllers[activeIndex]!.text +=
                        //       ' \u00B7 ';
                        // });
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
                        mathEditorControllers[activeIndex]?.insertCharacter(
                          buttons[index],
                        );
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     ' \u00F7 ',
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], '\u00F7');
                        // });
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
                        mathEditorControllers[activeIndex]?.insertCharacter(
                          buttons[index],
                        );
                        // setState(() {
                        //   textEditingControllers[activeIndex]!.text +=
                        //       buttons[index];
                        //   // customTextEditingControllers[activeIndex]!.text += buttons[index];
                        // });
                      },
                      buttonText: buttons[index],
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  // Clear Button
                  else if (index == 18) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.clear();
                        updateMathEditor();
                        setState(() {
                          // textEditingControllers[activeIndex]!.text = '';
                          // customTextEditingControllers[activeIndex]!.text = '';
                        });
                      },
                      buttonText: buttons[index],
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  // Enter button Button
                  else if (index == 19) {
                    return MyButton(
                      buttontapped: () {
                        setState(() {
                          if (mathEditorControllers[activeIndex]!.expr != '') {
                            // check if more than one variable in expression
                            String text =
                                mathEditorControllers[activeIndex]!.expr;
                            if (countVariablesInExpressions(text) >
                                text.split('\n').length) {
                              // Need more equations - add new line in same editor
                              mathEditorControllers[activeIndex]!
                                  .insertNewline();
                              // mathEditorControllers[activeIndex]!.expr += '\n';
                            } else {
                              _addDisplay();
                            }
                          }

                          updateMathEditor();
                        });
                      },
                      buttonText: '\u2318',
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  //  other buttons
                  else {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertCharacter(
                          buttons[index],
                        );
                        updateMathEditor();
                        // setState(() {
                        //   expressionInputManager(
                        //     textEditingControllers[activeIndex],
                        //     buttons[index],
                        //   );
                        //   // expressionInputManager(customTextEditingControllers[activeIndex], buttons[index]);
                        // });
                      },
                      buttonText: buttons[index],
                      color:
                          isOperator(buttons[index])
                              ? Colors.white
                              : Colors.white,
                      textColor:
                          isOperator(buttons[index])
                              ? Colors.black
                              : Colors.black,
                    );
                  }
                },
              ),
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: buttons.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                ),
                itemBuilder: (BuildContext context, int index) {
                  // ans button
                  if (index == 9) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertCharacter(
                          buttonsR[index],
                        );
                        updateMathEditor();
                      },
                      buttonText: buttonsR[index],
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  // complex number button
                  if (index == 1) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertCharacter(
                          buttonsR[index],
                        );
                      },
                      buttonText: buttonsR[index],
                      color: Colors.white,
                      textColor: Colors.grey,
                    );
                  }
                  // factorial Button
                  else if (index == 2) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertCharacter(
                          '!',
                        );
                        updateMathEditor();
                      },
                      buttonText: buttonsR[index],
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  // permutation Button
                  else if (index == 3) {
                    return MyButton(
                      buttontapped: () {
                        mathEditorControllers[activeIndex]?.insertPermutation();
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
                        mathEditorControllers[activeIndex]?.insertCombination();
                      },
                      buttonText: '\u207FC\u1D63',
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  // Clear All Button
                  else if (index == 4) {
                    return MyButton(
                      buttontapped: () {
                        _clearAllDisplays();
                      },
                      buttonText: buttonsR[index],
                      color: const Color.fromARGB(255, 226, 104, 104),
                      textColor: Colors.black,
                    );
                  }
                  // help Button
                  else if (index == 18) {
                    return MyButton(
                      buttontapped: () {
                        Navigator.push(
                          context,
                          SlidePageRoute(page: HelpPage()),
                        );
                      },
                      buttonText: buttonsR[index],
                      fontSize: 28,
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  // Settings Button
                  else if (index == 19) {
                    return MyButton(
                      buttontapped: () {
                        Navigator.push(
                          context,
                          SlidePageRoute(page: SettingsScreen()),
                        );
                      },
                      buttonText: '\u2699',
                      color: Colors.white,
                      textColor: Colors.black,
                    );
                  }
                  //  other buttons
                  else {
                    return MyButton(
                      // buttontapped: () {
                      //   mathEditorControllers[activeIndex]?.insertCharacter(
                      //     buttonsR[index],
                      //   );
                      //   updateMathEditor();
                      //   // setState(() {
                      //   //   expressionInputManager(
                      //   //     textEditingControllers[activeIndex],
                      //   //     buttons[index],
                      //   //   );
                      //   //   // expressionInputManager(customTextEditingControllers[activeIndex], buttonsR[index]);
                      //   // });
                      // },
                      buttonText: buttonsR[index],
                      color:
                          isOperator(buttonsR[index])
                              ? Colors.white
                              : Colors.white,
                      textColor:
                          isOperator(buttonsR[index])
                              ? Colors.black
                              : Colors.black,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // double complexEngine() {
  //   return 0.0;
  // }
  /// Gets all ANS values from all displays
  Map<int, String> _getAnsValues() {
    Map<int, String> ansValues = {};

    List<int> keys = mathEditorControllers.keys.toList()..sort();
    for (int key in keys) {
      String? result = mathEditorControllers[key]?.result;
      // Only include valid numeric results
      if (result != null && result.isNotEmpty) {
        // Check if it's a simple number
        if (double.tryParse(result) != null) {
          ansValues[key] = result;
        } else {
          // For multiline results (like simultaneous equations),
          // try to extract first value
          List<String> lines = result.split('\n');
          if (lines.isNotEmpty) {
            RegExp numRegex = RegExp(r'=\s*(-?\d+\.?\d*)');
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
  }

  // void updateMathEditor(int activeIndex) {
  //   mathEditorControllers[activeIndex]?.onCalculate();
  //   mathEditorControllers[activeIndex]?.updateAnswer(
  //     textDisplayControllers[activeIndex],
  //   );
  // }

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

  void replaceAnswer(int activeIndex) {
    // replace answer it if exists
    if (activeIndex > 0) {
      String? ans = mathEditorControllers[activeIndex - 1]!.result;
    }
  }

}
