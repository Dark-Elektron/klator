// Regression tests for Tier 3 fix 3.6: cells and the active index are now
// written as a single atomic blob, with backward-compatible reads of the old
// two-key format.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klator/math_renderer/cell_persistence_service.dart';
import 'package:klator/math_renderer/renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saveAll round-trips cells and active index atomically', () async {
    final expressions = <List<MathNode>>[
      [LiteralNode(text: '1+2')],
      [LiteralNode(text: '3*4')],
      [LiteralNode(text: '5')],
    ];
    final answers = <String>['3', '12', '5'];

    await CellPersistence.saveAll(expressions, answers, 2);

    final cells = await CellPersistence.loadCells();
    final activeIndex = await CellPersistence.loadActiveIndex();

    expect(cells, hasLength(3));
    expect(cells[0].answer, equals('3'));
    expect(cells[1].answer, equals('12'));
    expect(activeIndex, equals(2));
  });

  test('active index is stored inside the single blob (one key)', () async {
    await CellPersistence.saveAll([
      [LiteralNode(text: '9')],
    ], ['9'], 0);

    final prefs = await SharedPreferences.getInstance();
    // The legacy separate key is not written by saveAll.
    expect(prefs.getInt('active_cell'), isNull);

    final raw = prefs.getString('calculator_cells');
    expect(raw, isNotNull);
    final decoded = jsonDecode(raw!);
    expect(decoded, isA<Map>());
    expect((decoded as Map)['activeIndex'], equals(0));
  });

  test('reads the legacy bare-list format and separate active_cell key',
      () async {
    // Old format: a bare JSON list under calculator_cells + a separate int.
    final legacyCells = jsonEncode([
      {'expression': '', 'answer': '42'},
    ]);
    SharedPreferences.setMockInitialValues({
      'calculator_cells': legacyCells,
      'active_cell': 1,
    });

    final cells = await CellPersistence.loadCells();
    final activeIndex = await CellPersistence.loadActiveIndex();

    expect(cells, hasLength(1));
    expect(cells.first.answer, equals('42'));
    expect(activeIndex, equals(1)); // falls back to the legacy key
  });

  test('returns empty list and index 0 when nothing is stored', () async {
    expect(await CellPersistence.loadCells(), isEmpty);
    expect(await CellPersistence.loadActiveIndex(), equals(0));
  });
}
