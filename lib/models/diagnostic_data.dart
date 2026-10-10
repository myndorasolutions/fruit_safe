/// Result of one Fruit-Safe diagnostic check.
class DiagnosticData {
  const DiagnosticData({
    required this.fruitType,
    required this.acetylenePpm,
    required this.vocLevel,
    required this.adulterationScore,
    required this.visualScore,
    required this.gasScore,
    required this.apiScore,
    required this.status,
    required this.audioFeedbackText,
    this.remoteAudioUri,
    this.natlasProvidedText = false,
  });

  final String fruitType;

  /// Acetylene (C2H2) reading in parts per million.
  final double acetylenePpm;

  /// Total volatile organic compound reading in parts per million.
  final double vocLevel;

  /// Adulteration Probability Index, 0–100. Same value as [apiScore].
  final double adulterationScore;

  /// Optical surface anomaly, 0–100.
  final double visualScore;

  /// Chemical gas score from acetylene and VOC, 0–100.
  final double gasScore;

  /// Fused Adulteration Probability Index, 0–100.
  final double apiScore;

  /// One of `Safe`, `Warning`, or `Danger`.
  final String status;

  /// N-ATLAS spoken advice in the active market language.
  final String audioFeedbackText;

  /// Remote clip returned by Sovereign N-ATLAS, when the endpoint provides one.
  final String? remoteAudioUri;

  /// True when [audioFeedbackText] came from N-ATLAS rather than the local map.
  final bool natlasProvidedText;

  DiagnosticData copyWith({
    String? audioFeedbackText,
    String? remoteAudioUri,
    bool? natlasProvidedText,
  }) {
    return DiagnosticData(
      fruitType: fruitType,
      acetylenePpm: acetylenePpm,
      vocLevel: vocLevel,
      adulterationScore: adulterationScore,
      visualScore: visualScore,
      gasScore: gasScore,
      apiScore: apiScore,
      status: status,
      audioFeedbackText: audioFeedbackText ?? this.audioFeedbackText,
      remoteAudioUri: remoteAudioUri ?? this.remoteAudioUri,
      natlasProvidedText: natlasProvidedText ?? this.natlasProvidedText,
    );
  }
}
