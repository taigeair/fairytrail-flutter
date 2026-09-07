import 'package:fairytrail/components/registration/signup_logout_button.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/screens/signup/signup_progress.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Shared chrome for multi-step signup screens.
class SignupStepScaffold extends StatelessWidget {
  const SignupStepScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
    this.bottomHelper,
    this.canContinue = true,
    this.isLoading = false,
    this.continueLabel = 'Continue',
    this.onContinue,
    this.showContinue = true,
    this.secondaryLabel,
    this.onSecondary,
  });

  final int step;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final Widget? bottomHelper;
  final bool canContinue;
  final bool isLoading;
  final String continueLabel;
  final VoidCallback? onContinue;
  final bool showContinue;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final progress = SignupProgress.valueForStep(step);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [SignupLogoutButton(enabled: !isLoading)],
      ),
      body: AppSafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                children: [
                  AppProgressBar(value: progress),
                  // const SizedBox(height: 8),
                  // AppText(
                  //   'Step $step of ${AuthController.signupStepCount}',
                  //   variant: AppTextVariant.caption,
                  //   color: muted,
                  // ),
                ],
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppText(
                    subtitle!,
                    variant: AppTextVariant.bodySmall,
                    color: muted,
                  ),
                ),
              ),
            Expanded(child: child),
            ?footer,
            if (showContinue)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  children: [
                    AppButton(
                      label: continueLabel,
                      isLoading: isLoading,
                      onPressed: canContinue && !isLoading ? onContinue : null,
                    ),
                    if (secondaryLabel != null && onSecondary != null) ...[
                      const SizedBox(height: 4),
                      AppButton(
                        label: secondaryLabel!,
                        variant: AppButtonVariant.text,
                        onPressed: isLoading ? null : onSecondary,
                      ),
                    ],
                  ],
                ),
              ),
            if (bottomHelper != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                child: bottomHelper,
              ),
          ],
        ),
      ),
    );
  }
}

/// Selectable option card used across signup steps.
class SignupOptionTile extends StatelessWidget {
  const SignupOptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = selected
        ? AppColors.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.35);
    final bg = selected
        ? AppColors.primary.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticsService.selection();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: selected ? 1.5 : 0.5),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: selected
                      ? AppColors.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      label,
                      variant: AppTextVariant.body,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.primary : null,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      AppText(
                        subtitle!,
                        variant: AppTextVariant.caption,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected
                    ? AppColors.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
