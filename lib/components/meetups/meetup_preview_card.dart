import 'package:fairytrail/api/models/meetup_models.dart';
import 'package:fairytrail/meetups/meetup_icons.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Bottom preview when a meetup pin is selected — compact, usable layout.
class MeetupPreviewCard extends StatelessWidget {
  const MeetupPreviewCard({
    super.key,
    required this.meetup,
    this.onJoin,
    this.onOpenChat,
    this.onClose,
    this.busy = false,
  });

  final MeetupDto meetup;
  final VoidCallback? onJoin;
  final VoidCallback? onOpenChat;
  final VoidCallback? onClose;
  final bool busy;

  VoidCallback? get _onPrimary {
    if (busy) return null;
    if (meetup.joinedByMe) return onOpenChat;
    if (meetup.isActive && !meetup.isFull) return onJoin;
    return null;
  }

  String get _primaryLabel {
    if (meetup.joinedByMe) return 'Open Chat';
    if (meetup.isActive) {
      return meetup.isFull ? 'Meetup full' : 'Join Chat';
    }
    return 'Meetup ended';
  }

  String get _hostName {
    final n = meetup.creatorName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Someone';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? Theme.of(context).colorScheme.surface
        : Colors.white;
    final muted = AppColors.textSecondaryOf(context);
    final bodyColor = AppColors.textPrimaryOf(context);
    final nameAccent = isDark
        ? const Color(0xFF7EC8F5)
        : const Color(0xFF4A9FD8);
    final going = meetup.memberCount;
    final when = _whenWithTime(meetup.startsAt.toLocal());
    final avatars = meetup.avatars.where((u) => u.isNotEmpty).take(4).toList();

    return Material(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
      color: surface,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: meetupCategoryColor(
                      meetup.category,
                    ).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    meetupCategoryEmoji(meetup.category),
                    style: const TextStyle(fontSize: 22, height: 1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              color: bodyColor,
                            ),
                            children: [
                              TextSpan(
                                text: _hostName,
                                style: TextStyle(
                                  color: nameAccent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(text: ' is hosting '),
                              TextSpan(text: meetup.name),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          when,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            color: muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  icon: Icon(Icons.close_rounded, size: 22, color: muted),
                  tooltip: 'Close',
                ),
              ],
            ),
            if (avatars.isNotEmpty || going > 0) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (avatars.isNotEmpty)
                    SizedBox(
                      height: 32,
                      width: 32.0 + (avatars.length - 1) * 18.0,
                      child: Stack(
                        children: [
                          for (var i = avatars.length - 1; i >= 0; i--)
                            Positioned(
                              left: i * 18.0,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: surface,
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: AppCachedImage(url: avatars[i]),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (avatars.isNotEmpty) const SizedBox(width: 10),
                  Text(
                    going == 1
                        ? '1 member joined'
                        : '$going members joined',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              width: double.infinity,
              child: FilledButton(
                onPressed: _onPrimary,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.35,
                  ),
                  disabledForegroundColor: AppColors.white.withValues(
                    alpha: 0.85,
                  ),
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _primaryLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// e.g. `today · 3:30 PM`, `tomorrow · 10:00 AM`, `Sat · 5:00 PM`
  static String _whenWithTime(DateTime when) {
    final time = DateFormat.jm().format(when);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(when.year, when.month, when.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'today · $time';
    if (diff == 1) return 'tomorrow · $time';
    if (diff > 1 && diff < 7) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${names[when.weekday - 1]} · $time';
    }
    return DateFormat.MMMd().add_jm().format(when);
  }
}
