import 'package:fairytrail/api/nearby_users.dart';
import 'package:fairytrail/meetups/discovery_radius.dart';
import 'package:fairytrail/location/location_service.dart';
import 'package:fairytrail/utils/common.dart';

/// Map-header preview of nearby travelers (first [previewSize] avatars).
///
/// Free users reuse this cache on the Nearby list ([initLoadSize] rows;
/// first [previewSize] clear, rest blurred). Paid users seed page 1 from
/// this cache and paginate [initLoadSize] at a time from page 2 onward.
class NearbyUsersPreview {
  NearbyUsersPreview._();

  static const radiusKm = DiscoveryRadius.km;

  /// Avatars shown in the map header stack.
  static const previewSize = 4;

  /// Single init fetch size (free-tier full list + map preview source).
  static const initLoadSize = 8;

  static List<NearbyUserDto> users = [];
  static int totalCount = 0;
  static bool loaded = false;
  static bool loading = false;
  static String? error;

  static Future<void> ensureLoaded({bool force = false}) async {
    if (loading) return;
    if (loaded && !force) return;

    loading = true;
    error = null;
    try {
      final outcome = await LocationService.shareCurrentLocation();
      if (outcome.latitude == null || outcome.longitude == null) {
        error = 'location_required';
        users = [];
        totalCount = 0;
        loaded = true;
        return;
      }

      final page = await fetchNearbyUsersWithRetry(
        radiusKm: radiusKm,
        page: 1,
        pageSize: initLoadSize,
      );
      users = List<NearbyUserDto>.from(page.users);
      totalCount = page.totalCount;
      loaded = true;
    } catch (e) {
      final code = serverErrorCode(e);
      error = code == 'location_not_set'
          ? 'location_required'
          : serverErrorText(e);
      // Keep prior users on refresh failure.
      if (!loaded) {
        users = [];
        totalCount = 0;
        loaded = true;
      }
    } finally {
      loading = false;
    }
  }
}
