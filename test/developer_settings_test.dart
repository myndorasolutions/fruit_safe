import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fruit_safe/services/audio_service.dart';
import 'package:fruit_safe/theme/app_theme.dart';
import 'package:fruit_safe/widgets/developer_settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AudioService.instance.setHfToken(null);
  });

  testWidgets('save stores the token and clear returns to bundled assets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => const DeveloperSettingsDialog(),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('N-ATLAS Developer Settings'), findsOneWidget);
    expect(find.text('Evaluator / Dev Mode'), findsOneWidget);
    expect(find.text('Defaulting to bundled dialect assets'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hf_ok');
    await tester.tap(find.text('Save Token'));
    await tester.pumpAndSettle();

    expect(AudioService.instance.hfApiToken, 'hf_ok');
    expect(AudioService.instance.hasToken, isTrue);
    expect(find.text('Hugging Face token saved'), findsOneWidget);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Hugging Face token active'), findsOneWidget);

    await tester.tap(find.text('Clear Token'));
    await tester.pumpAndSettle();
    expect(AudioService.instance.hasToken, isFalse);
    expect(find.text('Defaulting to bundled dialect assets'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('hf_token'), isNull);
  });
}
