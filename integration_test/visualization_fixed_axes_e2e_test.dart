import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mathevo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/auth_test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('3D surface rotates inside fixed, data-scaled axes', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await preferences.setBool('mathverse.auth.signedIn', true);
    await preferences.setString('mathverse.profile.name', '3D Tester');
    await preferences.setString('mathverse.profile.username', '3d_tester');

    await tester.pumpWidget(
      MathevoApp(
        authApi: FakeAuthApi(registered: true),
        tokenStore: MemoryAuthTokenStore(refreshToken: '3d-test'),
      ),
    );
    await _pumpUntil(tester, find.byKey(const Key('nav-calculator')));
    await tester.tap(find.byKey(const Key('nav-calculator')));
    await tester.pumpAndSettle();
    await _selectMode(tester, 'Graphing');

    await _tap(tester, find.byKey(const ValueKey('function-key-x')));
    await _tap(tester, find.byKey(const ValueKey('basic-key-multiply')));
    await _tap(tester, find.byKey(const ValueKey('function-key-y')));
    await _open3D(tester);

    final semantics = find.byKey(const Key('visualization-chart-semantics'));
    final initialLabel = tester.widget<Semantics>(semantics).properties.label!;
    expect(initialLabel, contains('x axis from -6 to 6'));
    expect(initialLabel, contains('y axis from -6 to 6'));
    expect(initialLabel, contains('z axis from -60 to 60'));
    expect(initialLabel, contains('axes stay fixed'));

    final orientation = find.byKey(const Key('visualization-orientation'));
    final beforeDrag = tester.widget<Text>(orientation).data;
    await tester.drag(
      find.byKey(const Key('visualization-object-gesture')),
      const Offset(48, 30),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(orientation).data, isNot(beforeDrag));
    expect(
      tester.widget<Semantics>(semantics).properties.label,
      initialLabel,
      reason: 'Rotating the surface must leave the axis ranges unchanged.',
    );

    await tester.tap(find.text('Flip back to calculator'));
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('function-key-C')));
    await _tap(tester, find.byKey(const ValueKey('function-key-x')));
    await _tap(tester, find.byKey(const ValueKey('function-key-^')));
    await _tap(tester, find.byKey(const ValueKey('basic-key-2')));
    await _tap(tester, find.byKey(const ValueKey('basic-key-+')));
    await _tap(tester, find.byKey(const ValueKey('function-key-y')));
    await _tap(tester, find.byKey(const ValueKey('function-key-^')));
    await _tap(tester, find.byKey(const ValueKey('basic-key-2')));
    await _open3D(tester);

    final changedLabel = tester.widget<Semantics>(semantics).properties.label!;
    expect(changedLabel, contains('x axis from -6 to 6'));
    expect(changedLabel, contains('y axis from -6 to 6'));
    expect(changedLabel, contains('z axis from -20 to 80'));
    expect(changedLabel, isNot(initialLabel));
  });
}

Future<void> _open3D(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Flip to visualization'));
  await tester.pumpAndSettle();
  final threeDimensional = find.text('3D');
  if (tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .selected
          .single ==
      false) {
    await tester.tap(threeDimensional);
    await tester.pumpAndSettle();
  }
}

Future<void> _selectMode(WidgetTester tester, String mode) async {
  final finder = find.text(mode);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}
