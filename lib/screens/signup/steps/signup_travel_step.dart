import 'package:fairytrail/config/signup_options.dart';
import 'package:fairytrail/screens/signup/signup_step_scaffold.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Step 3 — travel kind (UI-only) + fully remote checkbox → mobility.
class SignupTravelStep extends StatelessWidget {
  const SignupTravelStep({
    super.key,
    required this.travelKind,
    required this.isFullyRemote,
    required this.onTravelKindChanged,
    required this.onFullyRemoteChanged,
    required this.onContinue,
    this.isLoading = false,
    this.error,
  });

  final String? travelKind;
  final bool isFullyRemote;
  final ValueChanged<String> onTravelKindChanged;
  final ValueChanged<bool> onFullyRemoteChanged;
  final VoidCallback onContinue;
  final bool isLoading;
  final String? error;

  bool get _canContinue => travelKind != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return SignupStepScaffold(
      step: 3,
      title: 'What best describes you?',
      // subtitle: '',
      subtitle: 'This helps people understand your lifestyle better',
      canContinue: _canContinue,
      isLoading: isLoading,
      onContinue: onContinue,
      footer: Material(
        color: theme.scaffoldBackgroundColor,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.25),
              ),
            ),
          ),
          child: CheckboxListTile(
            value: isFullyRemote,
            onChanged: isLoading
                ? null
                : (v) => onFullyRemoteChanged(v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const AppText(
              'I am fully remote',
              variant: AppTextVariant.bodySmall,
            ),
            subtitle: AppText(
              'Let people know you can work remotely',
              variant: AppTextVariant.caption,
              color: muted,
            ),
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          if (error != null) ...[
            AppText(
              error!,
              variant: AppTextVariant.bodySmall,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
          ],
          const AppText(
            'Pick your badge',
            variant: AppTextVariant.label,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 10),
          for (final opt in signupTravelKindOptions) ...[
            SignupOptionTile(
              label: opt.$1,
              subtitle: opt.$3,
              selected: travelKind == opt.$2,
              icon: switch (opt.$2) {
                'world_citizen' => Icons.public_rounded,
                'solo_traveller' => Icons.explore_outlined,
                'digital_nomad' => Icons.laptop_mac_rounded,
                'backpacker' => Icons.hiking_rounded,
                'transplant' => Icons.favorite_outline,
                'local' => Icons.location_on_outlined,
                'career_break' => Icons.hourglass_empty_rounded,
                'luxury' => Icons.diamond_outlined,
                'van_life' => Icons.airport_shuttle_outlined,
                'student' => Icons.school_outlined,
                'retired' => Icons.celebration_outlined,
                'socializer' => Icons.waving_hand_outlined,
                'sabbatical' => Icons.coffee_outlined,
                _ => Icons.travel_explore_rounded,
              },
              onTap: () => onTravelKindChanged(opt.$2),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
