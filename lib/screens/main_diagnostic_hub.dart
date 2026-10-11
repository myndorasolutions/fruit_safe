import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fruit_safe/providers/app_state.dart';
import 'package:fruit_safe/screens/splash_screen.dart';
import 'package:fruit_safe/screens/web_webcam.dart';
import 'package:fruit_safe/services/audio_service.dart';
import 'package:fruit_safe/widgets/developer_settings_dialog.dart';
import 'package:fruit_safe/services/reference_gallery.dart';
import 'package:fruit_safe/services/vision_service.dart';
import 'package:fruit_safe/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';

class MainDiagnosticHub extends StatefulWidget {
  const MainDiagnosticHub({super.key});

  @override
  State<MainDiagnosticHub> createState() => _MainDiagnosticHubState();
}

class _MainDiagnosticHubState extends State<MainDiagnosticHub> {
  final ImagePicker _picker = ImagePicker();
  bool _listening = false;
  bool _openingCamera = false;
  bool _showCalibrationNote = false;
  Timer? _chipTimer;

  @override
  void dispose() {
    _chipTimer?.cancel();
    AudioService.instance.stop();
    super.dispose();
  }

  Future<void> _snapPhoto() async {
    if (_openingCamera) return;
    if (!kIsWeb) {
      final bytes = await _readPickerImage(ImageSource.camera);
      if (bytes == null || !mounted) return;
      await _ingestImage(bytes, source: AppState.sourceCamera);
      return;
    }

    setState(() => _openingCamera = true);
    WebWebcamResult result;
    try {
      result = await showWebWebcam(context);
    } catch (_) {
      result = const WebWebcamResult.unavailable();
    } finally {
      if (mounted) setState(() => _openingCamera = false);
    }

    if (!mounted) return;
    if (result.status == WebWebcamStatus.captured && result.bytes != null) {
      await _ingestImage(result.bytes!, source: AppState.sourceCamera);
      return;
    }
    if (result.status != WebWebcamStatus.unavailable) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Live camera isn\'t available. Choose a photo instead.'),
      ),
    );
    final bytes = await _readPickerImage(ImageSource.camera);
    if (bytes == null || !mounted) return;
    await _ingestImage(bytes, source: AppState.sourceCamera);
  }

  Future<void> _pickGallery() async {
    final bytes = await _readPickerImage(
      ImageSource.gallery,
      failureMessage: 'Could not open the gallery. Try a reference photo.',
    );
    if (bytes == null || !mounted) return;
    await _ingestImage(bytes, source: AppState.sourceGallery);
  }

  Future<Uint8List?> _readPickerImage(
    ImageSource source, {
    String failureMessage =
        'Camera unavailable. Pick a gallery image or a reference photo.',
  }) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 70);
      if (file == null) return null;
      return await file.readAsBytes();
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
      );
      return null;
    }
  }

  Future<Uint8List?> _readReference(ReferencePreset preset) async {
    try {
      final data = await rootBundle.load(preset.assetPath);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load ${preset.label}.')),
      );
      return null;
    }
  }

  Future<void> _ingestImage(
    Uint8List bytes, {
    required String source,
    String? fruit,
    String? assetPath,
    ReferencePreset? preset,
  }) async {
    if (!mounted) return;
    final state = AppState.of(context);
    state.setCapturedImage(
      bytes,
      source: source,
      fruit: preset?.fruit ?? fruit,
      assetPath: preset?.assetPath ?? assetPath,
    );
    if (preset != null) {
      state.applyCalibratedReading(
        fruit: preset.fruit,
        sampleType: preset.sampleType,
        visualScore: preset.visualAnomalyScore,
        acetylenePpm: preset.acetylenePpm,
        vocPpm: preset.vocPpm,
        riskTier: preset.riskTier,
      );
    } else {
      final reading = await VisionService.instance.analyzeCapture(bytes);
      if (!mounted) return;
      final produce = fruit ?? AppState.of(context).activeFruit;
      AppState.of(context).applyCalibratedReading(
        fruit: produce,
        sampleType: VisionService.sampleTypeForScore(reading.visualAnomalyScore),
        visualScore: reading.visualAnomalyScore,
        acetylenePpm: reading.acetylenePpm,
        vocPpm: reading.vocPpm,
      );
    }
    if (!mounted) return;
    setState(() {});
    _showCalibrationChip();
  }

  void _showCalibrationChip() {
    _chipTimer?.cancel();
    setState(() => _showCalibrationNote = true);
    _chipTimer = Timer(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      setState(() => _showCalibrationNote = false);
    });
  }

  void _hideCalibrationChip() {
    _chipTimer?.cancel();
    if (!_showCalibrationNote || !mounted) return;
    setState(() => _showCalibrationNote = false);
  }

  /// Drops the in-progress photo, clears telemetry, and stops playback.
  Future<void> _endInspection() async {
    _hideCalibrationChip();
    if (_listening || _openingCamera) {
      setState(() {
        _listening = false;
        _openingCamera = false;
      });
    }
    if (!mounted) return;
    AppState.of(context).resetDiagnosticSession();
    await AudioService.instance.stop();
  }

  Future<void> _returnToWelcome() async {
    await _endInspection();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  Future<void> _confirmExitApplication() async {
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
    if (leave != true || !mounted) return;
    await _endInspection();
    if (!mounted) return;
    await _closeApplication();
  }

  Future<void> _closeApplication() async {
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

  void _openReferenceSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reference Library',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 460,
                  child: GridView.builder(
                    itemCount: ReferenceGallery.presets.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemBuilder: (context, index) {
                      final preset = ReferenceGallery.presets[index];
                      return _ReferenceTile(
                        preset: preset,
                        onTap: () async {
                          final bytes = await _readReference(preset);
                          if (bytes == null) return;
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                          await _ingestImage(
                            bytes,
                            source: AppState.sourceReference,
                            preset: preset,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleListening(String language) async {
    final next = !_listening;
    setState(() => _listening = next);
    if (next) {
      await AudioService.instance.playWelcome(language);
    } else {
      await AudioService.instance.stop();
    }
  }

  Future<void> _runDiagnostic(AppState state) async {
    final diagnostic = state.runDiagnostic();
    final language = state.selectedLanguage;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ScanDialog(),
    );
    final inferenceFuture = AudioService.instance.inferNATLASAdvice(
      fruit: diagnostic.fruitType,
      acetylene: diagnostic.acetylenePpm,
      voc: diagnostic.vocLevel,
      tier: diagnostic.status,
      language: language,
    );
    final visionFuture = state.imageSource == AppState.sourceReference
        ? Future<double>.value(state.visualAnomalyScore)
        : VisionService.instance.analyzeFruitVisualRisk(
            imageBytes: state.capturedImageBytes,
            sampleFruitName: state.selectedFruit,
          );
    final completed = await Future.wait<Object?>([
      Future<void>.delayed(const Duration(seconds: 2)),
      AudioService.instance.playScan(language),
      visionFuture,
      inferenceFuture,
    ]);
    final visualScore = completed[2]! as double;
    final advice = completed[3] as String?;
    if (!mounted) return;
    Navigator.of(context).pop();
    final fused = state.runDiagnostic(visualScore: visualScore);
    final result = advice == null
        ? fused
        : fused.copyWith(audioFeedbackText: advice, natlasProvidedText: true);
    if (!mounted) return;
    unawaited(
      AudioService.instance.playLocalResult(
        language: language,
        status: result.status,
      ),
    );
    await Navigator.pushNamed(context, '/results', arguments: result);
  }

  static const double _wideBreakpoint = 800;

  ButtonStyle _filledStyle({required bool wide, required Color background}) {
    return FilledButton.styleFrom(
      backgroundColor: background,
      foregroundColor: Colors.white,
      visualDensity: wide ? VisualDensity.compact : VisualDensity.standard,
      minimumSize: wide ? const Size(0, 44) : null,
      tapTargetSize: wide ? MaterialTapTargetSize.shrinkWrap : null,
    );
  }

  Widget _visionCard(BuildContext context, AppState state, {required bool wide}) {
    final textTheme = Theme.of(context).textTheme;
    final hasImage = state.capturedImageBytes != null || state.capturedAssetPath != null;
    final preview = _FruitPreview(
      fruit: state.selectedFruit,
      bytes: state.capturedImageBytes,
      assetPath: state.capturedAssetPath,
      expand: wide,
    );

    return _SectionCard(
      icon: Icons.visibility_outlined,
      title: 'Computer Vision',
      subtitle: 'Choose the produce in front of the lens.',
      expanded: wide,
      compact: wide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: wide ? 8 : 10,
            runSpacing: wide ? 8 : 10,
            children: [
              for (final fruit in AppState.fruits)
                ChoiceChip(
                  label: Text(fruit),
                  selected: state.selectedFruit == fruit,
                  visualDensity: wide ? VisualDensity.compact : VisualDensity.comfortable,
                  materialTapTargetSize: wide
                      ? MaterialTapTargetSize.shrinkWrap
                      : MaterialTapTargetSize.padded,
                  onSelected: (_) {
                    _hideCalibrationChip();
                    state.setFruit(fruit);
                    state.clearCapturedImage();
                  },
                  selectedColor: AppColors.harvestPureGreen,
                  labelStyle: textTheme.labelLarge?.copyWith(
                    color: state.selectedFruit == fruit ? Colors.white : AppColors.darkSlate,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          SizedBox(height: wide ? 10 : 16),
          if (wide) Expanded(child: preview) else preview,
          if (hasImage) ...[
            SizedBox(height: wide ? 8 : 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (state.imageSource != null) _SourceChip(label: state.imageSource!),
                _SourceChip(label: state.selectedFruit),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: wide
                    ? TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(48, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )
                    : null,
                onPressed: () {
                  _hideCalibrationChip();
                  state.clearCapturedImage();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retake / Clear'),
              ),
            ),
          ],
          SizedBox(height: wide ? 8 : 12),
          Wrap(
            spacing: wide ? 8 : 10,
            runSpacing: wide ? 8 : 10,
            children: [
              FilledButton.icon(
                style: _filledStyle(wide: wide, background: AppColors.harvestPureGreen),
                onPressed: _snapPhoto,
                icon: _openingCamera
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.camera_alt),
                label: const Text('Snap Photo'),
              ),
              FilledButton.icon(
                style: _filledStyle(wide: wide, background: AppColors.darkSlate),
                onPressed: _pickGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Upload from Gallery'),
              ),
              FilledButton.icon(
                style: _filledStyle(wide: wide, background: AppColors.nAtlasAmber),
                onPressed: _openReferenceSheet,
                icon: const Icon(Icons.collections),
                label: const Text('Reference Library'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _telemetryCard(
    BuildContext context,
    AppState appState, {
    required bool wide,
    required double micDiameter,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return _SectionCard(
      icon: Icons.sensors,
      title: 'Gas Telemetry',
      subtitle: appState.isSimulationMode
          ? 'Slide carbide and VOC readings from the simulated wand.'
          : 'Pair the E-Nose wand to stream live gas readings.',
      expanded: wide,
      compact: wide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showCalibrationNote && appState.calibrationMessage != null) ...[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: _CalibrationChip(
                key: ValueKey(appState.calibrationMessage),
                message: appState.calibrationMessage ??
                    'Auto-calibrated telemetry from visual inspection',
              ),
            ),
            SizedBox(height: wide ? 8 : 12),
          ],
          if (appState.isSimulationMode)
            ListenableBuilder(
              listenable: appState,
              builder: (context, _) {
                return _SimulationSliders(
                  compact: wide,
                  acetylene: appState.acetylenePpm.clamp(0.0, 100.0),
                  voc: appState.vocPpm.clamp(0.0, 500.0),
                  onAcetylene: (val) {
                    setState(() {
                      appState.acetylenePpm = val;
                    });
                  },
                  onVoc: (val) {
                    setState(() {
                      appState.vocPpm = val;
                    });
                  },
                );
              },
            )
          else
            const _BleDisconnected(),
          if (wide) const Spacer() else const SizedBox(height: 20),
          Center(
            child: _MicButton(
              listening: _listening,
              diameter: micDiameter,
              onPressed: () => _toggleListening(appState.selectedLanguage),
            ),
          ),
          SizedBox(height: wide ? 4 : 8),
          Center(
            child: Text(
              _listening ? 'N-ATLAS is listening' : 'N-ATLAS voice',
              style: textTheme.labelLarge?.copyWith(
                color: AppColors.nAtlasAmber,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: wide ? 8 : 16),
          FilledButton(
            style: wide
                ? FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size.fromHeight(44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                : null,
            onPressed: () => _runDiagnostic(appState),
            child: const Text('Run Diagnostic Check'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 56,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Back to Welcome Screen',
          onPressed: _returnToWelcome,
          icon: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.darkSlate,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
        ),
        title: const Text('Fruit-Safe', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new_rounded),
            tooltip: 'Exit Application',
            onPressed: _confirmExitApplication,
          ),
          IconButton(
            tooltip: 'Developer & N-ATLAS Settings',
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (_) => const DeveloperSettingsDialog(),
              );
            },
            icon: const Icon(Icons.tune_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _LanguageBadge(
                language: state.selectedLanguage,
                onTap: () => _openLanguageSheet(context),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Hardware Simulation Mode',
                    style: textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: state.isSimulationMode,
                  onChanged: state.setSimulationMode,
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
            final micDiameter = !wide ? 140.0 : (constraints.maxHeight < 640 ? 72.0 : 88.0);
            final vision = _visionCard(context, state, wide: wide);
            final telemetry = _telemetryCard(
              context,
              state,
              wide: wide,
              micDiameter: micDiameter,
            );
            if (wide) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 1, child: vision),
                    const SizedBox(width: 12),
                    Expanded(flex: 1, child: telemetry),
                  ],
                ),
              );
            }
            return ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: const {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      vision,
                      const SizedBox(height: 16),
                      telemetry,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

void _openLanguageSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _LanguageSheet(),
  );
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Market language',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final language in AppState.languages)
                  ChoiceChip(
                    label: Text(language),
                    selected: state.selectedLanguage == language,
                    selectedColor: AppColors.harvestPureGreen,
                    labelStyle: textTheme.labelLarge?.copyWith(
                      color: state.selectedLanguage == language
                          ? Colors.white
                          : AppColors.darkSlate,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => state.setLanguage(language),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge({required this.language, required this.onTap});

  final String language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Change Language',
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              language,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.expanded = false,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final bool expanded;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = compact ? textTheme.titleSmall : textTheme.titleMedium;
    final subtitleStyle = compact ? textTheme.bodySmall : textTheme.bodyMedium;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.harvestPureGreen, size: compact ? 20 : 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 4 : 6),
            Text(
              subtitle,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: subtitleStyle?.copyWith(
                color: AppColors.darkSlate.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: compact ? 10 : 16),
            if (expanded) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      AppState.sourceCamera => AppColors.harvestPureGreen,
      AppState.sourceGallery => AppColors.eNoseCyan,
      AppState.sourceReference => AppColors.nAtlasAmber,
      _ => AppColors.darkSlate,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile({required this.preset, required this.onTap});

  final ReferencePreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.asset(
                  preset.assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const ColoredBox(
                      color: AppColors.marketStone,
                      child: Center(
                        child: Icon(Icons.image_not_supported_outlined, size: 36),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                preset.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FruitPreview extends StatelessWidget {
  const _FruitPreview({
    required this.fruit,
    required this.bytes,
    required this.assetPath,
    this.expand = false,
  });

  final String fruit;
  final Uint8List? bytes;
  final String? assetPath;
  final bool expand;

  IconData get _icon {
    switch (fruit) {
      case 'Banana':
        return Icons.breakfast_dining_outlined;
      case 'Mango':
        return Icons.spa_outlined;
      default:
        return Icons.energy_savings_leaf_outlined;
    }
  }

  Widget _previewChild(BuildContext context) {
    if (assetPath != null) {
      return SizedBox.expand(
        child: Image.asset(
          assetPath!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.image_not_supported_outlined, size: 40),
            );
          },
        ),
      );
    }
    if (bytes != null) {
      return SizedBox.expand(
        child: Image.memory(bytes!, fit: BoxFit.cover),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(_icon, size: expand ? 36 : 40, color: AppColors.harvestPureGreen),
        const SizedBox(height: 8),
        Text(
          '$fruit sample preview',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: expand ? double.infinity : 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.marketStone,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkSlate.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: _previewChild(context),
    );
  }
}

class _CalibrationChip extends StatelessWidget {
  const _CalibrationChip({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.nAtlasAmber,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SimulationSliders extends StatelessWidget {
  const _SimulationSliders({
    required this.acetylene,
    required this.voc,
    required this.onAcetylene,
    required this.onVoc,
    this.compact = false,
  });

  final double acetylene;
  final double voc;
  final ValueChanged<double> onAcetylene;
  final ValueChanged<double> onVoc;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ReadingSlider(
          label: 'Acetylene (C2H2)',
          valueLabel: '${acetylene.toStringAsFixed(1)} ppm',
          value: acetylene,
          max: 100,
          activeColor: AppColors.nAtlasAmber,
          compact: compact,
          onChanged: onAcetylene,
        ),
        SizedBox(height: compact ? 2 : 8),
        _ReadingSlider(
          label: 'VOC',
          valueLabel: '${voc.toStringAsFixed(1)} ppm',
          value: voc,
          max: 500,
          activeColor: AppColors.eNoseCyan,
          compact: compact,
          onChanged: onVoc,
        ),
      ],
    );
  }
}

class _ReadingSlider extends StatefulWidget {
  const _ReadingSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.max,
    required this.activeColor,
    required this.onChanged,
    this.compact = false,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double max;
  final Color activeColor;
  final ValueChanged<double> onChanged;
  final bool compact;

  @override
  State<_ReadingSlider> createState() => _ReadingSliderState();
}

class _ReadingSliderState extends State<_ReadingSlider> with SingleTickerProviderStateMixin {
  late final AnimationController _glide;
  double _from = 0;
  double _to = 0;
  double? _queuedFrom;
  double? _queuedTo;
  double? _lastEmitted;
  bool _dragging = false;
  bool _glideQueued = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.value.clamp(0.0, widget.max);
    _from = initial;
    _to = initial;
    _glide = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))
      ..value = 1;
  }

  @override
  void didUpdateWidget(covariant _ReadingSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.value.clamp(0.0, widget.max);
    if (_dragging || (_lastEmitted != null && (next - _lastEmitted!).abs() < 0.05)) {
      _queuedFrom = null;
      _queuedTo = null;
      _from = next;
      _to = next;
      _lastEmitted = null;
      return;
    }
    if ((next - (_queuedTo ?? _to)).abs() < 0.05) return;
    _queuedFrom = _displayed;
    _queuedTo = next;
    if (_glideQueued) return;
    _glideQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _glideQueued = false;
      if (!mounted || _queuedTo == null || _dragging) {
        _queuedFrom = null;
        _queuedTo = null;
        return;
      }
      _from = _queuedFrom ?? _displayed;
      _to = _queuedTo!;
      _queuedFrom = null;
      _queuedTo = null;
      _glide.forward(from: 0);
    });
  }

  double get _displayed {
    final t = Curves.easeOut.transform(_glide.value);
    return (_from + (_to - _from) * t).clamp(0.0, widget.max);
  }

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = widget.compact ? textTheme.labelLarge : textTheme.titleSmall;
    return AnimatedBuilder(
      animation: _glide,
      builder: (context, _) {
        final shown = (_dragging ? widget.value : _displayed).clamp(0.0, widget.max);
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  widget.valueLabel,
                  style: labelStyle?.copyWith(
                    color: widget.activeColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: widget.compact ? 4 : null,
                overlayShape: widget.compact
                    ? const RoundSliderOverlayShape(overlayRadius: 14)
                    : null,
                thumbShape: widget.compact
                    ? const RoundSliderThumbShape(enabledThumbRadius: 8)
                    : null,
              ),
              child: Slider(
                value: shown,
                min: 0,
                max: widget.max,
                activeColor: widget.activeColor,
                onChangeStart: (_) {
                  setState(() {
                    _dragging = true;
                    _glide.stop();
                    final current = widget.value.clamp(0.0, widget.max);
                    _from = current;
                    _to = current;
                    _glide.value = 1;
                  });
                },
                onChangeEnd: (_) {
                  setState(() {
                    _dragging = false;
                    _lastEmitted = null;
                  });
                },
                onChanged: (val) {
                  _lastEmitted = val;
                  _from = val;
                  _to = val;
                  _glide.value = 1;
                  widget.onChanged(val);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BleDisconnected extends StatelessWidget {
  const _BleDisconnected();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: AppColors.statusDanger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'BLE Wand Disconnected',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.statusDanger,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.eNoseCyan,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No E-Nose wand is in range. Stay in simulation or pair hardware later.'),
              ),
            );
          },
          icon: const Icon(Icons.bluetooth_searching),
          label: const Text('Connect wand'),
        ),
      ],
    );
  }
}

class _MicButton extends StatefulWidget {
  const _MicButton({
    required this.listening,
    required this.onPressed,
    this.diameter = 140,
  });

  final bool listening;
  final VoidCallback onPressed;
  final double diameter;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    if (widget.listening) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant _MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listening && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.listening && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diameter = widget.diameter;
    final inner = diameter * (80 / 140);
    final iconSize = diameter * (36 / 140);
    return Semantics(
      button: true,
      label: widget.listening ? 'Stop N-ATLAS listening' : 'Start N-ATLAS listening',
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.listening) ...[
              _PulseRing(animation: _pulse, delay: 0, inner: inner, outer: diameter),
              _PulseRing(animation: _pulse, delay: 0.45, inner: inner, outer: diameter),
            ],
            Material(
              color: widget.listening ? AppColors.harvestPureGreen : AppColors.nAtlasAmber,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onPressed,
                child: SizedBox(
                  width: inner,
                  height: inner,
                  child: Icon(Icons.mic_rounded, color: Colors.white, size: iconSize),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({
    required this.animation,
    required this.delay,
    required this.inner,
    required this.outer,
  });

  final Animation<double> animation;
  final double delay;
  final double inner;
  final double outer;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = ((animation.value + delay) % 1.0);
        final size = inner + ((outer - inner) * t);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.nAtlasAmber.withValues(alpha: 1 - t),
              width: 3,
            ),
          ),
        );
      },
    );
  }
}

class _ScanDialog extends StatefulWidget {
  const _ScanDialog();

  @override
  State<_ScanDialog> createState() => _ScanDialogState();
}

class _ScanDialogState extends State<_ScanDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: AnimatedBuilder(
                  animation: _sweep,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _RadarPainter(_sweep.value),
                      child: const SizedBox.expand(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Fusing E-Nose VOC Telemetry & Computer Vision Analysis...',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.turn);

  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.eNoseCyan.withValues(alpha: 0.45);
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, ring);
    }
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      ring,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      ring,
    );

    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi / 2,
        colors: [
          AppColors.eNoseCyan.withValues(alpha: 0),
          AppColors.eNoseCyan.withValues(alpha: 0.55),
        ],
        transform: GradientRotation(turn * math.pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sweep);
    canvas.drawCircle(
      center,
      5,
      Paint()..color = AppColors.harvestPureGreen,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => oldDelegate.turn != turn;
}
