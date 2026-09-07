import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Explore activity card — photo, savers, Join Chat, bookmark, more.
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.savedCount,
    required this.isSaved,
    required this.avatars,
    this.heroTag,
    this.onJoinChat,
    this.onBookmark,
    this.onMoreOptions,
    this.onSavedPress,
    this.onImageTap,
  });

  final String title;
  final String imageUrl;
  final int savedCount;
  final bool isSaved;
  final List<String> avatars;

  /// Shared with Activity Info for the open/close image transition.
  final Object? heroTag;
  final VoidCallback? onJoinChat;
  final VoidCallback? onBookmark;
  final VoidCallback? onMoreOptions;
  final VoidCallback? onSavedPress;
  final VoidCallback? onImageTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final formattedSavedCount = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(savedCount);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderOf(context).withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppText(
              title,
              variant: AppTextVariant.title,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 1,
              child: _maybeHero(
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onImageTap,
                    child: AppCachedImage(url: imageUrl),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onSavedPress,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AvatarStack(avatars: avatars.take(4).toList()),
                          const SizedBox(height: 4),
                          AppText(
                            'Saved by $formattedSavedCount '
                            '${savedCount == 1 ? 'explorer' : 'explorers'}',
                            variant: AppTextVariant.caption,
                            fontSize: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _JoinChatButton(onPressed: onJoinChat),
                const SizedBox(width: 8),
                _IconAction(
                  onPressed: onBookmark,
                  child: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    size: 18,
                    color: isSaved
                        ? AppColors.primary
                        : AppColors.textPrimaryOf(context),
                  ),
                ),
                IconButton(
                  onPressed: onMoreOptions,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.more_vert,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _maybeHero({required Widget child}) {
    final tag = heroTag;
    if (tag == null) return child;
    return Hero(tag: tag, child: child);
  }
}

class _JoinChatButton extends StatelessWidget {
  const _JoinChatButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        child: const Text('Join Chat'),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.child, this.onPressed});

  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.borderOf(context).withValues(alpha: 0.9),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.avatars});

  final List<String> avatars;

  @override
  Widget build(BuildContext context) {
    if (avatars.isEmpty) {
      return const SizedBox(height: 28);
    }

    final width = 28.0 + (avatars.length - 1) * 18.0;
    return SizedBox(
      width: width,
      height: 28,
      child: Stack(
        children: [
          // Paint right→left so the leftmost avatar sits on top (RN zIndex).
          for (var i = avatars.length - 1; i >= 0; i--)
            Positioned(
              left: i * 18.0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1.5,
                  ),
                ),
                child: ClipOval(child: AppCachedImage(url: avatars[i])),
              ),
            ),
        ],
      ),
    );
  }
}
