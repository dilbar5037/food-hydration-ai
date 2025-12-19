import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'meal_result_screen.dart';
import 'ml/predictor_service.dart';

class ScanMealScreen extends StatefulWidget {
  const ScanMealScreen({super.key});

  @override
  State<ScanMealScreen> createState() => _ScanMealScreenState();
}

class _ScanMealScreenState extends State<ScanMealScreen> {
  final ImagePicker _picker = ImagePicker();
  final PredictorService _predictor = PredictorService();
  bool _isProcessing = false;

  Future<void> _pick(ImageSource source) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      final prediction = await _predictor.predict(pickedFile.path);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MealResultScreen(
            imagePath: pickedFile.path,
            predictedLabel: prediction.label,
            confidence: prediction.confidence,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to process image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Meal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Scan your meal from an image',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Pick from Gallery'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture from Camera'),
            ),
            const SizedBox(height: 24),
            if (_isProcessing) const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
