import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fruit_safe/providers/app_state.dart';
import 'package:fruit_safe/services/audio_service.dart';
import 'package:fruit_safe/screens/diagnostic_results_screen.dart';
import 'package:fruit_safe/screens/main_diagnostic_hub.dart';
import 'package:fruit_safe/screens/splash_screen.dart';
import 'package:fruit_safe/theme/app_theme.dart';

void main() {
  runApp(const FruitSafeApp());
}

class FruitSafeApp extends StatefulWidget {
  const FruitSafeApp({super.key});

  @override
  State<FruitSafeApp> createState() => _FruitSafeAppState();
}

class _FruitSafeAppState extends State<FruitSafeApp> {
  final AppState _state = AppState();

  @override
  void initState() {
    super.initState();
    unawaited(AudioService.instance.loadSavedToken());
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: _state,
      child: MaterialApp(
        title: 'Fruit-Safe',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        initialRoute: '/',
        routes: {
          '/': (_) => const SplashScreen(),
          '/hub': (_) => const MainDiagnosticHub(),
          '/results': (_) => const DiagnosticResultsScreen(),
        },
      ),
    );
  }
}
