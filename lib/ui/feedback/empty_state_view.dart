import 'package:flutter/material.dart';
import 'package:food_hydration_ai/ui/widgets/lottie_fallback.dart';

class EmptyStateView extends StatefulWidget {
  const EmptyStateView({
    super.key,
    required this.title,
    required this.subtitle,
    this.lottieAsset,
    this.fallbackIcon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? lottieAsset;
  final IconData fallbackIcon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<EmptyStateView> createState() => _EmptyStateViewState();
}

class _EmptyStateViewState extends State<EmptyStateView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _opacity =
      Tween(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
  );
  late final Animation<Offset> _offset = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
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
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animation or Icon
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Builder(builder: (c) {
                        if (widget.lottieAsset != null) {
                          return LottieFallback(
                            asset: widget.lottieAsset!,
                            repeat: true,
                            fallback: Icon(
                              widget.fallbackIcon,
                              size: 96,
                              color: Colors.grey[400],
                            ),
                          );
                        }
                        return Icon(
                          widget.fallbackIcon,
                          size: 96,
                          color: Colors.grey[400],
                        );
                      }),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 24),

                    // Optional Action Button
                    if (widget.actionLabel != null && widget.onAction != null)
                      ElevatedButton(
                        onPressed: widget.onAction,
                        child: Text(widget.actionLabel!),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
