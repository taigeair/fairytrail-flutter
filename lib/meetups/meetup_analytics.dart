import 'dart:async';

import 'package:fairytrail/api/models/meetup_models.dart';
import 'package:fairytrail/track/track.dart';

Map<String, dynamic> meetupTrackProps(MeetupDto m) => {
      'meetup_id': m.id,
      'meetup_name': m.name,
      'category': m.category.apiValue,
      'starts_at': m.startsAt.toUtc().toIso8601String(),
      'member_count': m.memberCount,
      if (m.distanceKm != null) 'distance_km': m.distanceKm,
    };

/// Mixpanel: created meetup (also refreshes profile `count_meetup_created`).
void trackCreatedMeetup(MeetupDto m) {
  unawaited(track('created_meetup', meetupTrackProps(m)));
}

/// Mixpanel: joined meetup (also refreshes profile `count_meetup_joined`).
void trackJoinedMeetup(MeetupDto m) {
  unawaited(track('joined_meetup', meetupTrackProps(m)));
}
