import 'package:flutter/material.dart';
import 'package:food_hydration_ai/ui/widgets/lottie_fallback.dart';

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.lottieAsset,
  });

  final String title;
  final String subtitle;
  final String lottieAsset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: LottieFallback(
              asset: lottieAsset,
              repeat: true,
              fallback: const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
