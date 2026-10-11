/// A bundled produce photo with research-grounded gas telemetry.
class ReferencePreset {
  const ReferencePreset({
    required this.id,
    required this.label,
    required this.fruit,
    required this.sampleType,
    required this.assetPath,
    required this.visualAnomalyScore,
    required this.acetylenePpm,
    required this.vocPpm,
    required this.riskTier,
  });

  final String id;
  final String label;

  /// Produce category: Plantain, Banana, or Mango.
  final String fruit;

  /// Ripening class shown in the calibration sentence.
  final String sampleType;
  final String assetPath;

  /// Visual anomaly score (Sv), 0–100.
  final double visualAnomalyScore;

  /// Acetylene (C2H2) target in ppm.
  final double acetylenePpm;

  /// Total VOC target in ppm.
  final double vocPpm;

  /// Research label: SAFE, WARNING, or DANGER.
  final String riskTier;
}

/// Authentic market photos shipped with the app.
class ReferenceGallery {
  const ReferenceGallery._();

  static const presets = <ReferencePreset>[
    ReferencePreset(
      id: 'plantain_carbide',
      label: 'Plantain: Chemical Suspect (CaC2)',
      fruit: 'Plantain',
      sampleType: 'Chemical Suspect',
      assetPath: 'assets/images/plantain_carbide.jpg',
      visualAnomalyScore: 84,
      acetylenePpm: 68.5,
      vocPpm: 310,
      riskTier: 'DANGER',
    ),
    ReferencePreset(
      id: 'plantain_natural',
      label: 'Plantain: Naturally Ripened',
      fruit: 'Plantain',
      sampleType: 'Naturally Ripened',
      assetPath: 'assets/images/plantain_natural.jpg',
      visualAnomalyScore: 18,
      acetylenePpm: 4.2,
      vocPpm: 42,
      riskTier: 'SAFE',
    ),
    ReferencePreset(
      id: 'banana_carbide',
      label: 'Banana: Chemical Suspect (CaC2)',
      fruit: 'Banana',
      sampleType: 'Chemical Suspect',
      assetPath: 'assets/images/banana_carbide.jpg',
      visualAnomalyScore: 88,
      acetylenePpm: 72,
      vocPpm: 345,
      riskTier: 'DANGER',
    ),
    ReferencePreset(
      id: 'banana_natural',
      label: 'Banana: Naturally Ripened',
      fruit: 'Banana',
      sampleType: 'Naturally Ripened',
      assetPath: 'assets/images/banana_natural.jpg',
      visualAnomalyScore: 14,
      acetylenePpm: 3.5,
      vocPpm: 38,
      riskTier: 'SAFE',
    ),
    ReferencePreset(
      id: 'mango_carbide',
      label: 'Mango: Chemical Suspect (CaC2)',
      fruit: 'Mango',
      sampleType: 'Chemical Suspect',
      assetPath: 'assets/images/mango_carbide.jpg',
      visualAnomalyScore: 79,
      acetylenePpm: 58,
      vocPpm: 260,
      riskTier: 'WARNING',
    ),
    ReferencePreset(
      id: 'mango_natural',
      label: 'Mango: Naturally Ripened',
      fruit: 'Mango',
      sampleType: 'Naturally Ripened',
      assetPath: 'assets/images/mango_natural.jpg',
      visualAnomalyScore: 22,
      acetylenePpm: 5.1,
      vocPpm: 50,
      riskTier: 'SAFE',
    ),
  ];
}
