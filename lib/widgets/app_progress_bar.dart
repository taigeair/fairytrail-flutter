import 'package:fairytrail/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Thin top progress bar (0.0 – 1.0).
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 4,
    this.backgroundColor,
    this.color,
  });

  final double value;
  final double height;
  final Color? backgroundColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: clamped,
        minHeight: height,
        backgroundColor: backgroundColor ??
            Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        color: color ?? AppColors.primary,
      ),
    );
  }
}

/// Full-screen or inline loading indicator.
class AppLoading extends StatelessWidget {
  const AppLoading({
    super.key,
    this.message,
    this.size = 32,
  });

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
