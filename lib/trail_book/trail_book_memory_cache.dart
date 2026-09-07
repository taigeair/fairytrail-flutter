import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/api/models/trail_book_models.dart';

/// Process-lifetime cache for Trail Book so reopening the screen can paint
/// instantly while a background refresh runs.
class TrailBookMemoryCache {
  TrailBookMemoryCache._();
  static final TrailBookMemoryCache instance = TrailBookMemoryCache._();

  bool feedReady = false;
  List<TrailBookItemDto> items = const [];
  int page = 1;
  bool hasMore = true;

  bool countriesReady = false;
  List<CountryDto> countries = const [];
  Set<int> visitedCountryIds = const {};
  String? profileName;
  String? profileMobility;

  void saveFeed({
    required List<TrailBookItemDto> items,
    required int page,
    required bool hasMore,
  }) {
    this.items = List<TrailBookItemDto>.from(items);
    this.page = page;
    this.hasMore = hasMore;
    feedReady = true;
  }

  void saveCountries({
    required List<CountryDto> countries,
    required Set<int> visitedCountryIds,
    String? profileName,
    String? profileMobility,
  }) {
    this.countries = List<CountryDto>.from(countries);
    this.visitedCountryIds = Set<int>.from(visitedCountryIds);
    this.profileName = profileName;
    this.profileMobility = profileMobility;
    countriesReady = true;
  }

  void removeItem(int id) {
    if (!feedReady) return;
    items = [for (final item in items) if (item.id != id) item];
  }

  void clear() {
    feedReady = false;
    items = const [];
    page = 1;
    hasMore = true;
    countriesReady = false;
    countries = const [];
    visitedCountryIds = const {};
    profileName = null;
    profileMobility = null;
  }
}
