import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_hydration_ai/ui/widgets/lottie_fallback.dart';

Future<void> showSuccessOverlay(BuildContext context) async {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  final entry = OverlayEntry(builder: (context) {
    return Material(
      color: Colors.black45,
      child: Center(
          child: SizedBox(
          width: 160,
          height: 160,
          child: LottieFallback(
            asset: 'assets/lottie/success.json',
            repeat: false,
            fallback: const Icon(Icons.check_circle_outline, size: 96, color: Colors.white),
          ),
        ),
      ),
    );
  });

  overlay.insert(entry);
  await Future.delayed(const Duration(milliseconds: 1200));
  try {
    entry.remove();
  } catch (_) {}
}
