import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

/// POST `{webApiBaseUrl}/auth/code/approve` — approve a desktop/web login code.
Future<void> approveWebLoginCode(String code) async {
  await HttpClient.instance.request(
    path: EndPoints.authCodeApprove,
    method: HttpMethod.post,
    requiresAuth: true,
    baseUrl: EndPoints.webApiBaseUrl,
    body: {'code': code},
  );
}
