import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/safe_unawaited.dart';
import '../../ui/components/app_card.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../foods/data/services/food_scan_log_service.dart';
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
  final FoodScanLogService _logService = FoodScanLogService();
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

      final label = prediction.label.trim();
      if (label.isNotEmpty) {
        safeUnawaited(
          _logService.logScan(
            label: label,
            confidence: prediction.confidence,
            imagePath: pickedFile.path,
            dedupeKey: pickedFile.path,
          ),
        );
      }

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
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF0FDFA),
                AppColors.background,
              ],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE0F2FE),
                        Color(0xFFF0FDFA),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.045),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.74),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.045),
                                  blurRadius: 14,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.restaurant,
                              color: AppColors.teal,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Scan Meal',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.teal.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              'AI powered',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.teal,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Capture or upload a photo to estimate calories & nutrients.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        height: 1,
                        width: double.infinity,
                        color: AppColors.border.withOpacity(0.18),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.teal,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Tip: Take photo in good light for better accuracy.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _PrimaryScanButton(
                  icon: Icons.camera_alt,
                  label: _isProcessing
                      ? 'Processing...'
                      : 'Capture from Camera',
                  caption: 'Camera recommended',
                  onTap:
                      _isProcessing ? null : () => _pick(ImageSource.camera),
                  isLoading: _isProcessing,
                ),
                const SizedBox(height: AppSpacing.md),
                _SecondaryScanButton(
                  icon: Icons.photo_library,
                  label: 'Pick from Gallery',
                  caption: 'Works with screenshots too',
                  onTap:
                      _isProcessing ? null : () => _pick(ImageSource.gallery),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How it works',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _HowItWorksRow(
                        icon: Icons.camera_alt_outlined,
                        text: 'Take a photo',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _HowItWorksRow(
                        icon: Icons.auto_awesome_outlined,
                        text: 'AI identifies foods',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _HowItWorksRow(
                        icon: Icons.fact_check_outlined,
                        text: 'Review & save log',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Photos are processed to estimate nutrition.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryScanButton extends StatelessWidget {
  const _PrimaryScanButton({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
    required this.isLoading,
  });

  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    final baseColor = AppColors.teal;
    final fgColor = Colors.white.withOpacity(isDisabled ? 0.55 : 1);
    final bgColor = baseColor.withOpacity(isDisabled ? 0.55 : 1);
    final captionColor = isDisabled
        ? Colors.white.withOpacity(0.55)
        : Colors.white.withOpacity(0.85);
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(22),
      elevation: isDisabled ? 0 : 2,
      shadowColor:
          Colors.black.withOpacity(isDisabled ? 0.0 : 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: fgColor,
                      ),
                    )
                  else
                    Icon(icon, color: fgColor, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: fgColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                caption,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: captionColor,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryScanButton extends StatelessWidget {
  const _SecondaryScanButton({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    final fgColor =
        AppColors.teal.withOpacity(isDisabled ? 0.55 : 1);
    final captionColor = isDisabled
        ? AppColors.textSecondary.withOpacity(0.55)
        : AppColors.textSecondary;
    return Material(
      color: AppColors.surface.withOpacity(isDisabled ? 0.55 : 1),
      borderRadius: BorderRadius.circular(22),
      elevation: isDisabled ? 0 : 1,
      shadowColor:
          Colors.black.withOpacity(isDisabled ? 0.0 : 0.06),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fgColor, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: fgColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                caption,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: captionColor,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorksRow extends StatelessWidget {
  const _HowItWorksRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.teal.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.teal, size: 18),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
        ),
      ],
    );
  }
}

// UI-only changes; logic unchanged.
