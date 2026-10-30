import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

String progressDayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class DailyChallenge {
  const DailyChallenge({required this.dateKey, required this.expression});

  factory DailyChallenge.forDate(DateTime date) {
    final seed = date.year * 372 + date.month * 31 + date.day;
    final a = 2 + seed % 8;
    final b = 2 + (seed ~/ 7) % 8;
    final c = 2 + (seed ~/ 13) % 7;
    final expression = switch (seed % 3) {
      0 => '($a + $b) * $c',
      1 => '$a * $b + $c',
      _ => '$a * $a - $b',
    };
    return DailyChallenge(
      dateKey: progressDayKey(date),
      expression: expression,
    );
  }

  final String dateKey;
  final String expression;
}

class UserProgress {
  const UserProgress({
    this.xp = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.completedDays = const {},
    this.completionTimes = const {},
    this.startedLearningIds = const {},
    this.completedLearningIds = const {},
    this.lastActiveAt,
    this.lastXpDecayAt,
  });

  final int xp;
  final int currentStreak;
  final int bestStreak;
  final Set<String> completedDays;
  final Map<String, DateTime> completionTimes;
  final Set<String> startedLearningIds;
  final Set<String> completedLearningIds;
  final DateTime? lastActiveAt;
  final DateTime? lastXpDecayAt;

  bool completedOn(DateTime date) =>
      completedDays.contains(progressDayKey(date));
  bool get isEmpty =>
      xp == 0 &&
      currentStreak == 0 &&
      completedDays.isEmpty &&
      startedLearningIds.isEmpty;

  int streakOn(DateTime date) {
    if (completedDays.isEmpty) return 0;
    final lastDay = (completedDays.toList()..sort()).last;
    final today = progressDayKey(date);
    final yesterday = progressDayKey(
      DateTime(date.year, date.month, date.day - 1),
    );
    return lastDay == today || lastDay == yesterday ? currentStreak : 0;
  }

  List<bool> get lastSevenDays => List.generate(7, (index) {
    final day = DateTime.now();
    final date = DateTime(day.year, day.month, day.day - 6 + index);
    return completedOn(date);
  });

  Map<String, Object?> toJson() => {
    'xp': xp,
    'currentStreak': currentStreak,
    'bestStreak': bestStreak,
    'completedDays': completedDays.toList()..sort(),
    'completionTimes': completionTimes.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    ),
    'startedLearningIds': startedLearningIds.toList()..sort(),
    'completedLearningIds': completedLearningIds.toList()..sort(),
    'lastActiveAt': lastActiveAt?.toIso8601String(),
    'lastXpDecayAt': lastXpDecayAt?.toIso8601String(),
  };

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    final completionTimes = ((json['completionTimes'] as Map?) ?? const {}).map(
      (key, value) => MapEntry(key as String, DateTime.parse(value as String)),
    );
    final completedAt = completionTimes.values.toList()..sort();
    final lastActiveAt = json['lastActiveAt'] == null
        ? (completedAt.isEmpty ? null : completedAt.last)
        : DateTime.parse(json['lastActiveAt'] as String);
    return UserProgress(
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      bestStreak: (json['bestStreak'] as num?)?.toInt() ?? 0,
      completedDays: ((json['completedDays'] as List?) ?? const [])
          .whereType<String>()
          .toSet(),
      completionTimes: completionTimes,
      startedLearningIds: ((json['startedLearningIds'] as List?) ?? const [])
          .whereType<String>()
          .toSet(),
      completedLearningIds:
          ((json['completedLearningIds'] as List?) ?? const [])
              .whereType<String>()
              .toSet(),
      lastActiveAt: lastActiveAt,
      lastXpDecayAt: json['lastXpDecayAt'] == null
          ? lastActiveAt
          : DateTime.parse(json['lastXpDecayAt'] as String),
    );
  }
}

class ProgressRepository {
  static const _key = 'mathverse.progress.v1';

  Future<UserProgress> load() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    if (value == null) return const UserProgress();
    try {
      return UserProgress.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } catch (_) {
      return const UserProgress();
    }
  }

  Future<UserProgress> applyInactivityDecay(DateTime now) async {
    final previous = await _read();
    final updated = _decay(previous, now);
    if (updated != previous) await _write(updated);
    return updated;
  }

  Future<UserProgress> recordCalculation(DateTime at) async {
    final previous = await _read();
    final current = _decay(previous, at);
    final updated = UserProgress(
      xp: current.xp + 3,
      currentStreak: current.currentStreak,
      bestStreak: current.bestStreak,
      completedDays: current.completedDays,
      completionTimes: current.completionTimes,
      startedLearningIds: current.startedLearningIds,
      completedLearningIds: current.completedLearningIds,
      lastActiveAt: at,
      lastXpDecayAt: at,
    );
    await _write(updated);
    return updated;
  }

  /// Awards 5 XP once when a lesson is started and 20 XP once on completion.
  Future<UserProgress> recordLearning({
    required DateTime at,
    required String lessonId,
    bool completed = false,
  }) async {
    final previous = await _read();
    final current = _decay(previous, at);
    final alreadyStarted = current.startedLearningIds.contains(lessonId);
    final alreadyCompleted = current.completedLearningIds.contains(lessonId);
    final award =
        (alreadyStarted ? 0 : 5) + (completed && !alreadyCompleted ? 20 : 0);
    final updated = UserProgress(
      xp: current.xp + award,
      currentStreak: current.currentStreak,
      bestStreak: current.bestStreak,
      completedDays: current.completedDays,
      completionTimes: current.completionTimes,
      startedLearningIds: {...current.startedLearningIds, lessonId},
      completedLearningIds: completed
          ? {...current.completedLearningIds, lessonId}
          : current.completedLearningIds,
      lastActiveAt: at,
      lastXpDecayAt: at,
    );
    await _write(updated);
    return updated;
  }

  Future<UserProgress> completeDailyChallenge(
    DateTime date, {
    DateTime? completedAt,
  }) async {
    final previous = await _read();
    final key = progressDayKey(date);
    final at = completedAt ?? date;
    final current = _decay(previous, at);
    if (current.completedDays.contains(key)) {
      if (current != previous) await _write(current);
      return current;
    }
    final lastDay = current.completedDays.isEmpty
        ? null
        : (current.completedDays.toList()..sort()).last;
    final yesterday = progressDayKey(
      DateTime(date.year, date.month, date.day - 1),
    );
    final streak = lastDay == yesterday ? previous.currentStreak + 1 : 1;
    final updated = UserProgress(
      xp: current.xp + 10,
      currentStreak: streak,
      bestStreak: streak > current.bestStreak ? streak : current.bestStreak,
      completedDays: {...current.completedDays, key},
      completionTimes: {...current.completionTimes, key: at},
      startedLearningIds: current.startedLearningIds,
      completedLearningIds: current.completedLearningIds,
      lastActiveAt: at,
      lastXpDecayAt: at,
    );
    await _write(updated);
    return updated;
  }

  Future<UserProgress> _read() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    if (value == null) return const UserProgress();
    try {
      return UserProgress.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } catch (_) {
      return const UserProgress();
    }
  }

  Future<void> _write(UserProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(progress.toJson()));
  }

  UserProgress _decay(UserProgress progress, DateTime now) {
    final anchor = progress.lastActiveAt;
    if (anchor == null || now.isBefore(anchor)) return progress;
    final elapsedPeriods = now.difference(anchor).inDays ~/ 3;
    final alreadyApplied = progress.lastXpDecayAt == null
        ? 0
        : (progress.lastXpDecayAt!.difference(anchor).inDays ~/ 3)
              .clamp(0, elapsedPeriods)
              .toInt();
    final newPeriods = elapsedPeriods - alreadyApplied;
    if (newPeriods <= 0) return progress;
    final decayBoundary = anchor.add(Duration(days: elapsedPeriods * 3));
    return UserProgress(
      xp: (progress.xp - 10 * newPeriods).clamp(0, 0x7fffffff).toInt(),
      currentStreak: progress.currentStreak,
      bestStreak: progress.bestStreak,
      completedDays: progress.completedDays,
      completionTimes: progress.completionTimes,
      startedLearningIds: progress.startedLearningIds,
      completedLearningIds: progress.completedLearningIds,
      lastActiveAt: anchor,
      lastXpDecayAt: decayBoundary,
    );
  }
}
