import 'package:flutter/material.dart';
import 'package:food_hydration_ai/ui/widgets/lottie_fallback.dart';

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({
    super.key,
    this.message,
    this.size = 96,
  });

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: LottieFallback(
              asset: 'assets/lottie/loading.json',
              fit: BoxFit.contain,
              repeat: true,
              fallback: const Center(child: CircularProgressIndicator()),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, textAlign: TextAlign.center),
          ]
        ],
      ),
    );
  }
}
