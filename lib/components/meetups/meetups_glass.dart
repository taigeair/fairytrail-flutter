import 'dart:ui';

import 'package:fairytrail/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Frosted panel for chrome sitting on the Meetups map.
class MeetupsGlassPanel extends StatelessWidget {
  const MeetupsGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.borderRadius = 12,
    this.fillOpacity = 0.18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double fillOpacity;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final fill = isDark
        ? AppColors.darkSurface.withValues(alpha: fillOpacity)
        : AppColors.white.withValues(alpha: fillOpacity);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : AppColors.borderOf(context).withValues(alpha: 0.35);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: border),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
