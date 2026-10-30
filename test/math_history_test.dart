import 'package:flutter_test/flutter_test.dart';
import 'package:mathevo/math_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stores, reloads all, and clears local records', () async {
    SharedPreferences.setMockInitialValues({});
    final history = MathHistory();
    final record = CalculationRecord(
      expression: '2 + 2',
      result: '4',
      createdAt: DateTime.utc(2026, 1, 1),
      isExact: true,
    );

    await history.add(record);
    final loaded = await history.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.expression, record.expression);
    expect(loaded.single.result, record.result);
    expect(loaded.single.createdAt, record.createdAt);
    expect(loaded.single.isExact, isTrue);

    for (var index = 1; index <= 100; index++) {
      await history.add(
        CalculationRecord(
          expression: '$index',
          result: '$index',
          createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
        ),
      );
    }
    final allRecords = await history.load();
    expect(allRecords, hasLength(101));
    expect(allRecords.first.expression, '100');
    expect(allRecords.last.expression, record.expression);

    await history.clear();
    expect(await history.load(), isEmpty);
  });
}
