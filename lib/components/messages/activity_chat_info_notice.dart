import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Pinned-style info strip under the activity group chat app bar (Telegram-like).
class ActivityChatInfoNotice extends StatelessWidget {
  const ActivityChatInfoNotice({
    super.key,
    required this.onClose,
    this.inAppBar = false,
  });

  final VoidCallback onClose;
  final bool inAppBar;

  static const message =
      'Introduce yourself, share your trip idea, and send connects to other travelers here';

  static const preferredHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    if (inAppBar) {
      return _PinnedStrip(onClose: onClose);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: _NoticeCard(onClose: onClose),
    );
  }
}

/// Drop shadow under the activity chat toolbar. Lives in the body so Scaffold
/// does not clip [BoxDecoration.boxShadow] / [Material.elevation].
class ActivityChatHeaderShadow extends StatelessWidget {
  const ActivityChatHeaderShadow({super.key});

  static const height = 8.0;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: isDark ? 0.22 : 0.1),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _PinnedStrip extends StatelessWidget {
  const _PinnedStrip({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: SizedBox(
        height: ActivityChatInfoNotice.preferredHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
          child: Row(
            children: [
              Transform.rotate(
                angle: 0.785398, // 45° — Telegram-style pin
                child: Icon(
                  Icons.push_pin_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppText(
                  ActivityChatInfoNotice.message,
                  variant: AppTextVariant.bodySmall,
                  fontSize: 13,
                  color: AppColors.textPrimaryOf(context),
                  maxLines: 2,
                ),
              ),
              IconButton(
                tooltip: 'Close',
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: onClose,
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A3A4A) : const Color(0xFFE1F4FE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF2A5A6A) : const Color(0xFFB3E5FC),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            Expanded(
              child: AppText(
                ActivityChatInfoNotice.message,
                variant: AppTextVariant.body,
                fontSize: 13,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: onClose,
              icon: Icon(
                Icons.close,
                size: 18,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// App bar extension: connectivity strip + optional activity chat info notice.
class ActivityChatAppBarBottom extends StatelessWidget
    implements PreferredSizeWidget {
  const ActivityChatAppBarBottom({
    super.key,
    required this.connectivityHeight,
    required this.showInfoNotice,
    required this.onCloseInfoNotice,
  });

  final double connectivityHeight;
  final bool showInfoNotice;
  final VoidCallback onCloseInfoNotice;

  @override
  Size get preferredSize => Size.fromHeight(
    connectivityHeight +
        (showInfoNotice ? ActivityChatInfoNotice.preferredHeight : 0),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: connectivityHeight,
          child: connectivityHeight > 0
              ? const ConnectivityBannerStrip()
              : const SizedBox.shrink(),
        ),
        if (showInfoNotice)
          ActivityChatInfoNotice(inAppBar: true, onClose: onCloseInfoNotice),
      ],
    );
  }
}
