import 'dart:async';
import 'dart:io' show Platform;

import 'package:fairytrail/analytics/analytics_service.dart';
import 'package:fairytrail/analytics/meta_events_service.dart';
import 'package:fairytrail/api/billing.dart';
import 'package:fairytrail/api/models/auth_models.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/billing/billing_plans.dart';
import 'package:fairytrail/billing/revenue_cat_service.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/screens/upgrade/upgrade_processing_screen.dart';
import 'package:fairytrail/screens/upgrade/upgrade_success_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/utils/api/https.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the upgrade paywall.
class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({
    super.key,
    this.reason = 'profile_upgrade',
    this.from = 'explore',
    this.preferredTier,
  });

  final String reason;
  final String from;
  final String? preferredTier;

  static Future<void> open(
    BuildContext context, {
    required String reason,
    String from = 'explore',
    String? preferredTier,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => UpgradeScreen(
          reason: reason,
          from: from,
          preferredTier: preferredTier,
        ),
      ),
    );
  }

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  String? _tierToShow;
  late int _selectedDuration;
  late String _selectedPlan;
  bool _offeringsLoading = true;
  bool _purchasing = false;
  bool _restoring = false;
  bool _initializedTier = false;
  List<String> _activeSubscriptions = [];
  Offerings? _offerings;

  String get _currentTier =>
      AuthScope.of(context).profileMeta?.tier ?? tierGated;

  String get _effectiveTierToShow => _tierToShow ?? tierSilver;

  bool get _isSubscribed =>
      _currentTier == _effectiveTierToShow && _effectiveTierToShow != tierFree;

  @override
  void initState() {
    super.initState();
    _applyDefaultPlanForTier(tierSilver);
    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedTier) return;
    _initializedTier = true;

    final preferred = widget.preferredTier;
    final current = _currentTier;
    final isSilver = current == tierSilver;
    final isGold = current == tierGold;

    if (isGold) {
      _tierToShow = tierGold;
    } else if (isSilver && widget.reason != 'subscription') {
      _tierToShow = tierGold;
    } else if (preferred != null && paidTiers.contains(preferred)) {
      _tierToShow = preferred;
    } else {
      _tierToShow = tierSilver;
    }

    _applyDefaultPlanForTier(_effectiveTierToShow);
  }

  void _applyDefaultPlanForTier(String tier) {
    if (tier == tierGold) {
      _selectedDuration = 3;
      _selectedPlan = r'$rc_three_month';
    } else {
      _selectedDuration = 1;
      _selectedPlan = r'$rc_monthly';
    }
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final auth = AuthScope.of(context);
    final userId = auth.user?.id;
    if (userId != null && userId.isNotEmpty) {
      try {
        await RevenueCatService.instance.configure(userId);
      } catch (_) {}
    }

    try {
      final offerings = await RevenueCatService.instance.refreshOfferings();
      final info = await RevenueCatService.instance.getCustomerInfo();
      if (!mounted) return;
      setState(() {
        _offerings = offerings;
        _activeSubscriptions = info.activeSubscriptions.toList();
        _offeringsLoading = false;
      });
    } catch (e) {
      unawaited(
        track('error_get_offerings', {
          'error': e.toString(),
          'from': widget.from,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      );
      if (!mounted) return;
      setState(() => _offeringsLoading = false);
    }
  }

  void _onClose() => Navigator.of(context).pop();

  void _onChangeTier(String tier) {
    setState(() {
      _tierToShow = tier;
      if (tier != tierFree) _applyDefaultPlanForTier(tier);
    });
  }

  BillingPlan? get _selectedBillingPlan {
    final plans = billingTiers[_effectiveTierToShow];
    if (plans == null) return null;
    for (final plan in plans) {
      if (plan.duration == _selectedDuration &&
          plan.rcPackageId == _selectedPlan) {
        return plan;
      }
    }
    return plans.isNotEmpty ? plans.first : null;
  }

  PackagePriceInfo get _selectedPrice {
    final plan = _selectedBillingPlan;
    if (plan == null) return PackagePriceInfo.empty;
    return RevenueCatService.instance.priceForPlan(
      tier: _effectiveTierToShow,
      plan: plan,
      offerings: _offerings,
    );
  }

  String get _periodLabel {
    final plan = _selectedBillingPlan;
    if (plan == null) return '';
    if (plan.rcPackageId == r'$rc_weekly') return 'week';
    if (plan.rcPackageId == r'$rc_annual') return 'year';
    if (plan.duration == 1) return 'month';
    return '${plan.duration} months';
  }

  Future<void> _subscribe() async {
    if (_purchasing) return;
    final plan = _selectedBillingPlan;
    if (plan == null) return;

    unawaited(
      track('click_subscribe_button', {
        'tier': _effectiveTierToShow,
        'duration': plan.rcPackageId == r'$rc_weekly' ? 1 : plan.duration,
        'price': plan.fullPrice,
        'duration_type': plan.rcPackageId == r'$rc_weekly'
            ? 'weekly'
            : plan.rcPackageId == r'$rc_annual'
            ? 'yearly'
            : 'monthly',
        'source': widget.from,
        'reason': widget.reason,
      }),
    );
    unawaited(
      AnalyticsService.instance.logEvent('started_subscription', {
        'tier': _effectiveTierToShow,
        'duration': plan.rcPackageId == r'$rc_weekly' ? 1 : plan.duration,
        'price': plan.fullPrice,
        'revenue': plan.fullPrice,
        'currency': 'USD',
      }),
    );

    final current = _currentTier;
    if (current == tierGold) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => UpgradeSuccessScreen(from: widget.from),
        ),
      );
      return;
    }

    setState(() => _purchasing = true);
    // Press haptic fired by sticky purchase bar.

    final auth = AuthScope.of(context);
    final userId = auth.user?.id;

    try {
      String? oldSku;
      if (current == tierSilver && _activeSubscriptions.isNotEmpty) {
        oldSku = _activeSubscriptions.first;
      }

      final purchase = await RevenueCatService.instance.purchasePlan(
        tier: _effectiveTierToShow,
        plan: plan,
        oldProductIdentifier: oldSku,
      );

      final price = _selectedPrice;
      final storeProduct = price.package?.storeProduct;
      final isUpgrade = current == tierSilver;
      final duration = plan.rcPackageId == r'$rc_weekly' ? 1 : plan.duration;
      final durationType = plan.rcPackageId == r'$rc_weekly'
          ? 'weekly'
          : plan.rcPackageId == r'$rc_annual'
          ? 'yearly'
          : 'monthly';
      final purchasePrice = storeProduct?.price ?? price.rawPrice;

      unawaited(
        track(
          isUpgrade ? 'upgraded_subscription' : 'started_subscription',
          {
            'source': widget.from,
            'reason': widget.reason,
            'tier': _effectiveTierToShow,
            'from_tier': current,
            'to_tier': _effectiveTierToShow,
            'duration': duration,
            'duration_type': durationType,
            'price': purchasePrice,
          },
        ),
      );
      unawaited(
        MetaEventsService.instance.logSubscriptionPurchase(
          eventName: isUpgrade
              ? 'upgraded_existing_subscription'
              : 'purchased_new_subscription',
          tier: _effectiveTierToShow,
          previousTier: current,
          price: storeProduct?.price ?? price.rawPrice,
          currency: storeProduct?.currencyCode ?? price.currencyCode,
          priceString: storeProduct?.priceString ?? price.priceString,
          duration: duration,
          durationType: durationType,
          productId: storeProduct?.identifier ?? plan.rcPackageId,
          productTitle: storeProduct?.title,
          subscriptionPeriod: storeProduct?.subscriptionPeriod,
          transactionId: purchase.storeTransaction.transactionIdentifier,
          purchaseDate: purchase.storeTransaction.purchaseDate,
          from: widget.from,
          reason: widget.reason,
          userId: userId,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => UpgradeProcessingScreen(from: widget.from),
        ),
      );
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        // User cancelled — silent.
      } else {
        unawaited(
          track('error_purchase_package', {
            'error': e.message ?? e.toString(),
            'offering': _effectiveTierToShow,
            'package': plan.rcPackageId,
            'platform': Platform.isIOS ? 'ios' : 'android',
          }),
        );
        if (mounted) {
          await AppDialog.show(
            context,
            title: 'Purchase failed',
            message: e.message ?? 'Unable to complete purchase',
          );
        }
      }
    } catch (e) {
      unawaited(
        track('error_purchase_package', {
          'error': e.toString(),
          'offering': _effectiveTierToShow,
          'package': plan.rcPackageId,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      );
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
    if (_restoring) return;
    setState(() => _restoring = true);

    try {
      final auth = AuthScope.of(context);
      await auth.refreshMe();
      if (isPaidTier(auth.profileMeta?.tier ?? 'gated')) {
        if (!mounted) return;
        await AppDialog.show(
          context,
          title: 'Purchase restored!',
          message: "You're already on ${auth.profileMeta!.tier} tier",
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      CustomerInfo? customerInfo;
      try {
        customerInfo = await RevenueCatService.instance.restorePurchases();
      } catch (_) {
        try {
          customerInfo = await RevenueCatService.instance.getCustomerInfo();
        } catch (_) {}
      }

      String? productId;
      String? originalTransactionId;

      final subsByProduct =
          customerInfo?.subscriptionsByProductIdentifier ?? {};
      for (final entry in subsByProduct.entries) {
        final key = entry.key;
        final sub = entry.value;
        if (sub.isActive && (key.contains('silver') || key.contains('gold'))) {
          originalTransactionId = sub.storeTransactionId;
          productId = sub.productIdentifier.isNotEmpty
              ? sub.productIdentifier
              : key;
          if (originalTransactionId != null &&
              originalTransactionId.isNotEmpty) {
            break;
          }
        }
      }

      if ((originalTransactionId == null || originalTransactionId.isEmpty) &&
          customerInfo != null &&
          customerInfo.activeSubscriptions.isNotEmpty) {
        final activeSubId = customerInfo.activeSubscriptions.first;
        final baseKey = activeSubId.contains(':')
            ? activeSubId.split(':').first
            : activeSubId;
        final sub = subsByProduct[baseKey] ?? subsByProduct[activeSubId];
        if (sub?.storeTransactionId != null) {
          originalTransactionId = sub!.storeTransactionId;
          productId ??= sub.productIdentifier.isNotEmpty
              ? sub.productIdentifier
              : activeSubId;
        }
      }

      if (productId == null && customerInfo != null) {
        final dates = customerInfo.allPurchaseDates;
        final subscriptionProduct = dates.keys.cast<String?>().firstWhere(
          (id) => id != null && (id.contains('silver') || id.contains('gold')),
          orElse: () => dates.keys.isNotEmpty ? dates.keys.first : null,
        );
        productId = subscriptionProduct;
      }

      if (productId == null && customerInfo != null) {
        final all = customerInfo.entitlements.all;
        if (all.isNotEmpty) {
          productId = all.values.first.productIdentifier;
        }
      }

      originalTransactionId = originalTransactionId?.replaceAll(
        RegExp(r'\.\.\d+$'),
        '',
      );

      final deviceInfo =
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      final restoreResponse = await restorePurchaseV2(
        deviceInfo: deviceInfo,
        originalTransactionId: originalTransactionId,
        productId: productId,
      );

      if (!mounted) return;

      if (restoreResponse.success) {
        await auth.refreshMe();
        if (!mounted) return;
        if (isPaidTier(auth.profileMeta?.tier ?? 'gated')) {
          await AppDialog.show(
            context,
            title: 'Success!',
            message:
                'Your ${auth.profileMeta!.tier} tier access has been restored.',
          );
          if (!mounted) return;
          Navigator.of(context).pop();
        } else {
          await AppDialog.show(
            context,
            title: 'Restoration in progress',
            message:
                'Your purchase restoration is being processed. Please check back in a few minutes or contact support if the issue persists.',
          );
        }
      } else if (restoreResponse.existingAccountEmail != null) {
        await AppDialog.show(
          context,
          title: 'Subscription already active',
          message:
              'This subscription is already active on another Fairytrail account (${restoreResponse.existingAccountEmail}). Please log in to that account to access your subscription.',
        );
      } else {
        await AppDialog.show(
          context,
          title: 'Restoration failed',
          message: restoreResponse.message.isNotEmpty
              ? restoreResponse.message
              : 'Failed to restore purchase. Please contact support.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      String message = serverErrorText(e);
      String? existingEmail;
      if (e is ApiException && e.payload is Map) {
        final payload = e.payload as Map;
        existingEmail = payload['existingAccountEmail'] as String?;
        if (payload['message'] is String &&
            (payload['message'] as String).isNotEmpty) {
          message = payload['message'] as String;
        }
      }
      if (existingEmail != null) {
        await AppDialog.show(
          context,
          title: 'Subscription already active',
          message:
              'This subscription is already active on another Fairytrail account ($existingEmail). Please log in to that account to access your subscription.',
        );
      } else {
        await AppDialog.show(context, title: 'Error', message: message);
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _openSubscriptionsSettings() async {
    final uri = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.parse(
            'https://play.google.com/store/account/subscriptions?package=app.fairytrail.release',
          );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final meta = AuthScope.of(context).profileMeta;
    final showPurchaseFooter =
        !_offeringsLoading &&
        !_isSubscribed &&
        _effectiveTierToShow != tierFree;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: AppColors.backgroundOf(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _onClose,
        ),
        title: Text(
          'Upgrade',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimaryOf(context)),
      ),
      body: _offeringsLoading
          ? const AppLoading(message: 'Loading plans…')
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      if (!_isSubscribed || _currentTier == tierSilver) ...[
                        _TierTabs(
                          currentUserTier: _currentTier,
                          tierToShow: _effectiveTierToShow,
                          onChange: _onChangeTier,
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (_isSubscribed) ...[
                        _HeroMessage(
                          title: _subscribedTitle(meta),
                          subtitle: 'Thanks for supporting Fairytrail',
                        ),
                        const SizedBox(height: 20),
                        _BenefitsCard(
                          tier: _effectiveTierToShow,
                          highlight: true,
                        ),
                        const SizedBox(height: 20),
                        if (meta?.tierIsCancelled == true) ...[
                          Text(
                            'Renew to keep your privileges',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondaryOf(context),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppButton(
                            label: 'Renew',
                            onPressed: _openSubscriptionsSettings,
                          ),
                        ] else
                          const _HowToCancel(),
                      ] else if (_effectiveTierToShow == tierFree) ...[
                        _HeroMessage(
                          title: widget.reason == 'limit_reached'
                              ? 'You reached today\'s limit'
                              : "You're on Free",
                          subtitle: widget.reason == 'limit_reached'
                              ? 'Upgrade for more profiles today or come back tomorrow'
                              : 'See what you get — or switch to Silver / Gold',
                        ),
                        const SizedBox(height: 20),
                        const _BenefitsCard(tier: tierFree, highlight: false),
                      ] else ...[
                        _HeroMessage(
                          title: reasonHeadline(
                            reason: widget.reason,
                            tierToShow: _effectiveTierToShow,
                            currentTier: _currentTier,
                          ),
                          subtitle: _effectiveTierToShow == tierGold
                              ? 'Unlimited exploring and higher visibility'
                              : 'Explore more profiles daily',
                        ),
                        const SizedBox(height: 22),
                        _PlanOptions(
                          tier: _effectiveTierToShow,
                          plans: billingTiers[_effectiveTierToShow] ?? const [],
                          selectedDuration: _selectedDuration,
                          selectedPlan: _selectedPlan,
                          offerings: _offerings,
                          onSelect: (duration, rcPackageId) {
                            HapticsService.selection();
                            setState(() {
                              _selectedDuration = duration;
                              _selectedPlan = rcPackageId;
                            });
                          },
                        ),
                        const SizedBox(height: 22),
                        _BenefitsCard(
                          tier: _effectiveTierToShow,
                          highlight: true,
                        ),
                        const SizedBox(height: 16),
                        const _TermsText(),
                      ],
                    ],
                  ),
                ),
                if (showPurchaseFooter)
                  _StickyPurchaseBar(
                    isUpgrade: _currentTier == tierSilver,
                    totalPrice: _selectedPrice.totalPrice,
                    periodLabel: _periodLabel,
                    unitPrice: _selectedPrice.monthlyPrice,
                    isLoading: _purchasing,
                    isRestoring: _restoring,
                    onPressed: _subscribe,
                    onRestore: _restore,
                  ),
              ],
            ),
    );
  }

  String _subscribedTitle(ProfileMetaDto? meta) {
    final status = meta?.tierIsCancelled == true ? 'Expires' : 'Renews';
    final until = meta?.tierValidUntil;
    final dateLabel = until != null
        ? DateFormat.yMMMd().format(until.toLocal())
        : 'soon';
    final name = _currentTier.isEmpty
        ? 'Premium'
        : '${_currentTier[0].toUpperCase()}${_currentTier.substring(1)}';
    return "You're on $name · $status $dateLabel";
  }
}

class _HeroMessage extends StatelessWidget {
  const _HeroMessage({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            height: 1.2,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: textSecondary,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _TierTabs extends StatefulWidget {
  const _TierTabs({
    required this.currentUserTier,
    required this.tierToShow,
    required this.onChange,
  });

  final String currentUserTier;
  final String tierToShow;
  final ValueChanged<String> onChange;

  @override
  State<_TierTabs> createState() => _TierTabsState();
}

class _TierTabsState extends State<_TierTabs>
    with SingleTickerProviderStateMixin {
  late TabController _controller;

  List<String> get _tabs => widget.currentUserTier == tierSilver
      ? <String>[tierGold, tierSilver]
      : <String>[tierGold, tierSilver, tierFree];

  int _selectedIndex(List<String> tabs) {
    final index = tabs.indexOf(widget.tierToShow);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    final tabs = _tabs;
    _controller = TabController(
      length: tabs.length,
      initialIndex: _selectedIndex(tabs),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant _TierTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tabs = _tabs;
    if (_controller.length != tabs.length) {
      _controller.dispose();
      _controller = TabController(
        length: tabs.length,
        initialIndex: _selectedIndex(tabs),
        vsync: this,
      );
      return;
    }

    final index = _selectedIndex(tabs);
    if (_controller.index != index) {
      _controller.animateTo(index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final textSecondary = AppColors.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _controller,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorAnimation: TabIndicatorAnimation.elastic,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        indicatorPadding: EdgeInsets.zero,
        dividerHeight: 0,
        labelPadding: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        labelColor: Colors.white,
        unselectedLabelColor: textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        onTap: (index) {
          HapticsService.selection();
          widget.onChange(tabs[index]);
        },
        tabs: [
          for (final tab in tabs)
            Tab(height: 40, text: '${tab[0].toUpperCase()}${tab.substring(1)}'),
        ],
      ),
    );
  }
}

class _PlanOptions extends StatelessWidget {
  const _PlanOptions({
    required this.tier,
    required this.plans,
    required this.selectedDuration,
    required this.selectedPlan,
    required this.offerings,
    required this.onSelect,
  });

  final String tier;
  final List<BillingPlan> plans;
  final int selectedDuration;
  final String selectedPlan;
  final Offerings? offerings;
  final void Function(int duration, String rcPackageId) onSelect;

  @override
  Widget build(BuildContext context) {
    final prices = [
      for (final plan in plans)
        RevenueCatService.instance.priceForPlan(
          tier: tier,
          plan: plan,
          offerings: offerings,
        ),
    ];
    final baselinePlan = plans.firstOrNull;
    final baselinePrice = prices.firstOrNull;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < plans.length; index++) ...[
          if (index > 0) const SizedBox(width: 10),
          Builder(
            builder: (context) {
              final plan = plans[index];
              final price = prices[index];
              final canCompare =
                  baselinePlan != null &&
                  baselinePrice != null &&
                  price.package != null &&
                  baselinePrice.package != null &&
                  price.currencyCode == baselinePrice.currencyCode;
              final savings = canCompare
                  ? calculateSavingsPercent(
                      plan: plan,
                      totalPrice: price.rawPrice,
                      baselinePlan: baselinePlan,
                      baselineTotalPrice: baselinePrice.rawPrice,
                    )
                  : null;
              return Expanded(
                child: _PlanCard(
                  plan: plan,
                  price: price,
                  savings: savings,
                  selected:
                      selectedDuration == plan.duration &&
                      selectedPlan == plan.rcPackageId,
                  onTap: () => onSelect(plan.duration, plan.rcPackageId),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.price,
    required this.savings,
    required this.selected,
    required this.onTap,
  });

  final BillingPlan plan;
  final PackagePriceInfo price;
  final int? savings;
  final bool selected;
  final VoidCallback onTap;

  String get _periodUnit {
    if (plan.rcPackageId == r'$rc_weekly') return 'week';
    if (plan.rcPackageId == r'$rc_annual') return 'year';
    if (plan.duration == 1) return 'month';
    return 'months';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final cardBg = selected
        ? AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.08)
        : AppColors.surfaceOf(context);
    // Near-black fill so white label text stays readable in both themes.
    final unselectedBadge = isDark
        ? const Color(0xFF1A1A1A)
        : AppColors.lightTextPrimary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderOf(context),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            SizedBox(
              height: 22,
              child: savings != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : unselectedBadge,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Save $savings%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : selected
                  ? const Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: AppColors.primary,
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
            Text(
              '${plan.durationLabel}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1,
                color: selected ? AppColors.primary : textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _periodUnit,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.85)
                    : textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              price.monthlyPrice,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              plan.duration > 1 || plan.rcPackageId == r'$rc_weekly'
                  ? price.totalPrice
                  : 'billed monthly',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
            if (plan.label != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : unselectedBadge,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  plan.label!.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: Colors.white,
                  ),
                ),
              ),
            ] else
              const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard({required this.tier, required this.highlight});

  final String tier;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final benefits = benefitsForTier(tier);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tier == tierFree ? "What's included" : 'What you unlock',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < benefits.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      benefits[i],
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: highlight && i < 2
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: textPrimary,
                      ),
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

class _StickyPurchaseBar extends StatelessWidget {
  const _StickyPurchaseBar({
    required this.isUpgrade,
    required this.totalPrice,
    required this.periodLabel,
    required this.unitPrice,
    required this.isLoading,
    required this.isRestoring,
    required this.onPressed,
    required this.onRestore,
  });

  final bool isUpgrade;
  final String totalPrice;
  final String periodLabel;
  final String unitPrice;
  final bool isLoading;
  final bool isRestoring;
  final VoidCallback onPressed;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final isDark = AppColors.isDark(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 8 + bottom),
      decoration: BoxDecoration(
        color: AppColors.backgroundOf(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      totalPrice,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'for $periodLabel · $unitPrice',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading || isRestoring
                        ? null
                        : () {
                            HapticsService.medium();
                            onPressed();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isUpgrade ? 'Upgrade' : 'Continue',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: isLoading || isRestoring ? null : onRestore,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isRestoring
                  ? 'Restoring… this may take a minute'
                  : 'Restore purchases',
              style: TextStyle(
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Platform.isIOS
                ? 'Cancel anytime · Secure App Store checkout'
                : 'Cancel anytime · Secure Play Store checkout',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsText extends StatelessWidget {
  const _TermsText();

  @override
  Widget build(BuildContext context) {
    final platformTerms = Platform.isIOS
        ? '24 hours prior to the end of the subscription, unless turned off in iTunes Account Settings.'
        : '24 hours prior to the end of the subscription, unless auto-renew is turned off.';
    return Text(
      'This subscription will automatically renew and charge $platformTerms Manage in Settings. Cancel anytime.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        height: 1.4,
        color: AppColors.textSecondaryOf(context),
      ),
    );
  }
}

class _HowToCancel extends StatelessWidget {
  const _HowToCancel();

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How do I cancel?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isIos
              ? 'Settings → your name → Subscriptions → Fairytrail → Cancel.'
              : 'Play Store → Menu → Subscriptions → Fairytrail → Cancel.',
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: AppColors.textSecondaryOf(context),
          ),
        ),
      ],
    );
  }
}
