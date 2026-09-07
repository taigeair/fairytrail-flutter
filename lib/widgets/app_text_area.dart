import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/app_text.dart';
import 'package:flutter/material.dart';

/// Multi-line themed text area.
class AppTextArea extends StatelessWidget {
  const AppTextArea({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.minLines = 4,
    this.maxLines = 8,
    this.maxLength,
    this.showInlineCounter = false,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final int minLines;
  final int maxLines;
  final int? maxLength;
  final bool showInlineCounter;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
        ],
        Stack(
          children: [
            TextFormField(
              controller: controller,
              minLines: minLines,
              maxLines: maxLines,
              maxLength: maxLength,
              buildCounter: showInlineCounter
                  ? (
                      context, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null
                  : null,
              onChanged: onChanged,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              enabled: enabled,
              keyboardType: TextInputType.multiline,
              keyboardAppearance: Theme.of(context).brightness,
              textCapitalization: textCapitalization,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: hint,
                alignLabelWithHint: true,
                contentPadding: showInlineCounter
                    ? const EdgeInsets.fromLTRB(16, 14, 56, 30)
                    : null,
              ),
            ),
            if (showInlineCounter && controller != null && maxLength != null)
              Positioned(
                right: 12,
                bottom: 10,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller!,
                  builder: (context, value, _) => AppText(
                    '${value.text.characters.length}/$maxLength',
                    variant: AppTextVariant.caption,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
