import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:fruit_safe/providers/app_state.dart';
import 'package:fruit_safe/services/natlas_client.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Plays bundled vernacular clips, a remote N-ATLAS URI, or device speech.
class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  Completer<void>? _speechDone;

  /// Sovereign N-ATLAS inference URL. Clear it to stay on bundled clips.
  String? nAtlasEndpoint = 'https://api.ncair.nitda.gov.ng/v1/natlas/infer';

  /// Hugging Face token for the public N-ATLaS repository. Empty stays on bundled clips.
  String? hfApiToken;

  static const _hfTokenKey = 'hf_token';

  int _tokenEpoch = 0;

  bool get hasToken => hfApiToken != null && hfApiToken!.trim().isNotEmpty;

  static final Uri _huggingFaceEndpoint = Uri.parse(
    'https://router.huggingface.co/hf-inference/models/NCAIR1/N-ATLaS',
  );

  /// True when the last consult used bundled audio instead of the cloud.
  bool isUsingLocalFallback = true;

  /// Last market line, from the hub or the bundled dialect script.
  String? lastAdviceText;

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

  /// Loads the saved Hugging Face token. A missing key or plugin failure stays local.
  Future<void> loadSavedToken() async {
    final epoch = _tokenEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (epoch != _tokenEpoch) return;
      final saved = prefs.getString(_hfTokenKey)?.trim();
      if (epoch != _tokenEpoch) return;
      hfApiToken = (saved == null || saved.isEmpty) ? null : saved;
    } catch (error) {
      debugPrint('N-ATLAS HF token load failed: $error');
      if (epoch == _tokenEpoch) hfApiToken = null;
    }
  }

  /// Writes [token] to memory and preferences, or clears both when it is blank.
  Future<void> setHfToken(String? token) async {
    _tokenEpoch++;
    final trimmed = token?.trim();
    final clear = trimmed == null || trimmed.isEmpty;
    if (clear) {
      hfApiToken = null;
      isUsingLocalFallback = true;
    } else {
      hfApiToken = trimmed;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (clear) {
        await prefs.remove(_hfTokenKey);
      } else {
        await prefs.setString(_hfTokenKey, trimmed);
      }
    } catch (error) {
      debugPrint('N-ATLAS HF token save failed: $error');
    }
  }

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
      _disableWebBoundaries();
      await _tts.setLanguage('en-US');
    } catch (_) {
      // A missing voice must not block the landing screen.
    }
  }

  void _disableWebBoundaries() {
    if (!kIsWeb) return;
    _tts.setProgressHandler((text, start, end, word) {});
  }

  /// Web Speech crashes on Yoruba, Hausa, Igbo, and Pidgin boundary indexes.
  bool _canUseTts(String language, String text) {
    if (!kIsWeb) return true;
    if (language != 'English') return false;
    return _isAscii(text);
  }

  bool _isAscii(String text) {
    for (final unit in text.codeUnits) {
      if (unit > 127) return false;
    }
    return true;
  }

  void _startSpeak(String language, String text) {
    if (!_canUseTts(language, text)) {
      unawaited(_playAsset(_asset(language, 'welcome_prompt.mp3')));
      final done = _speechDone;
      if (done != null && !done.isCompleted) done.complete();
      return;
    }
    _disableWebBoundaries();
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

  /// Plays the bundled dialect result clip for [status] without device speech.
  Future<void> playLocalResult({
    required String language,
    required String status,
  }) {
    return _playAsset(_asset(language, _resultFile(status)));
  }

  /// Plays a remote clip when one is present. N-ATLAS text and local fallback
  /// use the bundled dialect result clip.
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
    if (natlasProvidedText || isUsingLocalFallback) {
      await _playAsset(_asset(language, _resultFile(status)));
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
      if (!_canUseTts(language, line)) {
        await playLocalResult(language: language, status: status);
        return;
      }
      await _speak(language, line);
      return;
    }

    await _playAsset(_asset(language, _resultFile(status)));
  }

  /// Asks the public N-ATLaS model for a short market warning.
  ///
  /// Returns null when the token is missing, the call times out, or the hub
  /// answers with an error. The caller then plays the bundled dialect clip.
  Future<String?> inferNATLASAdvice({
    required String fruit,
    required double acetylene,
    required double voc,
    required String tier,
    required String language,
  }) async {
    debugPrint(
      'N-ATLAS HF payload fruit=$fruit acetylene=$acetylene voc=$voc tier=$tier language=$language',
    );
    final token = hfApiToken?.trim();
    if (token == null || token.isEmpty) {
      debugPrint('N-ATLAS HF call skipped: token is empty.');
      return _localFail(fruit, tier, language);
    }

    final body = jsonEncode({
      'inputs':
          'Fruit-Safe Alert: $fruit, Acetylene: ${acetylene.toStringAsFixed(1)} ppm ($tier). Warning in $language: ',
      'parameters': {
        'max_new_tokens': 45,
        'return_full_text': false,
        'temperature': 0.3,
      },
    });

    try {
      final generated = await _postNatlas(
        endpoint: _huggingFaceEndpoint,
        token: token,
        body: body,
      );
      if (generated.statusCode != 200) {
        debugPrint('[AudioService] HF Status ${generated.statusCode}: ${generated.body}');
        return _localFail(fruit, tier, language);
      }
      final text = _generatedText(generated.body);
      if (text == null) {
        debugPrint('N-ATLAS HF response had no generated text. Using local fallback.');
        return _localFail(fruit, tier, language);
      }
      isUsingLocalFallback = false;
      lastAdviceText = text;
      return text;
    } on TimeoutException {
      debugPrint('N-ATLAS HF call timed out.');
      return _localFail(fruit, tier, language);
    } on http.ClientException catch (error) {
      if (kIsWeb) {
        debugPrint(
          '[AudioService] Web browser CORS policy restricted direct API call. To bypass in development, run with --web-browser-flag "--disable-web-security"',
        );
      } else {
        debugPrint('N-ATLAS HF exception: $error');
      }
      return _localFail(fruit, tier, language);
    } catch (error) {
      debugPrint('N-ATLAS HF exception: $error');
      return _localFail(fruit, tier, language);
    }
  }

  String? _localFail(String fruit, String tier, String language) {
    isUsingLocalFallback = true;
    lastAdviceText = _getLocalAdvisory(fruit, tier, language);
    return null;
  }

  String _getLocalAdvisory(String fruit, String tier, String language) {
    return AppState.localAdvisory(language, tier, fruit);
  }

  Future<http.Response> _postNatlas({
    required Uri endpoint,
    required String token,
    required String body,
  }) {
    return http
        .post(
          endpoint,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 4));
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

  String? _generatedText(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is List) {
        if (decoded.isEmpty) return null;
        return _nonEmptyText(decoded[0]['generated_text']);
      }
      if (decoded is Map) {
        if (decoded['error'] != null) return null;
        return _nonEmptyText(decoded['generated_text']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _nonEmptyText(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
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
    if (!_canUseTts(language, text)) return;
    try {
      _disableWebBoundaries();
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
