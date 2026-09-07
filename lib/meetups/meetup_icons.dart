import 'package:fairytrail/meetups/meetup_category.dart';
import 'package:flutter/material.dart';

/// Emoji shown for each meetup category (map pins, picker, lists).
String meetupCategoryEmoji(MeetupCategory category) {
  return switch (category) {
    MeetupCategory.social => '🎉',
    MeetupCategory.outdoorActive => '🌲',
    MeetupCategory.sports => '🎯',
    MeetupCategory.nightlife => '🪩',
    MeetupCategory.foodDrinks => '☕',
    MeetupCategory.sightseeing => '🗺️',
    MeetupCategory.entertainment => '🎟️',
    MeetupCategory.shopping => '🛍️',
    MeetupCategory.rideshare => '🚗',
    MeetupCategory.wellness => '🧘',
    MeetupCategory.other => '📍',
  };
}

/// Distinct multi-color palette per category (pin borders, labels).
Color meetupCategoryColor(MeetupCategory category) {
  return switch (category) {
    MeetupCategory.social => const Color(0xFF5B8DEF),
    MeetupCategory.outdoorActive => const Color(0xFF2BB673),
    MeetupCategory.sports => const Color(0xFFE53935),
    MeetupCategory.nightlife => const Color(0xFF7C5CFF),
    MeetupCategory.foodDrinks => const Color(0xFFFF6B4A),
    MeetupCategory.sightseeing => const Color(0xFF00A3C4),
    MeetupCategory.entertainment => const Color(0xFFE91E8C),
    MeetupCategory.shopping => const Color(0xFFF5A623),
    MeetupCategory.rideshare => const Color(0xFF3D5AFE),
    MeetupCategory.wellness => const Color(0xFF26A69A),
    MeetupCategory.other => const Color(0xFF78909C),
  };
}

/// Colored circle badge with category emoji.
class MeetupCategoryIconBadge extends StatelessWidget {
  const MeetupCategoryIconBadge({
    super.key,
    required this.category,
    this.size = 40,
  });

  final MeetupCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = meetupCategoryColor(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      alignment: Alignment.center,
      child: Text(
        meetupCategoryEmoji(category),
        style: TextStyle(fontSize: size * 0.45, height: 1),
      ),
    );
  }
}
