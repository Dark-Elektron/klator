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

    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: Text('Precision: ${settings.precision.toInt()} decimal places'),
            subtitle: Slider(
              activeColor: Colors.blueGrey,
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
            activeColor: Colors.white,
            activeTrackColor: Colors.blueGrey,
            value: settings.isDarkTheme,
            onChanged: settings.toggleDarkTheme,
          ),
          SwitchListTile(
            title: Text('Angle Mode (Radians)'),
            activeColor: Colors.white,
            activeTrackColor: Colors.blueGrey,
            value: settings.isRadians,
            onChanged: settings.toggleRadians,
          ),
          SwitchListTile(
            title: Text('Haptic Feedback'),
            activeColor: Colors.white,
            activeTrackColor: Colors.blueGrey,
            value: settings.hapticFeedback,
            onChanged: settings.toggleHapticFeedback,
          ),
          SwitchListTile(
            title: Text('Sound Effects'),
            activeColor: Colors.white,
            activeTrackColor: Colors.blueGrey,
            value: settings.soundEffects,
            onChanged: settings.toggleSoundEffects,
          ),
        ],
      ),
    );
  }
}