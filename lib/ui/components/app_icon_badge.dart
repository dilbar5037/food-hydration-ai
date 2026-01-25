import 'package:flutter/material.dart';

import '../theme/app_radius.dart';

class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.size = 48,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Icon(icon, color: iconColor),
    );
  }
}
