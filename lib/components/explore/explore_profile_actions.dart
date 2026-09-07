import 'package:fairytrail/api/explore.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/moderation/local_moderation.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// RN ExploreBottomSheet → "Block & Report", then reason picker + submit.
Future<bool> showExploreProfileActionsSheet(
  BuildContext context, {
  required int profileId,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    ctx,
                  ).colorScheme.outline.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: Colors.redAccent,
                ),
                title: const AppText(
                  'Block & report',
                  variant: AppTextVariant.label,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: Colors.redAccent,
                ),
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.block_outlined,
                  color: Colors.redAccent,
                ),
                title: const AppText(
                  'Block only',
                  variant: AppTextVariant.label,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: Colors.redAccent,
                ),
                onTap: () => Navigator.pop(ctx, 'block'),
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
      );
    },
  );

  if (!context.mounted) return false;
  if (action == 'report') {
    return showReportProfileSheet(context, profileId: profileId);
  }
  if (action == 'block') {
    return blockProfileOnly(context, profileId: profileId);
  }
  return false;
}

Future<bool> blockProfileOnly(
  BuildContext context, {
  required int profileId,
}) async {
  final confirmed = await AppDialog.confirm(
    context,
    title: 'Block this user?',
    message: "You won't see each other or be able to interact.",
    confirmLabel: 'Block',
  );
  if (!confirmed || !context.mounted) return false;

  try {
    await reportProfile(
      profileId: profileId,
      reason: 'other',
      description: 'Blocked without reporting',
      blockOnly: true,
    );
    await LocalModeration.instance.blockProfile(profileId);
    if (context.mounted) {
      AppToast.show(context, message: 'User blocked');
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      AppToast.show(context, message: serverErrorText(e));
    }
    return false;
  }
}

Future<bool> showReportProfileSheet(
  BuildContext context, {
  required int profileId,
}) async {
  final reason = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      const reasons = <(String, String, IconData)>[
        ('distasteful', 'Distasteful', Icons.sentiment_dissatisfied_outlined),
        ('fake', 'Fake or scam', Icons.gpp_bad_outlined),
        ('other', 'Other', Icons.more_horiz),
      ];
      return AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
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
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: AppText("What's wrong?", variant: AppTextVariant.title),
              ),
              for (final r in reasons)
                ListTile(
                  leading: Icon(r.$3, color: AppColors.primary),
                  title: AppText(
                    r.$2,
                    variant: AppTextVariant.label,
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                  onTap: () => Navigator.pop(ctx, r.$1),
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
      );
    },
  );

  if (reason == null || !context.mounted) return false;

  final detail = await showDialog<String>(
    context: context,
    builder: (ctx) => _ReportDetailDialog(reason: reason),
  );

  if (detail == null || !context.mounted) return false;

  try {
    await reportProfile(
      profileId: profileId,
      reason: reason,
      description: detail,
    );
    await LocalModeration.instance.blockProfile(profileId);
    if (context.mounted) {
      AppToast.show(context, message: 'Thanks — we received your report');
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      AppToast.show(context, message: serverErrorText(e));
    }
    return false;
  }
}

class _ReportDetailDialog extends StatefulWidget {
  const _ReportDetailDialog({required this.reason});

  final String reason;

  @override
  State<_ReportDetailDialog> createState() => _ReportDetailDialogState();
}

class _ReportDetailDialogState extends State<_ReportDetailDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.length < 10) {
      AppToast.show(context, message: 'Please provide at least 10 characters');
      return;
    }
    setState(() => _submitting = true);
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const AppText('Report details', variant: AppTextVariant.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            'Please provide additional information for our human moderators',
            variant: AppTextVariant.bodySmall,
            fontSize: 13,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 4,
            autofocus: true,
            enabled: !_submitting,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'What happened?',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          isExpanded: false,
          onPressed: _submitting ? null : () => Navigator.pop(context),
        ),
        AppButton(
          label: 'Submit',
          isExpanded: false,
          onPressed: _submitting ? null : _submit,
        ),
      ],
    );
  }
}

/// Circular more button matching RN ExploreHeader ellipsis.
class ExploreMoreButton extends StatelessWidget {
  const ExploreMoreButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkBorder : const Color(0xFFE9E9E9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticsService.selection();
          onPressed();
        },
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.more_horiz,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Undo skip button matching RN ExploreHeader back/undo control.
class ExploreUndoButton extends StatelessWidget {
  const ExploreUndoButton({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled
            ? () {
                // Haptic fired in ExploreScreen._onUndoPressed (paid vs gated).
                onPressed();
              }
            : null,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: SvgPicture.asset(
              enabled
                  ? 'assets/explore/undo.svg'
                  : 'assets/explore/undo-gray.svg',
              width: 28,
              height: 28,
              colorFilter: enabled
                  ? ColorFilter.mode(
                      Theme.of(context).colorScheme.onSurface,
                      BlendMode.srcIn,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
