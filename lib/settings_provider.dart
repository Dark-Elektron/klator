import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'evaluate_expression_new.dart';

class SettingsProvider extends ChangeNotifier {
  double _precision = 8;
  bool _isDarkTheme = false;
  bool _isRadians = false;
  bool _hapticFeedback = true;
  bool _soundEffects = false;

  // Getters
  double get precision => _precision;
  bool get isDarkTheme => _isDarkTheme;
  bool get isRadians => _isRadians;
  bool get hapticFeedback => _hapticFeedback;
  bool get soundEffects => _soundEffects;

  // Static method to create provider with preloaded settings
  static Future<SettingsProvider> create() async {
    final provider = SettingsProvider._();
    await provider._loadSettings();
    return provider;
  }

  // Private constructor
  SettingsProvider._();

  // Load all settings from SharedPreferences
Future<void> _loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  _precision = prefs.getDouble('precision') ?? 6;
  _isDarkTheme = prefs.getBool('isDarkTheme') ?? false;
  _isRadians = prefs.getBool('isRadians') ?? false;
  _hapticFeedback = prefs.getBool('hapticFeedback') ?? true;
  _soundEffects = prefs.getBool('soundEffects') ?? false;
  
  // Set global precision on load
  MathSolverNew.setPrecision(_precision.toInt());
  
  notifyListeners();
}

  // Setters with persistence
Future<void> setPrecision(double value) async {
  _precision = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble('precision', value);
  
  // Update the global precision in MathSolverNew
  MathSolverNew.setPrecision(value.toInt());
  
  notifyListeners();
}

  Future<void> toggleDarkTheme(bool value) async {
    _isDarkTheme = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', value);
    notifyListeners();
  }

  Future<void> toggleRadians(bool value) async {
    _isRadians = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isRadians', value);
    notifyListeners();
  }

  Future<void> toggleHapticFeedback(bool value) async {
    _hapticFeedback = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hapticFeedback', value);
    notifyListeners();
  }

  Future<void> toggleSoundEffects(bool value) async {
    _soundEffects = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEffects', value);
    notifyListeners();
  }
}