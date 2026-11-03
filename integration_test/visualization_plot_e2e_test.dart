import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mathevo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/auth_test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('finite-difference curve renders correctly in 2D and 3D', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await preferences.setBool('mathverse.auth.signedIn', true);
    await preferences.setString('mathverse.profile.name', 'Plot Tester');
    await preferences.setString('mathverse.profile.username', 'plot_tester');

    await tester.pumpWidget(
      MathevoApp(
        authApi: FakeAuthApi(registered: true),
        tokenStore: MemoryAuthTokenStore(refreshToken: 'plot-test-refresh'),
      ),
    );
    await _pumpUntil(tester, find.byKey(const Key('nav-calculator')));
    await tester.tap(find.byKey(const Key('nav-calculator')));
    await tester.pumpAndSettle();

    final graphMode = find.text('Graphing');
    await tester.ensureVisible(graphMode);
    await tester.tap(graphMode);
    await tester.pumpAndSettle();

    final editToggle = find.byKey(const Key('expression-edit-toggle'));
    await tester.tap(editToggle);
    await tester.pumpAndSettle();
    final expression = find.byKey(const Key('expression-input'));
    await tester.enterText(expression, '((3+0.01)^2-(3-0.01)^2)/(2*0.01)');
    await tester.pumpAndSettle();
    await tester.tap(editToggle);
    await tester.pumpAndSettle();

    final equals = find.text('=').last;
    await tester.ensureVisible(equals);
    await tester.tap(equals);
    await tester.pumpAndSettle();
    final result = tester.widget<Semantics>(
      find.byKey(const Key('calculation-result')),
    );
    expect(result.properties.label, contains('6'));

    final visualization = find.byTooltip('Flip to visualization');
    await tester.ensureVisible(visualization);
    await tester.tap(visualization);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('visualization-plot-toggle')));
    await tester.pumpAndSettle();

    final plotFrame = find.byKey(const Key('visualization-plot-frame'));
    final navigation = find.byKey(const Key('floating-navigation-capsule'));
    expect(tester.getSize(plotFrame).height, lessThanOrEqualTo(260));
    expect(
      tester.getRect(plotFrame).bottom,
      lessThan(tester.getRect(navigation).top),
      reason: 'The plot must remain above the floating navigation island.',
    );

    final chartSemantics = tester.widget<Semantics>(
      find.byKey(const Key('visualization-chart-semantics')),
    );
    expect(chartSemantics.properties.label, contains('2D plot'));
    expect(chartSemantics.properties.label, contains('secant'));
    expect(chartSemantics.properties.label, contains('6'));

    await tester.tap(find.text('3D'));
    await tester.pumpAndSettle();
    final chart3DSemantics = tester.widget<Semantics>(
      find.byKey(const Key('visualization-chart-semantics')),
    );
    expect(chart3DSemantics.properties.label, contains('3D plot'));
    expect(chart3DSemantics.properties.label, contains('no surface area'));
    expect(find.byKey(const Key('visualization-orientation')), findsOneWidget);

    final before = tester
        .widget<Text>(find.byKey(const Key('visualization-orientation')))
        .data;
    await tester.drag(
      find.byKey(const Key('visualization-canvas')),
      const Offset(45, 30),
    );
    await tester.pumpAndSettle();
    final after = tester
        .widget<Text>(find.byKey(const Key('visualization-orientation')))
        .data;
    expect(after, isNot(before));
    expect(after, contains('°'));
    expect(after, isNot(contains('Â')));
  });
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}
