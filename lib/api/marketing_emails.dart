import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

class MarketingEmailSubscription {
  const MarketingEmailSubscription({required this.subscribed});

  final bool subscribed;

  factory MarketingEmailSubscription.fromJson(Map<String, dynamic> json) =>
      MarketingEmailSubscription(
        subscribed: json['subscribed'] as bool? ?? true,
      );
}

/// GET /api/v1/me/marketing-emails
Future<MarketingEmailSubscription> getMarketingEmails() async {
  final response = await HttpClient.instance.request(
    path: EndPoints.meMarketingEmails,
    method: HttpMethod.get,
    requiresAuth: true,
  );
  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected marketing emails response',
      payload: data,
    );
  }
  return MarketingEmailSubscription.fromJson(Map<String, dynamic>.from(data));
}

/// POST /api/v1/me/marketing-emails
Future<MarketingEmailSubscription> postMarketingEmails({
  required bool subscribed,
}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.meMarketingEmails,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'subscribed': subscribed},
  );
  final data = response.data;
  if (data is! Map) {
    return MarketingEmailSubscription(subscribed: subscribed);
  }
  return MarketingEmailSubscription.fromJson(Map<String, dynamic>.from(data));
}
