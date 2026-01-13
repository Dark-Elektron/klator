// cell_persistence.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../math_engine/math_expression_serializer.dart';
import 'renderer.dart';

class CellData {
  final String expressionJson;
  final String answer;

  CellData({required this.expressionJson, required this.answer});

  Map<String, dynamic> toJson() => {
    'expression': expressionJson,
    'answer': answer,
  };

  factory CellData.fromJson(Map<String, dynamic> json) => CellData(
    expressionJson: json['expression'] as String? ?? '',
    answer: json['answer'] as String? ?? '',
  );
}

class CellPersistence {
  static const String _key = 'calculator_cells';
  static const String _activeKey = 'active_cell';

  /// Save all cells
  static Future<void> saveCells(
    List<List<MathNode>> expressions,
    List<String> answers,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    List<Map<String, dynamic>> cells = [];
    for (int i = 0; i < expressions.length; i++) {
      cells.add(CellData(
        expressionJson: MathExpressionSerializer.serializeToJson(expressions[i]),
        answer: i < answers.length ? answers[i] : '',
      ).toJson());
    }

    await prefs.setString(_key, jsonEncode(cells));
  }

  /// Load all cells
  static Future<List<CellData>> loadCells() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString(_key);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => CellData.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Save active cell index
  static Future<void> saveActiveIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_activeKey, index);
  }

  /// Load active cell index
  static Future<int> loadActiveIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_activeKey) ?? 0;
  }

  /// Clear all saved data
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_activeKey);
  }
}