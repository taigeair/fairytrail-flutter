import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

/// PUT /api/v1/me/truth-serum — marks Truth Serum as purchased on the profile.
Future<bool> putTruthSerumPurchase() async {
  final response = await HttpClient.instance.request(
    path: EndPoints.meTruthSerum,
    method: HttpMethod.put,
    requiresAuth: true,
  );

  final data = response.data;
  if (data is Map && data['success'] == true) return true;
  if (response.statusCode >= 200 && response.statusCode < 300) return true;
  throw ApiException(
    statusCode: response.statusCode,
    message: data is Map
        ? (data['message'] as String? ?? 'Truth serum purchase failed')
        : 'Truth serum purchase failed',
    payload: data,
  );
}
