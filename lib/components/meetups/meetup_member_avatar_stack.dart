import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Overlapping member photos — activity / meetup cards.
class MeetupMemberAvatarStack extends StatelessWidget {
  const MeetupMemberAvatarStack({
    super.key,
    required this.avatars,
    this.size = 28,
    this.overlap = 18,
    this.borderColor,
    this.placeholderSize,
  });

  final List<String> avatars;
  final double size;
  final double overlap;
  final Color? borderColor;
  final double? placeholderSize;

  @override
  Widget build(BuildContext context) {
    final slots = avatars.take(4).toList();
    if (slots.isEmpty) {
      final box = placeholderSize ?? size;
      return SizedBox(
        width: box,
        height: box,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.1),
          ),
          child: Icon(
            Icons.groups_rounded,
            size: box * 0.5,
            color: AppColors.primary.withValues(alpha: 0.85),
          ),
        ),
      );
    }

    final width = size + (slots.length - 1) * overlap;
    final ring = borderColor ?? Theme.of(context).scaffoldBackgroundColor;

    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          for (var i = slots.length - 1; i >= 0; i--)
            Positioned(
              left: i * overlap,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: 1.5),
                  color: slots[i].isEmpty
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : null,
                ),
                child: slots[i].isEmpty
                    ? Icon(
                        Icons.person_rounded,
                        size: size * 0.52,
                        color: AppColors.primary.withValues(alpha: 0.75),
                      )
                    : ClipOval(child: AppCachedImage(url: slots[i])),
              ),
            ),
        ],
      ),
    );
  }
}

List<String> meetupAvatarUrls({
  required List<String> fromMeetup,
  Iterable<String?> memberPhotos = const [],
}) {
  if (fromMeetup.isNotEmpty) {
    return fromMeetup.where((u) => u.isNotEmpty).take(4).toList();
  }
  return memberPhotos
      .whereType<String>()
      .where((u) => u.isNotEmpty)
      .take(4)
      .toList();
}
