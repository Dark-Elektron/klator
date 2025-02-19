import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'buttons.dart';
import 'parser.dart';
// import 'equation_field.dart';
import 'evaluate_expression.dart';
import 'package:function_tree/function_tree.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.yellow,
        fontFamily: 'OpenSans',
		textSelectionTheme: TextSelectionThemeData(
			cursorColor: Colors.black, // Cursor color
			selectionColor: Colors.red.withValues(alpha: 0.4), // Highlight color
			selectionHandleColor: Colors.red, // Handle color
        ),
      ),
      home: HomePage(),
    ); // MaterialApp
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, String> replacements = {
	" \u2212 ": "-",
	" \u002B ": "+",
    " \u00B7 ": "*",
    " \u00F7 ": "/",
    "\u03C0": "*pi",
	"\u00B2": "^(2)",
	"\u221A": "sqrt",
    "sin": "*sin",
    "cos": "*cos",
    "tan": "*tan",
    "asin": "*asin",
    "acos": "*acos",
    "atan": "*atan",
    "a*sin": "*asin",
    "a*cos": "*acos",
    "a*tan": "*atan",
    "ln": "*ln",
    "log": "*log",
    "e": "*e",
    "**": "*",
    "* *": "*",
    "* +": "*",
    "- *": "- 1*",
    "+ *": "+ 1*",
    "/ *": "/",
    "(*": "(",
  };

  int count = 0;
  Map<int, TextEditingController> textEditingControllers = {};
  Map<int, TextEditingController> textDisplayControllers = {};
  Map<int, TextEditingController> customTextEditingControllers = {};
  Map<int, Container> displays = {}; 
  Map<int, FocusNode> focusNodes = {};
  int activeIndex = 0; // Tracks the active container
  PageController pgViewController = PageController(initialPage: 1, viewportFraction: 1);
  bool isVisible = true;


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
    'RAD',
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
    'ANS',
    'i',
    'x!',
    'nPr',
    'nCr',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
  ];

  // final _controller = TextEditingController();

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    for (TextEditingController controller in textEditingControllers.values) {
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
  void initState() {
    super.initState();
  }

  
  // double _opacity = 1.0; // Controls fade animation
  void _updateAnswer(String newAnswer) {

    textDisplayControllers[activeIndex]!.text = newAnswer;
  }

  void focusManager(index) {
    focusNodes[index]!.requestFocus();
    activeIndex = index;
  }

  Container _buildContainer(index) {
    TextEditingController controller = TextEditingController(); // create controller
    controller.addListener(evaluateExpression);
    textEditingControllers[index] = controller; // add controller to list

    TextEditingController resController = TextEditingController(); // create controller
    resController.addListener(evaluateExpression);
    textDisplayControllers[index] = resController; // add controller to list

    TextEditingController customController = TextEditingController(); // create controller
    customController.addListener(evaluateExpression);
    customTextEditingControllers[index] = customController; // add controller to list

    focusNodes[index] = FocusNode();

    return Container(
      color: Colors.blueGrey,
      child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Container(
                color: Colors.blueGrey,
                padding: EdgeInsets.all(0),
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
					curve: Curves.easeIn,
					duration: Duration(milliseconds: 500), // Smooth fade effect
					opacity: isVisible ? 1.0 : 0.0,
					child: TextField(
                    controller: controller,
					maxLines: null, // Allows multiple lines
					keyboardType: TextInputType.multiline, // Enables multi-line input
                    cursorColor: Colors.yellowAccent,
                    textAlign: TextAlign.center,
                    focusNode: focusNodes[index],
                    autofocus: false,
                    readOnly: true,
                    showCursor: true,
                    style: TextStyle(fontSize: 22.0, color: Colors.white),
                    decoration: InputDecoration(
                      border: InputBorder.none,  // This removes the underline or outline
                    ),
                    onTap: () => focusManager(index),
                  ),
                ),
              ),
      
              Row(children: <Widget>[
                  Expanded(
                    child: Container(
                        margin: const EdgeInsets.only(left: 0.0, right: 10.0),
                        child: Divider(
                          color: Colors.grey,
                          height: 6,
                        )),
                  ),
                  Text("NUMERIC", style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey),),
                  Expanded(
                    child: Container(
                        margin: const EdgeInsets.only(left: 10.0, right: 0.0),
                        child: Divider(
                          color: Colors.grey,
                          height: 6,
                        )),
                  ),
                ]),
      
              Container(
                color: Colors.blueGrey,
                padding: EdgeInsets.all(0),
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
					curve: Curves.easeIn,
					duration: Duration(milliseconds: 500), // Smooth fade effect
					opacity: isVisible ? 1.0 : 0.0,
					child: TextField(
                    controller: resController,
					maxLines: null, // Allows multiple lines
					keyboardType: TextInputType.multiline, // Enables multi-line input
                    textAlign: TextAlign.center,
                    focusNode: focusNodes[index],
                    autofocus: false,
                    readOnly: true,
                    showCursor: false,
                    style: TextStyle(fontSize: 22.0, color: Colors.white),
                    decoration: InputDecoration(
                      border: InputBorder.none,  // This removes the underline or outline
                    ),
                  ),
                ),
              ),
            //   Container(
            //     // color: Colors.blueGrey,
            //     width: double.infinity,
            //     // decoration: BoxDecoration(border: Border.all()),
            //     padding: EdgeInsets.all(0),
            //     // alignment: Alignment.centerRight,
            //     child: AnimatedOpacity(
			// 		curve: Curves.easeIn,
			// 		duration: Duration(milliseconds: 500), // Smooth fade effect
			// 		opacity: isVisible ? 1.0 : 0.0,
			// 		child: CustomTextField(
			// 			text: "Initial text here",
			// 			cursorColor: Colors.yellow,
			// 			controller: customController,
			// 			),
			// 	),
            //     ),
            ]),
    );
  }

  void _addDisplay(index) {
    displays[index] = _buildContainer(index);
    focusManager(index);
    count += 1;
  }

  void _removeDisplay(int index) {
      displays.remove(index);
      count -= 1;
	  
	  activeIndex = count-1;
	  focusManager(activeIndex);
  }

  double _boxHeight = 21.0; // Initial height when collapsed
  final double _minHeight = 21.0; // Minimum height (collapsed)

  void _updateHeight(DragUpdateDetails details, double maxHeight) {
    setState(() {
      _boxHeight -= details.primaryDelta!; // Adjust height based on drag
      _boxHeight = _boxHeight.clamp(_minHeight, maxHeight + _minHeight); // Keep within bounds
    });
  }

  @override
  Widget build(BuildContext context) {
    
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 5; // Fixed number of columns
    double buttonSize = screenWidth / crossAxisCount; // Square buttons
    int rowCount = 4; // Number of rows
    double gridHeight = buttonSize * rowCount; // Total height of grid

    int crossAxisCountBasic = 10; // Fixed number of columns
    double buttonSizeBasic = screenWidth / crossAxisCountBasic; // Square buttons
    double gridHeightBasic = buttonSizeBasic * 2; // Total height of grid

    if (displays.isEmpty) {
      displays[0] = _buildContainer(0); // add first input and result display
      count += 1;
    }

    return Scaffold(
      // appBar: AppBar(
      //   title: Text("Klator"),
      // ), //AppBar
      backgroundColor: Colors.white38,
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              reverse: true,
              children: displays.entries.map((entry) => 
              Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: entry.value
                )
              ).toList().reversed.toList(),
              
            ),
          ),
          Column(
            children: [
			// Draggable Handle & SizedBox
			GestureDetector(
				onVerticalDragUpdate: (details) => _updateHeight(details, gridHeightBasic), // Handles dragging
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
						color: Colors.blueGrey,
						borderRadius: BorderRadius.circular(10),
						),
					),
					Expanded(
						child: PageView(
						padEnds: false,
						controller: pgViewController,
						children: [
							GridView.builder(
							padding: EdgeInsets.zero,
							itemCount: buttonsBasic.length,
							gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
								crossAxisCount: crossAxisCountBasic),
							itemBuilder: (BuildContext context, int index) {
								// Addition Button
								if (index == 6) {
								return MyButton(
									buttontapped: () {
									setState(() {
										expressionInputManager(textEditingControllers[activeIndex], ' \u002B ');
										expressionInputManager(customTextEditingControllers[activeIndex], ' \u002B ');
										// textEditingControllers[activeIndex]!.text += ' \u00B7 ';
									});
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
									setState(() {
										expressionInputManager(textEditingControllers[activeIndex], ' \u2212 ');
										expressionInputManager(customTextEditingControllers[activeIndex], ' \u2212 ');
										// textEditingControllers[activeIndex]!.text += ' \u00B7 ';
									});
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
									setState(() {
										expressionInputManager(textEditingControllers[activeIndex], ' \u00B7 ');
										expressionInputManager(customTextEditingControllers[activeIndex], ' \u00B7 ');
										// textEditingControllers[activeIndex]!.text += ' \u00B7 ';
									});
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
									setState(() {
										expressionInputManager(textEditingControllers[activeIndex], ' \u00F7 ');
										expressionInputManager(customTextEditingControllers[activeIndex], ' \u00F7 ');
									});
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
										if (textEditingControllers[activeIndex]!.text != '') {
											// check if more than one variable in expression
											String text = textEditingControllers[activeIndex]!.text;
											if (countVariablesInExpressions(text) > text.split('\n').length){
												textEditingControllers[activeIndex]!.text += '\n';
											} else {
												_addDisplay(count);
											}
										}
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
									setState(() {
										if (textEditingControllers[activeIndex]!.text == '') {
										// if (customTextEditingControllers[activeIndex]!.text == '') {
										if (displays.length > 1) {
											// delete the currently active display
											_removeDisplay(activeIndex);
										}
										} else {
											deleteTextAtCursor(textEditingControllers[activeIndex]!);
											deleteTextAtCursor(customTextEditingControllers[activeIndex]!);
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
										textEditingControllers[activeIndex]!.text = '';
										customTextEditingControllers[activeIndex]!.text = '';
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
									setState(() {
										expressionInputManager(textEditingControllers[activeIndex], buttonsBasic[index]);
										expressionInputManager(customTextEditingControllers[activeIndex], buttonsBasic[index]);
									});
											HapticFeedback.heavyImpact();
									},
									buttonText: buttonsBasic[index],
									color: isOperator(buttonsBasic[index])
										? Colors.white
										: Colors.white,
									textColor: isOperator(buttonsBasic[index])
										? Colors.black
										: Colors.black,
								);
								}
							}),
							],
						),
				),
					]
					),
				),
			),
			SizedBox(
                height: gridHeight,
                child: PageView(
                  padEnds: false,
                  controller: pgViewController,
                  children: [
                    GridView.builder(
						padding: EdgeInsets.zero,
						gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
						itemCount: buttonsSci.length,
						itemBuilder: (BuildContext context, int index) {
                        // = button
                        if (index == 0) {
                          return MyButton(
                            buttontapped: () {
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], ' = ');
                                expressionInputManager(customTextEditingControllers[activeIndex], ' = ');
                              });
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
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], '\u03C0');
                                expressionInputManager(customTextEditingControllers[activeIndex], '\u03C0');
                              });
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
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], '\u00B2');
                                expressionInputManager(customTextEditingControllers[activeIndex], '\u00B2');
                              });
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
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], '^()');
                                expressionInputManager(customTextEditingControllers[activeIndex], '^()');
                              });
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
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], '\u221A()');
                                expressionInputManager(customTextEditingControllers[activeIndex], '\u221A()');
                              });
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
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], 'n\u221A7');
                                expressionInputManager(customTextEditingControllers[activeIndex], 'n\u221A7');
                              });
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
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], 'sin()');
                                expressionInputManager(customTextEditingControllers[activeIndex], 'sin()');
                              });
                            },
                            buttonText: 'sin',
                            color: Colors.white,
                            textColor: Colors.black,
                          );
                        }
                        // cos Button
                        else if (index == 8) {
                          return MyButton(
                            buttontapped: () {
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], 'cos()');
                                expressionInputManager(customTextEditingControllers[activeIndex], 'cos()');
                              });
                            },
                            buttonText: 'cos',
                            color: Colors.white,
                            textColor: Colors.black,
                          );
                        }
                        // tan Button
                        else if (index == 9) {
                          return MyButton(
                            buttontapped: () {
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], 'tan()');
                                expressionInputManager(customTextEditingControllers[activeIndex], 'tan()');
                              });
                            },
                            buttonText: 'tan',
                            color: Colors.white,
                            textColor: Colors.black,
                          );
                        }
                        // asin Button
                        else if (index == 12) {
                          return MyButton(
                            buttontapped: () {
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], 'asin()');
                                expressionInputManager(customTextEditingControllers[activeIndex], 'asin()');
                              });
                            },
                            buttonText: 'asin',
                            color: Colors.white,
                            textColor: Colors.black,
                          );
                        }
                        // acos Button
                        else if (index == 13) {
                          return MyButton(
                            buttontapped: () {
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], 'acos()');
                                expressionInputManager(customTextEditingControllers[activeIndex], 'acos()');
                              });
                            },
                            buttonText: 'acos',
                            color: Colors.white,
                            textColor: Colors.black,
                          );
                        }
                        // atan Button
                        else if (index == 14) {
                          return MyButton(
                            buttontapped: () {
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], 'atan()');
                                expressionInputManager(customTextEditingControllers[activeIndex], 'atan()');
                              });
                            },
                            buttonText: 'atan',
                            color: Colors.white,
                            textColor: Colors.black,
                          );
                        }
                        // ln Button
                        else if (index == 17) {
                          return MyButton(
                            buttontapped: () {
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], 'ln()');
                                expressionInputManager(customTextEditingControllers[activeIndex], 'ln()');
                              });
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
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], 'log()');
                                expressionInputManager(customTextEditingControllers[activeIndex], 'log()');
                              });
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
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], 'logn()');
                                expressionInputManager(customTextEditingControllers[activeIndex], 'logn()');
                              });
                            },
                            buttonText: 'LOG\u2099',
                            color: Colors.white,
                            textColor: Colors.black,
                          );
                        }
                        //  other buttons
                        else {
                          return MyButton(
                            buttontapped: () {
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], buttonsSci[index].toLowerCase());
                                expressionInputManager(customTextEditingControllers[activeIndex], buttonsSci[index].toLowerCase());
                              });
                            },
                            buttonText: buttonsSci[index],
                            color: isOperator(buttonsSci[index])
                                ? Colors.white
                                : Colors.white,
                            textColor: isOperator(buttonsSci[index])
                                ? Colors.black
                                : Colors.black,
                          );
                        }
                      }),
                    GridView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: buttons.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5),
                      itemBuilder: (BuildContext context, int index) {
                        // () button
                        if (index == 3) {
                          return MyButton(
                            buttontapped: () {
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], '\u0028\u0029');
                                expressionInputManager(customTextEditingControllers[activeIndex], '\u0028\u0029');
                                // textEditingControllers[activeIndex]!.text += '()';
                              });
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
                              setState(() {
                                if (textEditingControllers[activeIndex]!.text == '') {
                                // if (customTextEditingControllers[activeIndex]!.text == '') {
                                  if (displays.length > 1) {
                                    // delete the currently active display
                                    _removeDisplay(activeIndex);
                                  }
                                } else {
                                    deleteTextAtCursor(textEditingControllers[activeIndex]!);
                                    deleteTextAtCursor(customTextEditingControllers[activeIndex]!);
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
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], ' \u002B ');
                                expressionInputManager(customTextEditingControllers[activeIndex], ' \u002B ');
                                // textEditingControllers[activeIndex]!.text += ' \u00B7 ';
                              });
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
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], ' \u2212 ');
                                expressionInputManager(customTextEditingControllers[activeIndex], ' \u2212 ');
                                // textEditingControllers[activeIndex]!.text += ' \u00B7 ';
                              });
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
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], ' \u00B7 ');
                                expressionInputManager(customTextEditingControllers[activeIndex], ' \u00B7 ');
                                // textEditingControllers[activeIndex]!.text += ' \u00B7 ';
                              });
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
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], ' \u00F7 ');
                                expressionInputManager(customTextEditingControllers[activeIndex], ' \u00F7 ');
                              });
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
                              setState(() {
                                textEditingControllers[activeIndex]!.text += buttons[index];
                                customTextEditingControllers[activeIndex]!.text += buttons[index];
                              });
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
                              setState(() {
                                textEditingControllers[activeIndex]!.text = '';
                                customTextEditingControllers[activeIndex]!.text = '';
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
                                if (textEditingControllers[activeIndex]!.text != '') {
									// check if more than one variable in expression
									String text = textEditingControllers[activeIndex]!.text;
									if (countVariablesInExpressions(text) < text.split('\n').length){
										textEditingControllers[activeIndex]!.text += '\n';
									} else {
										_addDisplay(count);
									}
                                }
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
                              setState(() {
                                expressionInputManager(textEditingControllers[activeIndex], buttons[index]);
                                expressionInputManager(customTextEditingControllers[activeIndex], buttons[index]);
                              });
              						  HapticFeedback.heavyImpact();
                            },
                            buttonText: buttons[index],
                            color: isOperator(buttons[index])
                                ? Colors.white
                                : Colors.white,
                            textColor: isOperator(buttons[index])
                                ? Colors.black
                                : Colors.black,
                          );
                        }
                      }),
					GridView.builder(
					padding: EdgeInsets.zero,
					itemCount: buttons.length,
					gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
						crossAxisCount: 5),
					itemBuilder: (BuildContext context, int index) {
					// complex number button
					if (index == 0) {
						return MyButton(
						buttontapped: () {
							setState(() {
							expressionInputManager(textEditingControllers[activeIndex], 'ans');
							expressionInputManager(customTextEditingControllers[activeIndex], 'ans');
							});
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
							setState(() {
							expressionInputManager(textEditingControllers[activeIndex], 'i');
							expressionInputManager(customTextEditingControllers[activeIndex], 'i');
							});
						},
						buttonText: buttonsR[index],
						color: Colors.white,
						textColor: Colors.black,
						);
					}
					// factorial Button
					else if (index == 2) {
						return MyButton(
						buttontapped: () {
							setState(() {
							expressionInputManager(textEditingControllers[activeIndex], '!');
							expressionInputManager(customTextEditingControllers[activeIndex], '!');
							});
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
							setState(() {
							expressionInputManager(textEditingControllers[activeIndex], 'P');
							expressionInputManager(customTextEditingControllers[activeIndex], 'P');
							// textEditingControllers[activeIndex]!.text += ' \u00B7 ';
							});
						},
						buttonText: '\u207FP\u2098',
						color: Colors.white,
						textColor: Colors.black,
						);
					}
					// Combination Button
					else if (index == 4) {
						return MyButton(
						buttontapped: () {
							setState(() {
							expressionInputManager(textEditingControllers[activeIndex], 'C');
							expressionInputManager(customTextEditingControllers[activeIndex], 'C');
							});
						},
						buttonText: '\u207FC\u2098',
						color: Colors.white,
						textColor: Colors.black,
						);
					}
					// Settings Button
					else if (index == 19) {
						return MyButton(
						buttontapped: () {
							setState(() {
							if (textEditingControllers[activeIndex]!.text != '') {
							_addDisplay(count);
							}
							});
						},
						buttonText: '\u2699',
						color: Colors.white,
						textColor: Colors.black,
						);
					}
					//  other buttons
					else {
						return MyButton(
						buttontapped: () {
							setState(() {
							expressionInputManager(textEditingControllers[activeIndex], buttons[index]);
							expressionInputManager(customTextEditingControllers[activeIndex], buttonsR[index]);
							});
						},
						buttonText: buttonsR[index],
						color: isOperator(buttonsR[index])
							? Colors.white
							: Colors.white,
						textColor: isOperator(buttonsR[index])
							? Colors.black
							: Colors.black,
						);
					}
					}),
				],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool isOperator(String x) {
    if (x == '/' || x == 'x' || x == '-' || x == '+' || x == '=') {
      return true;
    }
    return false;
  }

  void expressionInputManager(controller, textToInsert) {
    dynamic text = controller.text;
    dynamic cursorPos = controller.selection.baseOffset;
    
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
		// Insert text at cursor position
		final newText = text.replaceRange(cursorPos, cursorPos, textToInsert);
		controller.text = newText;

		// Move cursor to the end of inserted text
		if (textToInsert.contains('()')) {
			controller.selection = TextSelection.collapsed(offset: cursorPos + textToInsert.length - 1);
		} else {
			controller.selection = TextSelection.fromPosition(
			TextPosition(offset: cursorPos + textToInsert.length),
			);
		}
    }

  }

	int countVariablesInExpressions(String expressions) {
		// Regular expression to match variables (single letters a-z, A-Z)
		RegExp variableRegex = RegExp(r'[a-zA-Z]');
		
		// Extract unique variable names from all lines
		Set<String> variables = {};
		for (var line in expressions.split('\n')) {
			for (var match in variableRegex.allMatches(line)) {
				variables.add(match.group(0)!);
			}
		}

		return variables.length;
	}

  void deleteTextAtCursor(TextEditingController controller, {bool deleteBefore = true}) {
    TextSelection selection = controller.selection;
    String text = controller.text;

    if (!selection.isValid) return; // Ensure the selection is valid

    int cursorPos = selection.baseOffset;

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
				String textToDelete = text.substring(cursorPos-1, cursorPos);
				String bracketString = '';

				if (textToDelete == ' ') {
					if (text.length > 3) {
						shiftPos = 3;
					}
				} else if (textToDelete == '(') {
					// Get index of corresponding right bracket
					String restSubstring = text.substring(cursorPos);
					
					forwardDeleteCount = 0;
					int detectClosingBracket = 1;
					for (int i = 0; i < restSubstring.length; i++){
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
					bracketString = text.substring(cursorPos, cursorPos+forwardDeleteCount-1);
				}
				controller.text = text.substring(0, cursorPos - shiftPos) + bracketString + text.substring(cursorPos+forwardDeleteCount);

				cursorPos -= shiftPos;
				if (bracketString == '') {
					controller.selection = TextSelection.collapsed(offset: cursorPos);
				} else {
					controller.selection = TextSelection(baseOffset: cursorPos, extentOffset: cursorPos+forwardDeleteCount-1);
				}

			} else {
				cursorPos = 0;
				controller.selection = TextSelection.collapsed(offset: cursorPos);
			}
		} else {
		// // Delete character after cursor
		// if (cursorPos < text.length) {
		//   controller.text = text.substring(0, cursorPos) + text.substring(cursorPos + 1);
		//   controller.selection = TextSelection.collapsed(offset: cursorPos);
		// }
		}
	}
}

// function to calculate the input operation
  void evaluateExpression() {
    String finalUserInput = textEditingControllers[activeIndex]!.text;
    finalUserInput = replaceMultiple(finalUserInput, replacements).replaceFirst(RegExp(r'^\*+\s*'), '');

	// replace answer it if exists
	if (activeIndex > 0) {
		String ans = textDisplayControllers[activeIndex-1]!.text;
		finalUserInput = finalUserInput.replaceAll('ans', ans);
	}

    finalUserInput = parseExpression(finalUserInput);

    try{
		// GrammarParser p = GrammarParser();
		// Expression exp = p.parse(finalUserInput);
		// ContextModel cm = ContextModel();
		// double eval = exp.evaluate(EvaluationType.REAL, cm);
     	//  _updateAnswer(eval.toString());

		// check if expression is regular, singleVariable or multiVariable
		if (['x', 'y', 'z', '='].every((parameter) => finalUserInput.contains(parameter))){
			dynamic eval = EquationSolver.solveLinearSystem(finalUserInput);
			_updateAnswer(eval.toString());
		} else if (['x', 'y', '='].every((parameter) => finalUserInput.contains(parameter))){
			dynamic eval = EquationSolver.solveLinearSystem(finalUserInput);
			_updateAnswer(eval.toString());
		} else if (['x', '='].every((parameter) => finalUserInput.contains(parameter))) {
			dynamic eval = EquationSolver.solveEquation(finalUserInput);
			_updateAnswer(eval.toString());
		} else {
			final expression = finalUserInput;
			dynamic eval = expression.interpret();
			_updateAnswer(properFormat(eval).toString());
		}
      
      // answer = eval.toString();
    } catch(e) {
      textDisplayControllers[activeIndex]!.text = '';
    }
  }

  String replaceMultiple(String text, Map<String, String> replacements) {
    replacements.forEach((key, value) {
      	text = text.replaceAll(key, value);
    });
    return text;
  }
}

