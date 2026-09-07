import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

Future<GetPrefsResponse> getPrefs() async {
  final response = await HttpClient.instance.request(
    path: EndPoints.mePrefs,
    method: HttpMethod.get,
    requiresAuth: true,
  );

  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected prefs response',
      payload: data,
    );
  }

  return GetPrefsResponse.fromJson(Map<String, dynamic>.from(data));
}

Future<void> putPrefs(UserPrefsDto prefs) async {
  await HttpClient.instance.request(
    path: EndPoints.mePrefs,
    method: HttpMethod.put,
    requiresAuth: true,
    body: prefs.toJson(),
  );
}

/// Seeds default match-with prefs (RN `/api/v1/me/match-with`).
Future<void> putMatchWith({
  required List<String> matchWith,
  int? ageFrom,
  int? ageTo,
}) async {
  await HttpClient.instance.request(
    path: EndPoints.meMatchWith,
    method: HttpMethod.put,
    requiresAuth: true,
    body: {
      'matchWith': matchWith,
      ?'ageFrom': ageFrom,
      ?'ageTo': ageTo,
    },
  );
}
