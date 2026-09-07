import 'package:cached_network_image/cached_network_image.dart';
import 'package:fairytrail/constants/blur_hash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

/// Network image with a stable BlurHash underlay and a one-shot fade-in.
///
/// Avoids [CachedNetworkImage]'s placeholder↔image swap (which flickered) by
/// painting the hash underneath and fading the decoded image on top only after
/// its first frame is ready. When no blur hash is available, a default blur
/// hash is used as the underlay.
///
/// Progressive load (when [thumbnailUrl] is set):
/// blur hash → sm ([thumbnailUrl]) → md ([url]). Both network layers mount
/// together so they download in parallel; sm usually paints first, md is final.
class AppCachedImage extends StatelessWidget {
  const AppCachedImage({
    super.key,
    required this.url,
    this.thumbnailUrl,
    this.blurHash,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.showPlaceholderUnderlay = true,
  });

  /// Final image URL (typically `_md` / 720px).
  final String url;

  /// Optional low-res preview (typically `_sm` / 128px). Loaded in parallel
  /// with [url] and shown until the full image is ready.
  final String? thumbnailUrl;

  final String? blurHash;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;

  /// Whether the loading placeholder remains painted beneath the decoded
  /// image. Disable for transparent artwork so its alpha reveals the parent.
  final bool showPlaceholderUnderlay;

  @override
  Widget build(BuildContext context) {
    final hash = effectiveBlurHash(blurHash);
    final thumb = thumbnailUrl?.trim();
    final hasThumb =
        thumb != null && thumb.isNotEmpty && thumb != url && url.isNotEmpty;

    final stacked = Stack(
      fit: StackFit.expand,
      children: [
        if (showPlaceholderUnderlay)
          // Stable underlay — never torn down when the network image arrives.
          Positioned.fill(
            child: Image(
              key: ValueKey('blur-$hash'),
              image: BlurHashImage(hash),
              fit: fit,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) {
                if (hash == kFallbackBlurHash) {
                  return const _Shimmer();
                }
                return Image(
                  image: BlurHashImage(kFallbackBlurHash),
                  fit: fit,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const _Shimmer(),
                );
              },
            ),
          ),
        if (hasThumb)
          Positioned.fill(
            child: _FadingNetworkImage(url: thumb, fit: fit),
          ),
        if (url.isNotEmpty)
          Positioned.fill(
            child: _FadingNetworkImage(url: url, fit: fit),
          ),
      ],
    );

    final sized = width != null || height != null
        ? SizedBox(width: width, height: height, child: stacked)
        : stacked;

    if (borderRadius <= 0) return sized;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: sized,
    );
  }
}

class _FadingNetworkImage extends StatelessWidget {
  const _FadingNetworkImage({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image(
      key: ValueKey('net-$url'),
      image: CachedNetworkImageProvider(url),
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        if (frame == null) {
          // Keep underlay (blur hash / sm) visible while decoding.
          return const SizedBox.expand();
        }
        return TweenAnimationBuilder<double>(
          key: ValueKey('fade-$url'),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          builder: (context, opacity, child) =>
              Opacity(opacity: opacity, child: child),
          child: child,
        );
      },
      errorBuilder: (context, _, _) => const SizedBox.expand(),
    );
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer();

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8);
    final highlight = isDark
        ? const Color(0xFF3C3C3C)
        : const Color(0xFFF4F4F4);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.8 + 3.6 * t, -0.25),
              end: Alignment(-0.2 + 3.6 * t, 0.25),
              colors: [base, highlight, base],
              stops: const [0.15, 0.5, 0.85],
            ),
          ),
        );
      },
    );
  }
}
