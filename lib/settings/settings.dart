import 'package:flutter/material.dart';
import 'settings_provider.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';

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
    final colors = AppColors.of(context);

    // Theme-aware colors for sliders and switches
    final activeColor = colors.accent;
    final activeTrackColor = colors.accent.withValues(alpha: 0.5);
    final sliderActiveColor = colors.accent;

    return Scaffold(
      backgroundColor: colors.displayBackground,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: colors.textPrimary)),
        backgroundColor: colors.displayBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: Column(
        children: [
          // Main settings in scrollable area
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                ListTile(
                  title: Text(
                    'Precision: ${settings.precision.toInt()} decimal places',
                    style: TextStyle(color: colors.textPrimary),
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

                // Number Format dropdown
                ListTile(
                  title: Text(
                    'Number Format',
                    style: TextStyle(color: colors.textPrimary),
                  ),
                  subtitle: Text(
                    _getNumberFormatDescription(settings.numberFormat),
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  trailing: DropdownButton<NumberFormat>(
                    value: settings.numberFormat,
                    dropdownColor: colors.containerBackground,
                    style: TextStyle(color: colors.textPrimary),
                    underline: const SizedBox(),
                    onChanged: (NumberFormat? newValue) {
                      if (newValue != null) {
                        settings.setNumberFormat(newValue);
                      }
                    },
                    items:
                        NumberFormat.values.map((NumberFormat format) {
                          return DropdownMenuItem<NumberFormat>(
                            value: format,
                            child: Text(
                              _getNumberFormatLabel(format),
                              style: TextStyle(color: colors.textPrimary),
                            ),
                          );
                        }).toList(),
                  ),
                ),

                ListTile(
                  title: Text(
                    'Theme',
                    style: TextStyle(color: colors.textPrimary),
                  ),
                  trailing: DropdownButton<ThemeType>(
                    value: settings.themeType,
                    dropdownColor: colors.containerBackground,
                    style: TextStyle(color: colors.textPrimary),
                    underline: const SizedBox(),
                    onChanged: (ThemeType? newValue) {
                      if (newValue != null) {
                        settings.setThemeType(newValue);
                      }
                    },
                    items:
                        ThemeType.values.map((ThemeType theme) {
                          return DropdownMenuItem<ThemeType>(
                            value: theme,
                            child: Text(
                              _getThemeLabel(theme),
                              style: TextStyle(color: colors.textPrimary),
                            ),
                          );
                        }).toList(),
                  ),
                ),
                SwitchListTile(
                  title: Text(
                    'Haptic Feedback',
                    style: TextStyle(color: colors.textPrimary),
                  ),
                  activeThumbColor: activeColor,
                  activeTrackColor: activeTrackColor,
                  value: settings.hapticFeedback,
                  onChanged: settings.toggleHapticFeedback,
                ),
                ListTile(
                  title: Text(
                    'Multiplication Sign',
                    style: TextStyle(color: colors.textPrimary),
                  ),
                  trailing: RadioGroup<String>(
                    groupValue: settings.multiplicationSign,
                    onChanged: (val) {
                      if (val != null) settings.setMultiplicationSign(val);
                    },
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildMultiplyOption(
                          settings,
                          '×',
                          '×',
                          sliderActiveColor,
                          colors.textPrimary,
                        ),
                        const SizedBox(width: 12),
                        _buildMultiplyOption(
                          settings,
                          '·',
                          '·',
                          sliderActiveColor,
                          colors.textPrimary,
                        ),
                      ],
                    ),
                  ),
                ),

                ListTile(
                  title: Text(
                    'E / % Button',
                    style: TextStyle(color: colors.textPrimary),
                  ),
                  trailing: RadioGroup<bool>(
                    groupValue: settings.useScientificNotationButton,
                    onChanged: (val) {
                      if (val != null) {
                        settings.setUseScientificNotationButton(val);
                      }
                    },
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildNotationOption(
                          settings,
                          false,
                          '%',
                          sliderActiveColor,
                          colors.textPrimary,
                        ),
                        const SizedBox(width: 12),
                        _buildNotationOption(
                          settings,
                          true,
                          '\u1D07',
                          sliderActiveColor,
                          colors.textPrimary,
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
                leading: Icon(Icons.school_outlined, color: colors.textPrimary),
                title: Text(
                  'Show Tutorial',
                  style: TextStyle(color: colors.textPrimary),
                ),
                subtitle: Text(
                  'Learn how to use the calculator',
                  style: TextStyle(color: colors.textSecondary),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: colors.textPrimary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: colors.containerBackground,
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

  // Helper to get display label for number format
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

  // Helper to get description for number format
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
    Color? textColor,
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
          Radio<String>(value: value, activeColor: activeColor),
          Text(
            displayText,
            style: TextStyle(
              fontSize: 24,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotationOption(
    SettingsProvider settings,
    bool value,
    String displayText,
    Color? activeColor,
    Color? textColor,
  ) {
    final isSelected = settings.useScientificNotationButton == value;

    return InkWell(
      onTap: () {
        settings.setUseScientificNotationButton(value);
      },
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<bool>(value: value, activeColor: activeColor),
          Text(
            displayText,
            style: TextStyle(
              fontSize: 24,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // Helper to get display label for themes
  String _getThemeLabel(ThemeType theme) {
    switch (theme) {
      case ThemeType.classic:
        return 'Classic';
      case ThemeType.dark:
        return 'Dark';
      case ThemeType.softPink:
        return 'Petal Soft Pink';
      case ThemeType.pink:
        return 'Midnight Peony';
      case ThemeType.sunsetEmber:
        return 'Sunset Ember';
      case ThemeType.desertSand:
        return 'Desert Sand';
      case ThemeType.digitalAmber:
        return 'Digital Amber';
      case ThemeType.roseChic:
        return 'Rose Chic';
      case ThemeType.honeyMustard:
        return 'Honey Mustard';
      case ThemeType.forestMoss:
        return 'Forest Moss';
    }
  }
}
