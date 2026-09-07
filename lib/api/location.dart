import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

/// POST /api/v1/location
Future<void> postLocation({
  required double latitude,
  required double longitude,
  bool updateCountry = true,
}) async {
  await HttpClient.instance.request(
    path: EndPoints.location,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {
      'latitude': latitude,
      'longitude': longitude,
      'updateCountry': updateCountry,
    },
  );
}

/// POST /api/v1/location/country-id
Future<int?> postCountryIdFromCoordinates({
  required double latitude,
  required double longitude,
}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.locationCountryId,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'latitude': latitude, 'longitude': longitude},
  );

  final data = response.data;
  if (data is! Map) return null;
  final id = data['countryId'];
  if (id is num) return id.toInt();
  return null;
}
