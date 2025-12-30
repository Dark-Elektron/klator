import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Tutorial Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  bool _showTutorial = true;

  @override
  void initState() {
    super.initState();
    // Show tutorial after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_showTutorial) {
        _startTutorial();
      }
    });
  }

  void _startTutorial() {
    showTutorial(
      context: context,
      steps: [
        TutorialStep(
          targetKey: _searchKey,
          title: 'Search',
          description: 'Tap here to search for items',
          shape: BoxShape.circle,
        ),
        TutorialStep(
          targetKey: _menuKey,
          title: 'Menu',
          description: 'Access your profile and settings here',
          shape: BoxShape.circle,
        ),
        TutorialStep(
          targetKey: _fabKey,
          title: 'Add New',
          description: 'Tap this button to create something new',
          shape: BoxShape.circle,
          pulseAnimation: true,
        ),
      ],
      onComplete: () {
        setState(() => _showTutorial = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My App'),
        actions: [
          IconButton(
            key: _searchKey,
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            key: _menuKey,
            icon: const Icon(Icons.menu),
            onPressed: () {},
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome to the App!'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startTutorial,
              child: const Text('Restart Tutorial'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: _fabKey,
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}

class TutorialStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final BoxShape shape;
  final bool pulseAnimation;

  TutorialStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.shape = BoxShape.rectangle,
    this.pulseAnimation = false,
  });
}

void showTutorial({
  required BuildContext context,
  required List<TutorialStep> steps,
  required VoidCallback onComplete,
}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      pageBuilder: (context, _, __) => TutorialOverlay(
        steps: steps,
        onComplete: onComplete,
      ),
    ),
  );
}

class TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onComplete;

  const TutorialOverlay({
    Key? key,
    required this.steps,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _controller.reverse().then((_) {
        Navigator.of(context).pop();
        widget.onComplete();
      });
    }
  }

  void _skipTutorial() {
    _controller.reverse().then((_) {
      Navigator.of(context).pop();
      widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final RenderBox? renderBox =
        step.targetKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null) {
      return const SizedBox.shrink();
    }

    final targetPosition = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.black54,
        child: GestureDetector(
          onTap: _nextStep,
          child: Stack(
            children: [
              // Highlight area
              CustomPaint(
                painter: HolePainter(
                  holeRect: Rect.fromLTWH(
                    targetPosition.dx,
                    targetPosition.dy,
                    targetSize.width,
                    targetSize.height,
                  ),
                  shape: step.shape,
                ),
                child: Container(),
              ),
              // Pulse animation for highlighted area
              if (step.pulseAnimation)
                Positioned(
                  left: targetPosition.dx,
                  top: targetPosition.dy,
                  child: PulseAnimation(
                    size: targetSize,
                    shape: step.shape,
                  ),
                ),
              // Description card
              Positioned(
                left: 20,
                right: 20,
                top: targetPosition.dy + targetSize.height + 20,
                child: TutorialCard(
                  title: step.title,
                  description: step.description,
                  currentStep: _currentStep + 1,
                  totalSteps: widget.steps.length,
                  onNext: _nextStep,
                  onSkip: _skipTutorial,
                ),
              ),
              // Animated pointer
              Positioned(
                left: targetPosition.dx + targetSize.width / 2 - 15,
                top: targetPosition.dy + targetSize.height + 5,
                child: const AnimatedPointer(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HolePainter extends CustomPainter {
  final Rect holeRect;
  final BoxShape shape;

  HolePainter({required this.holeRect, required this.shape});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    final holePaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear;

    final padding = 8.0;
    final expandedRect = holeRect.inflate(padding);

    if (shape == BoxShape.circle) {
      canvas.drawCircle(
        expandedRect.center,
        expandedRect.width / 2,
        holePaint,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(expandedRect, const Radius.circular(8)),
        holePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TutorialCard extends StatelessWidget {
  final String title;
  final String description;
  final int currentStep;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const TutorialCard({
    Key? key,
    required this.title,
    required this.description,
    required this.currentStep,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$currentStep/$totalSteps',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: onSkip,
                  child: const Text('Skip'),
                ),
                ElevatedButton(
                  onPressed: onNext,
                  child: Text(
                    currentStep == totalSteps ? 'Done' : 'Next',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedPointer extends StatefulWidget {
  const AnimatedPointer({Key? key}) : super(key: key);

  @override
  State<AnimatedPointer> createState() => _AnimatedPointerState();
}

class _AnimatedPointerState extends State<AnimatedPointer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: const Icon(
            Icons.arrow_upward,
            color: Colors.white,
            size: 30,
          ),
        );
      },
    );
  }
}

class PulseAnimation extends StatefulWidget {
  final Size size;
  final BoxShape shape;

  const PulseAnimation({
    Key? key,
    required this.size,
    required this.shape,
  }) : super(key: key);

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size.width + 16,
              height: widget.size.height + 16,
              decoration: BoxDecoration(
                shape: widget.shape,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        );
      },
    );
  }
}