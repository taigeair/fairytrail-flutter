/// Options for Explore filters (People).
const matchWithOptions = [
  ('Man', 'man'),
  ('Woman', 'woman'),
  ('Non-binary', 'non-binary'),
  ('Couple', 'couple'),
  ('Family', 'family'),
];

const exploreMobilityOptions = [
  ('Not remote', 'non-remote'),
  ('Hybrid', 'hybrid'),
  ('Remote', 'remote'),
];

/// Near-me radius options (miles). Null = off.
const exploreRadiusMilesOptions = <int>[5, 10, 25, 50, 100];

String labelForRadiusMiles(int? miles) {
  if (miles == null || miles <= 0) return 'Off';
  return '$miles mi';
}

/// Recently-active window options (weeks). Null = off.
const exploreRecentlyActiveWeeksOptions = <int>[1, 2, 4, 8];

String labelForRecentlyActiveWeeks(int? weeks) {
  if (weeks == null || weeks <= 0) return 'Off';
  return weeks == 1 ? '1 week' : '$weeks weeks';
}

String labelForMatchWith(String value) {
  for (final o in matchWithOptions) {
    if (o.$2 == value) return o.$1;
  }
  return value;
}

String labelForMobility(String value) {
  for (final o in exploreMobilityOptions) {
    if (o.$2 == value) return o.$1;
  }
  return value;
}

const openToOptions = [('Friends', 'friends'), ('Dating', 'love')];

String labelForOpenTo(String value) {
  for (final o in openToOptions) {
    if (o.$2 == value) return o.$1;
  }
  return value;
}

String labelsForOpenTo(List<String> values) {
  if (values.isEmpty) return '';
  return values.map(labelForOpenTo).join(', ');
}

String labelForProfileType(String value) => labelForMatchWith(value);
