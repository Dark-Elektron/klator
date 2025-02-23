import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'settings_provider.dart';

// creating Stateless Widget for buttons
class MyButton extends StatelessWidget {

  // declaring variables
  final dynamic color;
  final dynamic textColor;
  final String buttonText;
  final dynamic buttontapped;
  final double fontSize;

  //Constructor
  const MyButton({super.key, this.color, this.textColor,required this.buttonText, this.buttontapped, this.fontSize=22});

  @override
  Widget build(BuildContext context) {
    final bool hapticEnabled = Provider.of<SettingsProvider>(context).hapticFeedback;
    return GestureDetector(
      onTap: () {
        // Trigger haptic feedback only if it's enabled
        if (hapticEnabled) {
          HapticFeedback.heavyImpact(); // Or use the appropriate type
        }
        // Trigger the button tapped action
        if (buttontapped != null) {
          buttontapped();
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(0.2),
        child: ClipRRect(
          // borderRadius: BorderRadius.circular(25),
          child: Container(
            color: color,
            child: Center(
              child: Text(
                buttonText,
                style: TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
