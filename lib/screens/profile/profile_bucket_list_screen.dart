import 'dart:async';

import 'package:fairytrail/api/activities.dart';
import 'package:fairytrail/api/models/activity_models.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/bucket_list/bucket_list_controller.dart';
import 'package:fairytrail/components/bucket_list/bucket_list_row.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/screens/messages/activity_chat_screen.dart';
import 'package:fairytrail/screens/shell/floating_bottom_nav.dart';
import 'package:fairytrail/screens/shell/shell_chrome.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Read-only bucket list reached from another traveler's profile.
class ProfileBucketListScreen extends StatefulWidget {
  const ProfileBucketListScreen({
    super.key,
    required this.profileId,
    required this.profileName,
    required this.activities,
    this.messages,
    this.chrome,
  });

  final int profileId;
  final String profileName;
  final List<ActivityDto> activities;
  final MessagesController? messages;
  final ShellChromeController? chrome;

  static Future<void> open(
    BuildContext context, {
    required int profileId,
    required String profileName,
    required List<ActivityDto> activities,
    MessagesController? messages,
    ShellChromeController? chrome,
  }) {
    // Prefer callers' captured controllers — this route often sits above
    // [MessagesScope] / [ShellChromeScope] (e.g. profile view).
    final resolvedMessages = messages ?? MessagesScope.maybeOf(context);
    final resolvedChrome = chrome ?? ShellChromeScope.maybeOf(context);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileBucketListScreen(
          profileId: profileId,
          profileName: profileName,
          activities: activities,
          messages: resolvedMessages,
          chrome: resolvedChrome,
        ),
      ),
    );
  }

  @override
  State<ProfileBucketListScreen> createState() =>
      _ProfileBucketListScreenState();
}

class _ProfileBucketListScreenState extends State<ProfileBucketListScreen> {
  bool _busy = false;

  /// IDs from *my* bucket list only — never trust profile-activities `isSaved`
  /// (API historically marked every item on the viewed list as saved).
  Set<int> _savedActivityIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadOwnSavedIds());
    });
  }

  Future<void> _loadOwnSavedIds() async {
    final ownProfileId = AuthScope.of(context).profileMeta?.id;
    if (ownProfileId == null || ownProfileId <= 0) return;
    try {
      final mine = await getProfileActivities(ownProfileId);
      if (!mounted) return;
      setState(() {
        _savedActivityIds = {for (final a in mine) a.id};
      });
    } catch (_) {
      // Sheet still works; "Already…" simply won't show until we know.
    }
  }

  Future<void> _onActivityTap(ActivityDto activity) async {
    final ownProfileId = AuthScope.of(context).profileMeta?.id;
    if (ownProfileId == widget.profileId) return;

    final alreadySaved = _savedActivityIds.contains(activity.id);

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    ctx,
                  ).colorScheme.outline.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                enabled: !alreadySaved,
                leading: Icon(
                  alreadySaved
                      ? Icons.bookmark_added
                      : Icons.bookmark_add_outlined,
                ),
                title: AppText(
                  alreadySaved
                      ? 'Already in your bucket list'
                      : 'Add to my bucket list',
                  variant: AppTextVariant.label,
                  fontWeight: FontWeight.w600,
                ),
                onTap: alreadySaved
                    ? null
                    : () => Navigator.pop(ctx, 'save'),
              ),
              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: const AppText(
                  'Join activity chat',
                  variant: AppTextVariant.label,
                  fontWeight: FontWeight.w600,
                ),
                onTap: () => Navigator.pop(ctx, 'chat'),
              ),
              ListTile(
                title: AppText(
                  'Cancel',
                  variant: AppTextVariant.label,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: AppColors.textSecondaryOf(ctx),
                ),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null || _busy) return;

    if (action == 'save') {
      setState(() => _busy = true);
      try {
        await saveActivity(activity.id);
        BucketListController.markStale();
        if (mounted) {
          setState(() => _savedActivityIds.add(activity.id));
          AppToast.show(
            context,
            message: '${activity.name} has been added to your bucket list',
          );
        }
      } catch (e) {
        if (mounted) AppToast.show(context, message: serverErrorText(e));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    final messages = widget.messages;
    if (messages == null) {
      AppToast.show(context, message: 'Messages unavailable');
      return;
    }
    widget.chrome?.selectTab(AppTab.messages);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActivityChatScreen(
          controller: messages,
          activityId: activity.id,
          previewActivity: activity,
        ),
      ),
    );
    messages.closeThread();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.profileName}'s Fairytrail Bucket List"),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: widget.activities.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final activity = widget.activities[index];
          return BucketListRow(
            activity: activity,
            completed: activity.tag == BucketListActivityTag.completed,
            onTap: _busy ? null : () => _onActivityTap(activity),
          );
        },
      ),
    );
  }
}
