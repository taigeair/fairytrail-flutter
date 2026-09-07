import 'package:cached_network_image/cached_network_image.dart';
import 'package:fairytrail/api/models/trail_book_models.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/trail_book/postcard_art.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _postcardCream = Color(0xFFFFFAE9);

/// Vertical travel-poster postcard (illustration + message).
class TrailBookPostcardCard extends StatelessWidget {
  const TrailBookPostcardCard({
    super.key,
    required this.item,
    this.onTap,
    this.compact = false,
    this.isNew = false,
    this.heroTag,
  });

  final TrailBookItemDto item;
  final VoidCallback? onTap;
  final bool compact;
  final bool isNew;

  /// When set, only the illustration participates in a [Hero] flight.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return PostcardVisual(
      message: item.message,
      senderName: item.displaySenderName,
      location: item.senderLocation,
      date: item.createdAt,
      onTap: onTap,
      compact: compact,
      isNew: isNew,
      heroTag: heroTag,
    );
  }
}

/// Postcard visual used by inbox cards and the send-flow recipient preview.
class PostcardVisual extends StatelessWidget {
  const PostcardVisual({
    super.key,
    required this.message,
    required this.senderName,
    this.location = '',
    this.date,
    this.onTap,
    this.compact = false,
    this.isNew = false,
    this.maxMessageLines,
    this.scrollMessage = false,
    this.locationLoading = false,
    this.heroTag,
  });

  final String message;
  final String senderName;
  final String location;
  final DateTime? date;
  final VoidCallback? onTap;
  final bool compact;
  final bool isNew;
  final int? maxMessageLines;

  /// When true, shows the full message and scrolls if it overflows.
  final bool scrollMessage;

  /// When true, the illustration area shows a location shimmer instead of art.
  final bool locationLoading;

  /// When set, only the illustration participates in a [Hero] flight.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final resolvedDate = date ?? DateTime.now();
    final dateLabel = DateFormat('MMM d, y').format(resolvedDate.toLocal());
    final artUrl = PostcardArt.urlForLocation(location);
    final radius = compact ? 16.0 : 20.0;
    final messageLines = maxMessageLines ?? (compact ? 6 : 6);
    final imageTopRadius = radius - 3;
    final imageBottomRadius = 4.0;
    final imageBorderRadius = BorderRadius.only(
      topLeft: Radius.circular(imageTopRadius),
      topRight: Radius.circular(imageTopRadius),
      bottomLeft: Radius.circular(imageBottomRadius),
      bottomRight: Radius.circular(imageBottomRadius),
    );
    final imageClipRadius = BorderRadius.only(
      topLeft: Radius.circular(imageTopRadius - 0.5),
      topRight: Radius.circular(imageTopRadius - 0.5),
      bottomLeft: Radius.circular(imageBottomRadius),
      bottomRight: Radius.circular(imageBottomRadius),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _postcardCream,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE8DFC8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: compact ? 10 : 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Column(
              mainAxisSize: scrollMessage ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: _maybeHero(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: imageBorderRadius,
                        border: Border.all(
                          color: const Color(0xFFD6C9A8),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: imageClipRadius,
                        child: locationLoading
                            ? const _PostcardImageLocationShimmer()
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  _PostcardArtImage(url: artUrl),
                                  if (isNew)
                                    Positioned(
                                      top: 10,
                                      left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'NEW',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                _buildMessageBody(
                  compact: compact,
                  messageLines: messageLines,
                  dateLabel: dateLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _maybeHero({required Widget child}) {
    final tag = heroTag;
    if (tag == null) return child;
    return Hero(
      tag: tag,
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );
  }

  Widget _buildMessageBody({
    required bool compact,
    required int messageLines,
    required String dateLabel,
  }) {
    final signature = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            '— $senderName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              fontStyle: FontStyle.italic,
              color: AppColors.black.withValues(alpha: 0.85),
            ),
          ),
        ),
        SizedBox(width: compact ? 6 : 10),
        Text(
          dateLabel,
          maxLines: 1,
          style: TextStyle(
            fontSize: compact ? 9 : 11,
            color: const Color(0xFF8F8F8F),
          ),
        ),
      ],
    );

    final messageStyle = TextStyle(
      fontSize: compact ? 11 : 13,
      height: 1.35,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.italic,
      color: message.isEmpty ? AppColors.mediumGray : AppColors.black,
    );

    final body = Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 14,
        compact ? 10 : 12,
        compact ? 10 : 14,
        compact ? 8 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (scrollMessage)
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  message.isEmpty
                      ? 'No matter how far I travel, you are still my favorite destination. A small postcard to remind you that people care.'
                      : message,
                  style: messageStyle,
                ),
              ),
            )
          else
            Text(
              message.isEmpty
                  ? 'May this postcard remind you that you are surrounded by more kindness than you realize.'
                  : message,
              maxLines: messageLines,
              overflow: TextOverflow.ellipsis,
              style: messageStyle,
            ),
          SizedBox(height: compact ? 6 : 8),
          signature,
          SizedBox(height: compact ? 8 : 10),
          Center(
            child: Text(
              '@fairytrailapp',
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: AppColors.black.withValues(alpha: 0.28),
              ),
            ),
          ),
        ],
      ),
    );

    if (scrollMessage) return Expanded(child: body);
    return body;
  }
}

/// Country postcard art from CDN, with local default fallback.
class _PostcardArtImage extends StatelessWidget {
  const _PostcardArtImage({this.url});

  final String? url;

  Widget get _default => Image.asset(
        PostcardArt.defaultAsset,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        width: double.infinity,
        height: double.infinity,
      );

  @override
  Widget build(BuildContext context) {
    final artUrl = url;
    if (artUrl == null || artUrl.isEmpty) return _default;

    return CachedNetworkImage(
      imageUrl: artUrl,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => const ColoredBox(color: Color(0xFFE8DFC8)),
      errorWidget: (_, _, _) => _default,
    );
  }
}

/// Shimmer for the postcard illustration while country/location is resolving.
class _PostcardImageLocationShimmer extends StatefulWidget {
  const _PostcardImageLocationShimmer();

  @override
  State<_PostcardImageLocationShimmer> createState() =>
      _PostcardImageLocationShimmerState();
}

class _PostcardImageLocationShimmerState
    extends State<_PostcardImageLocationShimmer>
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
    const base = Color(0xFFE8DFC8);
    const highlight = Color(0xFFF7F1E3);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1.8 + 3.6 * t, -0.25),
                  end: Alignment(-0.2 + 3.6 * t, 0.25),
                  colors: const [base, highlight, base],
                  stops: const [0.15, 0.5, 0.85],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 26,
                    color: AppColors.black.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Loading location…',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
