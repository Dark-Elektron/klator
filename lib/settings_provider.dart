import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'math_engine.dart';
import 'renderer.dart';

enum NumberFormat {
  automatic, // Scientific only for very large/small numbers
  scientific, // Always scientific notation
  plain, // Commas, never scientific
}

class SettingsProvider extends ChangeNotifier {
  double _precision = 8;
  bool _isDarkTheme = false;
  bool _isRadians = false;
  bool _hapticFeedback = true;
  bool _soundEffects = false;
  String _multiplicationSign = '\u00D7'; // Default: ×
  NumberFormat _numberFormat = NumberFormat.automatic; // NEW

  // Getters
  double get precision => _precision;
  bool get isDarkTheme => _isDarkTheme;
  bool get isRadians => _isRadians;
  bool get hapticFeedback => _hapticFeedback;
  bool get soundEffects => _soundEffects;
  String get multiplicationSign => _multiplicationSign;
  NumberFormat get numberFormat => _numberFormat; // NEW

  // Static method to create provider with preloaded settings
  static Future<SettingsProvider> create() async {
    final provider = SettingsProvider._();
    await provider._loadSettings();
    return provider;
  }

  // Private constructor
  SettingsProvider._();

  SettingsProvider._forTesting({
    bool isDarkTheme = false,
    String multiplicationSign = '×',
    NumberFormat numberFormat = NumberFormat.automatic,
  })  : _isDarkTheme = isDarkTheme,
        _multiplicationSign = multiplicationSign,
        _numberFormat = numberFormat;

  // Factory constructor for tests
  static SettingsProvider forTesting({
    bool isDarkTheme = false,
    String multiplicationSign = '×',
    NumberFormat numberFormat = NumberFormat.automatic,
  }) {
    return SettingsProvider._forTesting(
      isDarkTheme: isDarkTheme,
      multiplicationSign: multiplicationSign,
      numberFormat: numberFormat,
    );
  }

  // Load all settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _precision = prefs.getDouble('precision') ?? 6;
    _isDarkTheme = prefs.getBool('isDarkTheme') ?? false;
    _isRadians = prefs.getBool('isRadians') ?? false;
    _hapticFeedback = prefs.getBool('hapticFeedback') ?? true;
    _soundEffects = prefs.getBool('soundEffects') ?? false;
    _multiplicationSign = prefs.getString('multiplicationSign') ?? '\u00D7';
    
    // Load number format
    String formatStr = prefs.getString('numberFormat') ?? 'automatic';
    _numberFormat = NumberFormat.values.firstWhere(
      (e) => e.name == formatStr,
      orElse: () => NumberFormat.automatic,
    );

    // Set global precision on load
    MathSolverNew.setPrecision(_precision.toInt());
    
    // Set global number format on load
    MathSolverNew.setNumberFormat(_numberFormat);

    // Set global multiplication sign on load
    MathTextStyle.setMultiplySign(_multiplicationSign);

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

  Future<void> setMultiplicationSign(String value) async {
    _multiplicationSign = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('multiplicationSign', value);

    // Update MathTextStyle
    MathTextStyle.setMultiplySign(value);
    notifyListeners();
  }

  // NEW: Set number format
  Future<void> setNumberFormat(NumberFormat value) async {
    _numberFormat = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('numberFormat', value.name);

    // Update MathSolverNew
    MathSolverNew.setNumberFormat(value);
    notifyListeners();
  }
}