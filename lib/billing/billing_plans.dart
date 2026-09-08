import 'dart:io' show Platform;

/// Paid subscription tiers.
typedef PaidTier = String;

const tierGold = 'gold';
const tierSilver = 'silver';
const tierFree = 'free';
const tierGated = 'gated';

const paidTiers = [tierGold, tierSilver];
const verifiedTiers = [tierGold, tierSilver, tierFree];

bool isPaidTier(String tier) => paidTiers.contains(tier);
bool isVerifiedTier(String tier) => verifiedTiers.contains(tier);

class BillingPlan {
  const BillingPlan({
    required this.duration,
    required this.durationLabel,
    required this.price,
    required this.fullPrice,
    required this.productId,
    required this.rcPackageId,
    this.label,
  });

  final int duration;
  final int durationLabel;
  final double price;
  final double fullPrice;
  final String? label;
  final String productId;
  final String rcPackageId;

  /// Silver weekly row (7-day period), regardless of A/B package id.
  bool get isWeekly => duration == 7;

  BillingPlan copyWith({
    int? duration,
    int? durationLabel,
    double? price,
    double? fullPrice,
    String? label,
    String? productId,
    String? rcPackageId,
  }) {
    return BillingPlan(
      duration: duration ?? this.duration,
      durationLabel: durationLabel ?? this.durationLabel,
      price: price ?? this.price,
      fullPrice: fullPrice ?? this.fullPrice,
      label: label ?? this.label,
      productId: productId ?? this.productId,
      rcPackageId: rcPackageId ?? this.rcPackageId,
    );
  }
}

/// Calculates savings against the tier's shortest (base) plan after normalizing
/// both prices to a daily rate from live/catalog totals.
/// Returns null for the baseline plan or invalid prices.
int? calculateSavingsPercent({
  required BillingPlan plan,
  required double totalPrice,
  required BillingPlan baselinePlan,
  required double baselineTotalPrice,
}) {
  if (totalPrice <= 0 || baselineTotalPrice <= 0) return null;

  final planDailyPrice = totalPrice / _billingPeriodDays(plan);
  final baselineDailyPrice =
      baselineTotalPrice / _billingPeriodDays(baselinePlan);
  final savings = ((1 - (planDailyPrice / baselineDailyPrice)) * 100).round();
  return savings > 0 ? savings.clamp(1, 99) : null;
}

double _billingPeriodDays(BillingPlan plan) {
  if (plan.isWeekly) return 7;
  return plan.duration * (365.25 / 12);
}

/// Silver catalog with the A/B weekly RevenueCat package id applied.
List<BillingPlan> silverPlansForWeeklyPackage(String weeklyPackageId) {
  final id = weeklyPackageId.trim().isEmpty
      ? r'$rc_weekly'
      : weeklyPackageId.trim();
  final weeklyProductId = _weeklyProductIdForPackage(id);
  return [
    for (final plan in billingTiers[tierSilver]!)
      if (plan.isWeekly)
        plan.copyWith(rcPackageId: id, productId: weeklyProductId)
      else
        plan,
  ];
}

/// Store product ids for Silver weekly A/B packages (offline / catalog fallback).
///
/// Matches RevenueCat offering `silver`:
/// - `$rc_weekly` → A (control)
/// - `weekly_b` → B (variant)
String _weeklyProductIdForPackage(String packageId) {
  if (packageId == 'weekly_b') {
    return _isAndroid ? 'silver:silver-1week' : 'silver_week_b';
  }
  return _isAndroid ? 'silver:silver-1-599' : 'silver.1.599';
}

/// Plans for [tier], applying weekly A/B package id when [tier] is Silver.
List<BillingPlan> plansForTier(
  String tier, {
  String weeklyPackageId = r'$rc_weekly',
}) {
  if (tier == tierSilver) {
    return silverPlansForWeeklyPackage(weeklyPackageId);
  }
  return List<BillingPlan>.from(billingTiers[tier] ?? const []);
}

final bool _isAndroid = Platform.isAndroid;

final Map<String, Map<String, String>> _productIds = {
  tierGold: {
    '1': _isAndroid ? 'gold:gold-1-5999' : 'gold.1.5999',
    '3': _isAndroid ? 'gold:gold-3-8999' : 'gold.3.8999',
    '6': _isAndroid ? 'gold:gold-6-11999' : 'gold.6.11999',
  },
  tierSilver: {
    '1': _isAndroid ? 'silver:silver-1' : 'silver',
    // Control weekly (A / $rc_weekly). Variant B uses weekly_b → see
    // [_weeklyProductIdForPackage].
    '1_weekly': _isAndroid ? 'silver:silver-1-599' : 'silver.1.599',
    '6': _isAndroid ? 'silver:silver-6' : 'silver.6',
    '12': _isAndroid ? 'silver:silver-12' : 'silver.12',
  },
};

/// Ordering matches the React Native catalog.
final Map<String, List<BillingPlan>> billingTiers = {
  tierGold: [
    BillingPlan(
      duration: 1,
      durationLabel: 1,
      price: 59.99,
      fullPrice: 59.99,
      productId: _productIds[tierGold]!['1']!,
      rcPackageId: r'$rc_monthly',
    ),
    BillingPlan(
      duration: 3,
      durationLabel: 3,
      price: 29.99,
      fullPrice: 89.99,
      label: 'most popular',
      productId: _productIds[tierGold]!['3']!,
      rcPackageId: r'$rc_three_month',
    ),
    BillingPlan(
      duration: 6,
      durationLabel: 6,
      price: 19.99,
      fullPrice: 119.99,
      label: 'best value',
      productId: _productIds[tierGold]!['6']!,
      rcPackageId: r'$rc_six_month',
    ),
  ],
  tierSilver: [
    BillingPlan(
      duration: 7,
      durationLabel: 1,
      price: 5.99,
      fullPrice: 5.99,
      productId: _productIds[tierSilver]!['1_weekly']!,
      rcPackageId: r'$rc_weekly',
    ),
    BillingPlan(
      duration: 1,
      durationLabel: 1,
      price: 13.99,
      fullPrice: 13.99,
      label: 'most popular',
      productId: _productIds[tierSilver]!['1']!,
      rcPackageId: r'$rc_monthly',
    ),
    BillingPlan(
      duration: 12,
      durationLabel: 1,
      price: 4.66,
      fullPrice: 55.99,
      label: 'best value',
      productId: _productIds[tierSilver]!['12']!,
      rcPackageId: r'$rc_annual',
    ),
  ],
};

const goldBenefits = [
  'Stay toward the top of profiles',
  // 'Unlimited daily profiles & Campfire',
  'Unlimited daily profiles',
  'Reveal who wants to connect',
  'View all nearby people',
  'Advanced filters',
  'Chat filtering',
  'Undo skips',
  'Free verification',
  'No ads',
];

const silverBenefits = [
  'Reveal who wants to connect',
  'More daily profiles',
  // 'See everyone nearby',
  // 'More daily profiles & Campfire',
  // 'More daily profiles',
  // 'Advanced search & undo skips',
  // 'Free verification & no ads',
  // 'Advanced filters',
  'View all nearby people',
  'Chat filtering',
  'Undo skips',
  'Free verification',
  'No ads',
];

const freeBenefits = [
  'Match with people in Explore to chat',
  'Get limited daily profiles',
  'Standard filters',
  'Browse limited people nearby',
  'Join or create local meetups',
  'Create a bucket list others can discover',
  'Browse & search bucket list activities',
  'Save activities to your bucket list',
  'Join activity & meetup group chats',
  // 'Join activity group chats',
  // 'Send and receive postcards',
];

List<String> benefitsForTier(String tier) {
  return switch (tier) {
    tierGold => goldBenefits,
    tierSilver => silverBenefits,
    _ => freeBenefits,
  };
}

String reasonHeadline({
  required String reason,
  required String tierToShow,
  required String currentTier,
}) {
  final isSilver = currentTier == tierSilver;

  if (tierToShow == tierGold) {
    return switch (reason) {
      'undo' => 'Undo skips and more! Try it today',
      'nearby_travelers' => 'Unlock all nearby travelers!',
      'profile_upgrade' => 'Make connections 68x faster 🚀',
      'limit_reached' =>
        isSilver
            ? 'Silver plan limit reached! Upgrade plan or wait until tomorrow'
            : 'Upgrade or wait until tomorrow',
      'incoming_connects' => 'See who wants to connect without exploring.',
      'messages_learn_more' => 'Make connections 68x faster 🚀',
      'match_country_filter' =>
        'Filter your existing connections!',
      'keyword_search' => 'Upgrade to Gold for more filters',
      'ads_remove' => 'Try Fairytrail without ads',
      _ =>
        isPaidTier(currentTier)
            ? 'Make connections 68x faster 🚀'
            : 'See who wants to chat and more!',
    };
  }

  return switch (reason) {
    'undo' => 'Undo skips and more! Try it today',
    'nearby_travelers' => 'Unlock all nearby travelers!',
    'profile_upgrade' => 'See who wants to chat instantly',
    'limit_reached' => 'Upgrade or wait until tomorrow',
    'incoming_connects' => 'See who wants to connect without matching',
    'messages_learn_more' => 'See who wants to connect without matching',
    'match_country_filter' =>
      'Filter your existing connections!',
    'keyword_search' => 'Upgrade to Gold for more filters',
    'ads_remove' => 'Try Fairytrail without ads',
    _ =>
      isPaidTier(currentTier)
          ? 'Make connections 68x faster 🚀'
          : 'See who wants to chat and more!',
  };
}
