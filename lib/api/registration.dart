import 'package:fairytrail/api/models/auth_models.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

/// POST /api/v1/registration
Future<RegistrationSuccessResponse> register(
  RegistrationRequest request,
) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.registration,
    method: HttpMethod.post,
    requiresAuth: true,
    body: request.toJson(),
  );

  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected registration response',
      payload: data,
    );
  }

  return RegistrationSuccessResponse.fromJson(Map<String, dynamic>.from(data));
}
