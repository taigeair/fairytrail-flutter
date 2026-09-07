import 'dart:async';

import 'package:fairytrail/api/travel.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/remote_config/remote_config_controller.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/api/https.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';

class AddTrailMoneyScreen extends StatefulWidget {
  const AddTrailMoneyScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AddTrailMoneyScreen()),
    );
  }

  @override
  State<AddTrailMoneyScreen> createState() => _AddTrailMoneyScreenState();
}

class _AddTrailMoneyScreenState extends State<AddTrailMoneyScreen> {
  bool _paying = false;
  bool _success = false;
  String? _error;

  Future<void> _chooseAmount() async {
    final amount = await showModalBottomSheet<double>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _AmountSheet(),
    );
    if (amount != null && mounted) await _purchase(amount);
  }

  Future<void> _purchase(double amount) async {
    if (_paying) return;
    setState(() {
      _paying = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        fetchStripeKeys(),
        createTrailMoneyPaymentIntent(amount),
      ]);
      final keys = results[0] as StripeKeysDto;
      final session = results[1] as TrailMoneyPaymentSession;
      if (keys.publishableKey.isEmpty || session.clientSecret.isEmpty) {
        throw StateError('Stripe is not configured');
      }

      Stripe.publishableKey = keys.publishableKey;
      Stripe.merchantIdentifier = 'merchant.app.taigeair.release';
      Stripe.urlScheme = 'com.fairytrail.app';
      await Stripe.instance.applySettings();
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: session.clientSecret,
          customerId: session.customer,
          customerEphemeralKeySecret: session.ephemeralKey,
          merchantDisplayName: 'Fairytrail',
          primaryButtonLabel: 'Add \$${amount.toStringAsFixed(0)}',
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

      final paymentIntentId = session.clientSecret.split('_secret_').first;
      await topUpTrailMoney(amount: amount, paymentIntentId: paymentIntentId);
      if (!mounted) return;
      try {
        await AuthScope.of(context).refreshMe();
      } catch (_) {
        // The top-up already succeeded; Profile will refresh on its next visit.
      }
      if (!mounted) return;
      setState(() {
        _paying = false;
        _success = true;
      });
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
    } catch (error, stackTrace) {
      debugPrint('[TrailMoney] Payment failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _paying = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _emailSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'team@fairytrail.app',
      queryParameters: {'subject': 'Add Trail Money'},
    );
    if (!await launchUrl(uri) && mounted) {
      AppToast.show(context, message: 'Email team@fairytrail.app for help.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return AppScaffold(
        title: 'Add funds',
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const AppText(
              'Your trail money increased!',
              variant: AppTextVariant.display,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Image.asset('assets/travel/money.png', height: 180),
            const SizedBox(height: 24),
            const AppText(
              'Have fun on your adventure.',
              variant: AppTextVariant.headline,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            AppButton(
              label: 'Continue',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }

    final stripeEnabled = RemoteConfigScope.of(context).isStripeEnabled;

    return AppScaffold(
      title: 'Add funds',
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Image.asset('assets/travel/money.png', height: 180),
          const SizedBox(height: 24),
          const AppText(
            'Not enough trail money? Easily top up your account here',
            variant: AppTextVariant.body,
            textAlign: TextAlign.center,
          ),
          if (!stripeEnabled) ...[
            const SizedBox(height: 16),
            AppText(
              'Email team@fairytrail.app to add funds.',
              variant: AppTextVariant.body,
              textAlign: TextAlign.center,
              color: AppColors.primary,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            AppText(
              _error!,
              variant: AppTextVariant.bodySmall,
              color: Theme.of(context).colorScheme.error,
              textAlign: TextAlign.center,
            ),
          ],
          const Spacer(),
          AppButton(
            label: stripeEnabled ? 'Add funds' : 'Email us',
            onPressed: stripeEnabled
                ? (_paying ? null : _chooseAmount)
                : _emailSupport,
            isLoading: _paying,
          ),
        ],
      ),
    );
  }
}

class _AmountSheet extends StatelessWidget {
  const _AmountSheet();

  Future<void> _custom(BuildContext context) async {
    final navigator = Navigator.of(context);
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _CustomAmountSheet(),
    );
    if (amount != null) navigator.pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AppSafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppText('Choose an amount', variant: AppTextVariant.title),
            const SizedBox(height: 16),
            for (final amount in const [5.0, 20.0, 50.0]) ...[
              AppButton(
                label: '\$${amount.toStringAsFixed(0)}',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.pop(context, amount),
              ),
              const SizedBox(height: 12),
            ],
            AppButton(
              label: 'Custom',
              variant: AppButtonVariant.secondary,
              onPressed: () => unawaited(_custom(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomAmountSheet extends StatefulWidget {
  const _CustomAmountSheet();

  @override
  State<_CustomAmountSheet> createState() => _CustomAmountSheetState();
}

class _CustomAmountSheetState extends State<_CustomAmountSheet> {
  final _controller = TextEditingController(text: '100');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_controller.text);
    if (amount == null || amount < 5 || amount > 300) {
      setState(() => _error = 'Enter an amount from \$5 to \$300.');
      return;
    }
    Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) {
    return AppSafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppText('Custom amount', variant: AppTextVariant.title),
            const SizedBox(height: 16),
            AppTextField(
              controller: _controller,
              label: 'Amount (USD)',
              prefixIcon: const Icon(Icons.attach_money_rounded),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d{0,3}(\.\d{0,2})?'),
                ),
              ],
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              AppText(
                _error!,
                variant: AppTextVariant.bodySmall,
                color: Theme.of(context).colorScheme.error,
              ),
            ],
            const SizedBox(height: 20),
            AppButton(label: 'Continue', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
