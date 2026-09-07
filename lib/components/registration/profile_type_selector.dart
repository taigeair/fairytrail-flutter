import 'package:fairytrail/config/registration_options.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/app_text.dart';
import 'package:flutter/material.dart';

/// Large self-identity cards — makes it clear the user is choosing who *they* are.
class ProfileTypeSelector extends StatelessWidget {
  const ProfileTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppText(
          'I am a…',
          variant: AppTextVariant.label,
          fontWeight: FontWeight.w600,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < profileTypeOptions.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _ProfileTypeCard(
                  label: profileTypeOptions[i].$1,
                  value: profileTypeOptions[i].$2,
                  icon: _iconFor(profileTypeOptions[i].$2),
                  selected: value == profileTypeOptions[i].$2,
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    if (value == profileTypeOptions[i].$2) return;
                    HapticsService.selection();
                    onChanged(profileTypeOptions[i].$2);
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  static IconData _iconFor(String value) {
    return switch (value) {
      'man' => Icons.man_rounded,
      'woman' => Icons.woman_rounded,
      'non-binary' => Icons.transgender_rounded,
      _ => Icons.person_outline_rounded,
    };
  }
}

class _ProfileTypeCard extends StatelessWidget {
  const _ProfileTypeCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = selected
        ? AppColors.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.4);
    final bg = selected
        ? AppColors.primary.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final fg = selected
        ? AppColors.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.75);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: selected ? 1.5 : 0.5),
          ),
          child: Column(
            children: [
              Icon(icon, size: 36, color: fg),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
