import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

class StrokeSymbolPrediction {
  const StrokeSymbolPrediction({required this.token, required this.confidence});

  final String token;
  final double confidence;

  String get display => switch (token) {
    '*' => '×',
    '/' => '÷',
    'pi' => 'π',
    _ => token,
  };
}

/// Small on-device multinomial logistic regression for one isolated glyph.
/// Full expressions continue through the existing ML Kit OCR path.
class StrokeSymbolModel {
  StrokeSymbolModel._({
    required this.inputSide,
    required this.tokens,
    required this.weights,
    required this.bias,
    required this.validationAccuracy,
  });

  final int inputSide;
  final List<String> tokens;
  final List<List<double>> weights;
  final List<double> bias;
  final double validationAccuracy;

  factory StrokeSymbolModel.fromJson(String source) {
    final root = jsonDecode(source) as Map<String, dynamic>;
    if (root['version'] != 1) {
      throw const FormatException('Unsupported handwriting model version.');
    }
    final side = root['input_side'] as int;
    final classes = (root['classes'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final tokens = classes.map((entry) => entry['token'] as String).toList();
    final weights = (root['weights'] as List<dynamic>)
        .map(
          (row) => (row as List<dynamic>)
              .cast<num>()
              .map((v) => v.toDouble())
              .toList(),
        )
        .toList();
    final bias = (root['bias'] as List<dynamic>)
        .cast<num>()
        .map((value) => value.toDouble())
        .toList();
    final featureCount = side * side;
    if (side < 8 ||
        tokens.isEmpty ||
        weights.length != tokens.length ||
        bias.length != tokens.length ||
        weights.any((row) => row.length != featureCount)) {
      throw const FormatException('Handwriting model dimensions are invalid.');
    }
    return StrokeSymbolModel._(
      inputSide: side,
      tokens: tokens,
      weights: weights,
      bias: bias,
      validationAccuracy: (root['validation_accuracy'] as num).toDouble(),
    );
  }

  List<StrokeSymbolPrediction> predict(List<double> features, {int limit = 3}) {
    if (features.length != inputSide * inputSide) {
      throw ArgumentError.value(
        features.length,
        'features',
        'Wrong feature count.',
      );
    }
    final logits = List<double>.generate(tokens.length, (classIndex) {
      var score = bias[classIndex];
      final classWeights = weights[classIndex];
      for (var index = 0; index < features.length; index++) {
        score += classWeights[index] * features[index];
      }
      return score;
    });
    final maxLogit = logits.reduce(
      (left, right) => math.max(left, right).toDouble(),
    );
    final probabilities = logits
        .map((score) => math.exp(score - maxLogit))
        .toList();
    final normalizer = probabilities.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final merged = <String, double>{};
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index];
      merged[token] = (merged[token] ?? 0) + probabilities[index] / normalizer;
    }
    final predictions =
        merged.entries
            .map(
              (entry) => StrokeSymbolPrediction(
                token: entry.key,
                confidence: entry.value,
              ),
            )
            .toList()
          ..sort((left, right) => right.confidence.compareTo(left.confidence));
    return predictions.take(limit).toList(growable: false);
  }

  /// Crops dark ink from a white canvas, centers it with margin, and returns
  /// row-major 28x28 foreground intensity values in [0, 1].
  static List<double>? featuresFromRgba({
    required int width,
    required int height,
    required Uint8List rgba,
    int inputSide = 28,
  }) {
    if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
      return null;
    }
    const edgeInset = 5;
    const inkThreshold = 238;
    var minX = width;
    var minY = height;
    var maxX = -1;
    var maxY = -1;
    for (var y = edgeInset; y < height - edgeInset; y++) {
      for (var x = edgeInset; x < width - edgeInset; x++) {
        final offset = (y * width + x) * 4;
        final red = rgba[offset];
        final green = rgba[offset + 1];
        final blue = rgba[offset + 2];
        final alpha = rgba[offset + 3] / 255;
        final luminance =
            (0.299 * red + 0.587 * green + 0.114 * blue) * alpha +
            255 * (1 - alpha);
        if (luminance < inkThreshold) {
          minX = math.min(minX, x);
          minY = math.min(minY, y);
          maxX = math.max(maxX, x);
          maxY = math.max(maxY, y);
        }
      }
    }
    if (maxX < minX || maxY < minY) return null;

    final glyphWidth = maxX - minX + 1;
    final glyphHeight = maxY - minY + 1;
    final glyphSide = math.max(glyphWidth, glyphHeight);
    final margin = math.max(3.0, glyphSide * 0.16);
    final squareSide = glyphSide + margin * 2;
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    final result = List<double>.filled(inputSide * inputSide, 0);
    for (var outY = 0; outY < inputSide; outY++) {
      for (var outX = 0; outX < inputSide; outX++) {
        final sourceX = centerX + ((outX + 0.5) / inputSide - 0.5) * squareSide;
        final sourceY = centerY + ((outY + 0.5) / inputSide - 0.5) * squareSide;
        final x = sourceX.round();
        final y = sourceY.round();
        if (x < minX || x > maxX || y < minY || y > maxY) continue;
        final offset = (y * width + x) * 4;
        final red = rgba[offset];
        final green = rgba[offset + 1];
        final blue = rgba[offset + 2];
        final alpha = rgba[offset + 3] / 255;
        final luminance =
            (0.299 * red + 0.587 * green + 0.114 * blue) * alpha +
            255 * (1 - alpha);
        result[outY * inputSide + outX] = ((255 - luminance) / 255)
            .clamp(0, 1)
            .toDouble();
      }
    }
    return result;
  }
}
