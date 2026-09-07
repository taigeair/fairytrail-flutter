import 'package:fairytrail/api/activities.dart';
import 'package:fairytrail/api/models/activity_models.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Bottom sheet listing explorers who saved an activity.
///
/// Returns a profile id when the user taps View on someone else.
Future<int?> showSavedExplorersSheet(
  BuildContext context, {
  required ActivityDto activity,
}) async {
  if (_savedExplorersSheetOpen) return null;
  _savedExplorersSheetOpen = true;
  try {
    return await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      // Activity info/search share a Hero. Pushing a modal during/after that
      // flight hits `_HeroFlight.divert` → overlayEntry!.
      builder: (ctx) => HeroControllerScope.none(
        child: _SavedExplorersSheet(activity: activity),
      ),
    );
  } finally {
    _savedExplorersSheetOpen = false;
  }
}

bool _savedExplorersSheetOpen = false;

class _SavedExplorersSheet extends StatefulWidget {
  const _SavedExplorersSheet({required this.activity});

  final ActivityDto activity;

  @override
  State<_SavedExplorersSheet> createState() => _SavedExplorersSheetState();
}

class _SavedExplorersSheetState extends State<_SavedExplorersSheet> {
  final _explorers = <SavedExplorerDto>[];
  bool _loading = false;
  bool _hasMore = false;
  int? _lastId;
  bool _initialDone = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    if (more && (!_hasMore || _lastId == null)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await getActivitySavedExplorers(
        activityId: widget.activity.id,
        lastId: more ? _lastId : null,
      );
      if (!mounted) return;
      setState(() {
        if (more) {
          final seen = {for (final e in _explorers) e.id};
          for (final e in res.explorers) {
            if (!seen.contains(e.id)) _explorers.add(e);
          }
        } else {
          _explorers
            ..clear()
            ..addAll(res.explorers);
        }
        _lastId = res.lastId;
        _hasMore = res.hasMore;
        _initialDone = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = serverErrorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<SavedExplorerDto> _displayList(BuildContext context) {
    final auth = AuthScope.of(context);
    final meta = auth.profileMeta;
    final user = auth.user;
    if (widget.activity.isSaved && meta != null && user != null) {
      final me = SavedExplorerDto(
        id: meta.id,
        name: user.name,
        previewUrl: meta.photoUrl,
        blurHash: meta.photoBlurHash,
        accountStatus: user.accountStatus,
      );
      return [me, ..._explorers.where((e) => e.id != meta.id)];
    }
    return _explorers;
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final myId = auth.profileMeta?.id;
    final list = _displayList(context);
    final height = MediaQuery.sizeOf(context).height * 0.55;

    return AppSafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: AppText(
                'Who wants to go?',
                variant: AppTextVariant.title,
                fontWeight: FontWeight.w700,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: AppText(
                'Explorers with this on their bucket list',
                variant: AppTextVariant.caption,
                textAlign: TextAlign.center,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppText(
                  _error!,
                  variant: AppTextVariant.bodySmall,
                  color: AppColors.primary,
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels >= n.metrics.maxScrollExtent - 80 &&
                      _initialDone &&
                      _hasMore &&
                      !_loading) {
                    _load(more: true);
                  }
                  return false;
                },
                child: list.isEmpty && _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount:
                            list.length + (_loading && _initialDone ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= list.length) {
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            );
                          }
                          final explorer = list[index];
                          final isMe = myId != null && explorer.id == myId;
                          final restricted = explorer.isRestricted;
                          final canOpen = !isMe && !restricted;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            onTap: canOpen
                                ? () => Navigator.of(context).pop(explorer.id)
                                : null,
                            leading: ClipOval(
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: restricted
                                    ? Image.asset(
                                        'assets/profile/profile_placeholder.png',
                                        fit: BoxFit.cover,
                                      )
                                    : (explorer.displayPhotoUrl != null &&
                                          explorer.displayPhotoUrl!.isNotEmpty)
                                    ? AppCachedImage(
                                        url: explorer.displayPhotoUrl!,
                                        blurHash: explorer.blurHash,
                                      )
                                    : ColoredBox(
                                        color: AppColors.chipTagBgOf(context),
                                        child: const Icon(
                                          Icons.person,
                                          size: 20,
                                        ),
                                      ),
                              ),
                            ),
                            title: AppText(
                              isMe && !restricted
                                  ? 'You'
                                  : explorer.displayName,
                              variant: AppTextVariant.label,
                              fontWeight: FontWeight.w700,
                              maxLines: 1,
                            ),
                            trailing: !canOpen
                                ? null
                                : SizedBox(
                                    height: 32,
                                    child: FilledButton(
                                      onPressed: () => Navigator.of(
                                        context,
                                      ).pop(explorer.id),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'View',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
