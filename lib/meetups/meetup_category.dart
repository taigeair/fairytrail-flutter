enum MeetupCategory {
  social,
  outdoorActive,
  foodDrinks,
  sports,
  wellness,
  nightlife,
  sightseeing,
  entertainment,
  shopping,
  rideshare,
  other;

  String get apiValue => switch (this) {
    MeetupCategory.social => 'social',
    MeetupCategory.outdoorActive => 'outdoor_active',
    MeetupCategory.sports => 'sports',
    MeetupCategory.nightlife => 'nightlife',
    MeetupCategory.foodDrinks => 'food_drinks',
    MeetupCategory.sightseeing => 'sightseeing',
    MeetupCategory.entertainment => 'entertainment',
    MeetupCategory.shopping => 'shopping',
    MeetupCategory.rideshare => 'rideshare',
    MeetupCategory.wellness => 'wellness',
    MeetupCategory.other => 'other',
  };

  String get label => switch (this) {
    MeetupCategory.social => 'Social',
    MeetupCategory.outdoorActive => 'Outdoor & adventure',
    MeetupCategory.sports => 'Sports & games',
    MeetupCategory.nightlife => 'Nightlife',
    MeetupCategory.foodDrinks => 'Food & drinks',
    MeetupCategory.sightseeing => 'Tours & sightseeing',
    MeetupCategory.entertainment => 'Shows & concerts',
    MeetupCategory.shopping => 'Markets & shopping',
    MeetupCategory.rideshare => 'Rideshare',
    MeetupCategory.wellness => 'Wellness',
    MeetupCategory.other => 'Other',
  };

  /// Material icon used for pins / category chips.
  String get iconName => switch (this) {
    MeetupCategory.social => 'groups',
    MeetupCategory.outdoorActive => 'terrain',
    MeetupCategory.sports => 'sports_soccer',
    MeetupCategory.nightlife => 'nightlife',
    MeetupCategory.foodDrinks => 'restaurant',
    MeetupCategory.sightseeing => 'camera_alt',
    MeetupCategory.entertainment => 'confirmation_number',
    MeetupCategory.shopping => 'shopping_bag',
    MeetupCategory.rideshare => 'directions_car',
    MeetupCategory.wellness => 'spa',
    MeetupCategory.other => 'place',
  };

  static MeetupCategory fromApi(String? value) {
    return switch (value) {
      'social' => MeetupCategory.social,
      'outdoor_active' => MeetupCategory.outdoorActive,
      'sports' => MeetupCategory.sports,
      'nightlife' => MeetupCategory.nightlife,
      'food_drinks' => MeetupCategory.foodDrinks,
      'sightseeing' => MeetupCategory.sightseeing,
      'entertainment' => MeetupCategory.entertainment,
      'shopping' => MeetupCategory.shopping,
      'rideshare' => MeetupCategory.rideshare,
      'wellness' => MeetupCategory.wellness,
      _ => MeetupCategory.other,
    };
  }
}
