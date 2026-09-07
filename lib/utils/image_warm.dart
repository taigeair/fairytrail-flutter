import 'package:cached_network_image/cached_network_image.dart';
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:flutter/painting.dart';

/// Downloads explore profile photo variants into the shared image cache.
///
/// Prefetch already returns `_sm` ([ProfilePhotoDto.thumbnailUrl]) and `_md`
/// ([ProfilePhotoDto.url]). Warming both lets the UI paint blur → sm → md
/// without waiting on the network when the card appears.
void warmExploreProfilePhotos(
  Iterable<FullProfileDto> profiles, {
  int profileLimit = 3,
}) {
  final urls = <String>{};
  for (final profile in profiles.take(profileLimit)) {
    for (final photo in profile.photos) {
      final sm = photo.thumbnailUrl?.trim();
      if (sm != null && sm.isNotEmpty) urls.add(sm);
      final md = photo.url.trim();
      if (md.isNotEmpty) urls.add(md);
    }
  }
  for (final url in urls) {
    _warmUrl(url);
  }
}

void _warmUrl(String url) {
  final provider = CachedNetworkImageProvider(url);
  final stream = provider.resolve(const ImageConfiguration());
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo _, bool _) {
      stream.removeListener(listener);
    },
    onError: (Object _, StackTrace? _) {
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
}
