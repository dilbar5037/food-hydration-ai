import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedPrimaryButton extends StatefulWidget {
  const AnimatedPrimaryButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.loading = false,
  });

  final Widget child;
  final Future<void> Function() onPressed;
  final bool loading;

  @override
  State<AnimatedPrimaryButton> createState() => _AnimatedPrimaryButtonState();
}

class _AnimatedPrimaryButtonState extends State<AnimatedPrimaryButton> {
  bool _pressed = false;
  bool _loadingLocal = false;

  @override
  void initState() {
    super.initState();
    _loadingLocal = widget.loading;
  }

  @override
  void didUpdateWidget(covariant AnimatedPrimaryButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadingLocal = widget.loading;
  }

  Future<void> _handleTap() async {
    if (_loadingLocal) return;
    setState(() => _loadingLocal = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _loadingLocal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.96 : 1.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 120),
        child: ElevatedButton(
          onPressed: _loadingLocal ? null : _handleTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: SizedBox(
            height: 20,
            child: Center(
              child: _loadingLocal
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : widget.child,
            ),
          ),
        ),
      ),
    ).animate().fade(duration: 300.ms).scale();
  }
}
