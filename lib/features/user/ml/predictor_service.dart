import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class Prediction {
  const Prediction({
    required this.label,
    required this.confidence,
  });

  final String label;
  final double confidence;
}

class PredictorService {
  static const double _confThreshold = 0.60;
  static const int _imageSize = 224;

  Interpreter? _interpreter;
  List<String> _labels = [];

  Future<void> _ensureLoaded() async {
    if (_interpreter != null && _labels.isNotEmpty) return;
    _interpreter = await Interpreter.fromAsset(
      'assets/models/food_model_v1.tflite',
    );
    final raw = await rootBundle.loadString('assets/models/labels.txt');
    _labels = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (kDebugMode) {
      debugPrint(
        'TFLite assets loaded: model=assets/models/food_model_v1.tflite '
        'labels=${_labels.length}',
      );
    }
  }

  Future<Prediction> predict(String imagePath) async {
    await _ensureLoaded();
    final interpreter = _interpreter!;
    final inTensor = interpreter.getInputTensor(0);
    final outTensor = interpreter.getOutputTensor(0);
    if (kDebugMode) {
      debugPrint('IN  shape=${inTensor.shape} type=${inTensor.type} q=${inTensor.params}');
      debugPrint('OUT shape=${outTensor.shape} type=${outTensor.type} q=${outTensor.params}');
      debugPrint('labels=${_labels.length}');
    }

    final imageBytes = await File(imagePath).readAsBytes();
    final resized = await _decodeAndResize(imageBytes);
    final numClasses =
        outTensor.shape.isNotEmpty ? outTensor.shape.last : _labels.length;
    List<double> scores;
    if (inTensor.type == TensorType.uint8) {
      final rgbBytes = _buildUint8RgbInput(resized, _imageSize, _imageSize);
      if (kDebugMode) {
        debugPrint('inTensor=${inTensor.type} shape=${inTensor.shape}');
        debugPrint(
          'rgbBytes=${rgbBytes.runtimeType} len=${rgbBytes.length} first=${rgbBytes[0]},${rgbBytes[1]},${rgbBytes[2]}',
        );
        debugPrint('outTensor=${outTensor.type} shape=${outTensor.shape}');
      }
      inTensor.setTo(rgbBytes);
      interpreter.invoke();
      final output2D = List.generate(
        1,
        (_) => List<double>.filled(numClasses, 0.0),
      );
      outTensor.copyTo(output2D);
      scores = output2D.first;
    } else {
      final input = _buildInput(resized);
      final output = List.generate(
        1,
        (_) => List<double>.filled(_labels.length, 0.0),
      );
      interpreter.run(input, output);
      scores = output.first;
    }

    if (kDebugMode) {
      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;
      debugPrint('TFLite input shape: $inputShape');
      debugPrint('TFLite output shape: $outputShape');
    }

    final probs = _maybeSoftmax(scores);
    final bestIndex = _argMax(probs);
    final bestLabel = _labels[bestIndex];
    final bestConfidence = probs[bestIndex];

    if (kDebugMode) {
      final top5 = _topK(probs, k: 5);
      for (final entry in top5) {
        debugPrint(
          'Top: ${_labels[entry.index]} = ${entry.score.toStringAsFixed(4)}',
        );
      }
      debugPrint(
        'Selected: $bestLabel (${bestConfidence.toStringAsFixed(4)})',
      );
    }

    if (bestConfidence < _confThreshold) {
      return Prediction(label: 'Unknown', confidence: bestConfidence);
    }

    return Prediction(label: bestLabel, confidence: bestConfidence);
  }

  Future<Uint8List> _decodeAndResize(Uint8List data) async {
    final codec = await ui.instantiateImageCodec(
      data,
      targetWidth: _imageSize,
      targetHeight: _imageSize,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  List<List<List<List<double>>>> _buildInput(Uint8List rgbaBytes) {
    final input = List.generate(
      1,
      (_) => List.generate(
        _imageSize,
        (_) => List.generate(
          _imageSize,
          (_) => List<double>.filled(3, 0.0),
        ),
      ),
    );
    for (var y = 0; y < _imageSize; y++) {
      for (var x = 0; x < _imageSize; x++) {
        final offset = (y * _imageSize + x) * 4;
        final r = rgbaBytes[offset];
        final g = rgbaBytes[offset + 1];
        final b = rgbaBytes[offset + 2];
        input[0][y][x][0] = r / 255.0;
        input[0][y][x][1] = g / 255.0;
        input[0][y][x][2] = b / 255.0;
        // TODO: If model was trained with MobileNetV2 preprocess_input, use (v / 127.5) - 1.
      }
    }
    return input;
  }

  Uint8List _buildUint8RgbInput(Uint8List rgbaBytes, int width, int height) {
    final input = Uint8List(width * height * 3);
    var outIndex = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = (y * width + x) * 4;
        input[outIndex++] = rgbaBytes[offset];
        input[outIndex++] = rgbaBytes[offset + 1];
        input[outIndex++] = rgbaBytes[offset + 2];
      }
    }
    return input;
  }

  List<double> _maybeSoftmax(List<double> logits) {
    final sum = logits.fold<double>(0, (a, b) => a + b);
    if (sum > 0.99 && sum < 1.01) {
      return logits;
    }
    final maxLogit = logits.reduce(math.max);
    final exps = logits.map((l) => math.exp(l - maxLogit)).toList();
    final sumExp = exps.fold<double>(0, (a, b) => a + b);
    return exps.map((e) => e / sumExp).toList();
  }

  int _argMax(List<double> values) {
    var maxIndex = 0;
    var maxValue = values[0];
    for (var i = 1; i < values.length; i++) {
      if (values[i] > maxValue) {
        maxValue = values[i];
        maxIndex = i;
      }
    }
    return maxIndex;
  }

  List<_ScoreEntry> _topK(List<double> scores, {required int k}) {
    final entries = <_ScoreEntry>[];
    for (var i = 0; i < scores.length; i++) {
      entries.add(_ScoreEntry(index: i, score: scores[i]));
    }
    entries.sort((a, b) => b.score.compareTo(a.score));
    return entries.take(k).toList();
  }
}

class _ScoreEntry {
  const _ScoreEntry({required this.index, required this.score});

  final int index;
  final double score;
}
