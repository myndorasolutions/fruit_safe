import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fruit_safe/main.dart';
import 'package:fruit_safe/providers/app_state.dart';
import 'package:fruit_safe/screens/main_diagnostic_hub.dart';
import 'package:fruit_safe/theme/app_theme.dart';

void main() {
  testWidgets('Fruit-Safe app boots to splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FruitSafeApp());

    // Verify Fruit-Safe branding or title is present
    expect(find.textContaining('Fruit-Safe'), findsWidgets);
  });

  testWidgets('wide hub fits the viewport and calibration moves the sliders', (tester) async {
    final state = AppState();
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pumpAt(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        AppStateScope(
          notifier: state,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const MainDiagnosticHub(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    await pumpAt(const Size(1440, 900));
    expect(find.text('Computer Vision'), findsOneWidget);
    expect(find.text('Run Diagnostic Check'), findsOneWidget);

    state.autoCalibrateFromVisualScore(80);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('68 ppm'), findsOneWidget);
    expect(find.text('280 ppm'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final slider = find.byType(Slider).first;
    await tester.drag(slider, const Offset(80, 0));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await pumpAt(const Size(1280, 720));
    await pumpAt(const Size(1024, 640));
    await pumpAt(const Size(390, 844));
  });
}