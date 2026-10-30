import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathevo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cloud signup duplicate redirects to cloud login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(480, 900));

    await tester.pumpWidget(
      MathVerseApp(
        authApi: FakeAuthApi(registered: true),
        tokenStore: MemoryAuthTokenStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('GET STARTED'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE YOUR ACCOUNT'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Alex Carter');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'saved@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.tap(find.text('CREATE ACCOUNT'));
    await _pumpUntil(tester, find.text('Login'));

    expect(find.text('Login'), findsOneWidget);
    expect(
      find.text('An account with this email already exists. Log in instead.'),
      findsOneWidget,
    );
    expect(find.text('saved@example.com'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('first launch walks onboarding, signup, login, and dashboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(480, 900));
    final authApi = FakeAuthApi();
    final tokenStore = MemoryAuthTokenStore();

    await tester.pumpWidget(
      MathVerseApp(authApi: authApi, tokenStore: tokenStore),
    );
    await tester.pumpAndSettle();
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(tester.getRect(find.byType(FilledButton)).bottom, greaterThan(830));

    await tester.tap(find.text('GET STARTED'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to MathVerse'), findsOneWidget);
    expect(tester.getRect(find.byType(FilledButton)).bottom, greaterThan(830));
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('What you'), findsOneWidget);
    expect(tester.getRect(find.byType(FilledButton)).bottom, greaterThan(830));
    await tester.tap(find.text('CREATE YOUR ACCOUNT'));
    await tester.pumpAndSettle();
    expect(find.text('Create new Account'), findsOneWidget);
    expect(tester.getRect(find.byType(FilledButton)).bottom, greaterThan(830));

    await tester.enterText(find.byType(TextFormField).at(0), 'Alex Carter');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'alex@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'mathpass123');
    await tester.tap(find.text('CREATE ACCOUNT'));
    await _pumpUntil(tester, find.byKey(const Key('nav-home')));
    expect(find.byKey(const Key('nav-home')), findsOneWidget);
    expect(find.text('MathVerse'), findsOneWidget);
    expect(await tokenStore.readRefreshToken(), isNotNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mathverse.auth.email'), isNull);
    expect(prefs.getString('mathverse.auth.passwordHash'), isNull);

    await tester.tap(find.byKey(const Key('nav-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to MathVerse'), findsOneWidget);
    expect(await tokenStore.readRefreshToken(), isNull);

    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Already have an account? Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'alex@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');
    await tester.tap(find.text('LOG IN'));
    await _pumpUntil(tester, find.text('Email or password is incorrect.'));
    await tester.enterText(find.byType(TextFormField).at(1), 'mathpass123');
    await tester.tap(find.text('LOG IN'));
    await _pumpUntil(tester, find.byKey(const Key('nav-home')));

    expect(prefs.getBool('mathverse.auth.signedIn'), isTrue);

    await tester.binding.setSurfaceSize(null);
  });
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  final errors = find
      .byKey(const Key('auth-error'))
      .evaluate()
      .map((element) => (element.widget as Text).data)
      .toList();
  fail('Timed out waiting for $finder; auth errors: $errors');
}
