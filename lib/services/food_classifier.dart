import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class FoodClassifier {
  Interpreter? _interpreter;
  List<String> _labels = [];

  List<String> get labels => _labels;
  Interpreter get interpreter {
    if (_interpreter == null) {
      throw StateError('Interpreter not initialized. Call loadModel() first.');
    }
    return _interpreter!;
  }

  Future<void> loadModel() async {
    if (_interpreter != null) return;
    _interpreter =
        await Interpreter.fromAsset('assets/models/food_model_v1.tflite');
    _labels = await _loadLabels();
    if (kDebugMode) {
      debugPrint(
        'TFLite assets loaded: model=assets/models/food_model_v1.tflite '
        'labels=${_labels.length}',
      );
    }
  }

  Future<List<String>> _loadLabels() async {
    final raw = await rootBundle.loadString('assets/models/labels.txt');
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
  }
}
