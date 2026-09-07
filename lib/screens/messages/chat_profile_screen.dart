import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/screens/profile/profile_view_screen.dart';
import 'package:fairytrail/screens/shell/shell_chrome.dart';
import 'package:flutter/material.dart';

/// Full profile view opened from a chat header / menu.
///
/// Thin wrapper around [ProfileViewScreen] for existing call sites.
class ChatProfileScreen extends StatelessWidget {
  const ChatProfileScreen({
    super.key,
    required this.profileId,
    this.messages,
    this.chrome,
    this.fromMatchChat = false,
  });

  final int profileId;

  /// Captured before push — chat routes sit above [MessagesScope].
  final MessagesController? messages;
  final ShellChromeController? chrome;

  /// True when opened from a 1:1 match chat — Message pops back.
  /// False for activity/meetup group chats — Message opens the DM instead.
  final bool fromMatchChat;

  /// Prefer this over pushing [ChatProfileScreen] directly so [messages] /
  /// [chrome] are captured from a context that still has the scopes.
  static Future<void> open(
    BuildContext context, {
    required int profileId,
    MessagesController? messages,
    ShellChromeController? chrome,
    bool fromMatchChat = false,
  }) {
    final resolvedMessages = messages ?? MessagesScope.maybeOf(context);
    final resolvedChrome = chrome ?? ShellChromeScope.maybeOf(context);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatProfileScreen(
          profileId: profileId,
          messages: resolvedMessages,
          chrome: resolvedChrome,
          fromMatchChat: fromMatchChat,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfileViewScreen(
      profileId: profileId,
      from: 'trailbook',
      showConnect: true,
      fromChat: fromMatchChat,
      messages: messages ?? MessagesScope.maybeOf(context),
      chrome: chrome ?? ShellChromeScope.maybeOf(context),
    );
  }
}
