import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Gas targets derived from a visual anomaly score.
class VisualReading {
  const VisualReading({
    required this.visualAnomalyScore,
    required this.acetylenePpm,
    required this.vocPpm,
  });

  /// Visual anomaly score (Sv), 0–100.
  final double visualAnomalyScore;

  /// Acetylene (C2H2) in ppm.
  final double acetylenePpm;

  /// Total VOC in ppm.
  final double vocPpm;
}

/// Estimates how chemically uniform a fruit surface looks.
class VisionService {
  VisionService._();

  static final VisionService instance = VisionService._();

  static const _sampleBaselines = <String, double>{
    'Banana': 45,
    'Plantain': 55,
    'Mango': 35,
  };

  /// Maps a visual anomaly score onto simulated wand readings.
  ///
  /// Acetylene is `(Sv / 100) * 80`, clamped to 2–85 ppm.
  /// VOC is `(Sv / 100) * 380`, clamped to 25–420 ppm.
  static VisualReading readingForScore(double visualAnomalyScore) {
    final sv = visualAnomalyScore.clamp(0.0, 100.0).toDouble();
    return VisualReading(
      visualAnomalyScore: sv,
      acetylenePpm: (sv / 100.0 * 80.0).clamp(2.0, 85.0).toDouble(),
      vocPpm: (sv / 100.0 * 380.0).clamp(25.0, 420.0).toDouble(),
    );
  }

  /// Ripening class for a photo that has no preset metadata.
  static String sampleTypeForScore(double visualAnomalyScore) {
    if (visualAnomalyScore >= 60) return 'Chemical Suspect';
    if (visualAnomalyScore < 30) return 'Naturally Ripened';
    return 'Mixed Ripening';
  }

  /// Scores a camera or gallery photo and maps Sv onto gas telemetry.
  Future<VisualReading> analyzeCapture(Uint8List imageBytes) async {
    final score = await analyzeFruitVisualRisk(imageBytes: imageBytes);
    return readingForScore(score);
  }

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
    final hues = <double>[];
    final saturations = <double>[];
    var brown = 0;
    final darkPerBlock = List<int>.filled(100, 0);
    final pixelCount = thumb.width * thumb.height;
    final hsv = <num>[0, 0, 0];

    for (var y = 0; y < thumb.height; y++) {
      for (var x = 0; x < thumb.width; x++) {
        final pixel = thumb.getPixel(x, y);
        final r = pixel.r.round();
        final g = pixel.g.round();
        final b = pixel.b.round();
        img.rgbToHsv(pixel.rNormalized, pixel.gNormalized, pixel.bNormalized, hsv);
        hues.add(hsv[0].toDouble());
        saturations.add(hsv[1].toDouble());
        if (_isDarkOrBrown(r, g, b)) {
          brown++;
          darkPerBlock[(y ~/ 10) * 10 + (x ~/ 10)]++;
        }
      }
    }

    final uniformity = _uniformityScore(hues, saturations);
    final speckle = _speckleScore(darkPerBlock);
    final naturalSpots = (brown / pixelCount / 0.20 * 100).clamp(0.0, 100.0);
    final artificial = (0.55 * uniformity) + (0.45 * (100 - speckle));
    final score = artificial * (1 - 0.7 * (naturalSpots / 100));
    return score.clamp(0.0, 100.0).toDouble();
  }

  /// High when hue and saturation barely vary across the peel.
  double _uniformityScore(List<double> hues, List<double> saturations) {
    final hueStd = _circularStdDevDegrees(hues);
    final satStd = _stdDev(saturations);
    final hueUniform = (1 - (hueStd / 45).clamp(0.0, 1.0)) * 100;
    final satUniform = (1 - (satStd / 0.25).clamp(0.0, 1.0)) * 100;
    return (hueUniform + satUniform) / 2;
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
    return (variance / 0.25 * 100).clamp(0.0, 100.0).toDouble();
  }

  double _stdDev(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((sum, value) => sum + value) / values.length;
    var variance = 0.0;
    for (final value in values) {
      final delta = value - mean;
      variance += delta * delta;
    }
    variance /= values.length;
    return math.sqrt(variance);
  }

  /// Hue is an angle, so wrap-around at 0°/360° stays a small deviation.
  double _circularStdDevDegrees(List<double> degrees) {
    if (degrees.isEmpty) return 0;
    var sumSin = 0.0;
    var sumCos = 0.0;
    for (final deg in degrees) {
      final rad = deg * math.pi / 180;
      sumSin += math.sin(rad);
      sumCos += math.cos(rad);
    }
    final meanLength = math.sqrt(sumSin * sumSin + sumCos * sumCos) / degrees.length;
    if (meanLength < 1e-9) return 180;
    return math.sqrt(-2 * math.log(meanLength.clamp(1e-9, 1.0))) * (180 / math.pi);
  }
}
