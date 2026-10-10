import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Estimates how chemically uniform a fruit surface looks.
class VisionService {
  VisionService._();

  static final VisionService instance = VisionService._();

  static const _sampleBaselines = <String, double>{
    'Banana': 45,
    'Plantain': 55,
    'Mango': 35,
  };

  /// Visual anomaly score from a photo, or a preset when no photo is attached.
  Future<double> analyzeFruitVisualRisk({
    Uint8List? imageBytes,
    String? sampleFruitName,
  }) async {
    if (imageBytes == null || imageBytes.isEmpty) {
      return _sampleBaselines[sampleFruitName] ?? 30;
    }

    await Future<void>.delayed(Duration.zero);
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return 30;
      final thumb = img.copyResize(decoded, width: 100, height: 100);
      return _scoreThumbnail(thumb);
    } catch (_) {
      return 30;
    }
  }

  double _scoreThumbnail(img.Image thumb) {
    var yellow = 0;
    var greenContrast = 0;
    final darkPerBlock = List<int>.filled(100, 0);
    const pixelCount = 100 * 100;

    for (var y = 0; y < thumb.height; y++) {
      for (var x = 0; x < thumb.width; x++) {
        final pixel = thumb.getPixel(x, y);
        final r = pixel.r.round();
        final g = pixel.g.round();
        final b = pixel.b.round();
        if (r > 180 && g > 160 && b < 80) yellow++;
        if (g > r + 40) greenContrast++;
        if (_isDarkOrBrown(r, g, b)) {
          darkPerBlock[(y ~/ 10) * 10 + (x ~/ 10)]++;
        }
      }
    }

    final yellowPct = yellow / pixelCount * 100;
    final greenPct = greenContrast / pixelCount * 100;
    final speckle = _speckleScore(darkPerBlock);
    final score = (0.55 * yellowPct) + (0.25 * (100 - speckle)) + (0.20 * greenPct);
    return score.clamp(0, 100);
  }

  bool _isDarkOrBrown(int r, int g, int b) {
    final dark = r < 90 && g < 80 && b < 70;
    final brown = r > 40 && r < 160 && g < r * 0.75 && b < 90;
    return dark || brown;
  }

  /// High when dark spots cluster in some blocks and not others.
  double _speckleScore(List<int> darkPerBlock) {
    final fractions = darkPerBlock.map((count) => count / 100).toList();
    final mean = fractions.reduce((sum, value) => sum + value) / fractions.length;
    var variance = 0.0;
    for (final fraction in fractions) {
      final delta = fraction - mean;
      variance += delta * delta;
    }
    variance /= fractions.length;
    return (variance / 0.25 * 100).clamp(0, 100);
  }
}
