import 'package:flutter/material.dart';
import 'settings_provider.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkTheme;

    // Theme-aware colors
    final activeColor = isDark ? Colors.white : Colors.white;
    final activeTrackColor = isDark ? Colors.blueGrey[700] : Colors.blueGrey;
    final sliderActiveColor = isDark ? Colors.blueGrey[300] : Colors.blueGrey;

    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: Text(
              'Precision: ${settings.precision.toInt()} decimal places',
            ),
            subtitle: Slider(
              activeColor: sliderActiveColor,
              value: settings.precision,
              min: 0,
              max: 16,
              divisions: 16,
              label: settings.precision.toInt().toString(),
              onChanged: (value) {
                settings.setPrecision(value);
              },
            ),
          ),
          SwitchListTile(
            title: Text('Dark Theme'),
            activeColor: activeColor,
            activeTrackColor: activeTrackColor,
            value: settings.isDarkTheme,
            onChanged: settings.toggleDarkTheme,
          ),
          SwitchListTile(
            title: Text('Haptic Feedback'),
            activeColor: activeColor,
            activeTrackColor: activeTrackColor,
            value: settings.hapticFeedback,
            onChanged: settings.toggleHapticFeedback,
          ),

          // Multiplication Sign Selection
          ListTile(
            title: const Text('Multiplication Sign'),
            // Move your row here to align it to the right
            trailing: Wrap(
              // Wrap is safer than Row here to prevent overflow
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildMultiplyOption(
                  settings,
                  '\u00D7',
                  '\u00D7',
                  sliderActiveColor,
                ),
                const SizedBox(
                  width: 12,
                ), // Slightly tighter spacing for the trailing area
                _buildMultiplyOption(
                  settings,
                  '\u00B7',
                  '\u00B7',
                  sliderActiveColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiplyOption(
    SettingsProvider settings,
    String value,
    String displayText,
    Color? activeColor,
  ) {
    final isSelected = settings.multiplicationSign == value;

    return InkWell(
      onTap: () {
        settings.setMultiplicationSign(value);
      },
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: settings.multiplicationSign,
            activeColor: activeColor,
            onChanged: (value) {
              if (value != null) {
                settings.setMultiplicationSign(value);
              }
            },
          ),
          Text(
            displayText,
            style: TextStyle(
              fontSize: 24,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
