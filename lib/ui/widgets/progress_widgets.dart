import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

class AnimatedCircularProgress extends StatelessWidget {
  const AnimatedCircularProgress({super.key, required this.percent, this.size = 80});

  final double percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircularPercentIndicator(
      radius: size / 2,
      lineWidth: 8,
      percent: (percent.clamp(0.0, 1.0)),
      animation: true,
      animationDuration: 800,
      center: Text('${(percent * 100).toStringAsFixed(0)}%'),
      progressColor: Theme.of(context).colorScheme.primary,
    );
  }
}
