import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fruit_safe/models/diagnostic_data.dart';

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
  double latestVisualScore = 30;
  double latestApiScore = 0;
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

  /// Sets simulated wand readings from a visual anomaly score.
  void autoCalibrateFromVisualScore(double visualScore, {String? fruitName}) {
    final score = visualScore.clamp(0, 100).toDouble();
    if (score > 60) {
      acetylenePpm = 68;
      vocPpm = 280;
    } else if (score < 30) {
      acetylenePpm = 6;
      vocPpm = 45;
    } else {
      acetylenePpm = 35;
      vocPpm = 140;
    }
    if (fruitName != null && fruits.contains(fruitName)) {
      selectedFruit = fruitName;
    }
    latestVisualScore = score;
    latestApiScore = adulterationScore(visualScore: score);
    notifyListeners();
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
