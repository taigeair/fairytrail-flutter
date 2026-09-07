import 'dart:async';

import 'package:fairytrail/api/gift_subscription.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/screens/profile/profile_view_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/api/https.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Full-screen blocker for an incoming gifted Silver subscription.
class GiftSubscriptionReceivedScreen extends StatefulWidget {
  const GiftSubscriptionReceivedScreen({
    super.key,
    required this.gift,
  });

  final GiftSubscriptionDto gift;

  static const routeName = '/gift-subscription-received';

  static Future<void> open(
    BuildContext context, {
    required GiftSubscriptionDto gift,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        settings: const RouteSettings(name: routeName),
        builder: (_) => GiftSubscriptionReceivedScreen(gift: gift),
      ),
    );
  }

  @override
  State<GiftSubscriptionReceivedScreen> createState() =>
      _GiftSubscriptionReceivedScreenState();
}

class _GiftSubscriptionReceivedScreenState
    extends State<GiftSubscriptionReceivedScreen> {
  bool _busy = false;

  String get _senderName {
    final n = widget.gift.senderName?.trim();
    if (n == null || n.isEmpty) return 'Someone';
    return n.split(' ').first;
  }

  bool get _alreadyUsed =>
      widget.gift.status == 'accepted' || widget.gift.status == 'declined';

  bool get _alreadySub => widget.gift.receiverAlreadySubscribed;

  Future<void> _seeSender() async {
    final senderId = widget.gift.senderProfileId;
    debugPrint(
      '[GiftSubscriptionReceived] see sender=$senderId status=${widget.gift.status}',
    );
    if (senderId <= 0) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop();
    await ProfileViewScreen.open(
      context,
      profileId: senderId,
      from: 'trailbook',
    );
  }

  /// Mark gift accepted when receiver already has a sub (clears pending blocker).
  Future<void> _acknowledge({required bool openProfile}) async {
    if (_busy) return;
    setState(() => _busy = true);
    debugPrint(
      '[GiftSubscriptionReceived] acknowledge gift=${widget.gift.id} '
      'openProfile=$openProfile',
    );
    try {
      final result = await acceptGiftSubscription(widget.gift.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (openProfile && result.senderProfileId > 0) {
        await ProfileViewScreen.open(
          context,
          profileId: result.senderProfileId,
          from: 'trailbook',
        );
      }
    } on ApiException catch (e) {
      debugPrint('[GiftSubscriptionReceived] acknowledge ApiException: $e');
      if (!mounted) return;
      // Already resolved — still allow see/close.
      Navigator.of(context).pop();
      if (openProfile && widget.gift.senderProfileId > 0) {
        await ProfileViewScreen.open(
          context,
          profileId: widget.gift.senderProfileId,
          from: 'trailbook',
        );
      }
    } catch (e, st) {
      debugPrint('[GiftSubscriptionReceived] acknowledge failed: $e\n$st');
      if (!mounted) return;
      AppToast.show(context, message: 'Something went wrong. Try again.');
      setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    debugPrint('[GiftSubscriptionReceived] accept gift=${widget.gift.id}');
    try {
      final result = await acceptGiftSubscription(widget.gift.id);
      debugPrint(
        '[GiftSubscriptionReceived] accept ok upgraded=${result.upgraded} '
        'alreadyHad=${result.alreadyHadSubscription}',
      );

      if (!mounted) return;

      unawaited(AuthScope.of(context).refreshMe());

      final senderId = result.senderProfileId;
      var openSenderProfile = false;
      if (result.alreadyHadSubscription) {
        openSenderProfile = await AppDialog.confirm(
          context,
          title: 'You already have a subscription',
          message:
              '$_senderName sent you a subscription but you already have one. '
              'You can still thank them.',
          confirmLabel: 'View $_senderName',
          cancelLabel: 'Do not thank',
        );
      } else if (result.upgraded) {
        openSenderProfile = await AppDialog.confirm(
          context,
          title: 'You’re upgraded',
          message:
              'Enjoy ${result.gift.durationLabel} of Silver, and thank $_senderName!',
          confirmLabel: 'View $_senderName',
          cancelLabel: 'Do not thank',
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      if (openSenderProfile && senderId > 0) {
        await ProfileViewScreen.open(
          context,
          profileId: senderId,
          from: 'trailbook',
        );
      }
    } on ApiException catch (e) {
      debugPrint('[GiftSubscriptionReceived] accept ApiException: $e');
      if (!mounted) return;
      // Already resolved on server — switch to already-used UX.
      if (e.message.contains('invalid_status') ||
          e.message.contains('forbidden')) {
        setState(() => _busy = false);
        await AppDialog.confirm(
          context,
          title: 'Gift already used',
          message:
              'This gift from $_senderName was already accepted or declined.',
          confirmLabel: 'View $_senderName',
          cancelLabel: 'Close',
        ).then((open) async {
          if (!mounted) return;
          Navigator.of(context).pop();
          if (open && widget.gift.senderProfileId > 0) {
            await ProfileViewScreen.open(
              context,
              profileId: widget.gift.senderProfileId,
              from: 'trailbook',
            );
          }
        });
        return;
      }
      AppToast.show(context, message: e.message);
      setState(() => _busy = false);
    } catch (e, st) {
      debugPrint('[GiftSubscriptionReceived] accept failed: $e\n$st');
      if (!mounted) return;
      AppToast.show(context, message: 'Could not accept gift. Try again.');
      setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    if (_busy) return;
    setState(() => _busy = true);
    debugPrint('[GiftSubscriptionReceived] decline gift=${widget.gift.id}');
    try {
      await declineGiftSubscription(widget.gift.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      debugPrint('[GiftSubscriptionReceived] decline ApiException: $e');
      if (!mounted) return;
      AppToast.show(context, message: e.message);
      setState(() => _busy = false);
    } catch (e, st) {
      debugPrint('[GiftSubscriptionReceived] decline failed: $e\n$st');
      if (!mounted) return;
      AppToast.show(context, message: 'Could not decline gift. Try again.');
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_alreadyUsed) {
      final wasAccepted = widget.gift.status == 'accepted';
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: AppSafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.card_giftcard_rounded,
                  size: 56,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 20),
                const AppText(
                  'Gift already used',
                  variant: AppTextVariant.title,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                AppText(
                  wasAccepted
                      ? 'You already accepted $_senderName’s Silver gift.'
                      : 'You already declined $_senderName’s Silver gift.',
                  variant: AppTextVariant.body,
                  textAlign: TextAlign.center,
                  color: AppColors.textSecondaryOf(context),
                ),
                const Spacer(),
                AppButton(
                  label: 'View $_senderName',
                  onPressed: _seeSender,
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Close',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.card_giftcard_rounded,
                size: 56,
                color: AppColors.primary,
              ),
              const SizedBox(height: 20),
              AppText(
                _alreadySub
                    ? '$_senderName sent you a gift'
                    : 'You got free Silver!',
                variant: AppTextVariant.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              AppText(
                _alreadySub
                    ? '$_senderName gifted you ${widget.gift.durationLabel} of Silver, '
                        'but you already have a subscription.'
                    : '$_senderName gifted you ${widget.gift.durationLabel} of Silver. '
                        'It does not auto-renew.',
                variant: AppTextVariant.body,
                textAlign: TextAlign.center,
                color: AppColors.textSecondaryOf(context),
              ),
              const Spacer(),
              if (_alreadySub) ...[
                AppButton(
                  label: 'View $_senderName',
                  onPressed: _busy ? null : () => _acknowledge(openProfile: true),
                  isLoading: _busy,
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Close',
                  variant: AppButtonVariant.secondary,
                  onPressed: _busy ? null : () => _acknowledge(openProfile: false),
                ),
              ] else ...[
                AppButton(
                  label: 'Accept',
                  onPressed: _busy ? null : _accept,
                  isLoading: _busy,
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Decline',
                  variant: AppButtonVariant.secondary,
                  onPressed: _busy ? null : _decline,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
