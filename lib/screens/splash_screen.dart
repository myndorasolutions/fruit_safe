import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fruit_safe/providers/app_state.dart';
import 'package:fruit_safe/services/audio_service.dart';
import 'package:fruit_safe/theme/app_theme.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _confirmations = <String, String>{
    'English': 'English selected.',
    'Hausa': 'An zaɓi Harshen Hausa.',
    'Yoruba': 'A ti yan Èdè Yorùbá.',
    'Igbo': 'A họrọla Asụsụ Igbo.',
    'Pidgin': 'We don choose Pidgin.',
  };

  SpeechToText? _speech;
  var _speechReady = false;
  var _recording = false;
  var _leaving = false;
  Future<void>? _greeting;

  SpeechToText get _recognizer => _speech ??= SpeechToText();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AudioService.instance.warmUp();
    });
  }

  @override
  void dispose() {
    unawaited(_stopListening());
    super.dispose();
  }

  void _onFirstPointer() {
    _greeting ??= _playGreeting();
  }

  Future<void> _playGreeting() {
    return AudioService.instance.speakLine(
      'English',
      'Welcome to Fruit-Safe. Tap or speak your language.',
    );
  }

  Future<void> _onMic() async {
    if (_leaving) return;
    _onFirstPointer();
    final started = await _startListening();
    if (!mounted || _leaving || started) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tap English, Hausa, Yoruba, Igbo, or Pidgin to continue.'),
      ),
    );
  }

  Future<bool> _startListening() async {
    if (_speechReady && _recognizer.isListening) return true;
    try {
      if (!_speechReady) {
        _speechReady = await _recognizer.initialize(
          options: [SpeechToText.androidNoBluetooth],
        );
      }
      if (!_speechReady || !mounted || _leaving) return false;
      await _recognizer.listen(
        onResult: (result) {
          final match = _matchLanguage(result.recognizedWords);
          if (match == null) return;
          unawaited(_activate(match));
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
          contextualPhrases: AppState.languages,
        ),
      );
      if (mounted && !_leaving) {
        setState(() => _recording = true);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _stopListening() async {
    if (!_speechReady) return;
    try {
      await _recognizer.stop();
    } catch (_) {
      // Stopping before a session starts is safe to ignore.
    }
  }

  String? _matchLanguage(String heard) {
    final text = heard.toLowerCase();
    const names = <String, String>{
      'yoruba': 'Yoruba',
      'yorùbá': 'Yoruba',
      'hausa': 'Hausa',
      'igbo': 'Igbo',
      'pidgin': 'Pidgin',
      'english': 'English',
    };
    String? match;
    for (final entry in names.entries) {
      if (!text.contains(entry.key)) continue;
      if (match != null && match != entry.value) return null;
      match = entry.value;
    }
    return match;
  }

  Future<void> _activate(String language) async {
    if (_leaving || !mounted) return;
    _leaving = true;
    _onFirstPointer();
    await _stopListening();
    if (!mounted) return;
    AppState.of(context).setLanguage(language);
    final line = _confirmations[language];
    if (line != null) {
      unawaited(AudioService.instance.speakLine(language, line));
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/hub');
  }

  Future<void> _enterHub() async {
    if (_leaving) return;
    _leaving = true;
    await _stopListening();
    await AudioService.instance.stop();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/hub');
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onFirstPointer(),
      child: Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _BrandMark(),
                          const SizedBox(height: 28),
                          Text(
                            'Fruit-Safe',
                            textAlign: TextAlign.center,
                            style: textTheme.displaySmall?.copyWith(
                              color: AppColors.harvestPureGreen,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Pure Produce. Powered by Native AI.',
                            textAlign: TextAlign.center,
                            style: textTheme.titleMedium?.copyWith(
                              color: AppColors.darkSlate.withValues(alpha: 0.75),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _VoiceMicButton(
                            breathing: true,
                            recording: _recording,
                            onPressed: _leaving ? null : _onMic,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Voice Enabled',
                            textAlign: TextAlign.center,
                            style: textTheme.labelLarge?.copyWith(
                              color: AppColors.nAtlasAmber,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Market language',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final language in AppState.languages)
                                _LanguagePill(
                                  label: language,
                                  selected: state.selectedLanguage == language,
                                  onSelected: _leaving ? null : () => _activate(language),
                                ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _leaving ? null : _enterHub,
                              child: const Text('Enter Market Hub'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.harvestPureGreen,
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Icon(Icons.eco_rounded, color: Colors.white, size: 52),
    );
  }
}

class _VoiceMicButton extends StatefulWidget {
  const _VoiceMicButton({
    required this.breathing,
    required this.recording,
    required this.onPressed,
  });

  final bool breathing;
  final bool recording;
  final VoidCallback? onPressed;

  @override
  State<_VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<_VoiceMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    if (widget.breathing) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant _VoiceMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.breathing && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.breathing && _pulse.isAnimating) {
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
    return Semantics(
      button: true,
      label: widget.recording ? 'Listening for your language' : 'Voice Enabled',
      child: SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.breathing) ...[
              _VoicePulseRing(animation: _pulse, delay: 0),
              _VoicePulseRing(animation: _pulse, delay: 0.45),
            ],
            Material(
              color: AppColors.nAtlasAmber,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onPressed,
                child: const SizedBox(
                  width: 88,
                  height: 88,
                  child: Icon(Icons.mic_rounded, color: Colors.white, size: 40),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoicePulseRing extends StatelessWidget {
  const _VoicePulseRing({required this.animation, required this.delay});

  final Animation<double> animation;
  final double delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = (animation.value + delay) % 1.0;
        final size = 88 + (52 * t);
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

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.harvestPureGreen : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? AppColors.harvestPureGreen
              : AppColors.darkSlate.withValues(alpha: 0.15),
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onSelected,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppTheme.minTouchTarget,
            minHeight: AppTheme.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? Colors.white : AppColors.darkSlate,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
