import 'dart:math';

import 'package:fairytrail/components/trail_book/postcard_info_sheet.dart';
import 'package:fairytrail/config/trail_book_quotes.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/remote_config/remote_config_controller.dart';
import 'package:fairytrail/screens/profile/gift_subscription_screen.dart';
import 'package:fairytrail/screens/trail_book/send_postcard_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Quote + ways to inspire another traveler.
class SelectCareOptionScreen extends StatefulWidget {
  const SelectCareOptionScreen({
    super.key,
    required this.profileId,
    required this.name,
    this.profilePhotoUrl,
    this.path = 'explore',
  });

  final int profileId;
  final String name;
  final String? profilePhotoUrl;
  final String path;

  @override
  State<SelectCareOptionScreen> createState() => _SelectCareOptionScreenState();
}

class _SelectCareOptionScreenState extends State<SelectCareOptionScreen> {
  late final TrailBookQuote _quote =
      trailBookQuotes[Random().nextInt(trailBookQuotes.length)];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowIntro());
  }

  Future<void> _maybeShowIntro() async {
    // final seen = await LocalStorage.instance.getHasSeenPostcardIntro();
    // if (seen || !mounted) return;
    // await LocalStorage.instance.setHasSeenPostcardIntro();
    // if (!mounted) return;
    // await showPostcardInfoSheet(context);
  }

  void _sendPostcard() {
    HapticsService.selection();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SendPostcardScreen(
          profileId: widget.profileId,
          name: widget.name,
          profilePhotoUrl: widget.profilePhotoUrl,
          path: widget.path,
        ),
      ),
    );
  }

  Future<void> _giftSubscription() async {
    HapticsService.selection();
    await GiftSubscriptionScreen.open(
      context,
      receiverProfileId: widget.profileId,
      receiverName: widget.name,
      receiverPhotoUrl: widget.profilePhotoUrl,
      path: widget.path,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showGift = RemoteConfigScope.of(context).showGiftSubscription;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const AppText('Inspire', variant: AppTextVariant.title),
        actions: [
          IconButton(
            onPressed: () => showPostcardInfoSheet(context),
            icon: Image.asset(
              'assets/trailBook/info.png',
              width: 22,
              height: 22,
              color: Theme.of(context).colorScheme.onSurface,
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
        ],
      ),
      body: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppText(
                        _quote.quote,
                        variant: AppTextVariant.title,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        textAlign: TextAlign.center,
                        color: AppColors.textPrimaryOf(context),
                      ),
                      const SizedBox(height: 16),
                      AppText(
                        _quote.author,
                        variant: AppTextVariant.body,
                        fontSize: 16,
                        textAlign: TextAlign.center,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ],
                  ),
                ),
              ),
              const AppButton(
                label: 'Recommend a trip - coming soon',
                onPressed: null,
              ),
              const SizedBox(height: 12),
              const AppButton(
                label: 'Send a carepack - coming soon',
                onPressed: null,
              ),
              const SizedBox(height: 12),
              AppButton(label: 'Write a postcard', onPressed: _sendPostcard),
              if (showGift) ...[
                const SizedBox(height: 12),
                AppButton(
                  label: 'Gift a subscription',
                  variant: AppButtonVariant.secondary,
                  onPressed: _giftSubscription,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
