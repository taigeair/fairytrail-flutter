/// Shared discovery radius for meetups, nearby travelers, and map pan limit.
abstract final class DiscoveryRadius {
  static const miles = 100.0;

  /// 100 mi in km (used by API query params and map pan bounds).
  static const km = miles * 1.609344;
}
