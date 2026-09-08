import 'dart:io' show Platform;

import 'package:fairytrail/billing/billing_plans.dart';
import 'package:fairytrail/config/billing_config.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';


class PackagePriceInfo {
  const PackagePriceInfo({
    required this.package,
    required this.priceString,
    required this.monthlyPrice,
    required this.totalPrice,
    required this.rawPrice,
    required this.currencyCode,
  });

  final Package? package;
  final String priceString;
  final String monthlyPrice;
  final String totalPrice;
  final double rawPrice;
  final String currencyCode;

  static const empty = PackagePriceInfo(
    package: null,
    priceString: 'N/A',
    monthlyPrice: 'N/A',
    totalPrice: 'N/A',
    rawPrice: 0,
    currencyCode: 'USD',
  );
}

/// Thin wrapper around RevenueCat for Fairytrail subscriptions.
class RevenueCatService {
  RevenueCatService._();

  static final RevenueCatService instance = RevenueCatService._();

  bool _configured = false;
  String? _appUserId;
  Offerings? _cachedOfferings;

  bool get isConfigured => _configured;

  Future<void> configure(String appUserId) async {
    if (appUserId.isEmpty) return;
    if (_configured && _appUserId == appUserId) return;

    if (!Platform.isIOS && !Platform.isAndroid) {
      debugPrint('[RevenueCat] Unsupported platform — skipping configure');
      return;
    }

    final apiKey =
        Platform.isIOS ? BillingConfig.appleApiKey : BillingConfig.googleApiKey;

    final configuration = PurchasesConfiguration(apiKey)
      ..appUserID = appUserId;

    await Purchases.configure(configuration);
    _configured = true;
    _appUserId = appUserId;
    _cachedOfferings = null;

    try {
      await refreshOfferings();
    } catch (e) {
      debugPrint('[RevenueCat] Failed to load offerings: $e');
    }
  }

  Future<void> logOut() async {
    if (!_configured) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('[RevenueCat] logOut failed: $e');
    }
    _configured = false;
    _appUserId = null;
    _cachedOfferings = null;
  }

  Future<Offerings> refreshOfferings() async {
    final offerings = await Purchases.getOfferings();
    _cachedOfferings = offerings;
    return offerings;
  }

  Future<Offerings> getOfferings() async {
    if (_cachedOfferings != null) return _cachedOfferings!;
    return refreshOfferings();
  }

  Future<CustomerInfo> getCustomerInfo() => Purchases.getCustomerInfo();

  Future<CustomerInfo> restorePurchases() => Purchases.restorePurchases();

  /// Whether this store account has already used the Silver annual trial.
  ///
  /// Apple exposes trial eligibility directly. Google Play reports eligibility
  /// as unknown, so purchase history is used there as the conservative fallback.
  Future<bool> hasUsedSilverAnnualTrial() async {
    if (!_configured) return false;

    final annualPlan = billingTiers[tierSilver]!.firstWhere(
      (plan) => plan.rcPackageId == r'$rc_annual',
    );
    final productId = annualPlan.productId;

    if (Platform.isIOS) {
      final eligibility =
          await Purchases.checkTrialOrIntroductoryPriceEligibility([productId]);
      final status = eligibility[productId]?.status;
      if (status == IntroEligibilityStatus.introEligibilityStatusIneligible) {
        return true;
      }
      if (status == IntroEligibilityStatus.introEligibilityStatusEligible) {
        return false;
      }
    }

    final customerInfo = await getCustomerInfo();
    return customerInfo.allPurchasedProductIdentifiers.contains(productId);
  }

  Package? findPackage({
    required String tier,
    required String rcPackageId,
    String? productId,
    Offerings? offerings,
  }) {
    final all = offerings?.all ?? _cachedOfferings?.all;
    if (all == null) return null;
    final offering = all[tier];
    if (offering == null) return null;
    Package? byProduct;
    for (final pkg in offering.availablePackages) {
      if (pkg.identifier == rcPackageId) return pkg;
      final storeId = pkg.storeProduct.identifier;
      if (storeId == rcPackageId ||
          (productId != null &&
              productId.isNotEmpty &&
              storeId == productId)) {
        byProduct ??= pkg;
      }
    }
    return byProduct;
  }

  PackagePriceInfo priceForPlan({
    required String tier,
    required BillingPlan plan,
    Offerings? offerings,
  }) {
    final pkg = findPackage(
      tier: tier,
      rcPackageId: plan.rcPackageId,
      productId: plan.productId,
      offerings: offerings,
    );
    if (pkg != null) {
      return formatPrice(pkg, plan.duration, plan.rcPackageId);
    }
    // Simulator / offline: show catalog prices so the paywall never reads "N/A".
    return fallbackPriceForPlan(plan);
  }

  PackagePriceInfo fallbackPriceForPlan(BillingPlan plan) {
    const currencySymbol = '\$';
    final isWeekly = plan.isWeekly;
    final unitPrice = isWeekly ? plan.fullPrice / 7 : plan.price;
    final suffix = isWeekly ? '/day' : '/mo';

    return PackagePriceInfo(
      package: null,
      priceString: '$currencySymbol${plan.fullPrice.toStringAsFixed(2)}',
      monthlyPrice: '$currencySymbol${unitPrice.toStringAsFixed(2)}$suffix',
      totalPrice: '$currencySymbol${plan.fullPrice.toStringAsFixed(2)}',
      rawPrice: plan.fullPrice,
      currencyCode: 'USD',
    );
  }

  PackagePriceInfo formatPrice(
    Package? pkg,
    int durationPeriod,
    String? packageId,
  ) {
    if (pkg == null) return PackagePriceInfo.empty;

    final isWeekly = durationPeriod == 7 ||
        packageId == r'$rc_weekly' ||
        (packageId != null && packageId.contains('weekly'));
    final duration = isWeekly ? 7 : durationPeriod;
    final price = pkg.storeProduct.price;
    final monthlyPrice = price / duration;
    final currencySymbol =
        pkg.storeProduct.priceString.replaceAll(RegExp(r'[\d.,\s]'), '');

    double formatMonthly(double value) {
      if (value < 1) return value;
      final whole = value.round();
      return whole - 0.01;
    }

    double formatTotal(double value) {
      final decimal = value % 1;
      if (decimal.abs() < 0.01) return value.floorToDouble() - 0.01;
      return value;
    }

    final formattedMonthly = formatMonthly(monthlyPrice);
    final suffix = isWeekly ? '/day' : '/mo';

    return PackagePriceInfo(
      package: pkg,
      priceString: pkg.storeProduct.priceString,
      monthlyPrice:
          '$currencySymbol${formattedMonthly.toStringAsFixed(2)}$suffix',
      totalPrice: '$currencySymbol${formatTotal(price).toStringAsFixed(2)}',
      rawPrice: price,
      currencyCode: pkg.storeProduct.currencyCode,
    );
  }

  Future<PurchaseResult> purchasePlan({
    required String tier,
    required BillingPlan plan,
    String? oldProductIdentifier,
  }) async {
    final offerings = await getOfferings();
    final pkg = findPackage(
      tier: tier,
      rcPackageId: plan.rcPackageId,
      productId: plan.productId,
      offerings: offerings,
    );
    if (pkg == null) {
      throw StateError('Package not found for $tier / ${plan.rcPackageId}');
    }

    StoreProductChangeInfo? changeInfo;
    if (Platform.isAndroid &&
        oldProductIdentifier != null &&
        oldProductIdentifier.isNotEmpty) {
      changeInfo = StoreProductChangeInfo(
        oldProductIdentifier,
        replacementMode: StoreReplacementMode.chargeFullPrice,
      );
    }

    return Purchases.purchase(
      PurchaseParams.package(
        pkg,
        productChangeInfo: changeInfo,
      ),
    );
  }

  /// Lifetime verification / entrance-fee product from the given offering.
  Future<StoreProduct?> getVerificationProduct({
    String offeringId = BillingConfig.verificationOfferingId,
  }) async {
    final offerings = await getOfferings();
    final offering = offerings.all[offeringId];
    final lifetime = offering?.lifetime;
    return lifetime?.storeProduct;
  }

  /// Lifetime Truth Serum product (`truth_serum` offering).
  Future<StoreProduct?> getTruthSerumProduct({
    String offeringId = BillingConfig.truthSerumOfferingId,
  }) async {
    final offerings = await getOfferings();
    final offering = offerings.all[offeringId];
    return offering?.lifetime?.storeProduct;
  }

  Future<PurchaseResult> purchaseStoreProduct(StoreProduct product) {
    return Purchases.purchase(PurchaseParams.storeProduct(product));
  }

  /// Postcard IAP products from the `postcards_fee` offering.
  Future<List<StoreProduct>> getPostcardProducts() async {
    final offerings = await getOfferings();
    final offering = offerings.all[BillingConfig.postcardsOfferingId];
    if (offering == null) return const [];
    final byId = <String, StoreProduct>{};
    for (final pkg in offering.availablePackages) {
      byId[pkg.storeProduct.identifier] = pkg.storeProduct;
    }
    return [
      for (final id in BillingConfig.postcardProductIds)
        if (byId[id] != null) byId[id]!,
    ];
  }
}
