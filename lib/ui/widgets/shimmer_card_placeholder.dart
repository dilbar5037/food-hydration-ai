import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerCardPlaceholder extends StatelessWidget {
  const ShimmerCardPlaceholder({super.key, this.height = 100});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: theme.cardColor.withOpacity(0.6),
      highlightColor: theme.cardColor.withOpacity(0.9),
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
