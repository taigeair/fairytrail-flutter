import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

/// GET /api/v2/check-kindness-rating/{matchId}
Future<bool> checkKindnessRating(int matchId) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.checkKindnessRating(matchId),
    method: HttpMethod.get,
    requiresAuth: true,
  );
  final data = response.data;
  if (data is! Map) return false;
  final inner = data['data'];
  if (inner is Map) {
    return inner['hasRated'] as bool? ?? false;
  }
  return false;
}

/// POST /api/v2/rate-user-kindness — [ratedValue] is `positive` or `neutral`.
Future<void> rateUserKindness({
  required int matchId,
  required int ratedUserId,
  required String ratedValue,
}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.rateUserKindness,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {
      'matchId': matchId.toString(),
      'ratedUserId': ratedUserId.toString(),
      'ratedValue': ratedValue,
    },
  );
  final data = response.data;
  if (data is Map && data['success'] == false) {
    throw ApiException(
      statusCode: response.statusCode,
      message: data['message']?.toString() ?? 'Failed to rate user',
      payload: data,
    );
  }
}
