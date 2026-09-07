import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/components/messages/conversation_tile.dart';
import 'package:fairytrail/constants/blur_hash.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

/// Banner at the top of Messages (RN `IncomingConnectsRow`).
class IncomingConnectsBanner extends StatelessWidget {
  const IncomingConnectsBanner({
    super.key,
    required this.total,
    required this.profile,
    required this.isSubscribed,
    required this.onReveal,
  });

  final int total;
  final FullProfileDto profile;
  final bool isSubscribed;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final photo = profile.photos.isEmpty ? null : profile.photos.first;
    final displayTotal = total > 500 ? '500+' : '$total';
    final text = total == 1
        ? 'Someone is waiting to connect'
        : '$displayTotal people are waiting to connect';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? AppColors.primary.withValues(alpha: 0.18)
        : AppColors.lightHighlightSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            HapticsService.selection();
            onReveal();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _Avatar(
                  url: photo?.displayUrl,
                  blurHash: photo?.blurHash,
                  blurred: !isSubscribed,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppText(
                    text,
                    variant: AppTextVariant.label,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: AppText(
                      'Reveal',
                      variant: AppTextVariant.label,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.blurHash,
    required this.blurred,
  });

  final String? url;
  final String? blurHash;
  final bool blurred;

  @override
  Widget build(BuildContext context) {
    const size = 56.0;

    Widget child;
    if (blurred) {
      // Never show the real photo when locked — use photo hash or a default blur.
      child = _BlurHashAvatar(hash: effectiveBlurHash(blurHash), size: size);
    } else {
      child = ChatAvatar(
        url: url,
        blurHash: effectiveBlurHash(blurHash),
        size: size,
      );
    }

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: blurred
            ? Stack(
                fit: StackFit.expand,
                children: [
                  child,
                  ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
                ],
              )
            : child,
      ),
    );
  }
}

class _BlurHashAvatar extends StatelessWidget {
  const _BlurHashAvatar({required this.hash, required this.size});

  final String hash;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: BlurHashImage(hash),
      fit: BoxFit.cover,
      width: size,
      height: size,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) {
        // Invalid/corrupt hash — fall back to the shared default, then asset.
        if (hash != kFallbackBlurHash) {
          return Image(
            image: BlurHashImage(kFallbackBlurHash),
            fit: BoxFit.cover,
            width: size,
            height: size,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => Image.asset(
              'assets/reveal/hidden3.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
        }
        return Image.asset(
          'assets/reveal/hidden3.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      },
    );
  }
}
