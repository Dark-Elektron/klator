
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ExpandableSizedBoxExample(),
    );
  }
}

class ExpandableSizedBoxExample extends StatefulWidget {
  const ExpandableSizedBoxExample({super.key});

  @override
  State<ExpandableSizedBoxExample> createState() => _ExpandableSizedBoxExampleState();
}

class _ExpandableSizedBoxExampleState extends State<ExpandableSizedBoxExample> {
  double _boxHeight = 50.0; // Initial height when collapsed
  final double _minHeight = 50.0; // Minimum height (collapsed)
  final double _maxHeight = 300.0; // Maximum height (expanded)

  void _updateHeight(DragUpdateDetails details) {
    setState(() {
      _boxHeight -= details.primaryDelta!; // Adjust height based on drag
      _boxHeight = _boxHeight.clamp(_minHeight, _maxHeight); // Keep within bounds
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Slide to Expand/Collapse")),
      body: Column(
        children: [
          // Draggable Handle & SizedBox
          GestureDetector(
            onVerticalDragUpdate: _updateHeight, // Handles dragging
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              height: _boxHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blue[300],
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    width: 40,
                    height: 5,
                    margin: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _boxHeight > _minHeight + 10 ? "Expanded Content" : "Slide Up",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
