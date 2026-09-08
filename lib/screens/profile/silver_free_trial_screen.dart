import 'dart:async';
import 'dart:io' show Platform;

import 'package:fairytrail/analytics/meta_events_service.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/billing/billing_plans.dart';
import 'package:fairytrail/billing/revenue_cat_service.dart';
import 'package:fairytrail/remote_config/remote_config_controller.dart';
import 'package:fairytrail/screens/upgrade/upgrade_processing_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Silver annual free-trial paywall.
class SilverFreeTrialScreen extends StatefulWidget {
  const SilverFreeTrialScreen({super.key, this.from = 'profile'});

  final String from;

  static Future<void> open(BuildContext context, {String from = 'profile'}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SilverFreeTrialScreen(from: from),
      ),
    );
  }

  @override
  State<SilverFreeTrialScreen> createState() => _SilverFreeTrialScreenState();
}

class _SilverFreeTrialScreenState extends State<SilverFreeTrialScreen> {
  static const _annualPlan = BillingPlan(
    duration: 12,
    durationLabel: 12,
    price: 4.66,
    fullPrice: 55.99,
    label: 'best value',
    productId: '',
    rcPackageId: r'$rc_annual',
  );

  static const _featureIcons = <IconData>[
    Icons.visibility_outlined,
    Icons.people_outline_rounded,
    Icons.undo_rounded,
    Icons.verified_outlined,
    Icons.block_flipped,
  ];

  static const _timelineIconLock = Icons.lock_open_rounded;
  static const _timelineIconExplore = Icons.explore_outlined;
  static const _timelineIconBell = Icons.notifications_outlined;
  static const _timelineIconStar = Icons.star_outline_rounded;

  static IconData _secondTimelineIcon(String key) => switch (key) {
        'explore' => _timelineIconExplore,
        _ => _timelineIconBell,
      };

  bool _loading = true;
  bool _purchasing = false;
  bool _trackedView = false;
  Package? _package;
  StoreProduct? _product;
  _TrialInfo? _trial;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_trackedView) return;
    _trackedView = true;
    unawaited(
      track('view_free_trial_offer', {
        'tier': tierSilver,
        'from': widget.from,
        'show_free_trial_x': RemoteConfigScope.of(context).showFreeTrialX,
      }),
    );
  }

  Future<void> _load() async {
    // Debug launch can open this screen before sign-in configures billing.
    if (!RevenueCatService.instance.isConfigured) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await Purchases.invalidateCustomerInfoCache();
      final offerings = await RevenueCatService.instance.refreshOfferings();
      final pkg = RevenueCatService.instance.findPackage(
        tier: tierSilver,
        rcPackageId: r'$rc_annual',
        offerings: offerings,
      );

      final productId = Platform.isAndroid ? 'silver:silver-12' : 'silver.12';
      StoreProduct? directProduct;
      try {
        final direct = await Purchases.getProducts([productId]);
        if (direct.isNotEmpty) directProduct = direct.first;
      } catch (_) {
        // Keep going with offering product.
      }

      final product = pkg?.storeProduct ?? directProduct;
      final trial = product == null ? null : _TrialInfo.fromProduct(product);

      if (!mounted) return;
      setState(() {
        _package = pkg;
        _product = product;
        _trial = trial ??
            (directProduct == null
                ? null
                : _TrialInfo.fromProduct(directProduct));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _purchase() async {
    if (_purchasing || _package == null) return;
    setState(() => _purchasing = true);

    final auth = AuthScope.of(context);
    final showFreeTrialX = RemoteConfigScope.of(context).showFreeTrialX;
    final userId = auth.user?.id;
    final product = _product ?? _package?.storeProduct;
    final trial = _trial;
    final price = trial != null ? 0.0 : (product?.price ?? _annualPlan.fullPrice);
    final currency = product?.currencyCode ?? 'USD';
    final priceString = trial != null
        ? '\$0.00'
        : (product?.priceString ?? '\$55.99');

    try {
      final purchase = await RevenueCatService.instance.purchasePlan(
        tier: tierSilver,
        plan: _annualPlan,
      );
      if (!mounted) return;

      if (trial != null) {
        unawaited(
          track('started_free_trial', {
            'show_free_trial_x': showFreeTrialX,
            'tier': tierSilver,
            'duration': 12,
            'duration_type': 'yearly',
            'price': price,
            'currency': currency,
            'product_id': product?.identifier ?? r'$rc_annual',
            'trial_days': trial.days,
            'from': widget.from,
            'source': widget.from,
            'reason': 'free_trial',
          }),
        );
        unawaited(
          MetaEventsService.instance.logStartedFreeTrial(
            tier: tierSilver,
            price: price,
            currency: currency,
            priceString: priceString,
            duration: 12,
            durationType: 'yearly',
            productId: product?.identifier ?? r'$rc_annual',
            trialDays: trial.days,
            productTitle: product?.title,
            subscriptionPeriod: product?.subscriptionPeriod,
            transactionId: purchase.storeTransaction.transactionIdentifier,
            purchaseDate: purchase.storeTransaction.purchaseDate,
            from: widget.from,
            userId: userId,
          ),
        );
      }

      if (widget.from == 'signup') {
        await AuthScope.of(context).completeSignupFlow();
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => UpgradeProcessingScreen(from: widget.from),
        ),
      );
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return;
      if (!mounted) return;
      await AppDialog.show(
        context,
        title: 'Purchase failed',
        message: e.message ?? 'Unable to complete purchase',
      );
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

  Future<void> _restore() async {
    if (!RevenueCatService.instance.isConfigured) return;
    try {
      await RevenueCatService.instance.restorePurchases();
      if (!mounted) return;
      AppToast.show(context, message: 'Purchases restored');
      await AuthScope.of(context).refreshMe();
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textSecondaryOf(context);
    final remoteConfig = RemoteConfigScope.of(context);
    final copy = remoteConfig.freeTrialText;
    final trial = _trial;
    final priceString = _product?.priceString ?? '\$55.99';
    final trialDays = trial?.days ?? 3;
    final midDay = trialDays <= 2
        ? trialDays
        : (trialDays / 2).ceil().clamp(2, trialDays);
    final isDark = AppColors.isDark(context);
    final timelineIcons = <IconData>[
      _timelineIconLock,
      _secondTimelineIcon(remoteConfig.freeTrial2ndIcon),
      _timelineIconStar,
    ];

    String t(String template) => copy.resolve(
          template,
          trialDays: trialDays,
          midDay: midDay,
          price: priceString,
        );

    final timelineSteps = <_TimelineStep>[
      for (var i = 0; i < copy.timeline.length; i++)
        _TimelineStep(
          icon: timelineIcons[i % timelineIcons.length],
          title: t(copy.timeline[i].title),
          subtitle: t(copy.timeline[i].subtitle),
        ),
    ];

    final features = <_BenefitFeature>[
      for (var i = 0; i < copy.features.length; i++)
        _BenefitFeature(
          icon: _featureIcons[i % _featureIcons.length],
          title: copy.features[i],
        ),
    ];

    final showClose = remoteConfig.showFreeTrialX;

    return PopScope(
      canPop: showClose,
      child: AppScaffold(
        title: copy.appBarTitle,
        leading: showClose
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : const SizedBox.shrink(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      children: [
                        AppText(
                          copy.headline,
                          variant: AppTextVariant.display,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        _TrialTimeline(steps: timelineSteps),
                        const SizedBox(height: 28),
                        _BenefitsCard(
                          header: copy.benefitsHeader,
                          features: features,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundOf(context),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.35 : 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppText(
                          t(
                            trial != null
                                ? copy.priceWithTrial
                                : copy.priceWithoutTrial,
                          ),
                          variant: AppTextVariant.bodySmall,
                          color: muted,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          label: trial != null
                              ? copy.ctaWithTrial
                              : copy.ctaWithoutTrial,
                          isLoading: _purchasing,
                          onPressed: _package == null || _purchasing
                              ? null
                              : _purchase,
                        ),
                        AppButton(
                          label: copy.restore,
                          variant: AppButtonVariant.text,
                          onPressed: _purchasing ? null : _restore,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TrialInfo {
  const _TrialInfo({required this.days, required this.source});

  final int days;
  final String source;

  static _TrialInfo? fromProduct(StoreProduct product) {
    final intro = product.introductoryPrice;
    if (intro != null && intro.price <= 0) {
      final days = _unitsToDays(
        intro.periodUnit,
        intro.periodNumberOfUnits * intro.cycles,
      );
      if (days != null && days > 0) {
        return _TrialInfo(days: days, source: 'introductoryPrice');
      }
    }

    final option = product.defaultOption;
    final freePhase = option?.freePhase;
    if (freePhase != null) {
      final days = _phaseToDays(freePhase);
      if (days != null && days > 0) {
        return _TrialInfo(days: days, source: 'defaultOption.freePhase');
      }
    }

    final options = product.subscriptionOptions ?? const <SubscriptionOption>[];
    for (final opt in options) {
      final phase = opt.freePhase;
      if (phase == null) continue;
      final days = _phaseToDays(phase);
      if (days != null && days > 0) {
        return _TrialInfo(days: days, source: 'subscriptionOptions.freePhase');
      }
    }

    return null;
  }

  static int? _phaseToDays(PricingPhase phase) {
    final period = phase.billingPeriod;
    if (period == null) return null;
    final cycles = phase.billingCycleCount ?? 1;
    return _unitsToDays(period.unit, period.value * cycles);
  }

  static int? _unitsToDays(PeriodUnit unit, int units) {
    if (units <= 0) return null;
    return switch (unit) {
      PeriodUnit.day => units,
      PeriodUnit.week => units * 7,
      PeriodUnit.month => units * 30,
      PeriodUnit.year => units * 365,
      PeriodUnit.unknown => null,
    };
  }
}

class _TimelineStep {
  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _TrialTimeline extends StatelessWidget {
  const _TrialTimeline({required this.steps});

  final List<_TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textSecondaryOf(context);

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 34,
                    child: Column(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            steps[i].icon,
                            color: AppColors.white,
                            size: 17,
                          ),
                        ),
                        if (i < steps.length - 1)
                          Container(
                            width: 2,
                            height: 24,
                            color: AppColors.primary.withValues(alpha: 0.35),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: 5,
                        bottom: i < steps.length - 1 ? 12 : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            steps[i].title,
                            variant: AppTextVariant.body,
                            fontWeight: FontWeight.w600,
                          ),
                          const SizedBox(height: 2),
                          AppText(
                            steps[i].subtitle,
                            variant: AppTextVariant.bodySmall,
                            color: muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BenefitFeature {
  const _BenefitFeature({required this.icon, required this.title});

  final IconData icon;
  final String title;
}

class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard({
    required this.header,
    required this.features,
  });

  final String header;
  final List<_BenefitFeature> features;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            header,
            variant: AppTextVariant.label,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < features.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(features[i].icon, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppText(
                      features[i].title,
                      variant: AppTextVariant.body,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
