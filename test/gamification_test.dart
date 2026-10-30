import 'package:flutter_test/flutter_test.dart';
import 'package:mathevo/gamification.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('daily challenge is deterministic and changes by date', () {
    final one = DailyChallenge.forDate(DateTime(2026, 10, 27));
    expect(
      DailyChallenge.forDate(DateTime(2026, 10, 27)).expression,
      one.expression,
    );
    expect(
      DailyChallenge.forDate(DateTime(2026, 10, 28)).dateKey,
      '2026-10-28',
    );
  });

  test('awards XP once and maintains consecutive and best streaks', () async {
    final repo = ProgressRepository();
    final first = DateTime(2026, 10, 27);
    var result = await repo.completeDailyChallenge(first);
    expect((result.xp, result.currentStreak, result.bestStreak), (10, 1, 1));
    result = await repo.completeDailyChallenge(first);
    expect(result.xp, 10);
    result = await repo.completeDailyChallenge(DateTime(2026, 10, 28));
    expect((result.xp, result.currentStreak, result.bestStreak), (20, 2, 2));
    result = await repo.completeDailyChallenge(DateTime(2026, 10, 31));
    expect((result.xp, result.currentStreak, result.bestStreak), (20, 1, 2));
    expect(result.streakOn(DateTime(2026, 10, 31)), 1);
    expect(result.streakOn(DateTime(2026, 11, 2)), 0);
    final reloaded = await repo.load();
    expect(reloaded.completedOn(first), isTrue);
    expect(reloaded.completedDays.length, 3);
  });

  test(
    'awards calculation and learning XP and decays after inactivity',
    () async {
      final repo = ProgressRepository();
      final start = DateTime(2026, 1, 1, 10);
      var progress = await repo.recordCalculation(start);
      expect(progress.xp, 3);
      progress = await repo.recordLearning(
        at: start.add(const Duration(days: 1)),
        lessonId: 'lesson-a',
      );
      expect(progress.xp, 8);
      progress = await repo.recordLearning(
        at: start.add(const Duration(days: 2)),
        lessonId: 'lesson-a',
        completed: true,
      );
      expect(progress.xp, 28);
      progress = await repo.recordLearning(
        at: start.add(const Duration(days: 2, minutes: 1)),
        lessonId: 'lesson-a',
        completed: true,
      );
      expect(progress.xp, 28);
      final lastActive = start.add(const Duration(days: 2, minutes: 1));

      progress = await repo.applyInactivityDecay(
        lastActive.add(const Duration(days: 2, hours: 23)),
      );
      expect(progress.xp, 28);
      progress = await repo.applyInactivityDecay(
        lastActive.add(const Duration(days: 3)),
      );
      expect(progress.xp, 18);
      progress = await repo.applyInactivityDecay(
        lastActive.add(const Duration(days: 6)),
      );
      expect(progress.xp, 8);

      progress = await repo.recordCalculation(
        lastActive.add(const Duration(days: 6, minutes: 1)),
      );
      expect(progress.xp, 11);
    },
  );
}
