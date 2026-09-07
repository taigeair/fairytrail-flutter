import 'package:fairytrail/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Date picker field that opens the platform date picker.
class AppDatePicker extends StatelessWidget {
  const AppDatePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.onClear,
    this.label,
    this.hint = 'When did you complete it?',
    this.firstDate,
    this.lastDate,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback? onClear;
  final String? label;
  final String hint;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    final display = value != null
        ? DateFormat.yMMMd().format(value!)
        : hint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          AppText(label!, variant: AppTextVariant.label),
          const SizedBox(height: 8),
        ],
        InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              suffixIcon: value != null && onClear != null
                  ? IconButton(
                      tooltip: 'Clear date',
                      onPressed: onClear,
                      icon: const Icon(Icons.cancel_outlined, size: 20),
                    )
                  : const Icon(Icons.calendar_today_outlined, size: 20),
            ),
            child: Text(
              display,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: value == null
                        ? Theme.of(context).hintColor
                        : null,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: firstDate ?? DateTime(1900),
      lastDate: lastDate ?? DateTime(now.year + 50),
    );
    if (picked != null) onChanged(picked);
  }
}
