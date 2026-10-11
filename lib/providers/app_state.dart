import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fruit_safe/models/diagnostic_data.dart';
import 'package:fruit_safe/services/vision_service.dart';

/// Shared market session: language, simulation inputs, and the last reading.
class AppState extends ChangeNotifier {
  static const languages = ['English', 'Hausa', 'Yoruba', 'Igbo', 'Pidgin'];
  static const fruits = ['Plantain', 'Banana', 'Mango'];
  static const sourceCamera = 'Live Camera Capture';
  static const sourceGallery = 'Device Gallery';
  static const sourceReference = 'Reference Library';

  bool isSimulationMode = true;
  String selectedLanguage = 'English';
  String selectedFruit = 'Plantain';
  double acetylenePpm = 12;
  double vocLevel = 40;

  /// VOC reading used by the gas sliders. Stored as [vocLevel] for diagnostics.
  double get vocPpm => vocLevel;
  set vocPpm(double value) => vocLevel = value;

  /// Produce under the lens. Same value as [selectedFruit].
  String get activeFruit => selectedFruit;
  set activeFruit(String value) {
    if (!fruits.contains(value)) return;
    selectedFruit = value;
  }

  double latestVisualScore = 30;

  /// Optical anomaly from the last calibration. Same value as [latestVisualScore].
  double get visualAnomalyScore => latestVisualScore;
  set visualAnomalyScore(double value) {
    latestVisualScore = value.clamp(0.0, 100.0).toDouble();
  }

  double latestApiScore = 0;
  String? activeRiskTier;
  String? calibrationMessage;
  Uint8List? capturedImageBytes;
  String? capturedAssetPath;
  String? imageSource;

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope is missing above this widget.');
    return scope!.notifier!;
  }

  void setSimulationMode(bool value) {
    if (isSimulationMode == value) return;
    isSimulationMode = value;
    notifyListeners();
  }

  void setLanguage(String language) {
    if (!languages.contains(language) || selectedLanguage == language) return;
    selectedLanguage = language;
    notifyListeners();
  }

  void setFruit(String fruit) {
    if (!fruits.contains(fruit) || selectedFruit == fruit) return;
    selectedFruit = fruit;
    notifyListeners();
  }

  void setAcetylenePpm(double value) {
    acetylenePpm = value.clamp(0, 100);
    notifyListeners();
  }

  void setVocLevel(double value) {
    vocLevel = value.clamp(0, 500);
    notifyListeners();
  }

  /// Updates both simulated wand readings in one notification.
  void setGasLevels(double acetylenePpm, double vocPpm) {
    final nextAcetylene = acetylenePpm.clamp(0, 100).toDouble();
    final nextVoc = vocPpm.clamp(0, 500).toDouble();
    if (this.acetylenePpm == nextAcetylene && vocLevel == nextVoc) return;
    this.acetylenePpm = nextAcetylene;
    vocLevel = nextVoc;
    notifyListeners();
  }

  /// Applies one calibrated sample and recomputes the adulteration index.
  void applyCalibratedReading({
    required String fruit,
    required String sampleType,
    required double visualScore,
    required double acetylenePpm,
    required double vocPpm,
    String? riskTier,
  }) {
    if (fruits.contains(fruit)) {
      selectedFruit = fruit;
    }
    latestVisualScore = visualScore.clamp(0.0, 100.0).toDouble();
    this.acetylenePpm = acetylenePpm.clamp(0.0, 100.0).toDouble();
    vocLevel = vocPpm.clamp(0.0, 500.0).toDouble();
    activeRiskTier = riskTier;
    latestApiScore = adulterationScore(visualScore: latestVisualScore);
    calibrationMessage = calibrationSentence(
      fruit: selectedFruit,
      sampleType: sampleType,
      acetylenePpm: this.acetylenePpm,
      vocPpm: vocLevel,
    );
    notifyListeners();
  }

  /// Sentence shown beside the gas sliders after a photo or reference pick.
  static String calibrationSentence({
    required String fruit,
    required String sampleType,
    required double acetylenePpm,
    required double vocPpm,
  }) {
    return 'Visual Auto-Calibration: $fruit $sampleType detected. '
        'Calibrated Acetylene to ${acetylenePpm.toStringAsFixed(1)} PPM, '
        'VOC to ${vocPpm.toStringAsFixed(1)} PPM.';
  }

  /// Sets simulated wand readings from a visual anomaly score.
  void autoCalibrateFromVisualScore(double visualScore, {String? fruitName}) {
    final reading = VisionService.readingForScore(visualScore);
    applyCalibratedReading(
      fruit: fruitName ?? selectedFruit,
      sampleType: VisionService.sampleTypeForScore(reading.visualAnomalyScore),
      visualScore: reading.visualAnomalyScore,
      acetylenePpm: reading.acetylenePpm,
      vocPpm: reading.vocPpm,
    );
  }

  /// Updates both simulated wand readings in one notification.
  void applyTelemetry({
    required double acetylenePpm,
    required double vocLevel,
  }) {
    final nextAcetylene = acetylenePpm.clamp(0, 100).toDouble();
    final nextVoc = vocLevel.clamp(0, 500).toDouble();
    if (this.acetylenePpm == nextAcetylene && this.vocLevel == nextVoc) return;
    this.acetylenePpm = nextAcetylene;
    this.vocLevel = nextVoc;
    notifyListeners();
  }

  void setCapturedImage(
    Uint8List bytes, {
    required String source,
    String? fruit,
    String? assetPath,
  }) {
    capturedImageBytes = bytes;
    capturedAssetPath = assetPath;
    imageSource = source;
    if (fruit != null && fruits.contains(fruit)) {
      selectedFruit = fruit;
    }
    notifyListeners();
  }

  void clearCapturedImage() {
    if (capturedImageBytes == null && capturedAssetPath == null && imageSource == null) {
      return;
    }
    capturedImageBytes = null;
    capturedAssetPath = null;
    imageSource = null;
    notifyListeners();
  }

  /// Clears the current batch so the next scan starts from a safe trace.
  void resetDiagnosticSession() {
    acetylenePpm = 4;
    vocLevel = 40;
    latestVisualScore = 0;
    latestApiScore = 0;
    activeRiskTier = null;
    calibrationMessage = null;
    capturedImageBytes = null;
    capturedAssetPath = null;
    imageSource = null;
    notifyListeners();
  }

  /// Chemical gas score. Acetylene is weighted as the carbide marker.
  double gasScore({double? acetylene, double? voc}) {
    final c2h2 = (acetylene ?? acetylenePpm).clamp(0, 100);
    final vocPpm = (voc ?? vocLevel).clamp(0, 500);
    final score = ((c2h2 / 100) * 0.7 + (vocPpm / 500) * 0.3) * 100;
    return score.clamp(0, 100).toDouble();
  }

  /// Fused Adulteration Probability Index: 75% gas, 25% visual.
  double adulterationScore({double? acetylene, double? voc, double visualScore = 30}) {
    final gas = gasScore(acetylene: acetylene, voc: voc);
    final visual = visualScore.clamp(0, 100);
    return ((0.75 * gas) + (0.25 * visual)).clamp(0, 100).toDouble();
  }

  String statusForScore(double score) {
    if (score < 25) return 'Safe';
    if (score <= 60) return 'Warning';
    return 'Danger';
  }

  DiagnosticData runDiagnostic({double? visualScore}) {
    final visual = (visualScore ?? latestVisualScore).clamp(0, 100).toDouble();
    final gas = gasScore();
    latestApiScore = ((0.75 * gas) + (0.25 * visual)).clamp(0.0, 100.0);
    final status = statusForScore(latestApiScore);
    return DiagnosticData(
      fruitType: selectedFruit,
      acetylenePpm: acetylenePpm,
      vocLevel: vocLevel,
      adulterationScore: latestApiScore,
      visualScore: visual,
      gasScore: gas,
      apiScore: latestApiScore,
      status: status,
      audioFeedbackText: _advice(selectedLanguage, status, selectedFruit),
    );
  }

  /// Bundled market warning used when cloud speech is unavailable.
  static String localAdvisory(String language, String status, String fruit) {
    return _advice(language, status, fruit);
  }

  static String _advice(String language, String status, String fruit) {
    final table = _adviceByLanguage[language] ?? _adviceByLanguage['English']!;
    return table[status]!.replaceAll('{fruit}', fruit);
  }

  static const _adviceByLanguage = <String, Map<String, String>>{
    'English': {
      'Safe':
          'This {fruit} reads within a safe carbide range. It is fit for the market.',
      'Warning':
          'This {fruit} shows a moderate adulteration risk. Recheck before you sell.',
      'Danger':
          'This {fruit} reads as toxic. Do not sell it. Keep it out of the market.',
    },
    'Hausa': {
      'Safe':
          'Wannan {fruit} yana da karbide mai lafiya. Ya dace da kasuwa.',
      'Warning':
          'Wannan {fruit} yana da haɗari matsakaici. Sake dubawa kafin sayarwa.',
      'Danger':
          'Wannan {fruit} yana da guba. Kada ka sayar da shi. Ka nisa da kasuwa.',
    },
    'Yoruba': {
      'Safe': '{fruit} yìí wà ní ìwọ̀n carbide tó dáa. Ó yẹ fún ọjà.',
      'Warning':
          '{fruit} yìí ní ewu àárín. Ṣàyẹ̀wò lẹ́ẹ̀kan síi kí o tó tà á.',
      'Danger': '{fruit} yìí jẹ́ olóró. Má tà á. Má gbé e wọlé ọjà.',
    },
    'Igbo': {
      'Safe': '{fruit} a dị n\'ókè carbide dị mma. Ọ dị mma maka ahịa.',
      'Warning': '{fruit} a nwere ihe ize ndụ dị n\'etiti. Lelee ya ọzọ tupu ire.',
      'Danger': '{fruit} a dị nsi. Erekwala ya. Ewepụ ya n\'ahịa.',
    },
    'Pidgin': {
      'Safe': 'Dis {fruit} carbide level dey safe. E fit enter market.',
      'Warning': 'Dis {fruit} get small risk. Check am again before you sell.',
      'Danger': 'Dis {fruit} dey toxic. No sell am. Comot am from market.',
    },
  };
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    required AppState notifier,
    required super.child,
    super.key,
  }) : super(notifier: notifier);
}
