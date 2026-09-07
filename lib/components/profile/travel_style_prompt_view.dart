import 'package:fairytrail/api/update_user_data.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/config/signup_options.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Mandatory prompt when the user has no travel style set.
class TravelStylePromptView extends StatefulWidget {
  const TravelStylePromptView({
    super.key,
    required this.onSuccess,
  });

  final VoidCallback onSuccess;

  @override
  State<TravelStylePromptView> createState() => _TravelStylePromptViewState();
}

class _TravelStylePromptViewState extends State<TravelStylePromptView> {
  String? _selected;
  bool _saving = false;
  String? _error;

  Future<void> _onContinue() async {
    final style = _selected;
    if (style == null || _saving) return;

    final auth = AuthScope.of(context);
    final name = auth.user?.name.trim();
    if (name == null || name.isEmpty) {
      setState(() => _error = 'Missing profile name. Please reopen the app.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await updateUserData(
        name: name,
        mobility: auth.profileMeta?.mobility ?? 'non-remote',
        travelStyle: style,
      );
      await auth.refreshMe();
      if (!mounted) return;
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = serverErrorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Icon(
            Icons.travel_explore_outlined,
            size: 40,
            color: AppColors.primary.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 16),
          const AppText(
            'What best describes you?',
            variant: AppTextVariant.headline,
            fontWeight: FontWeight.w700,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          AppText(
            'This helps us introduce you to travelers like you.',
            variant: AppTextVariant.body,
            color: muted,
            textAlign: TextAlign.center,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AppText(
              _error!,
              variant: AppTextVariant.bodySmall,
              color: AppColors.primary,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                for (final opt in signupTravelKindOptions) ...[
                  _TravelStyleTile(
                    label: opt.$1,
                    subtitle: opt.$3,
                    icon: switch (opt.$2) {
                      'world_citizen' => Icons.public_rounded,
                      'digital_nomad' => Icons.laptop_mac_rounded,
                      'backpacker' => Icons.hiking_rounded,
                      'transplant' => Icons.favorite,
                      'local' => Icons.location_on_outlined,
                      'career_break' => Icons.hourglass_empty_rounded,
                      'luxury' => Icons.diamond_outlined,
                      'van_life' => Icons.airport_shuttle_outlined,
                      'student' => Icons.school_outlined,
                      'retired' => Icons.elderly_rounded,
                      _ => Icons.travel_explore_rounded,
                    },
                    selected: _selected == opt.$2,
                    onTap: _saving
                        ? null
                        : () => setState(() => _selected = opt.$2),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          AppButton(
            label: 'Continue',
            isLoading: _saving,
            onPressed: _selected == null || _saving ? null : _onContinue,
          ),
        ],
      ),
    );
  }
}

class _TravelStyleTile extends StatelessWidget {
  const _TravelStyleTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.65),
              width: selected ? 2 : 1.25,
            ),
            color: selected
                ? AppColors.primary.withValues(alpha: 0.08)
                : theme.colorScheme.surface,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? AppColors.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        label,
                        variant: AppTextVariant.title,
                        fontWeight: FontWeight.w600,
                      ),
                      const SizedBox(height: 2),
                      AppText(
                        subtitle,
                        variant: AppTextVariant.caption,
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: selected
                      ? AppColors.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
