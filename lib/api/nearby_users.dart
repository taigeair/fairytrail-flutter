import 'package:fairytrail/meetups/discovery_radius.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';
import 'package:fairytrail/utils/common.dart';

const _nearbyUsersMaxAttempts = 5;
const _nearbyUsersRetryDelay = Duration(seconds: 2);

class NearbyUserDto {
  const NearbyUserDto({
    required this.profileId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.photoThumbnailUrl,
  });

  final int profileId;
  final String name;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String? photoThumbnailUrl;

  factory NearbyUserDto.fromJson(Map<String, dynamic> json) {
    return NearbyUserDto(
      profileId: (json['profileId'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      photoThumbnailUrl: json['photoThumbnailUrl'] as String?,
    );
  }
}

class NearbyUsersPage {
  const NearbyUsersPage({
    required this.users,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  final List<NearbyUserDto> users;
  final int page;
  final int pageSize;
  final int totalCount;

  factory NearbyUsersPage.fromJson(Map<String, dynamic> json) {
    final list = json['users'];
    return NearbyUsersPage(
      users: list is List
          ? list
                .whereType<Map>()
                .map((e) => NearbyUserDto.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 10,
      totalCount: (json['totalCount'] as num?)?.toInt() ??
          (json['count'] as num?)?.toInt() ??
          0,
    );
  }
}

/// GET /api/v1/nearby-users
Future<NearbyUsersPage> fetchNearbyUsers({
  double radiusKm = DiscoveryRadius.km,
  int page = 1,
  int pageSize = 10,
}) async {
  final query =
      'radius_km=$radiusKm&page=$page&page_size=$pageSize';
  final response = await HttpClient.instance.request(
    path: '${EndPoints.nearbyUsers}?$query',
    method: HttpMethod.get,
    requiresAuth: true,
  );
  final data = response.data;
  if (data is! Map) {
    return const NearbyUsersPage(
      users: [],
      page: 1,
      pageSize: 10,
      totalCount: 0,
    );
  }
  return NearbyUsersPage.fromJson(Map<String, dynamic>.from(data));
}

/// [fetchNearbyUsers] with up to [_nearbyUsersMaxAttempts] attempts and
/// [_nearbyUsersRetryDelay] between failures (non-retryable API codes skip retries).
Future<NearbyUsersPage> fetchNearbyUsersWithRetry({
  double radiusKm = DiscoveryRadius.km,
  int page = 1,
  int pageSize = 10,
}) async {
  Object? lastError;
  for (var attempt = 1; attempt <= _nearbyUsersMaxAttempts; attempt++) {
    try {
      return await fetchNearbyUsers(
        radiusKm: radiusKm,
        page: page,
        pageSize: pageSize,
      );
    } catch (e) {
      lastError = e;
      if (serverErrorCode(e) == 'location_not_set') rethrow;
      if (attempt >= _nearbyUsersMaxAttempts) rethrow;
      await Future<void>.delayed(_nearbyUsersRetryDelay);
    }
  }
  throw lastError!;
}
