import 'package:fairytrail/api/models/explore_models.dart';

/// Upcoming destination choice helpers.
///
/// - Empty / null → Open to all / Anywhere (matches any destination filter).
/// - Synthetic country [noneName] → opt-out (never matches real destination filters).
class UpcomingDestinations {
  UpcomingDestinations._();

  static const noneName = 'None';
  static const anywhereLabel = 'Anywhere';
  static const openToAllLabel = 'Open to all';

  static bool isNoneCountry(CountryDto c) => c.country == noneName;

  static bool isNoneDestination(UpcomingDestinationDto d) => d.name == noneName;

  static CountryDto? noneOf(Iterable<CountryDto> countries) {
    for (final c in countries) {
      if (isNoneCountry(c)) return c;
    }
    return null;
  }

  /// Real countries only (excludes None) — for current-country / explore filters.
  static List<CountryDto> realCountries(Iterable<CountryDto> countries) =>
      [for (final c in countries) if (!isNoneCountry(c)) c];

  /// Destination IDs safe to put in Explore "Traveling to" prefs.
  static List<int> filterableIds(Iterable<UpcomingDestinationDto> destinations) =>
      [
        for (final d in destinations)
          if (!isNoneDestination(d)) d.id,
      ];

  static String displayLabel(List<UpcomingDestinationDto> destinations) {
    if (destinations.isEmpty) return anywhereLabel;
    if (destinations.length == 1 && isNoneDestination(destinations.first)) {
      return noneName;
    }
    return destinations.map((d) => d.name).join(', ');
  }

  static bool isOpenToAll(List<UpcomingDestinationDto> destinations) =>
      destinations.isEmpty;

  static bool isNoneOnly(List<UpcomingDestinationDto> destinations) =>
      destinations.length == 1 && isNoneDestination(destinations.first);
}
