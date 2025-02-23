import 'package:flutter/material.dart';

class SettingsProvider with ChangeNotifier {
  double _precision = 6;
  bool _isDarkTheme = false;
  bool _isRadians = true;
  bool _hapticFeedback = true;
  bool _soundEffects = false;

  double get precision => _precision;
  bool get isDarkTheme => _isDarkTheme;
  bool get isRadians => _isRadians;
  bool get hapticFeedback => _hapticFeedback;
  bool get soundEffects => _soundEffects;

  void setPrecision(double value) {
    _precision = value;
    notifyListeners();
  }

  void toggleDarkTheme(bool value) {
    _isDarkTheme = value;
    notifyListeners();
  }

  void toggleRadians(bool value) {
    _isRadians = value;
    notifyListeners();
  }

  void toggleHapticFeedback(bool value) {
    _hapticFeedback = value;
    notifyListeners();
  }

  void toggleSoundEffects(bool value) {
    _soundEffects = value;
    notifyListeners();
  }
}
