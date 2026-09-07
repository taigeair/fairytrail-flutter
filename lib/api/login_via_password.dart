import 'package:fairytrail/api/models/auth_models.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

/// POST /api/v1/login-via-password
Future<LoginSuccessResponse> loginViaPassword({
  required String email,
  required String password,
}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.loginViaPassword,
    method: HttpMethod.post,
    requiresAuth: false,
    attachToken: false,
    body: {
      'email': email.trim().toLowerCase(),
      'password': password,
    },
  );

  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected login response',
      payload: data,
    );
  }

  return LoginSuccessResponse.fromJson(Map<String, dynamic>.from(data));
}
