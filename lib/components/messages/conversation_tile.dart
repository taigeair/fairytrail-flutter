import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/app_cached_image.dart';
import 'package:fairytrail/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String formatChatTime(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) {
    return DateFormat.jm().format(local);
  }
  if (day == today.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  }
  if (now.difference(local).inDays < 7) {
    return DateFormat.E().format(local);
  }
  return DateFormat.MMMd().format(local);
}

String formatMessageClock(DateTime dt) => DateFormat.jm().format(dt.toLocal());

String formatDateSeparator(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat.yMMMd().format(local);
}

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    this.url,
    this.assetPath,
    this.blurHash,
    this.size = 52,
    this.isGroup = false,
    this.leadingIcon,
    this.leadingEmoji,
  });

  final String? url;
  final String? assetPath;
  final String? blurHash;
  final double size;
  final bool isGroup;
  final IconData? leadingIcon;
  final String? leadingEmoji;

  @override
  Widget build(BuildContext context) {
    // Group chats use a rounded square; DMs stay circular.
    final radius = isGroup ? size * 0.16 : size / 2;
    if (leadingEmoji != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            leadingEmoji!,
            style: TextStyle(fontSize: size * 0.55, height: 1),
          ),
        ),
      );
    }
    if (leadingIcon != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: ColoredBox(
            color: AppColors.primary.withValues(alpha: 0.14),
            child: Icon(
              leadingIcon,
              size: size * 0.45,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    if (assetPath != null && assetPath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          assetPath!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    if (url != null && url!.isNotEmpty) {
      return AppCachedImage(
        url: url!,
        blurHash: blurHash,
        width: size,
        height: size,
        borderRadius: radius,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: AppColors.surfaceOf(context),
          child: Icon(
            isGroup ? Icons.groups_outlined : Icons.person_outline,
            size: size * 0.45,
            color: AppColors.mediumGray,
          ),
        ),
      ),
    );
  }
}

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.unread,
    required this.onTap,
    this.avatarUrl,
    this.blurHash,
    this.avatarAssetPath,
    this.isGroup = false,
    this.memberCount,
    this.isDraft = false,
    this.badgeLabel,
    this.leadingIcon,
    this.leadingEmoji,
  });

  final String title;
  final String subtitle;
  final DateTime time;
  final bool unread;
  final VoidCallback onTap;
  final String? avatarUrl;
  final String? blurHash;
  final String? avatarAssetPath;
  final bool isGroup;
  final int? memberCount;
  final bool isDraft;
  /// Optional chip next to the title (e.g. "Meetup").
  final String? badgeLabel;
  final IconData? leadingIcon;
  final String? leadingEmoji;

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.textPrimaryOf(context);
    final secondary = AppColors.textSecondaryOf(context);

    return InkWell(
      onTap: () {
        HapticsService.selection();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ChatAvatar(
              url: avatarUrl,
              blurHash: blurHash,
              assetPath: avatarAssetPath,
              isGroup: isGroup,
              leadingIcon: leadingIcon,
              leadingEmoji: leadingEmoji,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: AppText(
                                title,
                                variant: AppTextVariant.label,
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 16,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                color: primary,
                              ),
                            ),
                            if (badgeLabel != null &&
                                badgeLabel!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  badgeLabel!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppText(
                        formatChatTime(time),
                        variant: AppTextVariant.caption,
                        fontSize: 12,
                        color: unread ? AppColors.primary : secondary,
                        fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: isDraft && subtitle.isNotEmpty
                            ? Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.25,
                                    color: secondary,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: 'Draft: ',
                                      style: TextStyle(
                                        color: Color(0xFFE53935),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(text: subtitle),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : AppText(
                                subtitle.isEmpty
                                    ? (isGroup
                                          ? '${NumberFormat.decimalPattern().format(memberCount ?? 0)} members'
                                          : 'Say hello!')
                                    : subtitle,
                                variant: AppTextVariant.body,
                                fontSize: 14,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                color: unread ? primary : secondary,
                                fontWeight: unread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
