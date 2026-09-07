import 'dart:io';

import 'package:fairytrail/api/push_tokens.dart' as push_api;
import 'package:fairytrail/api/edit_profile_props.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/billing/billing_plans.dart';
import 'package:fairytrail/config/app_version.dart';
import 'package:fairytrail/push/notification_prompt_store.dart';
import 'package:fairytrail/push/push_service.dart';
import 'package:fairytrail/profile/profile_strength.dart';
import 'package:fairytrail/registration/background_photo_upload.dart';
import 'package:fairytrail/screens/profile/account_screen.dart';
import 'package:fairytrail/screens/profile/add_trail_money_screen.dart';
import 'package:fairytrail/screens/profile/edit_profile_screen.dart';
import 'package:fairytrail/screens/profile/marketing_emails_screen.dart';
import 'package:fairytrail/screens/profile/notification_preferences_screen.dart';
import 'package:fairytrail/screens/profile/search_prefs_screen.dart';
import 'package:fairytrail/screens/trail_book/trail_book_nav.dart';
import 'package:fairytrail/screens/truth_serum/truth_serum_screen.dart';
import 'package:fairytrail/screens/upgrade/upgrade_screen.dart';
import 'package:fairytrail/screens/verification/verification_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/theme/theme_controller.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/foundation.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loggingOut = false;
  int _profileStrength = 0;
  bool _findTrailItemsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotifPrefs();
    _loadProfileStrength();
    _loadPickupTrailMoneyPref();
  }

  Future<void> _loadPickupTrailMoneyPref() async {
    final disabled = await LocalStorage.instance.isPickupTrailMoneyDisabled();
    if (!mounted) return;
    setState(() => _findTrailItemsEnabled = !disabled);
  }

  Future<void> _setFindTrailItemsEnabled(bool enabled) async {
    setState(() => _findTrailItemsEnabled = enabled);
    setTrackedFindTrailTreasures(enabled);
    await LocalStorage.instance.setPickupTrailMoneyDisabled(!enabled);
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refetch push config when Profile tab is selected (e.g. after first-connect enable).
    if (widget.isActive && !oldWidget.isActive) {
      _loadNotifPrefs();
      AuthScope.of(context).refreshMe().catchError((_) {});
    }
  }

  Future<void> _loadProfileStrength() async {
    var strength = await LocalStorage.instance.getProfileStrength();
    if (strength == null) {
      try {
        final profile = (await getEditProfileProps()).profile;
        if (profile != null) {
          strength = calculateProfileStrength(profile);
          await LocalStorage.instance.setProfileStrength(strength);
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _profileStrength = strength ?? 0);
  }

  Future<void> _openEditProfile() async {
    await EditProfileScreen.open(context);
    await _loadProfileStrength();
  }

  Future<void> _openProfilePreview() async {
    await EditProfileScreen.open(context, startInPreview: true);
    await _loadProfileStrength();
  }

  Future<void> _loadNotifPrefs() async {
    try {
      final permitted = await PushService.instance.hasPermission();
      final config = await push_api.fetchNotificationConfig();
      if (!mounted) return;
      if (permitted && config.type != 'none') {
        NotificationPromptStore.markPrompted(
          userId: AuthScope.of(context).user?.id,
        );
      }
    } catch (e) {
      debugPrint('[Profile] load notif config failed: $e');
    }
  }

  Future<void> _openNotificationPreferences() async {
    await NotificationPreferencesScreen.open(context);
    if (!mounted) return;
    await _loadNotifPrefs();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Local gift shop while developing (Vite on LAN). Swap back to prod later.
  Future<void> _openGiftShop() async {
    final auth = AuthScope.of(context);
    final token = auth.apiToken?.trim();
    final uri = Uri(
      scheme: 'https',
      host: 'fairytrail.app',
      // port: 5173,
      path: '/giftshop/',
      queryParameters: {
        if (token != null && token.isNotEmpty) 'login_token': token,
      },
    );
    await _openUrl(uri.toString());
  }

  Future<void> _rateUs() async {
    final review = InAppReview.instance;
    try {
      // This is an explicit settings action, so always open a visible review
      // destination. Google Play may silently suppress requestReview() even
      // when isAvailable() returns true (especially on emulators).
      await review.openStoreListing(appStoreId: '1442011999');
    } catch (e) {
      debugPrint('[Profile] openStoreListing failed: $e');
      await _openUrl(
        Platform.isIOS
            ? 'https://apps.apple.com/app/apple-store/id1442011999'
            : 'https://play.google.com/store/apps/details?id=app.fairytrail.release',
      );
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Heads up!',
      message:
          'Be sure you know your email and sign-in method before logging out',
      confirmLabel: 'Log out',
    );
    if (!confirmed || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await AuthScope.of(context).logout();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  Future<void> _crashForSentry() async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Send test error to Sentry?',
      message:
          'This reports a fatal test exception (does not force-quit). Check Sentry Issues after a few seconds.',
      confirmLabel: 'Send',
    );
    if (!confirmed || !mounted) return;

    if (!Sentry.isEnabled) {
      AppToast.show(context, message: 'Sentry is not enabled');
      return;
    }

    final eventId = await Sentry.captureException(
      StateError('Sentry test crash'),
      stackTrace: StackTrace.current,
      withScope: (scope) {
        scope.level = SentryLevel.fatal;
        scope.setTag('source', 'profile_crash_button');
      },
    );

    // Native transport writes the envelope then uploads asynchronously —
    // give it a moment before the user backgrounds/kills the app.
    await Future<void>.delayed(const Duration(seconds: 2));

    debugPrint(
      '[Sentry] captureException done id=$eventId enabled=${Sentry.isEnabled}',
    );
    if (!mounted) return;
    if (eventId == SentryId.empty()) {
      AppToast.show(
        context,
        message: 'Sentry returned empty event id — check console logs',
      );
      return;
    }
    AppToast.show(context, message: 'Sent to Sentry: $eventId');
  }

  String _tierLabel(String tier) {
    if (tier.isEmpty || tier == 'gated') return 'Free';
    return '${tier[0].toUpperCase()}${tier.substring(1)}';
  }

  String _shortUserId({
    required String id,
    required String name,
    String? shortId,
  }) {
    if (shortId != null && shortId.isNotEmpty) {
      return shortId.toUpperCase();
    }
    final namePart = name.isNotEmpty
        ? name.substring(0, name.length.clamp(0, 4))
        : 'user';
    final idPart = id.isNotEmpty
        ? id.substring(0, id.length.clamp(0, 4))
        : '----';
    return '${namePart.toUpperCase()}-${idPart.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeScope.of(context);
    final auth = AuthScope.of(context);
    final isDark =
        themeController.mode == ThemeMode.dark ||
        (themeController.mode == ThemeMode.system &&
            Theme.of(context).brightness == Brightness.dark);
    final tier = auth.profileMeta?.tier ?? 'gated';
    final needsVerify = !isVerifiedTier(tier);
    final photoUrl = auth.profileMeta?.photoUrl;
    final pendingPhoto = BackgroundPhotoUpload.instance.hasPendingUpload
        ? BackgroundPhotoUpload.instance.photoPath
        : null;
    final isPaused = auth.user?.accountStatus == 'paused';
    final muted = AppColors.textSecondaryOf(context);

    return AppScaffold(
      title: 'Fairytrail Profile',
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 110),
            children: [
              if (auth.user != null)
                _Group(
                  children: [
                    _HeaderRow(
                      name: auth.user!.name.isNotEmpty
                          ? auth.user!.name
                          : 'User',
                      photoUrl: photoUrl,
                      blurHash: auth.profileMeta?.photoBlurHash,
                      pendingLocalPath: pendingPhoto,
                      isVerified: isVerifiedTier(tier),
                      isPaused: isPaused,
                      kindness: auth.profileMeta?.totalKindness ?? 0,
                      trailMoney: auth.profileMeta?.totalTravelMoney ?? 0,
                      onTap: _openProfilePreview,
                    ),
                  ],
                ),

              _SectionHeader('Profile'),
              _Group(
                children: [
                  if (needsVerify)
                    _Row(
                      title: 'Verify',
                      value: 'Get a badge',
                      onTap: () =>
                          VerificationScreen.open(context, from: 'profile'),
                    ),
                  _Row(title: 'Preview & edit', onTap: _openEditProfile),
                  _ProfileStrengthRow(
                    strength: _profileStrength,
                    onTap: _openEditProfile,
                  ),
                  _PhotoEpicnessRow(
                    score: auth.profileMeta?.photoEpicnessScore,
                    unlocked: auth.profileMeta?.isTruthSerumPurchased ?? false,
                    onReveal: () => TruthSerumScreen.open(context),
                  ),
                ],
              ),

              _SectionHeader('Manage'),
              _Group(
                children: [
                  _Row(
                    title: 'Postcards & travel map',
                    onTap: () => openTrailBook(context),
                  ),
                  _Row(
                    title: 'Filters',
                    onTap: () => SearchPrefsScreen.open(context),
                  ),
                  if (tier == tierGold)
                    _Row(
                      title: 'Subscription',
                      value: _tierLabel(tier),
                      onTap: () => UpgradeScreen.open(
                        context,
                        reason: 'subscription',
                        from: 'profile',
                      ),
                    )
                  else
                    _SubscriptionPromoRow(
                      tierLabel: _tierLabel(tier),
                      onManage: () => UpgradeScreen.open(
                        context,
                        reason: isPaidTier(tier)
                            ? 'subscription'
                            : 'profile_upgrade',
                        from: 'profile',
                      ),
                      onUpgrade: () => UpgradeScreen.open(
                        context,
                        reason: 'profile_upgrade',
                        from: 'profile',
                        preferredTier: tier == tierSilver
                            ? tierGold
                            : tierSilver,
                      ),
                    ),
                  _SwitchRow(
                    title: 'Find trail treasures',
                    value: _findTrailItemsEnabled,
                    onChanged: _setFindTrailItemsEnabled,
                  ),
                  _Row(
                    title: 'Email updates',
                    onTap: () => MarketingEmailsScreen.open(context),
                  ),
                  _Row(
                    title: 'Notifications',
                    onTap: _openNotificationPreferences,
                  ),
                  _Row(
                    title: 'Account',
                    value: isPaused ? 'Paused' : null,
                    onTap: () => AccountScreen.open(context),
                  ),
                  // _Row(
                  //   title: 'Login on desktop',
                  //   onTap: () => WebLoginScreen.open(context),
                  // ),
                  _SwitchRow(
                    title: 'Dark mode',
                    value: isDark,
                    onChanged: themeController.toggleDark,
                  ),
                ],
              ),

              _SectionHeader('Travel'),
              _Group(
                children: [
                  // _Row(
                  //   title: 'Search hotels',
                  //   isExternal: true,
                  //   onTap: () => _openUrl(
                  //     'https://www.awin1.com/cread.php?awinmid=6776&awinaffid=2023607',
                  //   ),
                  // ),
                  _Row(
                    title: 'Use trail money',
                    isExternal: true,
                    onTap: _openGiftShop,
                  ),
                  _Row(
                    title: 'Add trail money',
                    onTap: () => AddTrailMoneyScreen.open(context),
                  ),
                  _Row(
                    title: 'Find tours & experiences',
                    isExternal: true,
                    onTap: () => _openUrl(
                      'https://www.getyourguide.com?partner_id=2V7RFV7&utm_medium=platforms_and_communities',
                    ),
                  ),
                  _Row(
                    title: 'Get insurance',
                    isExternal: true,
                    onTap: () => _openUrl(
                      'https://safetywing.com/?referenceID=26285232&utm_source=26285232&utm_medium=Ambassador',
                    ),
                  ),
                  _Row(
                    title: 'Save up to 22% on tax',
                    value: 'Code: fairytrail',
                    isExternal: true,
                    onTap: () => _openUrl('https://savvynomad.io/?ref=taige75'),
                  ),
                  // _Row(
                  //   title: 'Get eSIM',
                  //   value: '5% off',
                  //   isExternal: true,
                  //   onTap: () => _openUrl(
                  //     'https://www.getroamify.com?referrer=6n554iFbYVb9ZyCp45qVkmz3Gnn1&utm_source=fairytrail&utm_medium=affiliate&utm_campaign=fairytrail_offer&utm_term=exclusive_deal&discount_code=TRAIL',
                  //   ),
                  // ),
                ],
              ),

              _SectionHeader('Community'),
              _Group(
                children: [
                  _Row(
                    title: 'Exclusive deals',
                    isExternal: true,
                    onTap: () =>
                        _openUrl('https://www.fairytrail.app/nomad-deals.html'),
                  ),
                  _Row(
                    title: 'Fairytrail blog',
                    isExternal: true,
                    onTap: () => _openUrl('https://www.fairytrail.app/blog/'),
                  ),
                  _Row(
                    title: 'Facebook group',
                    isExternal: true,
                    onTap: () => _openUrl(
                      'https://www.facebook.com/groups/campfirebyfairytrail/',
                    ),
                  ),
                  _Row(
                    title: 'YouTube',
                    isExternal: true,
                    onTap: () => _openUrl(
                      'https://www.youtube.com/channel/UCKdojQjL76D3NPA3DmOCFbw/videos',
                    ),
                  ),
                  _Row(
                    title: 'TikTok',
                    isExternal: true,
                    onTap: () =>
                        _openUrl('https://www.tiktok.com/@fairytrailapp'),
                  ),
                  _Row(
                    title: 'Instagram',
                    isExternal: true,
                    onTap: () =>
                        _openUrl('https://www.instagram.com/fairytrailapp/'),
                  ),
                ],
              ),

              _SectionHeader('Fairytrail'),
              _Group(
                children: [
                  _Row(
                    title: 'How it works',
                    isExternal: true,
                    onTap: () => _openUrl('https://youtu.be/kcEDmtY9x5A'),
                  ),
                  _Row(
                    title: "Open jobs",
                    isExternal: true,
                    onTap: () =>
                        _openUrl('https://www.fairytrail.app/jobs.html'),
                  ),
                  _Row(
                    title: 'Help & contact',
                    isExternal: true,
                    onTap: () => _openUrl('https://www.fairytrail.app/support'),
                  ),
                  _Row(
                    title: 'Give feedback',
                    isExternal: true,
                    onTap: () =>
                        _openUrl('https://www.fairytrail.app/feedback.html'),
                  ),
                  _Row(
                    title: 'Privacy policy',
                    isExternal: true,
                    onTap: () => _openUrl(
                      'https://www.fairytrail.app/terms.html#privacy',
                    ),
                  ),
                  _Row(
                    title: 'Terms of service',
                    isExternal: true,
                    onTap: () =>
                        _openUrl('https://www.fairytrail.app/terms.html'),
                  ),
                  _Row(title: 'Leave review', isExternal: true, onTap: _rateUs),
                ],
              ),

              const SizedBox(height: 24),
              _Group(
                children: [
                  _Row(title: 'Log out', isDestructive: true, onTap: _logout),
                ],
              ),

              // const SizedBox(height: 24),
              // _Group(
              //   children: [
              //     _Row(
              //       title: 'Send Sentry test error',
              //       isDestructive: true,
              //       onTap: _crashForSentry,
              //     ),
              //   ],
              // ),
              const SizedBox(height: 32),
              if (auth.user?.email.isNotEmpty == true) ...[
                AppText(
                  auth.user!.email,
                  variant: AppTextVariant.caption,
                  color: muted,
                  textAlign: TextAlign.center,
                  fontSize: 11,
                ),
                const SizedBox(height: 2),
              ],
              const SizedBox(height: 2),
              if (auth.user != null)
                AppText(
                  'UserID: ${_shortUserId(id: auth.user!.id, name: auth.user!.name, shortId: auth.user!.shortId)}',
                  variant: AppTextVariant.caption,
                  color: muted,
                  textAlign: TextAlign.center,
                  fontSize: 11,
                ),
              AppText(
                'Version: ${AppVersionInfo.version}',
                variant: AppTextVariant.caption,
                color: muted,
                textAlign: TextAlign.center,
                fontSize: 11,
              ),
              const SizedBox(height: 20),
              AppText(
                '🍃',
                variant: AppTextVariant.caption,
                color: muted,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: AppText(
                  'Friends and community, wherever you are.',
                  variant: AppTextVariant.bodySmall,
                  color: muted,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          if (_loggingOut)
            const Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: AppLoading(message: 'Logging out…'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Uppercase group label — the only element that breaks the list rhythm.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 26, 32, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: AppColors.textSecondaryOf(context),
        ),
      ),
    );
  }
}

/// Rounded surface block holding rows separated by inset hairlines.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.07),
            ),
          ),
        );
      }
      rows.add(children[i]);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(children: rows),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.onTap,
    this.value,
    this.isExternal = false,
    this.isDestructive = false,
  });

  final String title;
  final String? value;
  final VoidCallback onTap;
  final bool isExternal;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textSecondaryOf(context);
    final titleColor = isDestructive
        ? const Color(0xFFE0483C)
        : AppColors.textPrimaryOf(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 15, 16, 15),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                  color: titleColor,
                ),
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  value!,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
              ),
            if (!isDestructive)
              Icon(
                isExternal
                    ? Icons.north_east_rounded
                    : Icons.chevron_right_rounded,
                size: isExternal ? 15 : 20,
                color: muted.withValues(alpha: 0.7),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStrengthRow extends StatelessWidget {
  const _ProfileStrengthRow({required this.strength, required this.onTap});

  final int strength;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.textPrimaryOf(context);
    final secondary = AppColors.textSecondaryOf(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 13, 16, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Profile strength',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      color: primary,
                    ),
                  ),
                ),
                Text(
                  '$strength%',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    color: primary,
                  ),
                ),
              ],
            ),
            if (strength < 100) ...[
              const SizedBox(height: 4),
              Text(
                'Complete your profile to get to 100%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: secondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Photo Epicness row — shows score when unlocked, or Reveal CTA when locked.
class _PhotoEpicnessRow extends StatelessWidget {
  const _PhotoEpicnessRow({
    required this.unlocked,
    required this.onReveal,
    this.score,
  });

  final bool unlocked;
  final String? score;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF2F53);
    final title = unlocked && score != null ? 'Aura' : 'Aura';

    final row = Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        unlocked ? 15 : 10,
        16,
        unlocked ? 15 : 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
          ),
          if (unlocked && score != null)
            Text(
              score!,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
          if (!unlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Reveal',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
            ),
        ],
      ),
    );

    if (unlocked) return row;

    return InkWell(onTap: onReveal, child: row);
  }
}

/// Subscription row with Upgrade CTA for gated / free / silver.
/// Layout: `Subscription          [Upgrade] Free >`
class _SubscriptionPromoRow extends StatelessWidget {
  const _SubscriptionPromoRow({
    required this.tierLabel,
    required this.onManage,
    required this.onUpgrade,
  });

  final String tierLabel;
  final VoidCallback onManage;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textSecondaryOf(context);
    const accent = Color(0xFFFF2F53);

    return InkWell(
      onTap: onManage,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 16, 10),
        child: Row(
          children: [
            Text(
              'Subscription',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const Spacer(),
            Material(
              color: accent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onUpgrade,
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    'Upgrade',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              tierLabel,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: muted,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: muted.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.25,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.name,
    required this.onTap,
    this.photoUrl,
    this.blurHash,
    this.pendingLocalPath,
    this.isVerified = false,
    this.isPaused = false,
    this.kindness = 0,
    this.trailMoney = 0,
  });

  final String name;
  final VoidCallback onTap;
  final String? photoUrl;
  final String? blurHash;
  final String? pendingLocalPath;
  final bool isVerified;
  final bool isPaused;
  final int kindness;
  final double trailMoney;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textSecondaryOf(context);
    final money = trailMoney.toStringAsFixed(2);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            _ProfileAvatar(
              photoUrl: photoUrl,
              blurHash: blurHash,
              pendingLocalPath: pendingLocalPath,
              isVerified: isVerified,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Kindness: $kindness',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Trail Money: \$$money',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 7),
                  if (isPaused)
                    _Pill(label: 'Paused', color: const Color(0xFFE0483C))
                  else
                    _Pill(label: 'Preview & edit', color: AppColors.primary),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: muted.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    this.photoUrl,
    this.blurHash,
    this.pendingLocalPath,
    this.isVerified = false,
  });

  final String? photoUrl;
  final String? blurHash;
  final String? pendingLocalPath;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasNetwork = photoUrl != null && photoUrl!.isNotEmpty;
    final hasPending = pendingLocalPath != null && pendingLocalPath!.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: SizedBox(
            width: 64,
            height: 64,
            child: hasNetwork
                ? AppCachedImage(url: photoUrl!, blurHash: blurHash)
                : hasPending
                ? Image.file(
                    File(pendingLocalPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.person,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  )
                : ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
          ),
        ),
        if (isVerified)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 21,
              height: 21,
              decoration: BoxDecoration(
                color: AppColors.blue,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.surfaceOf(context),
                  width: 2,
                ),
              ),
              child: const Icon(Icons.check, size: 12, color: Colors.white),
            ),
          ),
      ],
    );
  }
}
