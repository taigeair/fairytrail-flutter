import 'package:fairytrail/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Simple 1–3 step indicator for signup.
class ProgressCircles extends StatelessWidget {
  const ProgressCircles({super.key, required this.activeStep, this.total = 3});

  final int activeStep;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final step = i + 1;
        final active = step <= activeStep;
        return Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? AppColors.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
        );
      }),
    );
  }
}
