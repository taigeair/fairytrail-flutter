/// Motives for joining Fairytrail ("What brings you here?").
const signupMotiveOptions = [
  ('Make like-minded friends', 'new_friends'),
  ('Find a travel buddy', 'travel_buddy'),
  ('Meet travelers nearby', 'meet_nearby'),
  // ('Find a romantic partner', 'romantic_partner'),
  ('Discover trips and adventures', 'discover_trips'),
  ('Save and plan future trips', 'plan_trips'),
];

String? labelForMotive(String? value) {
  if (value == null || value.isEmpty) return null;
  for (final opt in signupMotiveOptions) {
    if (opt.$2 == value) return opt.$1;
  }
  return value;
}

String labelsForMotives(List<String> values) {
  if (values.isEmpty) return '';
  return values.map(labelForMotive).whereType<String>().join(', ');
}

/// Travel style options.
/// (label, value, description)
///
/// Unfilled profiles keep `travel_style` NULL in the DB; treat that as Solo Traveler
/// in UI and explore queries (`null == solo_traveller`).
const soloTravellerValue = 'solo_traveller';

const signupTravelKindOptions = [
  ('Solo Traveler', soloTravellerValue, 'Travels independently'),
  ('World Citizen', 'world_citizen', 'Has multiple homes or citizenships'),
  ('Digital Nomad', 'digital_nomad', 'Works remotely while traveling'),
  ('Backpacker', 'backpacker', 'Travels on a budget'),
  ('Local', 'socializer', 'Enjoys meeting travelers'),
  ('Student', 'student', 'Studying in university or college'),
  ('Volunteer', 'transplant', 'Supporting communities and causes'),
  ('Sabbatical', 'sabbatical', 'Taking extended time off to travel'),
  ('Luxury', 'luxury', 'Prefers premium travel experiences'),
  ('Van Life', 'van_life', 'Traveling or living in a camper'),
  ('Retired', 'retired', 'Traveling without needing to work'),
];

/// Filter picker options: (label, value).
List<(String, String)> get exploreTravelStyleOptions => [
  for (final o in signupTravelKindOptions) (o.$1, o.$2),
];

/// Social-proof headline for a travel style — plural forms.
String socialProofTextForTravelKind(String? value) {
  const byValue = {
    soloTravellerValue: 'Meet other solo travelers like you',
    'world_citizen': 'Meet other world citizens like you',
    'digital_nomad': 'Meet other digital nomads like you',
    'backpacker': 'Meet other backpackers like you',
    'socializer': 'Meet other locals like you',
    'student': 'Meet other students like you',
    'transplant': 'Meet other volunteers like you',
    'sabbatical': 'Meet other sabbatical travelers like you',
    'luxury': 'Meet other luxury travelers like you',
    'van_life': 'Meet other van travelers like you',
    'retired': 'Meet other retirees like you',
  };
  if (value == null || value.isEmpty) {
    return byValue[soloTravellerValue]!;
  }
  return byValue[value] ?? 'Meet other travelers like you';
}

/// Display label — null/empty is Solo Traveler (DB stays null).
String labelForTravelStyle(String? value) {
  if (value == null || value.isEmpty) return 'Solo Traveler';
  for (final opt in signupTravelKindOptions) {
    if (opt.$2 == value) return opt.$1;
  }
  return value;
}
