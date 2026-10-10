/// A bundled produce photo the vision heuristic can score.
class ReferencePreset {
  const ReferencePreset({
    required this.label,
    required this.fruit,
    required this.assetPath,
  });

  final String label;
  final String fruit;
  final String assetPath;
}

/// Authentic market photos shipped with the app.
class ReferenceGallery {
  const ReferenceGallery._();

  static const presets = <ReferencePreset>[
    ReferencePreset(
      label: 'Plantain: Chemical Suspect (CaC2)',
      fruit: 'Plantain',
      assetPath: 'assets/images/plantain_carbide.jpg',
    ),
    ReferencePreset(
      label: 'Plantain: Naturally Ripened',
      fruit: 'Plantain',
      assetPath: 'assets/images/plantain_natural.jpg',
    ),
    ReferencePreset(
      label: 'Banana: Chemical Suspect (CaC2)',
      fruit: 'Banana',
      assetPath: 'assets/images/banana_carbide.jpg',
    ),
    ReferencePreset(
      label: 'Banana: Naturally Ripened',
      fruit: 'Banana',
      assetPath: 'assets/images/banana_natural.jpg',
    ),
    ReferencePreset(
      label: 'Mango: Chemical Suspect (CaC2)',
      fruit: 'Mango',
      assetPath: 'assets/images/mango_carbide.jpg',
    ),
    ReferencePreset(
      label: 'Mango: Naturally Ripened',
      fruit: 'Mango',
      assetPath: 'assets/images/mango_natural.jpg',
    ),
  ];
}
