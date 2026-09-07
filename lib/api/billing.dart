import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

class RestorePurchaseResponse {
  const RestorePurchaseResponse({
    required this.success,
    required this.message,
    this.tier,
    this.validUntil,
    this.existingAccountEmail,
  });

  final bool success;
  final String message;
  final String? tier;
  final String? validUntil;
  final String? existingAccountEmail;

  factory RestorePurchaseResponse.fromJson(Map<String, dynamic> json) {
    return RestorePurchaseResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      tier: json['tier'] as String?,
      validUntil: json['validUntil'] as String?,
      existingAccountEmail: json['existingAccountEmail'] as String?,
    );
  }
}

/// POST /api/v1/billing/restore-purchase/v2
Future<RestorePurchaseResponse> restorePurchaseV2({
  String? deviceInfo,
  String? originalTransactionId,
  String? productId,
}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.restorePurchaseV2,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {
      'deviceInfo': ?deviceInfo,
      'originalTransactionId': ?originalTransactionId,
      'productId': ?productId,
    },
  );

  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected restore purchase response',
      payload: data,
    );
  }

  return RestorePurchaseResponse.fromJson(Map<String, dynamic>.from(data));
}
