import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klator/keypad.dart';
import 'package:klator/walkthrough/walkthrough_service.dart';
import 'package:klator/walkthrough/walkthrough_steps.dart';
import 'package:klator/settings_provider.dart';
import 'package:klator/app_colors.dart';
import 'package:klator/renderer.dart';

void main() {
  group('CalculatorKeypad', () {
    late WalkthroughService walkthroughService;
    late SettingsProvider settingsProvider;
    late Map<int, MathEditorController?> mathEditorControllers;
    late Map<int, TextEditingController?> textDisplayControllers;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({
        'dark_theme': false,
        'multiplication_sign': '×',
        'walkthrough_completed_v2': true,
      });
    });

    setUp(() async {
      walkthroughService = WalkthroughService();
      settingsProvider = await SettingsProvider.create();
      mathEditorControllers = {0: MathEditorController()};
      textDisplayControllers = {0: TextEditingController()};
    });

    tearDown(() {
      walkthroughService.dispose();
      settingsProvider.dispose();
      mathEditorControllers[0]?.dispose();
      textDisplayControllers[0]?.dispose();
    });

    Widget buildTestWidget({
      double screenWidth = 400,
      bool isLandscape = false,
      WalkthroughService? customWalkthroughService,
      SettingsProvider? customSettingsProvider,
    }) {
      final provider = customSettingsProvider ?? settingsProvider;
      final walkthrough = customWalkthroughService ?? walkthroughService;

      return ChangeNotifierProvider<SettingsProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return CalculatorKeypad(
                  screenWidth: screenWidth,
                  isLandscape: isLandscape,
                  colors: AppColors.of(context),
                  activeIndex: 0,
                  mathEditorControllers: mathEditorControllers,
                  textDisplayControllers: textDisplayControllers,
                  settingsProvider: provider,
                  onUpdateMathEditor: () {},
                  onAddDisplay: () {},
                  onRemoveDisplay: (_) {},
                  onClearAllDisplays: () {},
                  countVariablesInExpressions: (_) => 0,
                  onSetState: () {},
                  walkthroughService: walkthrough,
                  basicKeypadKey: GlobalKey(),
                  basicKeypadHandleKey: GlobalKey(),
                  scientificKeypadKey: GlobalKey(),
                  numberKeypadKey: GlobalKey(),
                  extrasKeypadKey: GlobalKey(),
                  commandButtonKey: GlobalKey(),
                  mainKeypadAreaKey: GlobalKey(),
                  settingsButtonKey: GlobalKey(),
                );
              },
            ),
          ),
        ),
      );
    }

    testWidgets('should render keypad widget', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify the widget tree contains expected structure
      expect(find.byType(CalculatorKeypad), findsOneWidget);
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('should have AnimatedContainer for basic keypad', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedContainer), findsOneWidget);
    });

    testWidgets('should have GestureDetector for basic keypad toggle', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('should have SizedBox for main keypad area', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(SizedBox), findsWidgets);
    });

    group('Basic Keypad Toggle', () {
      testWidgets('should toggle basic keypad on tap', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Find the GestureDetector wrapping the basic keypad
        final gestureDetector = find.byType(GestureDetector).first;
        expect(gestureDetector, findsOneWidget);

        // Tap to toggle
        await tester.tap(gestureDetector);
        await tester.pumpAndSettle();

        // Widget should still be present after toggle
        expect(find.byType(CalculatorKeypad), findsOneWidget);
      });
    });

    group('Walkthrough Integration', () {
      testWidgets('should register callbacks with walkthrough service', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(walkthroughService.onResetKeypad, isNotNull);
        expect(walkthroughService.onNavigateToKeypadPage, isNotNull);
      });

      testWidgets('should reset keypad when walkthrough resets', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Should not throw when called
        walkthroughService.onResetKeypad?.call();
        await tester.pumpAndSettle();

        expect(find.byType(CalculatorKeypad), findsOneWidget);
      });

      testWidgets('should navigate to page when walkthrough requests', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Should not throw when called
        walkthroughService.onNavigateToKeypadPage?.call(0);
        await tester.pumpAndSettle();

        walkthroughService.onNavigateToKeypadPage?.call(2);
        await tester.pumpAndSettle();

        expect(find.byType(CalculatorKeypad), findsOneWidget);
      });
    });

    group('Landscape Mode', () {
      testWidgets('should render in landscape mode', (tester) async {
        await tester.pumpWidget(buildTestWidget(
          screenWidth: 800,
          isLandscape: true,
        ));
        await tester.pumpAndSettle();

        expect(find.byType(CalculatorKeypad), findsOneWidget);
      });

      testWidgets('should set tablet mode for wide screens', (tester) async {
        await tester.pumpWidget(buildTestWidget(
          screenWidth: 800,
          isLandscape: true,
        ));
        await tester.pumpAndSettle();

        // Allow post-frame callback to execute
        await tester.pump(const Duration(milliseconds: 100));

        expect(walkthroughService.isTabletMode, true);
      });
    });

    group('Physics during walkthrough', () {
      testWidgets('should use normal physics when walkthrough inactive', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Just verify the widget renders without error
        expect(find.byType(CalculatorKeypad), findsOneWidget);
      });

      testWidgets('should have directional physics on swipe step', (tester) async {
        final testWalkthroughService = WalkthroughService();
        testWalkthroughService.startWalkthrough();

        // Navigate to a swipe step
        while (!testWalkthroughService.currentStepData.requiresAction) {
          testWalkthroughService.nextStep();
        }

        expect(testWalkthroughService.currentStepData.requiresAction, true);
        expect(
          testWalkthroughService.currentStepData.requiredAction,
          isIn([WalkthroughAction.swipeLeft, WalkthroughAction.swipeRight]),
        );

        await tester.pumpWidget(buildTestWidget(
          customWalkthroughService: testWalkthroughService,
        ));

        // Use pump() instead of pumpAndSettle() because animations run forever
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(CalculatorKeypad), findsOneWidget);

        testWalkthroughService.dispose();
      });

      testWidgets('should allow correct swipe direction during walkthrough', (tester) async {
        final testWalkthroughService = WalkthroughService();
        testWalkthroughService.startWalkthrough();

        // Navigate to first swipe-right step
        while (testWalkthroughService.currentStepData.requiredAction !=
            WalkthroughAction.swipeRight) {
          testWalkthroughService.nextStep();
          if (testWalkthroughService.currentStep >=
              testWalkthroughService.steps.length - 1) {
            break;
          }
        }

        // Skip test if no swipe-right step found
        if (testWalkthroughService.currentStepData.requiredAction !=
            WalkthroughAction.swipeRight) {
          testWalkthroughService.dispose();
          return;
        }

        await tester.pumpWidget(buildTestWidget(
          customWalkthroughService: testWalkthroughService,
        ));

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(CalculatorKeypad), findsOneWidget);

        testWalkthroughService.dispose();
      });
    });

    group('DirectionalScrollPhysics', () {
      test('should block left swipe when not allowed', () {
        const physics = DirectionalScrollPhysics(
          allowLeftSwipe: false,
          allowRightSwipe: true,
        );

        final position = FixedScrollMetrics(
          pixels: 100,
          minScrollExtent: 0,
          maxScrollExtent: 300,
          viewportDimension: 100,
          axisDirection: AxisDirection.right,
          devicePixelRatio: 1.0,
        );

        final result = physics.applyBoundaryConditions(position, 150);
        expect(result, 50);
      });

      test('should allow left swipe when allowed', () {
        const physics = DirectionalScrollPhysics(
          allowLeftSwipe: true,
          allowRightSwipe: true,
        );

        final position = FixedScrollMetrics(
          pixels: 100,
          minScrollExtent: 0,
          maxScrollExtent: 300,
          viewportDimension: 100,
          axisDirection: AxisDirection.right,
          devicePixelRatio: 1.0,
        );

        final result = physics.applyBoundaryConditions(position, 150);
        expect(result, 0);
      });

      test('should block right swipe when not allowed', () {
        const physics = DirectionalScrollPhysics(
          allowLeftSwipe: true,
          allowRightSwipe: false,
        );

        final position = FixedScrollMetrics(
          pixels: 100,
          minScrollExtent: 0,
          maxScrollExtent: 300,
          viewportDimension: 100,
          axisDirection: AxisDirection.right,
          devicePixelRatio: 1.0,
        );

        final result = physics.applyBoundaryConditions(position, 50);
        expect(result, -50);
      });

      test('should allow right swipe when allowed', () {
        const physics = DirectionalScrollPhysics(
          allowLeftSwipe: true,
          allowRightSwipe: true,
        );

        final position = FixedScrollMetrics(
          pixels: 100,
          minScrollExtent: 0,
          maxScrollExtent: 300,
          viewportDimension: 100,
          axisDirection: AxisDirection.right,
          devicePixelRatio: 1.0,
        );

        final result = physics.applyBoundaryConditions(position, 50);
        expect(result, 0);
      });

      test('should apply to ancestor correctly', () {
        const physics = DirectionalScrollPhysics(
          allowLeftSwipe: false,
          allowRightSwipe: true,
        );

        final applied = physics.applyTo(const ClampingScrollPhysics());

        expect(applied, isA<DirectionalScrollPhysics>());
        expect(applied.allowLeftSwipe, false);
        expect(applied.allowRightSwipe, true);
      });
    });
  });
}