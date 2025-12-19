import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'food_classifier.dart';

class InferenceResult {
  InferenceResult({
    required this.label,
    required this.confidence,
  });

  final String label;
  final double confidence;
}

class FoodInferenceService {
  Future<InferenceResult> runInference({
    required Uint8List imageBytes,
    required FoodClassifier classifier,
  }) async {
    await classifier.loadModel();
    final Interpreter interpreter = classifier.interpreter;
    final labels = classifier.labels;

    final resizedBytes = await _decodeAndResize(imageBytes);
    final input = _buildInput(resizedBytes);

    if (kDebugMode) {
      final inT = interpreter.getInputTensor(0);
      final outT = interpreter.getOutputTensor(0);
      debugPrint('IN  shape=${inT.shape} type=${inT.type}');
      debugPrint('OUT shape=${outT.shape} type=${outT.type} q=${outT.params}');
    }

    final outTensor = interpreter.getOutputTensor(0);
    final outShape = outTensor.shape;
    final numClasses = outShape.isNotEmpty ? outShape.last : labels.length;
    final outTypeStr = outTensor.type.toString().toLowerCase();

    if (kDebugMode) {
      debugPrint('labels=${labels.length} numClasses=$numClasses');
      if (labels.length != numClasses) {
        debugPrint(
          'Warning: labels length (${labels.length}) != numClasses ($numClasses)',
        );
      }
    }

    List<double> logitsOrProbs;
    if (outTypeStr.contains('uint8')) {
      final outputUint8 = List.generate(
        1,
        (_) => Uint8List(numClasses),
      );
      interpreter.run(input, outputUint8);
      final scale = outTensor.params.scale;
      final zeroPoint = outTensor.params.zeroPoint;
      logitsOrProbs = outputUint8.first
          .map((v) => scale * (v - zeroPoint))
          .toList(growable: false);
    } else if (outTypeStr.contains('int8')) {
      final outputInt8 = List.generate(
        1,
        (_) => Int8List(numClasses),
      );
      interpreter.run(input, outputInt8);
      final scale = outTensor.params.scale;
      final zeroPoint = outTensor.params.zeroPoint;
      logitsOrProbs = outputInt8.first
          .map((v) => scale * (v - zeroPoint))
          .toList(growable: false);
    } else {
      final outputFloat = List.generate(
        1,
        (_) => List<double>.filled(numClasses, 0.0),
      );
      interpreter.run(input, outputFloat);
      logitsOrProbs = outputFloat.first;
    }

    final sum = logitsOrProbs.fold<double>(0, (a, b) => a + b);
    final probabilities = (sum > 0.99 && sum < 1.01)
        ? logitsOrProbs
        : _softmax(logitsOrProbs);
    final bestIndex = _argMax(probabilities);

    if (kDebugMode) {
      final top5 = _topK(probabilities, k: 5);
      for (final entry in top5) {
        final label = entry.index < labels.length
            ? labels[entry.index]
            : 'Unknown';
        debugPrint(
          'Top: $label = ${entry.score.toStringAsFixed(4)}',
        );
      }
      final selectedLabel =
          bestIndex < labels.length ? labels[bestIndex] : 'Unknown';
      debugPrint(
        'Selected: $selectedLabel (${probabilities[bestIndex].toStringAsFixed(4)})',
      );
    }

    return InferenceResult(
      label: bestIndex < labels.length ? labels[bestIndex] : 'Unknown',
      confidence: probabilities[bestIndex],
    );
  }

  Future<Uint8List> _decodeAndResize(Uint8List data) async {
    final codec = await ui.instantiateImageCodec(
      data,
      targetWidth: 224,
      targetHeight: 224,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  List<List<List<List<double>>>> _buildInput(Uint8List rgbaBytes) {
    const width = 224;
    const height = 224;
    final input = List.generate(
      1,
      (_) => List.generate(
        height,
        (_) => List.generate(
          width,
          (_) => List<double>.filled(3, 0.0),
        ),
      ),
    );

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = (y * width + x) * 4;
        final r = rgbaBytes[index];
        final g = rgbaBytes[index + 1];
        final b = rgbaBytes[index + 2];
        input[0][y][x][0] = r / 255.0;
        input[0][y][x][1] = g / 255.0;
        input[0][y][x][2] = b / 255.0;
      }
    }

    return input;
  }

  List<double> _softmax(List<double> logits) {
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
