import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Pill-style auth buttons matching the classic Fairytrail welcome UI.
class SocialLoginButtons extends StatelessWidget {
  const SocialLoginButtons({
    super.key,
    required this.onGooglePressed,
    required this.onApplePressed,
    required this.onEmailPressed,
    this.enabled = true,
  });

  final VoidCallback onGooglePressed;
  final VoidCallback onApplePressed;
  final VoidCallback onEmailPressed;
  final bool enabled;

  bool get _showApple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AuthPillButton(
          label: 'Continue with Google',
          icon: SvgPicture.asset(
            'assets/home/google.svg',
            width: 22,
            height: 22,
          ),
          background: AppColors.white,
          foreground: AppColors.gray,
          borderColor: AppColors.black,
          onPressed: enabled ? onGooglePressed : null,
        ),
        if (_showApple) ...[
          const SizedBox(height: 12),
          _AuthPillButton(
            label: 'Continue with Apple',
            icon: const Icon(Icons.apple, size: 22, color: AppColors.white),
            background: AppColors.black,
            foreground: AppColors.white,
            borderColor: AppColors.black,
            onPressed: enabled ? onApplePressed : null,
          ),
        ],
        const SizedBox(height: 12),
        _AuthPillButton(
          label: 'Continue with email',
          icon: const Icon(
            Icons.mail_outline_rounded,
            size: 22,
            color: AppColors.gray,
          ),
          background: AppColors.white,
          foreground: AppColors.gray,
          borderColor: AppColors.black,
          onPressed: enabled ? onEmailPressed : null,
        ),
      ],
    );
  }
}

class _AuthPillButton extends StatelessWidget {
  const _AuthPillButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.borderColor,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final Color background;
  final Color foreground;
  final Color borderColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: onPressed == null
              ? null
              : () {
                  HapticsService.light();
                  onPressed!();
                },
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomeHero extends StatelessWidget {
  const WelcomeHero({super.key});

  @override
  Widget build(BuildContext context) {
    // Brand landing is always light — pin colors so dark mode theme text
    // doesn't disappear on the white hero.
    const textColor = AppColors.lightTextPrimary;

    return Column(
      children: [
        Image.asset('assets/home/logo.png', height: 72, fit: BoxFit.contain),
        const SizedBox(height: 28),
        const AppText(
          'Find friends and adventure',
          variant: AppTextVariant.title,
          textAlign: TextAlign.center,
          fontWeight: FontWeight.w700,
          fontSize: 22,
          color: textColor,
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/home/l-wing.svg', width: 40, height: 70),
            const SizedBox(width: 14),
            const Column(
              children: [
                AppText(
                  '5 million',
                  variant: AppTextVariant.title,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: textColor,
                ),
                SizedBox(height: 2),
                AppText(
                  'connections made',
                  variant: AppTextVariant.bodySmall,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: textColor,
                ),
              ],
            ),
            const SizedBox(width: 14),
            SvgPicture.asset('assets/home/r-wing.svg', width: 40, height: 70),
          ],
        ),
      ],
    );
  }
}
