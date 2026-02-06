import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MathPlotterApp());
}

class MathPlotterApp extends StatelessWidget {
  const MathPlotterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Math Plotter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1a1a2e),
        colorScheme: ColorScheme.dark(
          primary: Colors.blue.shade400,
          secondary: Colors.tealAccent,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}