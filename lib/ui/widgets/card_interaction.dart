import 'package:flutter/material.dart';

class CardInteraction extends StatefulWidget {
  const CardInteraction({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<CardInteraction> createState() => _CardInteractionState();
}

class _CardInteractionState extends State<CardInteraction> {
  bool _pressed = false;

  void _set(bool v) {
    if (mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            boxShadow: _pressed
                ? [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))]
                : [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
