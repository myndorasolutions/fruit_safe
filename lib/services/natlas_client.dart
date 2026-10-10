import 'dart:convert';

import 'package:http/http.dart' as http;

/// Spoken or streamed reply from the Sovereign N-ATLAS inference endpoint.
class NatlasInference {
  const NatlasInference({this.audioUri, this.text});

  final String? audioUri;
  final String? text;

  bool get hasAudio => audioUri != null && audioUri!.isNotEmpty;
  bool get hasText => text != null && text!.trim().isNotEmpty;
}

/// One inference attempt, including the HTTP status or the failure message.
class NatlasAttempt {
  const NatlasAttempt({this.inference, this.statusCode, this.errorMessage});

  final NatlasInference? inference;
  final int? statusCode;
  final String? errorMessage;
}

/// Configurable client for the N-ATLAS produce-safety inference API.
class NatlasClient {
  NatlasClient({Uri? endpoint, http.Client? httpClient})
    : endpoint = endpoint ?? _defaultEndpoint,
      _http = httpClient ?? http.Client();

  static final NatlasClient instance = NatlasClient();

  static final Uri _defaultEndpoint = Uri.parse(
    'https://api.ncair.nitda.gov.ng/v1/natlas/infer',
  );

  final Uri endpoint;
  final http.Client _http;

  Future<NatlasAttempt> infer({
    Uri? endpoint,
    required String produceType,
    required double acetylenePpm,
    required double vocLevel,
    required String safetyTier,
    required String language,
  }) async {
    final target = endpoint ?? this.endpoint;
    try {
      final response = await _http
          .post(
            target,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'produceType': produceType,
              'acetylenePpm': acetylenePpm,
              'vocLevel': vocLevel,
              'safetyTier': safetyTier,
              'language': language,
            }),
          )
          .timeout(const Duration(seconds: 2));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return NatlasAttempt(statusCode: response.statusCode);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return NatlasAttempt(statusCode: response.statusCode);
      }
      final body = Map<String, dynamic>.from(decoded);
      final audioUri = _firstString(body, const [
        'audioUri',
        'audio_uri',
        'audioUrl',
        'audio',
        'uri',
      ]);
      final text = _firstString(body, const ['text', 'advice', 'message']);
      if ((audioUri == null || audioUri.isEmpty) && (text == null || text.trim().isEmpty)) {
        return NatlasAttempt(statusCode: response.statusCode);
      }
      return NatlasAttempt(
        statusCode: response.statusCode,
        inference: NatlasInference(audioUri: audioUri, text: text),
      );
    } catch (error) {
      return NatlasAttempt(errorMessage: error.toString());
    }
  }

  static String? _firstString(Map<String, dynamic> body, List<String> keys) {
    for (final key in keys) {
      final value = body[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}
