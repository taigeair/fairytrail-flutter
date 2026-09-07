import 'dart:async';
import 'dart:io' show Platform;

import 'package:fairytrail/analytics/analytics_service.dart';
import 'package:fairytrail/analytics/meta_events_service.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/billing/billing_plans.dart';
import 'package:fairytrail/billing/revenue_cat_service.dart';
import 'package:fairytrail/config/billing_config.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/remote_config/remote_config_controller.dart';
import 'package:fairytrail/screens/verification/verification_processing_screen.dart';
import 'package:fairytrail/screens/verification/verified_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// One-time verification / entrance-fee paywall (RN `/main/modal/verification`).
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key, this.from = 'explore'});

  final String from;

  static Future<void> open(BuildContext context, {String from = 'explore'}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => VerificationScreen(from: from)),
    );
  }

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  StoreProduct? _product;
  bool _loadingProduct = true;
  bool _purchasing = false;
  String _offeringId = BillingConfig.verificationOfferingId;

  static const _benefits = [
    'Join 185,000+ verified travelers',
    '4X more daily profiles',
    'Get more connect requests',
    'Help keep Fairytrail safe',
    'Never expires',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final auth = AuthScope.of(context);
    try {
      await auth.refreshMe();
    } catch (_) {}

    if (!mounted) return;
    if (isVerifiedTier(auth.profileMeta?.tier ?? tierGated)) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const VerifiedScreen()),
      );
      return;
    }

    final remoteConfig = RemoteConfigScope.of(context);
    try {
      // Always refresh so the offering matches current remote config
      // (`verificationFeeGroup`), not a stale/local default.
      await remoteConfig.refresh();
    } catch (_) {
      // Fall back to cached/default offering when config is offline.
    }
    if (!mounted) return;
    _offeringId = remoteConfig.verificationOfferingId;

    final userId = auth.user?.id;
    if (userId != null && userId.isNotEmpty) {
      try {
        await RevenueCatService.instance.configure(userId);
      } catch (_) {}
    }

    try {
      final product = await RevenueCatService.instance.getVerificationProduct(
        offeringId: _offeringId,
      );
      if (!mounted) return;
      if (product == null) {
        unawaited(
          track('error_get_offerings', {
            'error': 'Entrance fee product not found',
            'revenuecatFreePlanOfferingId': _offeringId,
            'from': widget.from,
            'platform': Platform.isIOS ? 'ios' : 'android',
          }),
        );
      }
      setState(() {
        _product = product;
        _loadingProduct = false;
      });
    } catch (e) {
      unawaited(
        track('error_get_offerings', {
          'error': e.toString(),
          'revenuecatFreePlanOfferingId': _offeringId,
          'from': widget.from,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      );
      if (!mounted) return;
      setState(() => _loadingProduct = false);
    }
  }

  Future<void> _purchase() async {
    if (_purchasing) return;
    unawaited(track('click_verification_button', {'from': widget.from}));
    final product = _product;
    if (product == null) {
      await AppDialog.show(
        context,
        title: 'Unavailable',
        message: 'Verification product not loaded. Please try again.',
      );
      return;
    }

    setState(() => _purchasing = true);
    // AppButton already fires light; bump to medium for purchase importance.
    HapticsService.medium();

    try {
      final purchase = await RevenueCatService.instance.purchaseStoreProduct(
        product,
      );
      if (!mounted) return;

      final auth = AuthScope.of(context);
      final user = auth.user;
      final tx = purchase.storeTransaction;
      unawaited(
        AnalyticsService.instance.logEvent('paid_verify', {
          'user_id': user?.id ?? '',
          'shortId': user?.shortId ?? '',
          'verification_fee_identifier': product.identifier,
          'transactionAmount': product.price,
          'currency': product.currencyCode,
          'revenue': product.price,
          'transaction_id': tx.transactionIdentifier,
        }),
      );
      unawaited(
        MetaEventsService.instance.logPurchaseFromStoreProduct(
          customEventName: 'purchased_verification',
          contentType: 'verification',
          product: product,
          transaction: tx,
          from: widget.from,
          userId: user?.id,
        ),
      );

      if ((auth.profileMeta?.tier ?? tierGated) == tierGated) {
        await auth.setTierOptimistic(tierFree);
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const VerificationProcessingScreen(),
        ),
      );
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        // Silent cancel.
      } else if (mounted) {
        await AppDialog.show(
          context,
          title: 'Purchase failed',
          message: e.message ?? 'Unable to complete verification',
        );
      }
    } catch (e) {
      if (!mounted) return;
      await AppDialog.show(
        context,
        title: 'Purchase failed',
        message: serverErrorText(e),
      );
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final photoUrl = auth.profileMeta?.photoUrl;
    // Prefer remote-config button text (e.g. "Verify - $4.99") when set;
    // otherwise fall back to the live RevenueCat store price.
    final remoteCta =
        RemoteConfigScope.of(context).verificationButtonText;
    final price = _product?.priceString ?? '';
    final ctaLabel = (remoteCta != null && remoteCta.isNotEmpty)
        ? remoteCta
        : (price.isEmpty ? 'Verify' : 'Verify · $price');

    final bg = AppColors.backgroundOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final isDark = AppColors.isDark(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loadingProduct
                ? const AppLoading(message: 'Loading…')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      Center(
                        child: SizedBox(
                          width: 240,
                          height: 240,
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: photoUrl != null && photoUrl.isNotEmpty
                                    ? AppCachedImage(
                                        url: photoUrl,
                                        blurHash:
                                            auth.profileMeta?.photoBlurHash,
                                        width: 240,
                                        height: 240,
                                        fit: BoxFit.cover,
                                        borderRadius: 20,
                                      )
                                    : ColoredBox(
                                        color: AppColors.surfaceOf(context),
                                        child: Center(
                                          child: Icon(
                                            Icons.person_rounded,
                                            size: 96,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.18,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_rounded,
                                        size: 14,
                                        color: AppColors.white,
                                      ),
                                      SizedBox(width: 4),
                                      AppText(
                                        'Verified',
                                        variant: AppTextVariant.label,
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      AppText(
                        BillingConfig.verificationScreenTitle,
                        variant: AppTextVariant.headline,
                        textAlign: TextAlign.center,
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        color: textPrimary,
                      ),
                      const SizedBox(height: 8),
                      AppText(
                        'A one-time badge that helps others trust your profile',
                        variant: AppTextVariant.bodySmall,
                        textAlign: TextAlign.center,
                        color: textSecondary,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceOf(context),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          children: [
                            for (final benefit in _benefits)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: AppText(
                                        benefit,
                                        variant: AppTextVariant.body,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          if (!_loadingProduct)
            Container(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 8 + bottom),
              decoration: BoxDecoration(
                color: bg,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: AppButton(
                label: ctaLabel,
                isLoading: _purchasing,
                haptic: false,
                onPressed: _product == null ? null : _purchase,
              ),
            ),
        ],
      ),
    );
  }
}
