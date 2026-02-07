import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../math_engine/math_engine.dart';
import '../math_renderer/renderer.dart';

enum NumberFormat {
  automatic, // Scientific only for very large/small numbers
  scientific, // Always scientific notation
  plain, // Commas, never scientific
}

enum ThemeType {
  classic,
  dark,
  softPink,
  pink,
  sunsetEmber,
  desertSand,
  digitalAmber,
  roseChic,
  honeyMustard,
}

class SettingsProvider extends ChangeNotifier {
  double _precision = 8;
  ThemeType _themeType = ThemeType.classic;
  bool _isRadians = false;
  bool _hapticFeedback = true;
  bool _soundEffects = false;
  String _multiplicationSign = '\u00D7'; // Default: ×
  NumberFormat _numberFormat = NumberFormat.automatic; // NEW
  bool _useScientificNotationButton = false;
  double _borderRadius = 0.0; // NEW: Global button styling

  // Getters
  double get precision => _precision;
  ThemeType get themeType => _themeType;
  bool get isDarkTheme =>
      _themeType != ThemeType.classic &&
      _themeType != ThemeType.softPink &&
      _themeType != ThemeType.desertSand &&
      _themeType != ThemeType.honeyMustard;
  bool get isRadians => _isRadians;
  bool get hapticFeedback => _hapticFeedback;
  bool get soundEffects => _soundEffects;
  String get multiplicationSign => _multiplicationSign;
  NumberFormat get numberFormat => _numberFormat; // NEW
  bool get useScientificNotationButton => _useScientificNotationButton;
  double get borderRadius => _borderRadius; // NEW

  // Static method to create provider with preloaded settings
  static Future<SettingsProvider> create() async {
    final provider = SettingsProvider._();
    await provider._loadSettings();
    return provider;
  }

  // Private constructor
  SettingsProvider._();

  SettingsProvider._forTesting({
    ThemeType themeType = ThemeType.classic,
    String multiplicationSign = '×',
    NumberFormat numberFormat = NumberFormat.automatic,
    bool useScientificNotationButton = false,
  }) : _themeType = themeType,
        _multiplicationSign = multiplicationSign,
        _numberFormat = numberFormat,
        _useScientificNotationButton = useScientificNotationButton;

  // Factory constructor for tests
  static SettingsProvider forTesting({
    ThemeType themeType = ThemeType.classic,
    String multiplicationSign = '×',
    NumberFormat numberFormat = NumberFormat.automatic,
    bool useScientificNotationButton = false,
  }) {
    return SettingsProvider._forTesting(
      themeType: themeType,
      multiplicationSign: multiplicationSign,
      numberFormat: numberFormat,
      useScientificNotationButton: useScientificNotationButton,
    );
  }

  // Load all settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _precision = prefs.getDouble('precision') ?? 6;

    // Load theme
    String? themeStr = prefs.getString('themeType');
    if (themeStr != null) {
      _themeType = ThemeType.values.firstWhere(
        (e) => e.name == themeStr,
        orElse: () => ThemeType.classic,
      );
    } else {
      // Migrate from old isDarkTheme bool if it exists
      bool oldIsDark = prefs.getBool('isDarkTheme') ?? false;
      _themeType = oldIsDark ? ThemeType.dark : ThemeType.classic;
    }

    _isRadians = prefs.getBool('isRadians') ?? false;
    _hapticFeedback = prefs.getBool('hapticFeedback') ?? true;
    _soundEffects = prefs.getBool('soundEffects') ?? false;
    _multiplicationSign = prefs.getString('multiplicationSign') ?? '\u00D7';
    _useScientificNotationButton =
        prefs.getBool('useScientificNotationButton') ?? false;
    _borderRadius =
        prefs.getDouble('borderRadius') ?? 0.0; // Match user preference

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

  Future<void> setThemeType(ThemeType value) async {
    _themeType = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeType', value.name);
    notifyListeners();
  }

  Future<void> toggleDarkTheme(bool value) async {
    await setThemeType(value ? ThemeType.dark : ThemeType.classic);
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

  Future<void> setUseScientificNotationButton(bool value) async {
    _useScientificNotationButton = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useScientificNotationButton', value);
    notifyListeners();
  }

  Future<void> setBorderRadius(double value) async {
    _borderRadius = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('borderRadius', value);
    notifyListeners();
  }
}
