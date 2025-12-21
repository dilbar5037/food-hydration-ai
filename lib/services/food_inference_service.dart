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
  static const bool _useZeroToOneNormalization = true;

  Future<InferenceResult> runInference({
    required Uint8List imageBytes,
    required FoodClassifier classifier,
  }) async {
    await classifier.loadModel();
    final Interpreter interpreter = classifier.interpreter;
    final labels = classifier.labels;

    final resizedBytes = await _decodeAndResize(imageBytes);
    final inTensor = interpreter.getInputTensor(0);
    final outTensor = interpreter.getOutputTensor(0);
    if (kDebugMode) {
      debugPrint('MODEL CHECK ----------------');
      debugPrint('IN  type=${inTensor.type} shape=${inTensor.shape} q=${inTensor.params}');
      debugPrint('OUT type=${outTensor.type} shape=${outTensor.shape} q=${outTensor.params}');
      debugPrint('labels=${labels.length}');
      debugPrint('--------------------------------');
    }
    final inShape = inTensor.shape;
    final height = inShape.length > 1 ? inShape[1] : 224;
    final width = inShape.length > 2 ? inShape[2] : 224;
    final channels = inShape.length > 3 ? inShape[3] : 3;
    final outShape = outTensor.shape;
    final numClasses = outShape.isNotEmpty ? outShape.last : labels.length;
    late List<double> logitsOrProbs;

    if (kDebugMode) {
      debugPrint(
        'IN  shape=${inTensor.shape} type=${inTensor.type} q=${inTensor.params}',
      );
      debugPrint(
        'OUT shape=${outTensor.shape} type=${outTensor.type} q=${outTensor.params}',
      );
      debugPrint('labels=${labels.length}');
      if (height != 224 || width != 224 || channels != 3) {
        debugPrint(
          'Warning: input tensor shape is $inShape, expected [1,224,224,3]',
        );
      }
    }

    if (inTensor.type == TensorType.uint8) {
      final rgbBytes = _buildUint8RgbInput(resizedBytes, width, height);
      if (kDebugMode) {
        debugPrint('inTensor type=${inTensor.type} shape=${inTensor.shape}');
        debugPrint('outTensor type=${outTensor.type} shape=${outTensor.shape}');
        debugPrint(
          'rgbBytes type=${rgbBytes.runtimeType} len=${rgbBytes.length}',
        );
        debugPrint(
          'rgbBytes first=${rgbBytes[0]},${rgbBytes[1]},${rgbBytes[2]}',
        );
      }
      inTensor.setTo(rgbBytes);
      interpreter.invoke();
      final output2D = List.generate(
        1,
        (_) => List<double>.filled(numClasses, 0.0),
      );
      outTensor.copyTo(output2D);
      logitsOrProbs = output2D.first;
    } else {
      final Object preparedInput = _buildInput(
        rgbaBytes: resizedBytes,
        width: width,
        height: height,
        channels: channels,
        inputTensor: inTensor,
      );
      switch (outTensor.type) {
        case TensorType.uint8:
          final outputUint8 = List.generate(
            1,
            (_) => Uint8List(numClasses),
          );
          interpreter.run(preparedInput, outputUint8);
          final scale = outTensor.params.scale;
          final zeroPoint = outTensor.params.zeroPoint;
          logitsOrProbs = outputUint8.first
              .map((v) => scale * (v - zeroPoint))
              .toList(growable: false);
          break;
        case TensorType.int8:
          final outputInt8 = List.generate(
            1,
            (_) => Int8List(numClasses),
          );
          interpreter.run(preparedInput, outputInt8);
          final scale = outTensor.params.scale;
          final zeroPoint = outTensor.params.zeroPoint;
          logitsOrProbs = outputInt8.first
              .map((v) => scale * (v - zeroPoint))
              .toList(growable: false);
          break;
        case TensorType.float32:
          final outputFloat = List.generate(
            1,
            (_) => List<double>.filled(numClasses, 0.0),
          );
          interpreter.run(preparedInput, outputFloat);
          logitsOrProbs = outputFloat.first;
          break;
        default:
          throw UnsupportedError(
            'Unsupported output tensor type: ${outTensor.type}',
          );
      }
    }

    if (kDebugMode) {
      if (labels.length != numClasses) {
        debugPrint(
          'Warning: labels length (${labels.length}) != numClasses ($numClasses)',
        );
      }
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
          'Top: ${entry.index} $label = ${entry.score.toStringAsFixed(4)}',
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

  Object _buildInput({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
    required int channels,
    required Tensor inputTensor,
  }) {
    if (channels != 3) {
      throw StateError('Expected 3 input channels, got $channels');
    }
    switch (inputTensor.type) {
      case TensorType.uint8:
        return _buildUint8RgbInput(rgbaBytes, width, height);
      case TensorType.int8:
        return _buildInt8Input(
          rgbaBytes,
          width,
          height,
          inputTensor.params,
        );
      case TensorType.float32:
        if (kDebugMode) {
          final mode = _useZeroToOneNormalization ? '0..1' : '-1..1';
          debugPrint('Input normalization: $mode');
        }
        return _buildFloatInput(rgbaBytes, width, height);
      default:
        throw UnsupportedError(
          'Unsupported input tensor type: ${inputTensor.type}',
        );
    }
  }

  List<List<List<List<double>>>> _buildFloatInput(
    Uint8List rgbaBytes,
    int width,
    int height,
  ) {
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
        input[0][y][x][0] = _normalizePixel(r);
        input[0][y][x][1] = _normalizePixel(g);
        input[0][y][x][2] = _normalizePixel(b);
      }
    }

    return input;
  }

  Uint8List _buildUint8RgbInput(
    Uint8List rgbaBytes,
    int width,
    int height,
  ) {
    final input = Uint8List(width * height * 3);
    var outIndex = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = (y * width + x) * 4;
        input[outIndex++] = rgbaBytes[index];
        input[outIndex++] = rgbaBytes[index + 1];
        input[outIndex++] = rgbaBytes[index + 2];
      }
    }
    return input;
  }

  Int8List _buildInt8Input(
    Uint8List rgbaBytes,
    int width,
    int height,
    QuantizationParams params,
  ) {
    final input = Int8List(width * height * 3);
    final scale = params.scale;
    final zeroPoint = params.zeroPoint;
    var outIndex = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = (y * width + x) * 4;
        input[outIndex++] = _quantize(rgbaBytes[index], scale, zeroPoint);
        input[outIndex++] = _quantize(rgbaBytes[index + 1], scale, zeroPoint);
        input[outIndex++] = _quantize(rgbaBytes[index + 2], scale, zeroPoint);
      }
    }
    return input;
  }

  double _normalizePixel(int value) {
    if (_useZeroToOneNormalization) {
      return value / 255.0;
    }
    return (value / 127.5) - 1.0;
  }

  int _quantize(int value, double scale, int zeroPoint) {
    final quantized = (value / scale + zeroPoint).round();
    return quantized.clamp(-128, 127).toInt();
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
