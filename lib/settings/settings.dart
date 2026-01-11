import 'package:flutter/material.dart';
import 'settings_provider.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onShowTutorial;
  const SettingsScreen({super.key, this.onShowTutorial});

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
      body: Column(
        children: [
          // Main settings in scrollable area
          Expanded(
            child: ListView(
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
                
                // NEW: Number Format dropdown
                ListTile(
                  title: const Text('Number Format'),
                  subtitle: Text(_getNumberFormatDescription(settings.numberFormat)),
                  trailing: DropdownButton<NumberFormat>(
                    value: settings.numberFormat,
                    underline: const SizedBox(), // Remove underline
                    onChanged: (NumberFormat? newValue) {
                      if (newValue != null) {
                        settings.setNumberFormat(newValue);
                      }
                    },
                    items: NumberFormat.values.map((NumberFormat format) {
                      return DropdownMenuItem<NumberFormat>(
                        value: format,
                        child: Text(_getNumberFormatLabel(format)),
                      );
                    }).toList(),
                  ),
                ),
                
                SwitchListTile(
                  title: Text('Dark Theme'),
                  activeThumbColor: activeColor,
                  activeTrackColor: activeTrackColor,
                  value: settings.isDarkTheme,
                  onChanged: settings.toggleDarkTheme,
                ),
                SwitchListTile(
                  title: Text('Haptic Feedback'),
                  activeThumbColor: activeColor,
                  activeTrackColor: activeTrackColor,
                  value: settings.hapticFeedback,
                  onChanged: settings.toggleHapticFeedback,
                ),
                ListTile(
                  title: const Text('Multiplication Sign'),
                  trailing: RadioGroup<String>(
                    groupValue: settings.multiplicationSign,
                    onChanged: (String? value) {
                      if (value != null) {
                        settings.setMultiplicationSign(value);
                      }
                    },
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildMultiplyOption(
                          settings,
                          '\u00D7',
                          '\u00D7',
                          sliderActiveColor,
                        ),
                        const SizedBox(width: 12),
                        _buildMultiplyOption(
                          settings,
                          '\u00B7',
                          '\u00B7',
                          sliderActiveColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tutorial button at bottom
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('Show Tutorial'),
                subtitle: const Text('Learn how to use the calculator'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: isDark ? Colors.blueGrey[800] : Colors.blueGrey[50],
                onTap: () {
                  if (widget.onShowTutorial != null) {
                    widget.onShowTutorial!();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Helper to get display label for number format
  String _getNumberFormatLabel(NumberFormat format) {
    switch (format) {
      case NumberFormat.automatic:
        return 'Automatic';
      case NumberFormat.scientific:
        return 'Scientific';
      case NumberFormat.plain:
        return 'Plain (commas)';
    }
  }

  // NEW: Helper to get description for number format
  String _getNumberFormatDescription(NumberFormat format) {
    switch (format) {
      case NumberFormat.automatic:
        return 'Scientific for large/small numbers';
      case NumberFormat.scientific:
        return 'Always use scientific notation';
      case NumberFormat.plain:
        return 'Use commas (e.g., 1,000,000)';
    }
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
            activeColor: activeColor,
            // Remove groupValue and onChanged - RadioGroup handles these now
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