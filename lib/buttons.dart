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
  
  return Padding(
    padding: const EdgeInsets.all(0.2),
    child: ClipRRect(
      // borderRadius: BorderRadius.circular(25),
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
          splashColor: Colors.black.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Container(
            // Remove color here since Material has it now
            child: Center(
              child: Text(
                buttonText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
