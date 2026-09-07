import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

/// POST /api/v1/logout — requires auth token.
Future<void> logout() async {
  await HttpClient.instance.request(
    path: EndPoints.logout,
    method: HttpMethod.post,
    requiresAuth: true,
    attachToken: true,
  );
}
