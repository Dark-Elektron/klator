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
            title: Text('Precision: ${settings.precision.toInt()} decimal places'),
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
          // SwitchListTile(
          //   title: Text('Angle Mode (Radians)'),
          //   activeColor: activeColor,
          //   activeTrackColor: activeTrackColor,
          //   value: settings.isRadians,
          //   onChanged: settings.toggleRadians,
          // ),
          SwitchListTile(
            title: Text('Haptic Feedback'),
            activeColor: activeColor,
            activeTrackColor: activeTrackColor,
            value: settings.hapticFeedback,
            onChanged: settings.toggleHapticFeedback,
          ),
          // SwitchListTile(
          //   title: Text('Sound Effects'),
          //   activeColor: activeColor,
          //   activeTrackColor: activeTrackColor,
          //   value: settings.soundEffects,
          //   onChanged: settings.toggleSoundEffects,
          // ),
        ],
      ),
    );
  }
}