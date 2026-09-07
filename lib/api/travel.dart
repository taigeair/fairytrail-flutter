import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

class StripeKeysDto {
  const StripeKeysDto({required this.publishableKey});

  final String publishableKey;
}

class TrailMoneyPaymentSession {
  const TrailMoneyPaymentSession({
    required this.clientSecret,
    required this.customer,
    required this.ephemeralKey,
  });

  final String clientSecret;
  final String customer;
  final String ephemeralKey;
}

Future<StripeKeysDto> fetchStripeKeys() async {
  final response = await HttpClient.instance.request(
    path: EndPoints.stripeKeys,
    requiresAuth: true,
  );
  final data = Map<String, dynamic>.from(response.data as Map);
  final nested = data['data'];
  final values = nested is Map ? nested : data;
  return StripeKeysDto(
    publishableKey: values['publishableKey']?.toString() ?? '',
  );
}

Future<TrailMoneyPaymentSession> createTrailMoneyPaymentIntent(
  double amount,
) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.createPaymentIntent,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'amount': amount},
  );
  final envelope = Map<String, dynamic>.from(response.data as Map);
  final data = Map<String, dynamic>.from(envelope['data'] as Map);
  return TrailMoneyPaymentSession(
    clientSecret: data['clientSecret']?.toString() ?? '',
    customer: data['customer']?.toString() ?? '',
    ephemeralKey: data['ephemeralKey']?.toString() ?? '',
  );
}

Future<double> topUpTrailMoney({
  required double amount,
  required String paymentIntentId,
}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.trailMoneyTopUp,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {
      'amount': amount,
      'paymentMethodDetails': {
        'type': 'card',
        'label': 'Credit Card',
        'paymentIntentId': paymentIntentId,
      },
      'location': '',
    },
  );
  final envelope = Map<String, dynamic>.from(response.data as Map);
  final data = Map<String, dynamic>.from(envelope['data'] as Map);
  return (data['newBalance'] as num?)?.toDouble() ?? 0;
}

/// RN `apiPostFreeTravelMoney` — adds $1 trail money.
Future<double> addFreeTravelMoney({int travelMoney = 1}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.travelAddMoney,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'travelMoney': travelMoney},
  );

  final data = response.data;
  if (data is Map && data['newBalance'] is num) {
    return (data['newBalance'] as num).toDouble();
  }
  return 0;
}

/// RN `apiPostTravelUpdatePickupCountdown` — schedules the next pickup checkpoint.
Future<int?> updatePickupCountdown({required int totalActions}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.travelUpdatePickupCountdown,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'totalActions': totalActions},
  );

  final data = response.data;
  if (data is Map && data['countdown'] is num) {
    return (data['countdown'] as num).toInt();
  }
  return null;
}
