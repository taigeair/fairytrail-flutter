import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/app_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fairytrail/widgets/app_safe_area.dart';

/// Age field that opens a native-style scroll dialer in a bottom sheet.
class AppAgePicker extends StatelessWidget {
  const AppAgePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Age',
    this.hint = 'Choose age',
    this.minAge = 18,
    this.maxAge = 99,
  });

  final int? value;
  final ValueChanged<int> onChanged;
  final String label;
  final String hint;
  final int minAge;
  final int maxAge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, variant: AppTextVariant.label),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            _openPicker(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              suffixIcon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            child: Text(
              hasValue ? '$value' : hint,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: hasValue ? null : theme.hintColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final ages = List<int>.generate(maxAge - minAge + 1, (i) => minAge + i);
    final initial = value != null && ages.contains(value)
        ? ages.indexOf(value!)
        : ages.indexOf(25).clamp(0, ages.length - 1);
    var selected = ages[initial];
    final controller = FixedExtentScrollController(initialItem: initial);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottomPad = MediaQuery.paddingOf(ctx).bottom;
        return AppSafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPad * 0.25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      ctx,
                    ).colorScheme.outline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: AppText(
                        'Select age',
                        variant: AppTextVariant.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 216,
                  child: CupertinoPicker(
                    scrollController: controller,
                    itemExtent: 40,
                    magnification: 1.15,
                    useMagnifier: true,
                    squeeze: 1.1,
                    selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                      background: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    onSelectedItemChanged: (index) {
                      selected = ages[index];
                    },
                    children: [
                      for (final age in ages)
                        Center(
                          child: Text(
                            '$age',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();
    if (confirmed == true) onChanged(selected);
  }
}
