import 'dart:async';

import 'package:fairytrail/api/models/chat_models.dart';
import 'package:fairytrail/api/models/meetup_models.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/components/messages/conversation_tile.dart';
import 'package:fairytrail/components/messages/incoming_connects_banner.dart';
import 'package:fairytrail/components/messages/match_country_filter_sheet.dart';
import 'package:fairytrail/components/messages/messages_filter_chips_bar.dart';
import 'package:fairytrail/constants/profile_status.dart';
import 'package:fairytrail/meetups/meetup_icons.dart';
import 'package:fairytrail/messages/incoming_connects_controller.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/screens/meetups/meetup_chat_screen.dart';
import 'package:fairytrail/screens/messages/activity_chat_screen.dart';
import 'package:fairytrail/screens/messages/match_chat_screen.dart';
import 'package:fairytrail/screens/messages/reveal_premium_notice_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _countryFilterResetScheduled = false;

  @override
  void didUpdateWidget(covariant MessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      final messages = MessagesScope.maybeOf(context);
      if (messages != null) unawaited(messages.ensureInboxStarted());
      IncomingConnectsScope.maybeOf(context)?.load(force: true);
    }
  }

  Future<void> _openMatch(MatchDto match) async {
    final controller = MessagesScope.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchChatScreen(match: match, controller: controller),
      ),
    );
    if (!mounted) return;
    controller.closeThread();
    unawaited(controller.loadInbox(silent: true));
  }

  Future<void> _openActivity(ActivityChatDto chat) async {
    final controller = MessagesScope.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActivityChatScreen(controller: controller, chat: chat),
      ),
    );
    if (!mounted) return;
    controller.closeThread();
    unawaited(controller.loadInbox(silent: true));
  }

  Future<void> _openMeetup(MeetupChatDto chat) async {
    await MeetupChatScreen.open(context, meetup: chat.meetup);
    if (!mounted) return;
    unawaited(MessagesScope.of(context).loadInbox(silent: true));
  }

  Future<void> _refresh() async {
    await Future.wait([
      MessagesScope.of(context).loadInbox(fullMatchesSync: true),
      IncomingConnectsScope.maybeOf(context)?.load(force: true) ??
          Future<void>.value(),
    ]);
  }

  Future<void> _openCountryFilter(MessagesController controller) async {
    await showMatchCountryFilterSheet(context, controller: controller);
  }

  @override
  Widget build(BuildContext context) {
    final controller = MessagesScope.of(context);
    final incoming = IncomingConnectsScope.maybeOf(context);
    final me = AuthScope.of(context).user?.id;
    final myStatus = AuthScope.of(context).profileMeta?.status;
    final isPaid = AuthScope.of(context).isPaid;

    final listenables = <Listenable>[controller];
    if (incoming != null) listenables.add(incoming);

    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) {
        if (!isPaid && controller.hasMatchCountryFilter) {
          if (!_countryFilterResetScheduled) {
            _countryFilterResetScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _countryFilterResetScheduled = false;
              controller.clearMatchCountryFilter();
            });
          }
        } else {
          _countryFilterResetScheduled = false;
        }

        final items = controller.inboxItems;
        final loading =
            controller.loadState == MessagesLoadState.loading && items.isEmpty;
        final errored =
            controller.loadState == MessagesLoadState.error && items.isEmpty;
        final filteredEmpty =
            !loading &&
            !errored &&
            items.isEmpty &&
            controller.hasMatchCountryFilter;
        final showBanner = incoming?.hasIncoming == true;
        final first = incoming?.firstProfile;

        Widget inboxBody;
        if (loading) {
          inboxBody = const Padding(
            padding: EdgeInsets.only(top: 120),
            child: Center(child: AppLoading()),
          );
        } else if (errored) {
          inboxBody = Column(
            children: [
              const SizedBox(height: 80),
              AppEmptyView(
                title: 'Couldn’t load messages',
                subtitle: controller.error ?? 'Pull to retry',
                icon: Icons.wifi_off_outlined,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: AppButton(
                  label: 'Try again',
                  onPressed: () => controller.loadInbox(),
                ),
              ),
            ],
          );
        } else if (filteredEmpty) {
          inboxBody = Padding(
            padding: const EdgeInsets.only(top: 60),
            child: AppEmptyView(
              title: 'No connections in selected country',
              subtitle: 'Try choosing another country or clear the filter.',
              icon: Icons.filter_list_off_outlined,
              actionLabel: 'Clear filter',
              onAction: controller.clearMatchCountryFilter,
            ),
          );
        } else if (items.isEmpty) {
          inboxBody = const Padding(
            padding: EdgeInsets.only(top: 60),
            child: AppEmptyView(
              title: 'No conversations yet',
              subtitle:
                  'When you connect with travelers or join group chats, they’ll show up here.',
              icon: Icons.chat_bubble_outline,
            ),
          );
        } else {
          inboxBody = const SizedBox.shrink();
        }

        return AppScaffold(
          title: 'Messages',
          padding: EdgeInsets.zero,
          extendBody: true,
          body: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4 , bottom: 8),
                    child: MessagesFilterChipsBar(
                      countryName: isPaid
                          ? controller.matchCountryFilterName
                          : null,
                      isLocked: !isPaid,
                      onOpenFilters: () => _openCountryFilter(controller),
                    ),
                  ),
                ),
                if (showBanner && first != null)
                  SliverToBoxAdapter(
                    child: IncomingConnectsBanner(
                      total: incoming!.total,
                      profile: first,
                      isSubscribed: isPaid,
                      onReveal: () => openRevealFlow(context),
                    ),
                  ),
                if (items.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: inboxBody,
                    ),
                  )
                else
                  SliverPadding(
                    // Keep the final conversation clear of the floating nav and
                    // allow it to scroll upward by roughly two full rows.
                    padding: const EdgeInsets.only(top: 4, bottom: 256),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 80,
                        color: AppColors.borderOf(
                          context,
                        ).withValues(alpha: 0.5),
                      ),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final unread = item.hasUnreadFor(me);
                        if (item.kind == InboxItemKind.match) {
                          final m = item.match!;
                          final draft = controller.draftFor(
                            MessagesController.matchDraftKey(m.id),
                          );
                          final restricted = m.profile.isRestricted;
                          return ConversationTile(
                            title: m.profile.displayName,
                            subtitle: draft ?? item.previewText ?? '',
                            time: item.sortAt,
                            unread: unread,
                            avatarUrl: m.profile.displayPhotoUrl,
                            blurHash: m.profile.displayBlurHash,
                            avatarAssetPath: restricted
                                ? 'assets/profile/profile_placeholder.png'
                                : null,
                            isDraft: draft != null,
                            onTap: () => _openMatch(m),
                          );
                        }
                        if (item.kind == InboxItemKind.meetup) {
                          final u = item.meetupChat!;
                          final lastUser = u.lastMessage?.user;
                          final hideFraudPreview =
                              lastUser?.status == ProfileStatus.fraud &&
                              myStatus != ProfileStatus.fraud;
                          var subtitle = item.previewText ?? '';
                          if (hideFraudPreview) {
                            subtitle = 'Failed to load message preview';
                          }
                          return ConversationTile(
                            title: u.meetup.name,
                            subtitle: subtitle,
                            time: item.sortAt,
                            unread: unread,
                            isGroup: true,
                            memberCount: u.memberCount,
                            badgeLabel: 'Meetup',
                            leadingEmoji: meetupCategoryEmoji(
                              u.meetup.category,
                            ),
                            onTap: () => _openMeetup(u),
                          );
                        }
                        final a = item.activityChat!;
                        final draft = controller.draftFor(
                          MessagesController.activityDraftKey(a.activity.id),
                        );
                        final lastUser = a.lastMessage?.user;
                        final hideFraudPreview =
                            lastUser?.status == ProfileStatus.fraud &&
                            myStatus != ProfileStatus.fraud;
                        var subtitle = draft ?? item.previewText ?? '';
                        if (hideFraudPreview && draft == null) {
                          subtitle = 'Failed to load message preview';
                        }
                        return ConversationTile(
                          title: a.activity.displayTitle,
                          subtitle: subtitle,
                          time: item.sortAt,
                          unread: unread,
                          avatarUrl: a.activity.photo.displayUrl,
                          isGroup: true,
                          memberCount: a.memberCount,
                          isDraft: draft != null,
                          onTap: () => _openActivity(a),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
