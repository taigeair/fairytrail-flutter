import 'dart:async';
import 'dart:io' show Platform;

import 'package:fairytrail/analytics/meta_events_service.dart';
import 'package:fairytrail/api/truth_serum.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/billing/revenue_cat_service.dart';
import 'package:fairytrail/config/billing_config.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/screens/truth_serum/truth_serum_processing_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Truth Serum paywall — unlocks Photo Epicness (RN `/main/truthserum`).
class TruthSerumScreen extends StatefulWidget {
  const TruthSerumScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const TruthSerumScreen()),
    );
  }

  @override
  State<TruthSerumScreen> createState() => _TruthSerumScreenState();
}

class _TruthSerumScreenState extends State<TruthSerumScreen> {
  StoreProduct? _product;
  bool _loadingProduct = true;
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProduct());
  }

  Future<void> _loadProduct() async {
    final auth = AuthScope.of(context);
    if (auth.profileMeta?.isTruthSerumPurchased == true) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    final userId = auth.user?.id;
    if (userId != null && userId.isNotEmpty) {
      try {
        await RevenueCatService.instance.configure(userId);
      } catch (_) {}
    }

    try {
      final product = await RevenueCatService.instance.getTruthSerumProduct();
      if (!mounted) return;
      if (product == null) {
        unawaited(
          track('error_get_offerings', {
            'error': 'Truth serum product not found',
            'revenuecatTruthSerumOfferingId':
                BillingConfig.truthSerumOfferingId,
            'from': 'truthSerum',
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
          'revenuecatTruthSerumOfferingId': BillingConfig.truthSerumOfferingId,
          'from': 'truthSerum',
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      );
      if (!mounted) return;
      setState(() => _loadingProduct = false);
    }
  }

  Future<void> _purchase() async {
    if (_purchasing) return;
    unawaited(track('click_truth_serum_purchase'));

    final product = _product;
    if (product == null) {
      await AppDialog.show(
        context,
        title: 'Unavailable',
        message: 'Truth serum product not loaded. Please try again.',
      );
      return;
    }

    setState(() => _purchasing = true);
    HapticsService.medium();

    try {
      final purchase = await RevenueCatService.instance.purchaseStoreProduct(
        product,
      );
      if (!mounted) return;

      unawaited(track('truth_serum_purchase_success'));

      final ok = await putTruthSerumPurchase();
      if (!mounted) return;
      if (!ok) {
        await AppDialog.show(
          context,
          title: 'Purchase failed',
          message: 'Truth serum purchase failed. Please try again.',
        );
        return;
      }

      final auth = AuthScope.of(context);
      final user = auth.user;
      final tx = purchase.storeTransaction;
      unawaited(
        MetaEventsService.instance.logPurchaseFromStoreProduct(
          customEventName: 'purchased_truthserum',
          contentType: 'truth_serum',
          product: product,
          transaction: tx,
          userId: user?.id,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const TruthSerumProcessingScreen(),
        ),
      );
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        // Silent cancel.
      } else {
        unawaited(track('truth_serum_purchase_error'));
        if (mounted) {
          await AppDialog.show(
            context,
            title: 'Purchase failed',
            message: e.message ?? 'Unable to complete purchase',
          );
        }
      }
    } catch (e) {
      unawaited(track('truth_serum_purchase_error'));
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
    final bg = AppColors.backgroundOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final isDark = AppColors.isDark(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final price = _product?.priceString ?? '';
    final ctaLabel = price.isEmpty ? 'Reveal' : 'Reveal - $price';
    final buttonLoading = _loadingProduct || _purchasing;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Truth Serum'),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Image.asset(
                    'assets/profile/potion.png',
                    width: 112,
                    height: 112,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 30),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Column(
                      children: [
                        AppText(
                          'What\'s your aura?',
                          variant: AppTextVariant.display,
                          textAlign: TextAlign.center,
                          color: textPrimary,
                        ),
                        const SizedBox(height: 20),
                        AppText(
                          'Aura is determined by how often travelers choose to connect with you',
                          variant: AppTextVariant.body,
                          textAlign: TextAlign.center,
                          color: textSecondary,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
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
              isLoading: buttonLoading,
              haptic: false,
              onPressed: (_product == null || buttonLoading) ? null : _purchase,
            ),
          ),
        ],
      ),
    );
  }
}
