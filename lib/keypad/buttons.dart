import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../settings/settings_provider.dart';

// creating Stateless Widget for buttons
class MyButton extends StatelessWidget {
  // declaring variables
  final dynamic color;
  final dynamic textColor;
  final String buttonText;
  final dynamic buttontapped;
  final double fontSize;
  final bool mirror;

  //Constructor
  const MyButton({
    super.key,
    this.color,
    this.textColor,
    required this.buttonText,
    this.buttontapped,
    this.fontSize = 22,
    this.mirror = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool hapticEnabled =
        Provider.of<SettingsProvider>(context).hapticFeedback;
    // 2. Create the text widget separately for clarity
    Widget textWidget = Text(
      buttonText,
      textAlign: TextAlign.center,
      style: TextStyle(color: textColor, fontSize: fontSize),
    );

    // 3. If mirror is true, wrap the text in a Transform
    if (mirror) {
      textWidget = Transform.scale(
        scaleX: -1, // This flips the widget horizontally
        child: textWidget,
      );
    }
    return Padding(
      padding: const EdgeInsets.all(0.5),
      child: Container(
        decoration: BoxDecoration(
          // IMPORTANT: borderRadius here must match ClipRRect to make the shadow curved
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3), // Shadow color
              blurRadius: 2, // Softness
              spreadRadius: 0, // Size
              offset: Offset(0, 0), // Position (x, y)
            ),
          ],
        ),
        child: ClipRRect(
          // borderRadius: BorderRadius.circular(4),
          child: Material(
            color: color,
            child: InkWell(
              onTap: () {
                if (hapticEnabled) {
                  HapticFeedback.heavyImpact();
                }
                if (buttontapped != null) {
                  buttontapped();
                }
              },
              splashColor: Colors.black.withValues(alpha: 0.2),
              highlightColor: Colors.white.withValues(alpha: 0.1),
              // child: Container(
              // Remove color here since Material has it now
              child: Center(
                child: textWidget
              ),
              // ),
            ),
          ),
        ),
      ),
    );
  }
}
