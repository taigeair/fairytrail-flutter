import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

/// POST /api/v1/me/account-status — pause or unpause.
Future<void> postAccountStatus(String status) async {
  await HttpClient.instance.request(
    path: EndPoints.meAccountStatus,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'status': status},
  );
}

/// DELETE /api/v1/delete-account
Future<void> deleteAccount({required String reason}) async {
  await HttpClient.instance.request(
    path: EndPoints.deleteAccount,
    method: HttpMethod.delete,
    requiresAuth: true,
    body: {'reason': reason},
  );
}
