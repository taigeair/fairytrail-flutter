import 'package:fairytrail/api/models/auth_models.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

/// POST /api/v1/login/apple
Future<LoginSuccessResponse> loginApple({
  required String identityToken,
  Map<String, dynamic>? credential,
}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.loginApple,
    method: HttpMethod.post,
    requiresAuth: false,
    attachToken: false,
    body: {
      'identityToken': identityToken,
      'credential': credential,
    },
  );

  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected Apple login response',
      payload: data,
    );
  }

  return LoginSuccessResponse.fromJson(Map<String, dynamic>.from(data));
}
