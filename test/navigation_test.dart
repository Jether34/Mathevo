import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathevo/gamification.dart';
import 'package:mathevo/main.dart';
import 'package:mathevo/math_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_test_support.dart';

void main() {
  testWidgets('fits compact and wide viewports without layout exceptions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('pages extend behind the floating capsule overlay', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 731));
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    final content = tester.getRect(find.byType(SingleChildScrollView).first);
    final capsule = tester.getRect(
      find.byKey(const Key('floating-navigation-capsule')),
    );
    expect(content.bottom, greaterThan(capsule.bottom));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('shows five persistent destinations and opens calculator', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());

    for (final label in [
      'home',
      'lessons',
      'calculator',
      'community',
      'settings',
    ]) {
      expect(find.byKey(Key('nav-$label')), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    expect(find.text('MathVerse'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-lessons')));
    await tester.pumpAndSettle();
    expect(find.text('Search learning materials'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-community')));
    await tester.pumpAndSettle();
    expect(
      find.text('Questions, ideas, and learning together'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('nav-settings')));
    await tester.pumpAndSettle();
    expect(find.text('App preferences and local data'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-calculator')));
    await tester.pumpAndSettle();
    expect(find.text('Basic'), findsOneWidget);
  });

  testWidgets(
    'dashboard provides the requested header, streak, and 4 workspaces',
    (tester) async {
      await tester.pumpWidget(_testApp());
      expect(find.byTooltip('History'), findsOneWidget);
      expect(find.byTooltip('Leaderboards'), findsOneWidget);
      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(find.text('DAY STREAK'), findsOneWidget);
      expect(find.text('Calculator'), findsOneWidget);
      expect(find.text('Graphing'), findsOneWidget);
      expect(find.text('Lessons'), findsWidgets);
      expect(find.text('Community'), findsWidgets);
      expect(find.text('Recent activity'), findsOneWidget);
      await tester.tap(find.byTooltip('Leaderboards'));
      await tester.pumpAndSettle();
      expect(find.text('Your ranking on this device'), findsOneWidget);
      Navigator.of(
        tester.element(find.text('Your ranking on this device')),
      ).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('See more'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See more'));
      await tester.pumpAndSettle();
      expect(find.text('Local rank #1 of 1'), findsOneWidget);
      expect(
        find.textContaining('Global rankings need shared player accounts'),
        findsOneWidget,
      );
    },
  );

  testWidgets('home history opens every saved computation in a full page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'mathverse.auth.signedIn': true,
      'mathverse.history.v1': jsonEncode([
        for (var index = 0; index < 12; index++)
          {
            'expression': 'history_expression_$index',
            'result': '$index',
            'createdAt': DateTime(2026, 10, 28, 12, index).toIso8601String(),
            'isExact': true,
          },
      ]),
    });
    await tester.pumpWidget(
      MathVerseApp(
        tokenStore: MemoryAuthTokenStore(
          accessToken: 'test-access',
          refreshToken: 'test-refresh',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
    expect(find.text('All 12 saved computations'), findsOneWidget);
    expect(find.text('history_expression_0'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('history_expression_11'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('history_expression_11'), findsOneWidget);
  });

  testWidgets('settings logout invokes the local sign-out action', (
    tester,
  ) async {
    var didLogOut = false;
    await tester.pumpWidget(_testApp(onLogOut: () => didLogOut = true));
    await tester.tap(find.byKey(const Key('nav-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    expect(didLogOut, isTrue);
  });

  testWidgets(
    'calculator categories, live results, and editable fraction input work',
    (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.tap(find.byKey(const Key('nav-calculator')));
      await tester.pumpAndSettle();
      expect(find.text('Scientific'), findsOneWidget);
      expect(find.text('Graphing'), findsOneWidget);
      await tester.tap(find.byKey(const Key('expression-edit-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('expression-input')),
        '3 * 5 + 7',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('=').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(find.byKey(const Key('calculation-result')))
            .properties
            .label,
        '≈ 22',
      );
      expect(find.text('Solution steps'), findsNothing);
      expect(find.text('Calculate'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('function-key-a/b')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('function-key-a/b')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byKey(const Key('fraction-insert')), findsOneWidget);
    },
  );

  testWidgets(
    'Lessons and Community show their filters with honest no-data states',
    (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.tap(find.byKey(const Key('nav-lessons')));
      await tester.pumpAndSettle();
      expect(find.text('Continue learning'), findsOneWidget);
      expect(find.text('Popular topics'), findsOneWidget);
      expect(find.byTooltip('Filter lessons'), findsOneWidget);
      await tester.tap(find.text('Order of Operations'));
      await tester.pumpAndSettle();
      expect(find.textContaining('What is 6 + 2'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('lesson-answer-input')),
        '16',
      );
      await tester.tap(find.text('Check answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-community')));
      await tester.pumpAndSettle();
      expect(find.text('For you'), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Top'), findsOneWidget);
      expect(find.byTooltip('Search filter'), findsOneWidget);
    },
  );
  testWidgets('Settings exposes profile, appearance, app, and about groups', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.tap(find.byKey(const Key('nav-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('App settings'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Change profile photo'), findsOneWidget);
    await tester.tap(find.text('Test learner'));
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Name'), findsOneWidget);
  });
}

Widget _testApp({VoidCallback onLogOut = _ignore}) => MaterialApp(
  home: TickerMode(
    enabled: false,
    child: MathVerseShell(
      records: [],
      onCalculation: _ignoreRecord,
      darkMode: false,
      onDarkModeChanged: _ignoreBool,
      onClearHistory: _ignore,
      onLogOut: onLogOut,
      progress: const UserProgress(),
      onDailyChallengeComplete: _ignoreProgress,
      onLearningActivity: _ignoreLearning,
      onLessonComplete: _ignoreLearning,
      displayName: 'Test learner',
      username: '@test',
      profileImagePath: null,
      onOpenHistory: _ignore,
      onOpenNotifications: _ignore,
      onPickProfilePhoto: _ignore,
      onSaveProfile: _ignoreProfile,
    ),
  ),
);

void _ignoreRecord(CalculationRecord record) {}
void _ignoreBool(bool value) {}
void _ignore() {}
Future<UserProgress> _ignoreProgress(DateTime date) async =>
    const UserProgress();
Future<UserProgress> _ignoreLearning(String lessonId) async =>
    const UserProgress();
Future<void> _ignoreProfile({
  String? name,
  String? username,
  String? imagePath,
}) async {}
