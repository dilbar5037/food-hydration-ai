import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

/// Safely loads a Lottie asset. Falls back to [fallback] if the asset is
/// missing, corrupted, or has invalid frames (startFrame == endFrame).
class LottieFallback extends StatelessWidget {
  const LottieFallback({
    super.key,
    required this.asset,
    this.fit = BoxFit.contain,
    this.repeat = true,
    this.fallback,
  });

  final String asset;
  final BoxFit fit;
  final bool repeat;
  final Widget? fallback;

  Future<LottieComposition?> _load() async {
    try {
      final data = await rootBundle.load(asset);
      final composition = await LottieComposition.fromByteData(data);
      // Guard against invalid animations (the assertion that was crashing)
      if (composition.startFrame >= composition.endFrame) return null;
      return composition;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LottieComposition?>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return fallback ?? const SizedBox.shrink();
        }
        final composition = snapshot.data;
        if (composition == null) {
          return fallback ?? const SizedBox.shrink();
        }
        return Lottie(
          composition: composition,
          fit: fit,
          repeat: repeat,
        );
      },
    );
  }
}
