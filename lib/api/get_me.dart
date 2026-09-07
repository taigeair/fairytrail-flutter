import 'package:fairytrail/api/models/auth_models.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

/// GET /api/v1/me
Future<UserInfoResponse> getMe() async {
  final response = await HttpClient.instance.request(
    path: EndPoints.me,
    method: HttpMethod.get,
    requiresAuth: true,
  );

  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected me response',
      payload: data,
    );
  }

  return UserInfoResponse.fromJson(Map<String, dynamic>.from(data));
}
