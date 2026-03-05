import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_hydration_ai/ui/widgets/lottie_fallback.dart';

/// Global manager for a single success feedback overlay.
class SuccessFeedbackOverlay {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static Future<void> show(BuildContext context, {String? message}) async {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    // Prevent duplicates
    if (_currentEntry != null) return;

    final entry = OverlayEntry(builder: (ctx) {
      return _SuccessFeedbackWidget(
        message: message,
      );
    });

    _currentEntry = entry;
    overlay.insert(entry);

    // Auto dismiss sequence (total 1600ms)
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(milliseconds: 1600), () {
      try {
        _currentEntry?.remove();
      } catch (_) {}
      _currentEntry = null;
      _dismissTimer?.cancel();
      _dismissTimer = null;
    });
  }

  static bool get isShowing => _currentEntry != null;
}

class _SuccessFeedbackWidget extends StatefulWidget {
  const _SuccessFeedbackWidget({this.message, Key? key}) : super(key: key);

  final String? message;

  @override
  State<_SuccessFeedbackWidget> createState() => _SuccessFeedbackWidgetState();
}

class _SuccessFeedbackWidgetState extends State<_SuccessFeedbackWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _scale = Tween(begin: 0.8, end: 1.0).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
  );
  late final Animation<double> _opacity = Tween(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _opacity,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: LottieFallback(
                      asset: 'assets/lottie/success.json',
                      repeat: false,
                      fallback: const Icon(
                        Icons.check_circle_outline,
                        size: 96,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (widget.message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.message!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Convenience function matching requested API.
Future<void> showSuccessFeedback(BuildContext context, {String? message}) async {
  await SuccessFeedbackOverlay.show(context, message: message);
}
