import 'package:fairytrail/api/models/auth_models.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

/// GET /api/v1/email/{email}
Future<EmailCheckResponse> checkEmail(String email) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.emailByEmail(email.trim().toLowerCase()),
    method: HttpMethod.get,
    requiresAuth: false,
    attachToken: false,
  );

  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected email check response',
      payload: data,
    );
  }

  return EmailCheckResponse.fromJson(Map<String, dynamic>.from(data));
}
