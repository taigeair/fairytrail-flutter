import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Compact Reels-style activity tile for the local search grid.
class ActivitySearchGridCard extends StatelessWidget {
  const ActivitySearchGridCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.savedCount,
    required this.avatars,
    this.heroTag,
    this.onTap,
  });

  final String title;
  final String imageUrl;
  final int savedCount;
  final List<String> avatars;
  final Object? heroTag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final formattedSavedCount = NumberFormat.compact(
      locale: Localizations.localeOf(context).toLanguageTag(),
    ).format(savedCount);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _maybeHero(
              child: Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: AppCachedImage(url: imageUrl, borderRadius: 12),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x99000000)],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText(
                      title,
                      variant: AppTextVariant.label,
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _MiniAvatarStack(avatars: avatars.take(3).toList()),
                        if (avatars.isNotEmpty) const SizedBox(width: 6),
                        Expanded(
                          child: AppText(
                            savedCount == 1
                                ? '1 saved'
                                : '$formattedSavedCount saved',
                            variant: AppTextVariant.caption,
                            color: AppColors.white.withValues(alpha: 0.92),
                            fontSize: 11,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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

class _MiniAvatarStack extends StatelessWidget {
  const _MiniAvatarStack({required this.avatars});

  final List<String> avatars;

  @override
  Widget build(BuildContext context) {
    if (avatars.isEmpty) return const SizedBox.shrink();

    const size = 18.0;
    const overlap = 11.0;
    final width = size + (avatars.length - 1) * overlap;

    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          for (var i = avatars.length - 1; i >= 0; i--)
            Positioned(
              left: i * overlap,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: ClipOval(child: AppCachedImage(url: avatars[i])),
              ),
            ),
        ],
      ),
    );
  }
}
