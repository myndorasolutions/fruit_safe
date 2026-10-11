import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fruit_safe/models/diagnostic_data.dart';
import 'package:fruit_safe/providers/app_state.dart';
import 'package:fruit_safe/screens/splash_screen.dart';
import 'package:fruit_safe/services/audio_service.dart';
import 'package:fruit_safe/services/audit_report_service.dart';
import 'package:fruit_safe/theme/app_theme.dart';
import 'package:fruit_safe/widgets/audit_report_modal.dart';

class DiagnosticResultsScreen extends StatelessWidget {
  const DiagnosticResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = ModalRoute.of(context)?.settings.arguments as DiagnosticData?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new_rounded),
            tooltip: 'Exit Application',
            onPressed: () => _confirmExitApplication(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Exit to Home',
            onPressed: () => _confirmExitToHome(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: data == null
                ? _MissingResult(onBack: () => _backToHub(context))
                : _ResultBody(data: data),
          ),
        ),
      ),
    );
  }

  void _backToHub(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacementNamed(context, '/hub');
  }
}

Future<void> _confirmExitToHome(BuildContext context) async {
  final exit = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Exit Diagnostic Session?'),
        content: const Text(
          'This will reset all current telemetry and return to the main language selection screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Exit'),
          ),
        ],
      );
    },
  );
  if (exit != true || !context.mounted) return;
  await _exitToWelcome(context);
}

Future<void> _exitToWelcome(BuildContext context) async {
  await AudioService.instance.stop();
  if (!context.mounted) return;
  AppState.of(context).resetDiagnosticSession();
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
    (route) => false,
  );
}

Future<void> _confirmExitApplication(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Exit Fruit-Safe?'),
        content: const Text(
          'This will shut down active sensor feeds, clear inspection telemetry, and terminate the session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Exit App'),
          ),
        ],
      );
    },
  );
  if (leave != true || !context.mounted) return;
  AppState.of(context).resetDiagnosticSession();
  await AudioService.instance.stop();
  if (!context.mounted) return;
  if (!kIsWeb) {
    try {
      await SystemNavigator.pop();
    } on Object {
      // The host already closed the window, or this platform ignores pop.
    }
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
    (route) => false,
  );
  if (messenger == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Session ended. You may now close this browser tab.'),
      ),
    );
  });
}

void _scanNewBatch(BuildContext context) {
  AudioService.instance.stop();
  AppState.of(context).resetDiagnosticSession();
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
    return;
  }
  Navigator.of(context).pushReplacementNamed('/hub');
}

class _MissingResult extends StatelessWidget {
  const _MissingResult({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'No diagnostic reading is available yet.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: onBack, child: const Text('Back to Diagnostic Hub')),
        ],
      ),
    );
  }
}

class _ResultBody extends StatefulWidget {
  const _ResultBody({required this.data});

  final DiagnosticData data;

  @override
  State<_ResultBody> createState() => _ResultBodyState();
}

class _ResultBodyState extends State<_ResultBody> {
  void _playAdvice() {
    final language = AppState.of(context).selectedLanguage;
    final data = widget.data;
    AudioService.instance.playLocalResult(
      language: language,
      status: data.status,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final textTheme = Theme.of(context).textTheme;
    final statusColor = AppColors.forStatus(data.status);
    final percent = data.apiScore.round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
      children: [
        Text(
          data.fruitType,
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Adulteration Probability Index',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.darkSlate.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: data.apiScore / 100,
                    strokeWidth: 12,
                    backgroundColor: AppColors.darkSlate.withValues(alpha: 0.08),
                    color: statusColor,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      'API',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.darkSlate.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Gas Outgassing (C\u2082H\u2082 + VOC): ${data.gasScore.round()}%',
          textAlign: TextAlign.center,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Optical Surface Anomaly (S\u1d65): ${data.visualScore.round()}%',
          textAlign: TextAlign.center,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.harvestPureGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.harvestPureGreen.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'Multi-Factor Sensor Fusion (75% Chemical / 25% Visual)',
              textAlign: TextAlign.center,
              style: textTheme.labelLarge?.copyWith(
                color: AppColors.harvestPureGreen,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            data.status,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Acetylene ${data.acetylenePpm.toStringAsFixed(0)} ppm  ·  VOC ${data.vocLevel.toStringAsFixed(0)} ppm',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () {
            final report = AuditReportData.fromDiagnostic(
              data,
              languageName: AppState.of(context).selectedLanguage,
            );
            showAuditReport(context, report);
          },
          icon: const Icon(Icons.receipt_long_rounded),
          label: const Text('View Official Audit Receipt / PDF'),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.record_voice_over, color: AppColors.nAtlasAmber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'N-ATLAS Sovereign Vernacular Speech',
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _NatlasStatusChip(
                  usingFallback: AudioService.instance.isUsingLocalFallback,
                ),
                const SizedBox(height: 12),
                Text(
                  data.audioFeedbackText,
                  style: textTheme.bodyLarge?.copyWith(height: 1.45),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _playAdvice,
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Play N-ATLAS Spoken Audio'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _ResultActions(onScanNewBatch: () => _scanNewBatch(context)),
      ],
    );
  }
}

class _ResultActions extends StatelessWidget {
  const _ResultActions({required this.onScanNewBatch});

  final VoidCallback onScanNewBatch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onScanNewBatch,
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Scan New Batch'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.darkSlate,
            side: const BorderSide(color: AppColors.darkSlate, width: 1.5),
          ),
          onPressed: () => _exitToWelcome(context),
          icon: const Icon(Icons.home_outlined),
          label: const Text(
            'Exit & Return to Welcome Screen',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _NatlasStatusChip extends StatelessWidget {
  const _NatlasStatusChip({required this.usingFallback});

  final bool usingFallback;

  static const _fallbackTip =
      'Open-market fallback enabled. Using bundled native dialect bitstream assets.';

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: usingFallback ? AppColors.statusWarning : AppColors.statusVerdant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        usingFallback
            ? 'N-ATLAS Edge Failsafe Active (Offline Resilient)'
            : 'N-ATLAS Sovereign Model Active (Hugging Face Hub)',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
    if (!usingFallback) return chip;
    return Tooltip(message: _fallbackTip, child: chip);
  }
}
