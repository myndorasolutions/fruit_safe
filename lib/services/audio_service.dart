import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:fruit_safe/services/natlas_client.dart';

/// Plays bundled vernacular clips, a remote N-ATLAS URI, or device speech.
class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  Completer<void>? _speechDone;

  /// Sovereign N-ATLAS inference URL. Clear it to stay on bundled clips.
  String? nAtlasEndpoint = 'https://api.ncair.nitda.gov.ng/v1/natlas/infer';

  /// True when the last consult used bundled audio instead of the cloud.
  bool isUsingLocalFallback = true;

  static const _folders = <String, String>{
    'English': 'en',
    'Hausa': 'ha',
    'Yoruba': 'yo',
    'Igbo': 'ig',
    'Pidgin': 'pcm',
  };

  static const _ttsCodes = <String, String>{
    'Hausa': 'ha',
    'Yoruba': 'yo',
    'Igbo': 'ig',
    'Pidgin': 'en-NG',
  };

  Future<void> playWelcome(String language) {
    return _playAsset(_asset(language, 'welcome_prompt.mp3'));
  }

  /// Speaks [text] and returns when playback ends, or after a short timeout.
  ///
  /// [FlutterTts.speak] is invoked before the first await so a pointer
  /// handler can satisfy browser autoplay rules.
  Future<void> speakLine(String language, String text) {
    final previous = _speechDone;
    if (previous != null && !previous.isCompleted) {
      previous.complete();
    }
    final done = Completer<void>();
    _speechDone = done;
    _tts.setCompletionHandler(() {
      if (!done.isCompleted) done.complete();
    });
    _startSpeak(language, text);
    return done.future.timeout(const Duration(seconds: 8), onTimeout: () {});
  }

  /// Constructs the speech engine without playing audio.
  void warmUp() {
    unawaited(_warm());
  }

  Future<void> _warm() async {
    try {
      await _tts.setLanguage('en-US');
    } catch (_) {
      // A missing voice must not block the landing screen.
    }
  }

  void _startSpeak(String language, String text) {
    if (language == 'English') {
      unawaited(_tts.setLanguage('en-US'));
      unawaited(_tts.speak(text));
      return;
    }
    unawaited(_speak(language, text));
  }

  Future<void> playScan(String language) {
    return _playAsset(_asset(language, 'scan_in_progress.mp3'));
  }

  /// Prefers a Sovereign N-ATLAS clip or line, then the bundled result MP3.
  Future<void> playResult({
    required String language,
    required String status,
    required String produceType,
    required double acetylenePpm,
    required double vocLevel,
    String? remoteAudioUri,
    String? spokenText,
    bool natlasProvidedText = false,
  }) async {
    if (remoteAudioUri != null && remoteAudioUri.isNotEmpty) {
      if (await _playUrl(remoteAudioUri)) return;
    }
    if (natlasProvidedText && spokenText != null && spokenText.trim().isNotEmpty) {
      await _speak(language, spokenText);
      return;
    }

    final inference = await consultNatlas(
      produceType: produceType,
      acetylenePpm: acetylenePpm,
      vocLevel: vocLevel,
      safetyTier: status,
      language: language,
    );
    if (inference != null && inference.hasAudio) {
      if (await _playUrl(inference.audioUri!)) return;
    }
    final line = inference?.hasText == true ? inference!.text! : spokenText;
    if (inference != null && inference.hasText && line != null) {
      await _speak(language, line);
      return;
    }

    await _playAsset(_asset(language, _resultFile(status)));
  }

  /// Calls Sovereign N-ATLAS, logs the attempt, and records local fallback.
  Future<NatlasInference?> consultNatlas({
    required String produceType,
    required double acetylenePpm,
    required double vocLevel,
    required String safetyTier,
    required String language,
  }) async {
    final payload = {
      'produceType': produceType,
      'acetylenePpm': acetylenePpm,
      'vocLevel': vocLevel,
      'safetyTier': safetyTier,
      'language': language,
    };
    final endpoint = nAtlasEndpoint?.trim();
    debugPrint('N-ATLAS request payload: $payload');
    debugPrint('N-ATLAS target URI: ${endpoint == null || endpoint.isEmpty ? '(empty)' : endpoint}');
    if (endpoint == null || endpoint.isEmpty) {
      debugPrint('N-ATLAS call skipped: endpoint is empty.');
      isUsingLocalFallback = true;
      return null;
    }

    final Uri target;
    try {
      target = Uri.parse(endpoint);
    } catch (error) {
      debugPrint('N-ATLAS exception: $error');
      isUsingLocalFallback = true;
      return null;
    }

    final attempt = await NatlasClient.instance.infer(
      endpoint: target,
      produceType: produceType,
      acetylenePpm: acetylenePpm,
      vocLevel: vocLevel,
      safetyTier: safetyTier,
      language: language,
    );
    if (attempt.errorMessage != null) {
      debugPrint('N-ATLAS exception: ${attempt.errorMessage}');
      isUsingLocalFallback = true;
      return null;
    }

    debugPrint('N-ATLAS HTTP status: ${attempt.statusCode}');
    final inference = attempt.inference;
    final usable = inference != null && (inference.hasAudio || inference.hasText);
    isUsingLocalFallback = !usable;
    if (!usable) {
      debugPrint('N-ATLAS response had no audio URI or text. Using local fallback.');
    }
    return usable ? inference : null;
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {
      // A player that never started can reject stop.
    }
    try {
      await _tts.stop();
    } catch (_) {
      // Stopping a silent engine is not a user-facing failure.
    }
  }

  String _asset(String language, String fileName) {
    final folder = _folders[language] ?? 'en';
    return 'audio/$folder/$fileName';
  }

  String _resultFile(String status) {
    switch (status) {
      case 'Warning':
        return 'result_warning.mp3';
      case 'Danger':
        return 'result_danger.mp3';
      default:
        return 'result_safe.mp3';
    }
  }

  Future<void> _playAsset(String path) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(path));
    } catch (_) {
      // A missing vernacular file must not crash the market flow.
    }
  }

  Future<bool> _playUrl(String url) async {
    try {
      await _player.stop();
      await _player.play(UrlSource(url));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _speak(String language, String text) async {
    try {
      await _tts.stop();
      if (language == 'English') {
        await _tts.setLanguage('en-US');
        await _tts.speak(text);
        return;
      }
      final code = _ttsCodes[language];
      if (code != null && await _isAvailable(code)) {
        await _tts.setLanguage(code);
        await _tts.speak(text);
        return;
      }
      await _tts.setLanguage('en-US');
      await _tts.speak(text);
    } catch (_) {
      // Web Speech and device voices can reject a language. Stay silent.
    }
  }

  Future<bool> _isAvailable(String code) async {
    try {
      final result = await _tts.isLanguageAvailable(code);
      return result == true || result == 1;
    } catch (_) {
      return false;
    }
  }
}
