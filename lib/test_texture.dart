import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const PaperLabApp());

class PaperLabApp extends StatelessWidget {
  const PaperLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const PaperExperimentScreen(),
    );
  }
}

class PaperExperimentScreen extends StatefulWidget {
  const PaperExperimentScreen({super.key});

  @override
  State<PaperExperimentScreen> createState() => _PaperExperimentScreenState();
}

class _PaperExperimentScreenState extends State<PaperExperimentScreen> {
  Color _paperColor = const Color(0xFFFAF9F6); // Off-white
  double _grainIntensity = 0.15;
  double _fiberDensity = 0.05;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),
      appBar: AppBar(title: const Text('Procedural Paper Lab'), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                width: 300,
                height: 450,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CustomPaint(
                    painter: PaperPainter(
                      baseColor: _paperColor,
                      grainIntensity: _grainIntensity,
                      fiberDensity: _fiberDensity,
                    ),
                    child: const Center(
                      child: Text(
                        "Handmade\nQuality",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Serif',
                          fontSize: 28,
                          color: Colors.black38,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _colorBtn(const Color(0xFFFAF9F6)), // Cream
              _colorBtn(const Color(0xFFD2B48C)), // Kraft
              _colorBtn(const Color(0xFF8DA399)), // Sage
              _colorBtn(const Color(0xFFE6E6FA)), // Lavender
            ],
          ),
          const SizedBox(height: 20),
          _slider("Grain Intensity", _grainIntensity, (v) => setState(() => _grainIntensity = v)),
          _slider("Fiber Density", _fiberDensity, (v) => setState(() => _fiberDensity = v)),
        ],
      ),
    );
  }

  Widget _colorBtn(Color color) => GestureDetector(
    onTap: () => setState(() => _paperColor = color),
    child: CircleAvatar(backgroundColor: color, radius: 20),
  );

  Widget _slider(String label, double val, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Slider(value: val, onChanged: onChanged, max: 0.5),
      ],
    );
  }
}

class PaperPainter extends CustomPainter {
  final Color baseColor;
  final double grainIntensity;
  final double fiberDensity;

  PaperPainter({
    required this.baseColor,
    required this.grainIntensity,
    required this.fiberDensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = baseColor;
    final random = math.Random(42); 

    // 1. Draw Background Base
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // 2. Draw Grain (Micro-noise)
    // We use a high density of tiny dots to simulate paper pulp
    for (int i = 0; i < (size.width * size.height * 0.5).toInt(); i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      
      // Randomly choose between a white speck or a dark speck
      final isLight = random.nextBool();
      paint.color = (isLight ? Colors.white : Colors.black)
          .withOpacity(random.nextDouble() * grainIntensity);
      
      canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
    }

    // 3. Draw Fibers (The "Recycled" look)
    // I increased the multiplier here significantly (from 0.05 to 5.0)
    final int fiberCount = (size.width * size.height * fiberDensity * 5.0).toInt();
    
    for (int i = 0; i < fiberCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      
      // Fibers look best when they are slightly darker than the base paper
      paint.color = Colors.black.withOpacity(0.15);
      paint.strokeWidth = 0.6;
      paint.style = PaintingStyle.stroke;

      // Draw a tiny organic "hair"
      final path = Path();
      path.moveTo(x, y);
      path.quadraticBezierTo(
        x + random.nextDouble() * 4, 
        y + random.nextDouble() * 4, 
        x + random.nextDouble() * 8 - 4, 
        y + random.nextDouble() * 8 - 4
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PaperPainter oldDelegate) => 
      oldDelegate.baseColor != baseColor || 
      oldDelegate.grainIntensity != grainIntensity ||
      oldDelegate.fiberDensity != fiberDensity;
}

