import 'package:fairytrail/api/models/trail_book_models.dart';
import 'package:fairytrail/api/trail_book.dart';
import 'package:fairytrail/components/explore/explore_profile_actions.dart';
import 'package:fairytrail/components/trail_book/trail_book_postcard_card.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/screens/profile/profile_view_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/trail_book/postcard_share.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Result when leaving the postcard detail screen.
enum PostcardDetailResult { deleted, reported }

/// Full postcard detail with hero transition and minimal actions.
class PostcardDetailScreen extends StatefulWidget {
  const PostcardDetailScreen({
    super.key,
    required this.item,
    required this.heroTag,
  });

  final TrailBookItemDto item;
  final Object heroTag;

  static Future<PostcardDetailResult?> open(
    BuildContext context, {
    required TrailBookItemDto item,
  }) {
    final tag = 'trailbook-postcard-${item.id}';
    return Navigator.of(context).push<PostcardDetailResult>(
      PageRouteBuilder<PostcardDetailResult>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) {
          return PostcardDetailScreen(item: item, heroTag: tag);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(opacity: fade, child: child);
        },
      ),
    );
  }

  @override
  State<PostcardDetailScreen> createState() => _PostcardDetailScreenState();
}

class _PostcardDetailScreenState extends State<PostcardDetailScreen> {
  final _postcardKey = GlobalKey();
  bool _sharing = false;
  bool _saving = false;

  TrailBookItemDto get item => widget.item;

  bool get _canViewProfile =>
      !(item.isAnonymous ||
          item.isSenderDeleted ||
          item.isSenderReported ||
          item.isSenderUnmatched);

  Future<void> _onProfile() async {
    HapticsService.selection();
    await ProfileViewScreen.open(
      context,
      profileId: item.senderId,
      from: 'trailbook',
    );
  }

  Future<void> _onShare() async {
    if (_sharing || _saving) return;
    setState(() => _sharing = true);
    try {
      await PostcardShare.shareCapturedPostcard(
        context,
        boundaryKey: _postcardKey,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _onSave() async {
    if (_sharing || _saving) return;
    setState(() => _saving = true);
    try {
      await PostcardShare.saveCapturedPostcard(
        context,
        boundaryKey: _postcardKey,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onReport() async {
    HapticsService.selection();
    final reported = await showReportProfileSheet(
      context,
      profileId: item.senderId,
    );
    if (!reported || !mounted) return;
    try {
      await reportTrailBookItem(trailbookId: item.id, reason: 'reported');
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pop(PostcardDetailResult.reported);
    }
  }

  Future<void> _onDelete() async {
    HapticsService.selection();
    final ok = await AppDialog.confirm(
      context,
      title: 'Delete',
      message: 'Are you sure you want to delete this postcard?',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    try {
      await deleteTrailBookItem(item.id);
      if (mounted) {
        Navigator.of(context).pop(PostcardDetailResult.deleted);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: serverErrorText(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
        title: const Text('Postcard'),
        actions: [
          if (_canViewProfile)
            IconButton(
              onPressed: _onReport,
              tooltip: 'Report',
              icon: const Icon(Icons.flag_outlined, color: Colors.redAccent),
            ),
        ],
      ),
      body: AppSafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: AspectRatio(
                      aspectRatio: 0.62,
                      child: RepaintBoundary(
                        key: _postcardKey,
                        child: PostcardVisual(
                          message: item.message,
                          senderName: item.displaySenderName,
                          location: item.senderLocation,
                          date: item.createdAt,
                          scrollMessage: true,
                          heroTag: widget.heroTag,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_canViewProfile)
                    Expanded(
                      child: _DetailAction(
                        icon: Icons.person_outline,
                        label: 'View sender',
                        onTap: _sharing || _saving ? null : _onProfile,
                      ),
                    ),
                  Expanded(
                    child: _DetailAction(
                      icon: Icons.ios_share_outlined,
                      label: 'Share',
                      isLoading: _sharing,
                      onTap: _sharing || _saving ? null : _onShare,
                    ),
                  ),
                  Expanded(
                    child: _DetailAction(
                      icon: Icons.photo_library_outlined,
                      label: 'Save to Photos',
                      isLoading: _saving,
                      onTap: _sharing || _saving ? null : _onSave,
                    ),
                  ),
                  Expanded(
                    child: _DetailAction(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      onTap: _sharing || _saving ? null : _onDelete,
                    ),
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

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = AppColors.textPrimaryOf(context)
        .withValues(alpha: enabled ? 1 : 0.35);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            else
              Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: enabled ? 0.85 : 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
