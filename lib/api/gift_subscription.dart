import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

class GiftSubscriptionPlan {
  const GiftSubscriptionPlan({
    required this.durationMonths,
    required this.plan,
    required this.amountCents,
    required this.amount,
    required this.label,
  });

  final int durationMonths;
  final String plan;
  final int amountCents;
  final double amount;
  final String label;

  factory GiftSubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return GiftSubscriptionPlan(
      durationMonths: (json['duration_months'] as num?)?.toInt() ?? 0,
      plan: json['plan']?.toString() ?? 'silver',
      amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      label: json['label']?.toString() ?? '',
    );
  }
}

class GiftSubscriptionDto {
  const GiftSubscriptionDto({
    required this.id,
    required this.status,
    required this.plan,
    required this.durationMonths,
    required this.amount,
    required this.amountCents,
    required this.senderProfileId,
    required this.receiverProfileId,
    this.senderName,
    this.alreadyHadSubscription = false,
    this.receiverAlreadySubscribed = false,
    this.validUntil,
    this.paidAt,
    this.createdAt,
  });

  final String id;
  final String status;
  final String plan;
  final int durationMonths;
  final double amount;
  final int amountCents;
  final int senderProfileId;
  final int receiverProfileId;
  final String? senderName;
  final bool alreadyHadSubscription;
  final bool receiverAlreadySubscribed;
  final String? validUntil;
  final String? paidAt;
  final String? createdAt;

  String get durationLabel {
    if (durationMonths == 1) return '1 month';
    if (durationMonths == 12) return '1 year';
    return '$durationMonths months';
  }

  factory GiftSubscriptionDto.fromJson(Map<String, dynamic> json) {
    return GiftSubscriptionDto(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      plan: json['plan']?.toString() ?? 'silver',
      durationMonths: (json['durationMonths'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      senderProfileId: (json['senderProfileId'] as num?)?.toInt() ?? 0,
      receiverProfileId: (json['receiverProfileId'] as num?)?.toInt() ?? 0,
      senderName: json['senderName']?.toString(),
      alreadyHadSubscription: json['alreadyHadSubscription'] == true,
      receiverAlreadySubscribed: json['receiverAlreadySubscribed'] == true,
      validUntil: json['validUntil']?.toString(),
      paidAt: json['paidAt']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class GiftPaymentSession {
  const GiftPaymentSession({
    required this.giftId,
    required this.clientSecret,
    required this.customer,
    required this.ephemeralKey,
    required this.publishableKey,
    required this.amount,
    required this.amountCents,
    required this.durationMonths,
    required this.plan,
  });

  final String giftId;
  final String clientSecret;
  final String customer;
  final String ephemeralKey;
  final String publishableKey;
  final double amount;
  final int amountCents;
  final int durationMonths;
  final String plan;

  factory GiftPaymentSession.fromJson(Map<String, dynamic> json) {
    return GiftPaymentSession(
      giftId: json['giftId']?.toString() ?? '',
      clientSecret: json['clientSecret']?.toString() ?? '',
      customer: json['customer']?.toString() ?? '',
      ephemeralKey: json['ephemeralKey']?.toString() ?? '',
      publishableKey: json['publishableKey']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      durationMonths: (json['durationMonths'] as num?)?.toInt() ?? 0,
      plan: json['plan']?.toString() ?? 'silver',
    );
  }
}

class GiftAcceptResult {
  const GiftAcceptResult({
    required this.gift,
    required this.upgraded,
    required this.alreadyHadSubscription,
    required this.senderProfileId,
    this.senderName,
  });

  final GiftSubscriptionDto gift;
  final bool upgraded;
  final bool alreadyHadSubscription;
  final int senderProfileId;
  final String? senderName;

  factory GiftAcceptResult.fromJson(Map<String, dynamic> json) {
    return GiftAcceptResult(
      gift: GiftSubscriptionDto.fromJson(
        Map<String, dynamic>.from(json['gift'] as Map? ?? {}),
      ),
      upgraded: json['upgraded'] == true,
      alreadyHadSubscription: json['alreadyHadSubscription'] == true,
      senderProfileId: (json['senderProfileId'] as num?)?.toInt() ?? 0,
      senderName: json['senderName']?.toString(),
    );
  }
}

Future<List<GiftSubscriptionPlan>> fetchGiftSubscriptionPlans() async {
  final res = await HttpClient.instance.request(
    path: EndPoints.giftSubscriptionPlans,
    requiresAuth: true,
  );
  final raw = res.data is Map ? (res.data as Map)['plans'] : null;
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => GiftSubscriptionPlan.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

Future<GiftPaymentSession> createGiftSubscriptionPayment({
  required int receiverProfileId,
  required int durationMonths,
}) async {
  final res = await HttpClient.instance.request(
    path: EndPoints.giftSubscriptionCreatePayment,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {
      'receiverProfileId': receiverProfileId,
      'durationMonths': durationMonths,
    },
  );
  return GiftPaymentSession.fromJson(Map<String, dynamic>.from(res.data as Map));
}

Future<GiftSubscriptionDto> confirmGiftSubscriptionPayment({
  required String giftId,
}) async {
  final res = await HttpClient.instance.request(
    path: EndPoints.giftSubscriptionConfirm,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'giftId': giftId},
  );
  final gift = (res.data as Map)['gift'];
  return GiftSubscriptionDto.fromJson(Map<String, dynamic>.from(gift as Map));
}

Future<List<GiftSubscriptionDto>> fetchPendingGiftSubscriptions() async {
  final res = await HttpClient.instance.request(
    path: EndPoints.giftSubscriptionPending,
    requiresAuth: true,
  );
  final raw = res.data is Map ? (res.data as Map)['gifts'] : null;
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => GiftSubscriptionDto.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

Future<GiftSubscriptionDto> fetchGiftSubscription(String idOrToken) async {
  final res = await HttpClient.instance.request(
    path: EndPoints.giftSubscriptionById(idOrToken),
    requiresAuth: true,
  );
  final gift = (res.data as Map)['gift'];
  return GiftSubscriptionDto.fromJson(Map<String, dynamic>.from(gift as Map));
}

Future<GiftAcceptResult> acceptGiftSubscription(String giftId) async {
  final res = await HttpClient.instance.request(
    path: EndPoints.giftSubscriptionAccept(giftId),
    method: HttpMethod.post,
    requiresAuth: true,
  );
  return GiftAcceptResult.fromJson(Map<String, dynamic>.from(res.data as Map));
}

Future<GiftSubscriptionDto> declineGiftSubscription(String giftId) async {
  final res = await HttpClient.instance.request(
    path: EndPoints.giftSubscriptionDecline(giftId),
    method: HttpMethod.post,
    requiresAuth: true,
  );
  final gift = (res.data as Map)['gift'];
  return GiftSubscriptionDto.fromJson(Map<String, dynamic>.from(gift as Map));
}
