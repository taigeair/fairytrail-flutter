import 'dart:async';

import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/components/explore/photo_issue_sheet.dart';
import 'package:fairytrail/components/messages/conversation_tile.dart';
import 'package:fairytrail/config/signup_options.dart';
import 'package:fairytrail/constants/blur_hash.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/messages/incoming_connects_controller.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/push/notification_router.dart';
import 'package:fairytrail/screens/explore/connected_screen.dart';
import 'package:fairytrail/screens/profile/notifications_settings_screen.dart';
import 'package:fairytrail/screens/profile/profile_view_screen.dart';
import 'package:fairytrail/screens/shell/floating_bottom_nav.dart';
import 'package:fairytrail/screens/shell/shell_chrome.dart';
import 'package:fairytrail/screens/verification/verification_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Paid Reveal screen — list of everyone waiting to connect.
///
/// Controllers are passed in because this route is pushed on the root navigator
/// and sits outside [IncomingConnectsScope] / [MessagesScope].
class RevealScreen extends StatefulWidget {
  const RevealScreen({
    super.key,
    required this.incoming,
    this.messages,
    this.chrome,
  });

  final IncomingConnectsController incoming;
  final MessagesController? messages;
  final ShellChromeController? chrome;

  static Future<void> open(BuildContext context) {
    final incoming = IncomingConnectsScope.of(context);
    final messages = MessagesScope.maybeOf(context);
    final chrome = ShellChromeScope.maybeOf(context);
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RevealScreen(
          incoming: incoming,
          messages: messages,
          chrome: chrome,
        ),
      ),
    );
  }

  @override
  State<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<RevealScreen> {
  IncomingConnectsController get _incoming => widget.incoming;

  @override
  void initState() {
    super.initState();
    _incoming.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _incoming.loadRevealList(force: true);
    });
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _incoming.removeListener(_onChanged);
    // Sync Messages banner after leaving Reveal.
    _incoming.load(force: true);
    super.dispose();
  }

  Future<void> _onConnect(FullProfileDto profile) async {
    if (_incoming.isBusy(profile.id)) return;
    HapticsService.selection();

    try {
      final result = await _incoming.accept(profile);
      if (!mounted || result == null) return;

      EnableNotificationsScreen.openIfNeeded(context, from: 'first_connect');

      if (result.isMatch) {
        HapticsService.success();
        unawaited(LocalStorage.instance.markHasMatch());
        // Prefetch matches so Send message opens instantly.
        unawaited(widget.messages?.loadInbox(silent: true));
        final messages = widget.messages;
        final chrome = widget.chrome;
        final photo = profile.photos.isNotEmpty ? profile.photos.first : null;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (ctx) => ConnectedScreen(
              profileName: profile.name,
              onLater: () => Navigator.of(ctx).pop(),
              onSendMessage: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
                if (messages == null) {
                  chrome?.selectTab(AppTab.messages);
                  return;
                }
                NotificationRouter.openMatchChat(
                  profileId: profile.id,
                  profileName: profile.name,
                  previewUrl: photo?.displayUrl,
                  blurHash: photo?.blurHash,
                  messages: messages,
                  chrome: chrome,
                );
              },
            ),
          ),
        );
      } else {
        AppToast.show(context, message: 'Connected with ${profile.name}');
      }

      if (mounted && _incoming.total == 0) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      final code = serverErrorCode(e);
      if (code == 'photo_issue') {
        showPhotoIssueSheet(context);
        return;
      }
      if (code == 'gated_limit') {
        VerificationScreen.open(context, from: 'messages');
        return;
      }
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  Future<void> _onUndo() async {
    if (_incoming.lastSkipped == null) return;
    HapticsService.selection();
    try {
      await _incoming.undoLastSkip();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  Future<void> _ignoreFromProfile(
    FullProfileDto profile,
    BuildContext profileContext,
  ) async {
    if (_incoming.isBusy(profile.id)) return;
    HapticsService.selection();
    try {
      await _incoming.ignore(profile);
      if (profileContext.mounted) Navigator.of(profileContext).pop();
    } catch (e) {
      if (!profileContext.mounted) return;
      AppToast.show(profileContext, message: serverErrorText(e));
    }
  }

  Future<void> _connectFromProfile(
    FullProfileDto profile,
    BuildContext profileContext,
  ) async {
    await _onConnect(profile);
    if (profileContext.mounted &&
        ModalRoute.of(profileContext)?.isCurrent == true) {
      Navigator.of(profileContext).pop();
    }
  }

  Future<void> _openProfile(FullProfileDto profile) async {
    HapticsService.selection();
    await ProfileViewScreen.open(
      context,
      profileId: profile.id,
      from: 'incoming',
      showConnect: false,
      onIgnore: (profileContext) => _ignoreFromProfile(profile, profileContext),
      onConnect: (profileContext) =>
          _connectFromProfile(profile, profileContext),
    );
    await _incoming.loadRevealList(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _incoming.profiles;
    final loading = _incoming.revealLoading && profiles.isEmpty;
    final canUndo = _incoming.lastSkipped != null;
    final total = _incoming.total;

    return AppScaffold(
      title: 'Reveal',
      padding: EdgeInsets.zero,
      actions: [
        IconButton(
          tooltip: 'Undo ignore',
          onPressed: canUndo ? _onUndo : null,
          icon: Icon(
            Icons.undo_rounded,
            color: canUndo
                ? AppColors.textPrimaryOf(context)
                : AppColors.textSecondaryOf(context).withValues(alpha: 0.35),
          ),
        ),
      ],
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _incoming.loadRevealList(force: true),
        child: loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 160),
                  Center(child: AppLoading()),
                ],
              )
            : profiles.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  AppEmptyView(
                    title: total > 0
                        ? 'Couldn’t load who wants to connect'
                        : 'This connect request is no longer available',
                    subtitle: total > 0
                        ? (_incoming.error ??
                              'Pull to refresh, or try again in a moment.')
                        : 'When someone wants to connect, they’ll show up here.',
                    icon: Icons.call_missed,
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 4, bottom: 40),
                itemCount: profiles.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 80,
                  color: AppColors.borderOf(context).withValues(alpha: 0.55),
                ),
                itemBuilder: (context, i) {
                  final profile = profiles[i];
                  return _RevealTile(
                    profile: profile,
                    busy: _incoming.isBusy(profile.id),
                    onTap: () => _openProfile(profile),
                    onConnect: () => _onConnect(profile),
                  );
                },
              ),
      ),
    );
  }
}

class _RevealTile extends StatelessWidget {
  const _RevealTile({
    required this.profile,
    required this.busy,
    required this.onTap,
    required this.onConnect,
  });

  final FullProfileDto profile;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final photo = profile.photos.isEmpty ? null : profile.photos.first;
    final secondary = AppColors.textSecondaryOf(context);
    final subtitleParts = <String>[
      if (profile.country?.country.isNotEmpty == true) profile.country!.country,
      labelForTravelStyle(profile.travelStyle),
      // if (profile.occupation != null && profile.occupation!.trim().isNotEmpty)
      //   profile.occupation!.trim(),
    ];

    return InkWell(
      onTap: busy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            ChatAvatar(
              url: photo?.displayUrl,
              blurHash: effectiveBlurHash(photo?.blurHash),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    profile.name,
                    variant: AppTextVariant.label,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitleParts.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    AppText(
                      subtitleParts.join(' · '),
                      variant: AppTextVariant.body,
                      fontSize: 13,
                      color: secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: onConnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
