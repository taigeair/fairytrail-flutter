import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/app_text.dart';
import 'package:flutter/material.dart';

/// Skip + Send + Connect — solid buttons over a transparent bar.
class ExploreActionBar extends StatelessWidget {
  const ExploreActionBar({
    super.key,
    required this.onSkip,
    required this.onCare,
    required this.onConnect,
    this.enabled = true,
    this.connecting = false,
  });

  final VoidCallback onSkip;
  final VoidCallback onCare;
  final VoidCallback onConnect;
  final bool enabled;

  /// Shows a spinner on Connect while the connect API is in flight.
  final bool connecting;

  /// RN Skip `#F0F1F6` / `#959595` (light).
  static const _skipBgLight = Color(0xFFF0F1F6);
  static const _skipFgLight = Color(0xFF959595);

  /// Dark Skip — elevated charcoal so it reads on dark surfaces.
  static const _skipBgDark = Color(0xFF2C2C2C);
  static const _skipFgDark = Color(0xFFB0B0B0);

  /// Brand violet for Send.
  static const _messageBg = AppColors.primary;

  /// RN Connect `#FF2F53`.
  static const _connectBg = Color(0xFFFF2F53);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // No fade/scrim behind the row — only the buttons are opaque.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: 'Skip',
              background: isDark ? _skipBgDark : _skipBgLight,
              foreground: isDark ? _skipFgDark : _skipFgLight,
              onPressed: enabled
                  ? () {
                      HapticsService.light();
                      onSkip();
                    }
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              label: 'Inspire',
              background: _messageBg,
              foreground: Colors.white,
              onPressed: enabled
                  ? () {
                      HapticsService.medium();
                      onCare();
                    }
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              label: 'Connect',
              background: _connectBg,
              foreground: Colors.white,
              loading: connecting,
              onPressed: enabled && !connecting
                  ? () {
                      HapticsService.medium();
                      onConnect();
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(16),
        splashColor: foreground.withValues(alpha: 0.12),
        child: SizedBox(
          height: 52,
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: foreground,
                    ),
                  )
                : AppText(
                    label,
                    variant: AppTextVariant.label,
                    color: foreground,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
          ),
        ),
      ),
    );
  }
}
