import 'package:fairytrail/api/models/auth_models.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

/// POST /api/v1/password-reset — sends reset email (204 on success).
Future<void> requestPasswordReset({required String email}) async {
  await HttpClient.instance.request(
    path: EndPoints.passwordReset,
    method: HttpMethod.post,
    requiresAuth: false,
    attachToken: false,
    body: {
      'email': email.trim().toLowerCase(),
    },
  );
}

/// POST /api/v1/password-reset-confirmation — sets password and returns session.
Future<LoginSuccessResponse> confirmPasswordReset({
  required String token,
  required String password,
}) async {
  // Backend sometimes receives "token&app=true" — strip extras.
  var sanitized = token.trim();
  if (sanitized.contains('&')) {
    sanitized = sanitized.split('&').first;
  }

  final response = await HttpClient.instance.request(
    path: EndPoints.passwordResetConfirmation,
    method: HttpMethod.post,
    requiresAuth: false,
    attachToken: false,
    body: {
      'token': sanitized,
      'password': password,
    },
  );

  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected password reset response',
      payload: data,
    );
  }

  return LoginSuccessResponse.fromJson(Map<String, dynamic>.from(data));
}
