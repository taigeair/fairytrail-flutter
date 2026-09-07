import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// RN `ChatTopBanner` — kindness prompt above the message list.
class ChatTopBanner extends StatelessWidget {
  const ChatTopBanner({
    super.key,
    required this.onClose,
    required this.onYes,
  });

  final VoidCallback onClose;
  final VoidCallback onYes;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A3A4A)
              : const Color(0xFFE1F4FE),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 36, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: AppText(
                      'Is this person being kind to you?',
                      variant: AppTextVariant.label,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: onYes,
                      borderRadius: BorderRadius.circular(10),
                      child: const SizedBox(
                        width: 60,
                        height: 36,
                        child: Center(
                          child: AppText(
                            'Yes',
                            variant: AppTextVariant.label,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onClose,
                icon: Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
