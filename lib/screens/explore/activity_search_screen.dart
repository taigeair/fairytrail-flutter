import 'dart:async';

import 'package:fairytrail/activities/activities_controller.dart';
import 'package:fairytrail/api/activities.dart';
import 'package:fairytrail/api/models/activity_models.dart';
import 'package:fairytrail/bucket_list/bucket_list_controller.dart';
import 'package:fairytrail/components/activities/activity_search_grid_card.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/remote_config/remote_config_controller.dart';
import 'package:fairytrail/screens/messages/activity_chat_info_screen.dart';
import 'package:fairytrail/screens/messages/activity_chat_screen.dart';
import 'package:fairytrail/screens/shell/floating_bottom_nav.dart';
import 'package:fairytrail/screens/shell/shell_chrome.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Activity name search against `/api/v1/search/activities`.
class ActivitySearchScreen extends StatefulWidget {
  const ActivitySearchScreen({
    super.key,
    required this.controller,
    this.messages,
    this.shellChrome,
  });

  final ActivitiesController controller;

  /// Captured before push — this route sits above [MessagesScope].
  final MessagesController? messages;

  /// Captured before push — this route sits above [ShellChromeScope].
  final ShellChromeController? shellChrome;

  static Future<void> open(
    BuildContext context, {
    required ActivitiesController controller,
  }) {
    final messages = MessagesScope.maybeOf(context);
    final shellChrome = ShellChromeScope.maybeOf(context);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActivitySearchScreen(
          controller: controller,
          messages: messages,
          shellChrome: shellChrome,
        ),
      ),
    );
  }

  @override
  State<ActivitySearchScreen> createState() => _ActivitySearchScreenState();
}

class _ActivitySearchScreenState extends State<ActivitySearchScreen> {
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  String _query = '';

  /// When true, search runs only on Search/OK submit; false debounces on type.
  /// Sourced from remote config (`activity_search_on_submit`).
  bool _searchOnSubmit = false;

  /// Last query that actually hit the API (submit mode: may lag behind [_query]).
  String _searchedQuery = '';
  List<ActivityDto> _results = const [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int? _lastExplorerCount;
  int? _lastId;
  String? _error;
  int _searchGen = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _searchOnSubmit =
        RemoteConfigScope.maybeOf(context)?.activitySearchOnSubmit ?? false;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      unawaited(_loadMore());
    }
  }

  void _clearResults() {
    _searchedQuery = '';
    _results = const [];
    _loading = false;
    _loadingMore = false;
    _hasMore = false;
    _lastExplorerCount = null;
    _lastId = null;
    _error = null;
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (_searchOnSubmit) {
      setState(() {
        _query = value;
        // Drop stale results while editing; next Search/OK runs a fresh query.
        if (trimmed.isEmpty || trimmed != _searchedQuery) {
          _clearResults();
        }
      });
      return;
    }

    setState(() => _query = value);
    if (trimmed.isEmpty) {
      setState(_clearResults);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 340), () {
      unawaited(_search(trimmed));
    });
  }

  void _onQuerySubmitted(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    setState(() => _query = value);
    if (trimmed.isEmpty) {
      setState(_clearResults);
      return;
    }
    unawaited(_search(trimmed));
  }

  Future<void> _search(String q) async {
    unawaited(track('search_bucket_list_activity', {'bucketlist_query': q}));
    final gen = ++_searchGen;
    setState(() {
      _searchedQuery = q;
      _loading = true;
      _error = null;
      _hasMore = false;
      _lastExplorerCount = null;
      _lastId = null;
    });

    try {
      final page = await searchActivities(q: q);
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _results = page.activities;
        _lastExplorerCount = page.lastExplorerCount;
        _lastId = page.lastId;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _loading = false;
        _error = serverErrorText(e);
        _results = const [];
      });
    }
  }

  Future<void> _loadMore() async {
    final q = _query.trim();
    if (q.isEmpty ||
        _loadingMore ||
        !_hasMore ||
        _lastId == null ||
        _lastExplorerCount == null) {
      return;
    }
    setState(() => _loadingMore = true);
    final gen = _searchGen;
    try {
      final page = await searchActivities(
        q: q,
        lastExplorerCount: _lastExplorerCount,
        lastId: _lastId,
      );
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _results = [..._results, ...page.activities];
        _lastExplorerCount = page.lastExplorerCount;
        _lastId = page.lastId;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || gen != _searchGen) return;
      setState(() => _loadingMore = false);
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  Future<void> _joinChat(ActivityDto activity) async {
    final messages = widget.messages;
    if (messages == null) {
      AppToast.show(context, message: 'Messages unavailable');
      return;
    }
    widget.shellChrome?.selectTab(AppTab.messages);
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

  Future<void> _onSave(ActivityDto activity) async {
    HapticsService.selection();
    await saveActivity(activity.id);
    BucketListController.markStale();
    widget.controller.syncLocalSave(activity.id, true);
    if (!mounted) return;
    setState(() {
      _results = [
        for (final a in _results)
          if (a.id == activity.id)
            a.copyWith(isSaved: true, explorerCount: a.explorerCount + 1)
          else
            a,
      ];
    });
  }

  Future<void> _openActivityInfo(ActivityDto activity) async {
    HapticsService.selection();
    final heroTag = 'activity-search-image-${activity.id}';
    final latest = _results.firstWhere(
      (a) => a.id == activity.id,
      orElse: () => activity,
    );
    await ActivityChatInfoScreen.openActivity(
      context,
      activity: latest,
      controller: widget.messages,
      onJoinChat: () => _joinChat(latest),
      onSave: latest.isSaved ? null : () => _onSave(latest),
      heroTag: heroTag,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.trim().isNotEmpty;

    return AppScaffold(
      title: 'Search activities',
      padding: EdgeInsets.zero,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: AppTextField(
              controller: _queryController,
              hint: 'Iceland, safari, turtles, ...',
              autofocus: true,
              textInputAction: TextInputAction.search,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: hasQuery
                  ? IconButton(
                      tooltip: 'Clear',
                      onPressed: () {
                        _debounce?.cancel();
                        _queryController.clear();
                        _onQueryChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    )
                  : null,
              onChanged: _onQueryChanged,
              onSubmitted: _onQuerySubmitted,
            ),
          ),
          Expanded(child: _buildBody(hasQuery)),
        ],
      ),
    );
  }

  Widget _buildBody(bool hasQuery) {
    final awaitingSubmit = _searchOnSubmit && _searchedQuery.trim().isEmpty;
    if (!hasQuery || awaitingSubmit) {
      return AppEmptyView(
        title: 'Search by activity name',
        subtitle: _searchOnSubmit
            ? 'Type a word, then tap Search on the keyboard'
            : 'Try “Safari”, “hot springs”, or anything on a bucket list',
        icon: Icons.search_rounded,
      );
    }
    if (_loading && _results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null && _results.isEmpty) {
      return AppEmptyView(
        title: "Couldn't search",
        subtitle: _error,
        icon: Icons.wifi_off_outlined,
        actionLabel: 'Retry',
        onAction: () => _search(_query.trim()),
      );
    }
    if (_results.isEmpty) {
      return const AppEmptyView(
        title: 'No matches',
        subtitle: 'Try a different activity name.',
        icon: Icons.search_off_rounded,
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: _results.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _results.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
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
        final activity = _results[index];
        final heroTag = 'activity-search-image-${activity.id}';
        return ActivitySearchGridCard(
          title: activity.displayTitle,
          imageUrl: activity.photo.url,
          savedCount: activity.explorerCount,
          avatars: activity.avatars,
          heroTag: heroTag,
          onTap: () => _openActivityInfo(activity),
        );
      },
    );
  }
}
