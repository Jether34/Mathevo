import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mathevo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/auth_test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Draw mode reviews and solves a handwritten expression', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await preferences.setBool('mathverse.auth.signedIn', true);
    await preferences.setString('mathverse.profile.name', 'Draw Tester');
    await preferences.setString('mathverse.profile.username', 'draw_tester');

    await tester.pumpWidget(
      MathevoApp(
        authApi: FakeAuthApi(registered: true),
        tokenStore: MemoryAuthTokenStore(refreshToken: 'draw-test-refresh'),
      ),
    );
    await _pumpUntil(tester, find.byKey(const Key('nav-calculator')));
    await tester.tap(find.byKey(const Key('nav-calculator')));
    await _pumpForUi(tester);

    final drawMode = find.text('Draw');
    await tester.ensureVisible(drawMode);
    await tester.tap(drawMode);
    await _pumpForUi(tester);
    expect(find.text('Handwritten calculation'), findsOneWidget);
    expect(find.byKey(const Key('drawing-canvas')), findsOneWidget);
    expect(find.text('Automatic'), findsOneWidget);
    expect(find.text('Suggest'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(find.byTooltip('Pen'), findsOneWidget);
    expect(find.byTooltip('Highlighter'), findsOneWidget);
    expect(find.byTooltip('Stroke eraser'), findsOneWidget);

    await tester.tap(find.text('Suggest'));
    await _pumpForUi(tester);
    final canvas = tester.getRect(find.byKey(const Key('drawing-canvas')));
    final symbolCenter = canvas.center;
    await _drawPolyline(tester, [
      Offset(symbolCenter.dx - 12, symbolCenter.dy),
      Offset(symbolCenter.dx + 12, symbolCenter.dy),
    ]);
    await _drawPolyline(tester, [
      Offset(symbolCenter.dx, symbolCenter.dy - 12),
      Offset(symbolCenter.dx, symbolCenter.dy + 12),
    ]);
    await tester.ensureVisible(find.text('Read one symbol'));
    await tester.tap(find.text('Read one symbol'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const Key('stroke-symbol-+')),
      findsOneWidget,
      reason: 'The trained model should suggest plus for a clearly drawn plus.',
    );
    await tester.tap(find.byKey(const Key('stroke-symbol-+')));
    await _pumpForUi(tester);
    final symbolReview = tester.widget<TextField>(
      find.byKey(const Key('drawing-expression-review')),
    );
    expect(symbolReview.controller?.text, '+');
    await tester.tap(find.byTooltip('Clear'));
    await _pumpForUi(tester);

    final resetCanvas = tester.getRect(find.byKey(const Key('drawing-canvas')));
    final top = resetCanvas.top + resetCanvas.height * .34;
    final middle = resetCanvas.top + resetCanvas.height * .50;
    final bottom = resetCanvas.top + resetCanvas.height * .68;
    final left = resetCanvas.left + resetCanvas.width * .20;
    final right = resetCanvas.left + resetCanvas.width * .34;
    await _drawPolyline(tester, [
      Offset(left, top),
      Offset(right, top),
      Offset(right, middle),
      Offset(left, bottom),
      Offset(right, bottom),
    ]);
    final plusX = resetCanvas.left + resetCanvas.width * .48;
    await _drawPolyline(tester, [
      Offset(plusX - 12, middle),
      Offset(plusX + 12, middle),
    ]);
    await _drawPolyline(tester, [
      Offset(plusX, middle - 12),
      Offset(plusX, middle + 12),
    ]);
    final secondLeft = resetCanvas.left + resetCanvas.width * .61;
    final secondRight = resetCanvas.left + resetCanvas.width * .75;
    await _drawPolyline(tester, [
      Offset(secondLeft, top),
      Offset(secondRight, top),
      Offset(secondRight, middle),
      Offset(secondLeft, bottom),
      Offset(secondRight, bottom),
    ]);
    await _drawPolyline(tester, [
      Offset(resetCanvas.left + resetCanvas.width * .85, middle - 8),
      Offset(resetCanvas.left + resetCanvas.width * .94, middle - 8),
    ]);
    await _drawPolyline(tester, [
      Offset(resetCanvas.left + resetCanvas.width * .85, middle + 8),
      Offset(resetCanvas.left + resetCanvas.width * .94, middle + 8),
    ]);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1900)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Analyze'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1200)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.text('Expression recognized. Tap Solve to calculate it.'),
      findsOneWidget,
      reason: 'The emulator must recognize the drawn expression before review.',
    );

    final review = find.byKey(const Key('drawing-expression-review'));
    expect(review, findsOneWidget);
    await tester.enterText(review, '2+2=');
    await tester.tap(find.byTooltip('Solve corrected expression'));
    await _pumpForUi(tester);
    expect(find.text('4'), findsOneWidget);
    expect(
      find.text('Expression recognized. Tap Solve to calculate it.'),
      findsNothing,
    );

    await tester.enterText(review, 'x=3');
    await tester.tap(find.byTooltip('Solve corrected expression'));
    await _pumpForUi(tester);
    expect(find.text('x = 3'), findsOneWidget);
    await tester.enterText(review, 'x+20=');
    await tester.tap(find.byTooltip('Solve corrected expression'));
    await _pumpForUi(tester);
    expect(find.text('23'), findsOneWidget);

    await tester.tap(find.text('Use in calculator'));
    await _pumpForUi(tester);
    await tester.tap(find.byKey(const Key('expression-edit-toggle')));
    await _pumpForUi(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('expression-input')))
          .controller
          ?.text,
      'x+20=',
    );
  });
}

Future<void> _drawPolyline(WidgetTester tester, List<Offset> points) async {
  final gesture = await tester.startGesture(points.first);
  for (final point in points.skip(1)) {
    await gesture.moveTo(point);
  }
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 60));
}

Future<void> _pumpForUi(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}
