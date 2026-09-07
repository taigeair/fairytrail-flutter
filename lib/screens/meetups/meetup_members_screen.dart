import 'package:fairytrail/api/meetups.dart';
import 'package:fairytrail/api/models/meetup_models.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/screens/messages/chat_profile_screen.dart';
import 'package:fairytrail/screens/shell/shell_chrome.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

class MeetupMembersScreen extends StatefulWidget {
  const MeetupMembersScreen({
    super.key,
    required this.meetupId,
    required this.title,
    this.messages,
    this.chrome,
  });

  final int meetupId;
  final String title;
  final MessagesController? messages;
  final ShellChromeController? chrome;

  static Future<void> open(
    BuildContext context, {
    required int meetupId,
    required String title,
    MessagesController? messages,
    ShellChromeController? chrome,
  }) {
    // Capture before push — this route sits above [MessagesScope].
    final resolvedMessages = messages ?? MessagesScope.maybeOf(context);
    final resolvedChrome = chrome ?? ShellChromeScope.maybeOf(context);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MeetupMembersScreen(
          meetupId: meetupId,
          title: title,
          messages: resolvedMessages,
          chrome: resolvedChrome,
        ),
      ),
    );
  }

  @override
  State<MeetupMembersScreen> createState() => _MeetupMembersScreenState();
}

class _MeetupMembersScreenState extends State<MeetupMembersScreen> {
  List<MeetupMemberDto> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await fetchMeetupMembers(widget.meetupId);
      if (mounted) setState(() => _members = members);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Who’s going',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
          ? const AppEmptyView(title: 'No members yet')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _members.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final m = _members[index];
                final restricted = m.isRestricted;
                return AppCard(
                  onTap: restricted || m.profileId <= 0
                      ? null
                      : () => ChatProfileScreen.open(
                          context,
                          profileId: m.profileId,
                          messages: widget.messages,
                          chrome: widget.chrome,
                        ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.12,
                        ),
                        backgroundImage: m.displayPhotoUrl != null
                            ? NetworkImage(m.displayPhotoUrl!)
                            : null,
                        child: m.displayPhotoUrl == null
                            ? Text(
                                m.displayName.isNotEmpty
                                    ? m.displayName[0].toUpperCase()
                                    : '?',
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppText(
                          m.displayName,
                          variant: AppTextVariant.label,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!restricted)
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondaryOf(context),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
