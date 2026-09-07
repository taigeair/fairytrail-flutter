import 'dart:async';

import 'package:fairytrail/api/gift_subscription.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/screens/profile/gift_subscription_success_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/api/https.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/intl.dart';

/// Pick 1 month / 6 months / 1 year of Silver and pay via Stripe PaymentSheet.
class GiftSubscriptionScreen extends StatefulWidget {
  const GiftSubscriptionScreen({
    super.key,
    required this.receiverProfileId,
    required this.receiverName,
    this.receiverPhotoUrl,
    this.path = 'explore',
  });

  final int receiverProfileId;
  final String receiverName;
  final String? receiverPhotoUrl;
  final String path;

  static Future<void> open(
    BuildContext context, {
    required int receiverProfileId,
    required String receiverName,
    String? receiverPhotoUrl,
    String path = 'explore',
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GiftSubscriptionScreen(
          receiverProfileId: receiverProfileId,
          receiverName: receiverName,
          receiverPhotoUrl: receiverPhotoUrl,
          path: path,
        ),
      ),
    );
  }

  @override
  State<GiftSubscriptionScreen> createState() => _GiftSubscriptionScreenState();
}

class _GiftSubscriptionScreenState extends State<GiftSubscriptionScreen> {
  List<GiftSubscriptionPlan> _plans = const [];
  GiftSubscriptionPlan? _selected;
  bool _loading = true;
  bool _paying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlans());
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plans = await fetchGiftSubscriptionPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _selected = plans.isEmpty ? null : plans.first;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load plans. Try again.';
      });
    }
  }

  Future<void> _pay() async {
    final plan = _selected;
    if (plan == null || _paying) return;

    setState(() {
      _paying = true;
      _error = null;
    });

    try {
      final session = await createGiftSubscriptionPayment(
        receiverProfileId: widget.receiverProfileId,
        durationMonths: plan.durationMonths,
      );

      Stripe.publishableKey = session.publishableKey;
      Stripe.merchantIdentifier = 'merchant.app.taigeair.release';
      Stripe.urlScheme = 'com.fairytrail.app';
      await Stripe.instance.applySettings();

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: session.clientSecret,
          customerEphemeralKeySecret: session.ephemeralKey,
          customerId: session.customer,
          merchantDisplayName: 'Fairytrail',
          returnURL: 'com.fairytrail.app://stripe-redirect',
          style: ThemeMode.system,
          applePay: const PaymentSheetApplePay(merchantCountryCode: 'US'),
          googlePay: PaymentSheetGooglePay(
            merchantCountryCode: 'US',
            currencyCode: 'USD',
            testEnv: kDebugMode,
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      await confirmGiftSubscriptionPayment(giftId: session.giftId);

      if (!mounted) return;
      try {
        await AuthScope.of(context).refreshMe();
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => GiftSubscriptionSuccessScreen(path: widget.path),
        ),
      );
    } on StripeException catch (e) {
      if (!mounted) return;
      if (e.error.code == FailureCode.Canceled) {
        setState(() => _paying = false);
        return;
      }
      setState(() {
        _paying = false;
        _error = e.error.localizedMessage ?? 'Payment failed.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _error = 'Something went wrong. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.receiverName.split(' ').first;
    final currency = NumberFormat.simpleCurrency(name: 'USD');

    return AppScaffold(
      title: 'Gift a subscription',
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      body: _loading
          ? const Center(child: AppLoading())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppText(
                  'Give $firstName an upgrade',
                  variant: AppTextVariant.title,
                ),
                const SizedBox(height: 8),
                AppText(
                  'One-time gift, does not renew. We’ll let them know you sent this by email and in-app. Once they accept, they’ll enjoy all the benefits of Silver including reveal.',
                  variant: AppTextVariant.bodySmall,
                  color: AppColors.textSecondaryOf(context),
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  AppText(
                    _error!,
                    variant: AppTextVariant.bodySmall,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                ],
                ..._plans.map((plan) {
                  final selected =
                      _selected?.durationMonths == plan.durationMonths;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: AppColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _paying
                            ? null
                            : () => setState(() => _selected = plan),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.borderOf(context),
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: AppText(
                                  plan.label,
                                  variant: AppTextVariant.label,
                                ),
                              ),
                              AppText(
                                currency.format(plan.amount),
                                variant: AppTextVariant.label,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                AppButton(
                  label: _selected == null
                      ? 'Choose a plan'
                      : 'Pay ${currency.format(_selected!.amount)}',
                  onPressed: _selected == null || _paying ? null : _pay,
                  isLoading: _paying,
                ),
              ],
            ),
    );
  }
}
