import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CalculationRecord {
  const CalculationRecord({
    required this.expression,
    required this.result,
    required this.createdAt,
    this.isExact = false,
    this.calculationCount = 1,
  });

  final String expression;
  final String result;
  final DateTime createdAt;
  final bool isExact;
  final int calculationCount;

  Map<String, Object> toJson() => {
    'expression': expression,
    'result': result,
    'createdAt': createdAt.toIso8601String(),
    'isExact': isExact,
    'calculationCount': calculationCount,
  };

  factory CalculationRecord.fromJson(Map<String, dynamic> json) =>
      CalculationRecord(
        expression: json['expression'] as String,
        result: json['result'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        isExact: json['isExact'] as bool? ?? false,
        calculationCount: json['calculationCount'] as int? ?? 1,
      );
}

/// Private, device-local calculation history. No account or network is used.
class MathHistory {
  static const _storageKey = 'mathverse.history.v1';

  Future<List<CalculationRecord>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null) return const [];
    try {
      final values = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return values.map(CalculationRecord.fromJson).toList(growable: false);
    } on Object {
      // A damaged local history should not prevent the calculator from opening.
      return const [];
    }
  }

  Future<void> add(CalculationRecord record) async {
    final records = (await load()).toList();
    records.insert(0, record);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(records.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }
}
