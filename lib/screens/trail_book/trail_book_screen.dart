import 'dart:math';

import 'package:fairytrail/api/edit_profile_props.dart';
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/api/models/trail_book_models.dart';
import 'package:fairytrail/api/trail_book.dart';
import 'package:fairytrail/api/update_user_data.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/components/trail_book/postcard_info_sheet.dart';
import 'package:fairytrail/components/trail_book/trail_book_postcard_card.dart';
import 'package:fairytrail/components/trail_book/visited_countries_view.dart';
import 'package:fairytrail/config/trail_book_quotes.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/screens/trail_book/postcard_detail_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/trail_book/trail_book_memory_cache.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

class TrailBookScreen extends StatefulWidget {
  const TrailBookScreen({super.key});

  @override
  State<TrailBookScreen> createState() => _TrailBookScreenState();
}

class _TrailBookScreenState extends State<TrailBookScreen>
    with SingleTickerProviderStateMixin {
  final _items = <TrailBookItemDto>[];
  final _countries = <CountryDto>[];
  final _visitedCountryIds = <int>{};
  final _quote =
      trailBookShortQuotes[Random().nextInt(trailBookShortQuotes.length)];
  late final TabController _tabController;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _profileName;
  String? _profileMobility;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _hydrateFromMemory();
    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cachedName = AuthScope.of(context).user?.name.trim() ?? '';
    if ((_profileName == null || _profileName!.trim().isEmpty) &&
        cachedName.isNotEmpty) {
      _profileName = cachedName;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _hydrateFromMemory() {
    final cache = TrailBookMemoryCache.instance;
    if (cache.feedReady) {
      _items
        ..clear()
        ..addAll(cache.items);
      _page = cache.page;
      _hasMore = cache.hasMore;
      _loading = false;
    }
    if (cache.countriesReady) {
      _profileName = cache.profileName;
      _profileMobility = cache.profileMobility;
      _countries
        ..clear()
        ..addAll(cache.countries);
      _visitedCountryIds
        ..clear()
        ..addAll(cache.visitedCountryIds);
    }
  }

  Future<void> _bootstrap() async {
    try {
      await markAllTrailBookRead();
    } catch (_) {}
    final cache = TrailBookMemoryCache.instance;
    await Future.wait([
      _load(page: 1, silent: cache.feedReady),
      _loadCountryData(silent: cache.countriesReady),
    ]);
  }

  Future<void> _loadCountryData({bool silent = false}) async {
    try {
      final props = await getEditProfileProps();
      final profile = props.profile;
      final serverVisited =
          profile?.visitedCountries.map((c) => c.id).toSet() ?? <int>{};

      // One-time migrate from local device storage → profile.
      var visited = serverVisited;
      if (visited.isEmpty) {
        final local = await LocalStorage.instance
            .getTrailBookVisitedCountryIds();
        if (local.isNotEmpty && profile != null) {
          visited = local;
          try {
            await updateUserData(
              name: profile.name,
              mobility: profile.mobility ?? 'non-remote',
              visitedCountries: visited.toList(),
            );
            await LocalStorage.instance.setTrailBookVisitedCountryIds({});
          } catch (_) {
            // Keep local ids in UI if migrate fails; retry next open.
          }
        }
      } else {
        await LocalStorage.instance.setTrailBookVisitedCountryIds({});
      }

      if (!mounted) return;
      final nextVisited = visited
          .where((id) => props.countries.any((c) => c.id == id))
          .toSet();
      setState(() {
        _profileName = profile?.name;
        _profileMobility = profile?.mobility;
        _countries
          ..clear()
          ..addAll(props.countries);
        _visitedCountryIds
          ..clear()
          ..addAll(nextVisited);
      });
      TrailBookMemoryCache.instance.saveCountries(
        countries: props.countries,
        visitedCountryIds: nextVisited,
        profileName: profile?.name,
        profileMobility: profile?.mobility,
      );
    } catch (e) {
      if (mounted && !silent) {
        AppToast.show(context, message: serverErrorText(e));
      }
    }
  }

  Future<void> _setVisitedCountries(Set<int> ids) async {
    final previous = Set<int>.from(_visitedCountryIds);
    setState(() {
      _visitedCountryIds
        ..clear()
        ..addAll(ids);
    });
    TrailBookMemoryCache.instance.saveCountries(
      countries: _countries,
      visitedCountryIds: ids,
      profileName: _profileName,
      profileMobility: _profileMobility,
    );

    final name = _profileName;
    if (name == null || name.isEmpty) {
      if (mounted) {
        setState(() {
          _visitedCountryIds
            ..clear()
            ..addAll(previous);
        });
        TrailBookMemoryCache.instance.saveCountries(
          countries: _countries,
          visitedCountryIds: previous,
          profileName: _profileName,
          profileMobility: _profileMobility,
        );
        AppToast.show(context, message: 'Could not save visited countries');
      }
      return;
    }

    try {
      await updateUserData(
        name: name,
        mobility: _profileMobility ?? 'non-remote',
        visitedCountries: ids.toList(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _visitedCountryIds
          ..clear()
          ..addAll(previous);
      });
      TrailBookMemoryCache.instance.saveCountries(
        countries: _countries,
        visitedCountryIds: previous,
        profileName: _profileName,
        profileMobility: _profileMobility,
      );
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  Future<void> _load({required int page, bool silent = false}) async {
    if (page == 1) {
      // Keep cached cards visible; only block the UI on a cold first open.
      if (!silent && _items.isEmpty) {
        setState(() => _loading = true);
      }
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final res = await fetchTrailBook(page: page);
      if (!mounted) return;
      setState(() {
        if (page == 1) {
          _items
            ..clear()
            ..addAll(res.items.where((e) => e.isPostcard));
        } else {
          _items.addAll(res.items.where((e) => e.isPostcard));
        }
        _page = page;
        _hasMore = res.hasMore;
        _loading = false;
        _loadingMore = false;
      });
      TrailBookMemoryCache.instance.saveFeed(
        items: _items,
        page: _page,
        hasMore: _hasMore,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      if (!silent) {
        AppToast.show(context, message: serverErrorText(e));
      }
    }
  }

  Future<void> _onItemTap(TrailBookItemDto item) async {
    HapticsService.selection();
    final result = await PostcardDetailScreen.open(context, item: item);
    if (!mounted || result == null) return;
    if (result == PostcardDetailResult.deleted) {
      setState(() => _items.removeWhere((e) => e.id == item.id));
      TrailBookMemoryCache.instance.removeItem(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileName = _profileName?.trim();
    final title = profileName == null || profileName.isEmpty
        ? 'Travels'
        : '$profileName\'s Collection';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: AppText(title, variant: AppTextVariant.title),
        actions: [
          IconButton(
            onPressed: () => _tabController.index == 1
                ? showTrailBookInfoSheet(context)
                : showPostcardInfoSheet(context),
            icon: Image.asset(
              'assets/trailBook/info.png',
              width: 22,
              height: 22,
              color: Theme.of(context).colorScheme.onSurface,
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: AppLoading())
          : Column(
              children: [
                AppSlidingTabs(
                  controller: _tabController,
                  tabs: const [
                    AppSlidingTab(
                      icon: Icons.mail_outlined,
                      label: 'Postcards',
                    ),
                    AppSlidingTab(icon: Icons.public, label: 'Map'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPostcards(),
                      VisitedCountriesView(
                        countries: _countries,
                        visitedIds: _visitedCountryIds,
                        onChanged: _setVisitedCountries,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPostcards() {
    if (_items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(28, 48, 28, 40),
        children: [
          AppText(
            'Postcards from friends and strangers will appear here',
            variant: AppTextVariant.body,
            fontSize: 17,
            textAlign: TextAlign.center,
            color: AppColors.textSecondaryOf(context),
          ),
          const SizedBox(height: 56),
          Center(
            child: Container(
              width: MediaQuery.sizeOf(context).width / 3,
              height: 1,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 56),
          AppText(
            _quote.quote,
            variant: AppTextVariant.title,
            fontSize: 18,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          AppText(
            _quote.author,
            variant: AppTextVariant.body,
            color: AppColors.textSecondaryOf(context),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(page: 1),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >
                  notification.metrics.maxScrollExtent - 200 &&
              _hasMore &&
              !_loadingMore) {
            _load(page: _page + 1);
          }
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              sliver: SliverToBoxAdapter(
                child: _TrailBookPostcardMasonry(
                  items: _items,
                  onItemTap: _onItemTap,
                ),
              ),
            ),
            if (_loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Center(child: AppLoading()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Two-column masonry so each postcard sizes to its message length.
class _TrailBookPostcardMasonry extends StatelessWidget {
  const _TrailBookPostcardMasonry({
    required this.items,
    required this.onItemTap,
  });

  final List<TrailBookItemDto> items;
  final ValueChanged<TrailBookItemDto> onItemTap;

  @override
  Widget build(BuildContext context) {
    final left = <Widget>[];
    final right = <Widget>[];

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final card = Padding(
        padding: EdgeInsets.only(bottom: i < items.length - 2 ? 16 : 0),
        child: TrailBookPostcardCard(
          item: item,
          compact: true,
          heroTag: 'trailbook-postcard-${item.id}',
          onTap: () => onItemTap(item),
        ),
      );
      if (i.isEven) {
        left.add(card);
      } else {
        right.add(card);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: left)),
        const SizedBox(width: 14),
        Expanded(child: Column(children: right)),
      ],
    );
  }
}
