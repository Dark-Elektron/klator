import 'package:flutter/material.dart';
import 'buttons.dart';
import 'package:math_expressions/math_expressions.dart';
import 'parser.dart';
import 'package:math_keyboard/math_keyboard.dart';

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
        primarySwatch: Colors.yellow
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
    "\u00B7": "*",
    "\u00F7": "/",
    "\u03C0": "*3.141592653589793238462643383279502884197",
  };

  int count = 0;
  Map<int, TextEditingController> textEditingControllers = {};
  Map<int, TextEditingController> textDisplayControllers = {};
  Map<int, Container> displays = {}; 
  Map<int, FocusNode> focusNodes = {};
  int activeIndex = 0; // Tracks the active container
  PageController pgViewController = PageController(initialPage: 1, viewportFraction: 1);
  bool isVisible = true;
  

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
    // setState(() {
    //   _opacity = 0.0; // Start fade-out
    // });

    textDisplayControllers[activeIndex]!.text = newAnswer;
    // Future.delayed(Duration(milliseconds: 500), () {
    //   setState(() {
    //     _opacity = 1.0; // Fade-in new text
    //   });
    // });
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
                  duration: Duration(milliseconds: 500), // Smooth fade effect
                  opacity: isVisible ? 1.0 : 0.0,
                  child: TextField(
                    controller: controller,
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
                  duration: Duration(milliseconds: 500), // Smooth fade effect
                  opacity: isVisible ? 1.0 : 0.0,
                  child: TextField(
                    controller: resController,
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
  }

  @override
  Widget build(BuildContext context) {
    
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 5; // Fixed number of columns
    double buttonSize = screenWidth / crossAxisCount; // Square buttons
    int rowCount = 4; // Number of rows
    double gridHeight = buttonSize * rowCount; // Total height of grid

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
                    // pi button
                    if (index == 6) {
                      return MyButton(
                        buttontapped: () {
                          setState(() {
                            textEditingControllers[activeIndex]!.text += '\u03C0';
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
                            textEditingControllers[activeIndex]!.text += '^2';
                          });
                        },
                        buttonText: 'x^2',
                        color: Colors.white,
                        textColor: Colors.black,
                      );
                    }
                    // ^ Button
                    else if (index == 2) {
                      return MyButton(
                        buttontapped: () {
                          setState(() {
                            textEditingControllers[activeIndex]!.text += '^';
                          });
                        },
                        buttonText: 'x^n',
                        color: Colors.white,
                        textColor: Colors.black,
                      );
                    }
                    // nth root Button
                    else if (index == 4) {
                      return MyButton(
                        buttontapped: () {
                          setState(() {
                            textEditingControllers[activeIndex]!.text += ' n\u221A7 ';
                          });
                        },
                        buttonText: 'n\u221A',
                        color: Colors.white,
                        textColor: Colors.black,
                      );
                    }
                    // ln Button
                    else if (index == 17) {
                      return MyButton(
                        buttontapped: () {
                          setState(() {
                            textEditingControllers[activeIndex]!.text += 'ln';
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
                            textEditingControllers[activeIndex]!.text += 'log()';
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
                            textEditingControllers[activeIndex]!.text = 'logn()';
                          });
                        },
                        buttonText: buttonsSci[index],
                        color: Colors.white,
                        textColor: Colors.black,
                      );
                    }
                    //  other buttons
                    else {
                      return MyButton(
                        buttontapped: () {
                          setState(() {
                            textEditingControllers[activeIndex]!.text += buttonsSci[index].toLowerCase();
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
                            expressionInputManager(textEditingControllers[activeIndex], '()');
                            // textEditingControllers[activeIndex]!.text += '()';
                          });
                        },
                        buttonText: buttons[index],
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
                              if (displays.length > 1) {
                                // delete the currently active display
                                _removeDisplay(activeIndex);
                              }
                            } else {
                                deleteTextAtCursor(textEditingControllers[activeIndex]!);
                            }
                          });
                        },
                        buttonText: '\u2190',
                        color: const Color.fromARGB(255, 226, 104, 104),
                        textColor: Colors.black,
                      );
                    }
                    // Multiplication Button
                    else if (index == 13) {
                      return MyButton(
                        buttontapped: () {
                          setState(() {
                            expressionInputManager(textEditingControllers[activeIndex], '\u00B7');
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
                            expressionInputManager(textEditingControllers[activeIndex], '\u00F7');
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
                            _addDisplay(count);
                            }
                          });
                        },
                        buttonText: '\u21B5',
                        color: Colors.white,
                        textColor: Colors.black,
                      );
                    }
                    //  other buttons
                    else {
                      return MyButton(
                        buttontapped: () {
                          setState(() {
                            // textEditingControllers[activeIndex]!.text += buttons[index];
                            expressionInputManager(textEditingControllers[activeIndex], buttons[index]);
                          });
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
            ],
            ),
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
    final text = controller.text;
        final cursorPos = controller.selection.baseOffset;

        if (cursorPos < 0) {
          // If no cursor is set, append at the end
          controller.text = text + textToInsert;
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
        } else {
          // Insert text at cursor position
          final newText = text.replaceRange(cursorPos, cursorPos, textToInsert);
          controller.text = newText;
          // Move cursor to the end of inserted text
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: cursorPos + textToInsert.length),
          );
        }
  }

  void deleteTextAtCursor(TextEditingController controller, {bool deleteBefore = true}) {
    TextSelection selection = controller.selection;
    String text = controller.text;

    if (!selection.isValid) return; // Ensure the selection is valid

    int cursorPos = selection.baseOffset;
    if (cursorPos == -1) return; // No cursor position available

    if (deleteBefore) {
      // Delete character before cursor
      if (cursorPos > 0) {
        controller.text = text.substring(0, cursorPos - 1) + text.substring(cursorPos);
        controller.selection = TextSelection.collapsed(offset: cursorPos - 1);
      }
    } else {
      // Delete character after cursor
      if (cursorPos < text.length) {
        controller.text = text.substring(0, cursorPos) + text.substring(cursorPos + 1);
        controller.selection = TextSelection.collapsed(offset: cursorPos);
      }
    }
}

// function to calculate the input operation
  void evaluateExpression() {
    String finalUserInput = textEditingControllers[activeIndex]!.text;
    finalUserInput = replaceMultiple(finalUserInput, replacements);
    // finaluserinput = finaluserinput.replaceAll('\u00B7', '*');
    // finaluserinput = finaluserinput.replaceAll('\u03C0', '*3.14');
    // finaluserinput = finaluserinput.replaceAll('\u00F7', '/');
    finalUserInput = parseExpression(finalUserInput);

    try{
      GrammarParser p = GrammarParser();
      Expression exp = p.parse(finalUserInput);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      
      _updateAnswer(eval.toString());
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

