import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/utils/safe_unawaited.dart';
import '../data/services/food_scan_log_service.dart';
import '../../../services/food_classifier.dart';
import '../../../services/food_inference_service.dart';
import '../../../services/image_capture_service.dart';

class FoodScanScreen extends StatefulWidget {
  const FoodScanScreen({super.key});

  @override
  State<FoodScanScreen> createState() => _FoodScanScreenState();
}

class _FoodScanScreenState extends State<FoodScanScreen> {
  final ImageCaptureService _captureService = ImageCaptureService();
  final FoodClassifier _classifier = FoodClassifier();
  final FoodInferenceService _inferenceService = FoodInferenceService();
  final FoodScanLogService _logService = FoodScanLogService();

  static const double _confThreshold = 0.60;

  ImageCaptureResult? _result;
  bool _isCapturing = false;
  String? _error;
  String? _predictedLabel;
  double? _predictedConfidence;
  bool _isLowConfidence = false;

  Future<void> _capture() async {
    if (_isCapturing) return;
    setState(() {
      _isCapturing = true;
      _error = null;
    });

    try {
      final capture = await _captureService.captureFromCamera();
      if (!mounted) return;
      if (capture == null) {
        setState(() {
          _result = null;
          _predictedLabel = null;
          _predictedConfidence = null;
        });
        return;
      }

      Uint8List? bytes = capture.bytes;
      if (bytes == null && capture.file != null) {
        bytes = await capture.file!.readAsBytes();
      }

      InferenceResult? prediction;
      if (bytes != null) {
        prediction = await _inferenceService.runInference(
          imageBytes: bytes,
          classifier: _classifier,
        );
      }

      setState(() {
        _result = capture;
        _predictedConfidence = prediction?.confidence;
        final isLow = (_predictedConfidence ?? 0) < _confThreshold;
        _isLowConfidence = isLow;
        _predictedLabel = prediction == null
            ? null
            : isLow
                ? 'Unknown'
                : prediction.label;
      });

      if (prediction != null &&
          _predictedLabel != null &&
          _predictedLabel != 'Unknown') {
        // Fire-and-forget to avoid blocking UI.
        final dedupeKey =
            '${capture.path}_${capture.byteLength ?? 0}';
        safeUnawaited(
          _logService.logScan(
            label: _predictedLabel!,
            confidence: _predictedConfidence ?? 0,
            imagePath: capture.path,
            dedupeKey: dedupeKey,
          ),
          onError: (error, st) {
            debugPrint('Food scan log error: $error');
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Widget _buildPreview() {
    if (_result == null) {
      return const Text('No image captured yet.');
    }

    final file = _result!.file;
    final path = _result!.path;
    final length = _result!.byteLength;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (file != null && file.existsSync())
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              file,
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 12),
        Text('Path: $path'),
        if (length != null) Text('Bytes: $length'),
        const SizedBox(height: 12),
        if (_predictedLabel != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Food: $_predictedLabel'),
              if (_predictedConfidence != null)
                Text(
                  'Confidence: ${(_predictedConfidence! * 100).toStringAsFixed(1)}%',
                ),
              if (_isLowConfidence)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Low confidence. Retake photo with better lighting.',
                  ),
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food Scan')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isCapturing ? null : _capture,
              child: _isCapturing
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Capture Food Photo'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            Expanded(
              child: SingleChildScrollView(
                child: _buildPreview(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
