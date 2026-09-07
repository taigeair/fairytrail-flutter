import 'package:confetti/confetti.dart';
import 'package:fairytrail/activities/activity_share.dart';
import 'package:fairytrail/api/activities.dart';
import 'package:fairytrail/api/models/activity_models.dart';
import 'package:fairytrail/components/activities/saved_by_explorers_card.dart';
import 'package:fairytrail/components/activities/saved_explorers_sheet.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/screens/bucket_list/add_edit_activity_screen.dart';
import 'package:fairytrail/screens/messages/activity_chat_screen.dart';
import 'package:fairytrail/screens/profile/profile_view_screen.dart';
import 'package:fairytrail/screens/shell/floating_bottom_nav.dart';
import 'package:fairytrail/screens/shell/shell_chrome.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ActivityDetailsScreen extends StatefulWidget {
  const ActivityDetailsScreen({
    super.key,
    required this.activity,
    this.messages,
    this.openSavedList = false,
  });

  final ActivityDto activity;
  final MessagesController? messages;

  /// When true, opens the Saved explorers sheet after the screen loads
  /// (e.g. `activity_saved` push notification).
  final bool openSavedList;

  static Future<bool?> open(
    BuildContext context,
    ActivityDto activity, {
    bool openSavedList = false,
  }) {
    // Capture before push — the details route sits above [MessagesScope].
    final messages = MessagesScope.maybeOf(context);
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ActivityDetailsScreen(
          activity: activity,
          messages: messages,
          openSavedList: openSavedList,
        ),
      ),
    );
  }

  @override
  State<ActivityDetailsScreen> createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  late ActivityDto _activity;
  DateTime? _completedDate;
  bool _loading = true;
  bool _savingDate = false;
  bool _didAutoOpenSavedList = false;
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
    _completedDate = _parseDate(widget.activity.completedDate);
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _reload();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final fresh = await getActivity(_activity.id);
      if (!mounted) return;
      setState(() {
        _activity = fresh;
        _completedDate = _parseDate(fresh.completedDate);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
    _maybeAutoOpenSavedList();
  }

  void _maybeAutoOpenSavedList() {
    if (!widget.openSavedList || _didAutoOpenSavedList || !mounted) return;
    _didAutoOpenSavedList = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openSavedExplorers();
    });
  }

  Future<void> _openChat() async {
    final messages = widget.messages ?? MessagesScope.maybeOf(context);
    if (messages == null) {
      AppToast.show(context, message: 'Messages unavailable');
      return;
    }
    ShellChromeScope.maybeOf(context)?.selectTab(AppTab.messages);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActivityChatScreen(
          controller: messages,
          activityId: _activity.id,
          previewActivity: _activity,
        ),
      ),
    );
    messages.closeThread();
  }

  Future<void> _openSavedExplorers() async {
    final profileId = await showSavedExplorersSheet(
      context,
      activity: _activity,
    );
    if (!mounted || profileId == null) return;
    await ProfileViewScreen.open(
      context,
      profileId: profileId,
      from: 'trailbook',
    );
  }

  Future<void> _onCompleteDate(DateTime date) async {
    final today = DateTime.now();
    final selected = DateTime(date.year, date.month, date.day);
    final now = DateTime(today.year, today.month, today.day);
    if (selected.isAfter(now)) {
      AppToast.show(
        context,
        message: 'You can only select today or past dates.',
      );
      return;
    }

    final previous = _completedDate;
    setState(() {
      _completedDate = selected;
      _savingDate = true;
    });
    _confetti.play();

    try {
      final iso = DateFormat('yyyy-MM-dd').format(selected);
      await completeActivity(id: _activity.id, completedDate: iso);
      if (!mounted) return;
      setState(() {
        _activity = _activity.copyWith(
          completedDate: iso,
          tag: BucketListActivityTag.completed,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _completedDate = previous);
      AppToast.show(context, message: serverErrorText(e));
    } finally {
      if (mounted) setState(() => _savingDate = false);
    }
  }

  Future<void> _clearCompleteDate() async {
    final previousDate = _completedDate;
    final previousActivity = _activity;
    setState(() {
      _completedDate = null;
      _savingDate = true;
      _activity = _activity.copyWith(
        clearCompletedDate: true,
        tag: BucketListActivityTag.upcoming,
      );
    });

    try {
      await completeActivity(id: _activity.id, completedDate: null);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _completedDate = previousDate;
        _activity = previousActivity;
      });
      AppToast.show(context, message: serverErrorText(e));
    } finally {
      if (mounted) setState(() => _savingDate = false);
    }
  }

  Future<void> _onMore() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return AppSafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              if (_activity.isEditable)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const AppText(
                    'Edit',
                    variant: AppTextVariant.label,
                    fontWeight: FontWeight.w600,
                  ),
                  onTap: () => Navigator.pop(ctx, 'edit'),
                ),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: const AppText(
                  'Share activity',
                  variant: AppTextVariant.label,
                  fontWeight: FontWeight.w600,
                ),
                onTap: () => Navigator.pop(ctx, 'share'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const AppText(
                  'Remove activity',
                  variant: AppTextVariant.label,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
                onTap: () => Navigator.pop(ctx, 'remove'),
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
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'share') {
      await ActivityShare.shareActivity(context, _activity);
      return;
    }

    if (action == 'edit') {
      final updated = await AddEditActivityScreen.open(
        context,
        activity: _activity,
      );
      if (updated != null && mounted) {
        setState(() => _activity = updated);
      }
      return;
    }

    if (action == 'remove') {
      final ok = await AppDialog.confirm(
        context,
        title: 'Remove from bucket list?',
        message: 'Remove this activity from your bucket list',
        confirmLabel: 'Remove',
      );
      if (!ok || !mounted) return;
      try {
        await unsaveActivity(_activity.id);
        if (mounted) Navigator.of(context).pop(true);
      } catch (e) {
        if (mounted) AppToast.show(context, message: serverErrorText(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final imageDimension = screenSize.shortestSide >= 600
        ? screenSize.width * 0.66
        : 280.0;

    return Stack(
      children: [
        AppScaffold(
          title: 'My Fairytrail Activity',
          actions: [
            IconButton(onPressed: _onMore, icon: const Icon(Icons.more_horiz)),
          ],
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : ListView(
                  children: [
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.center,
                      child: SizedBox.square(
                        dimension: imageDimension,
                        child: AppCachedImage(
                          url: _activity.photo.url,
                          borderRadius: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppText(
                      _activity.displayTitle,
                      variant: AppTextVariant.title,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FractionallySizedBox(
                      widthFactor: 0.1,
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          color: AppColors.borderOf(context),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_completedDate != null) ...[
                      AppText(
                        'Completed date',
                        variant: AppTextVariant.body,
                        color: AppColors.textSecondaryOf(context),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],
                    AppDatePicker(
                      hint: 'Tap to mark completed',
                      value: _completedDate,
                      firstDate: DateTime(1970),
                      lastDate: DateTime.now(),
                      onChanged: _savingDate ? (_) {} : _onCompleteDate,
                      onClear: _savingDate ? null : _clearCompleteDate,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Chat',
                      icon: Icons.chat_bubble_outline,
                      onPressed: _openChat,
                    ),
                    const SizedBox(height: 16),
                    SavedByExplorersCard(
                      explorerCount: _activity.explorerCount,
                      onTap: _openSavedExplorers,
                    ),
                  ],
                ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 24,
            colors: const [
              AppColors.primary,
              AppColors.blue,
              Color(0xFFFFC107),
              Color(0xFF4CAF50),
            ],
          ),
        ),
      ],
    );
  }
}
