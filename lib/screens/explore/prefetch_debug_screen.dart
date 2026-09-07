import 'package:fairytrail/api/explore.dart';
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/api/https.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Debug-only inspector for `GET /api/v1/profiles/prefetch`.
class PrefetchDebugScreen extends StatefulWidget {
  const PrefetchDebugScreen({super.key});

  @override
  State<PrefetchDebugScreen> createState() => _PrefetchDebugScreenState();
}

class _PrefetchDebugScreenState extends State<PrefetchDebugScreen> {
  static const _typeOrder = ['man', 'woman', 'non-binary', 'couple', 'family'];

  bool _firstTime = false;
  bool _noMatch = false;
  bool _loading = false;
  String? _error;
  String? _revealError;
  PrefetchProfilesResponse? _response;
  Set<int> _incomingIds = {};
  int _revealTotal = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _revealError = null;
    });

    final revealFuture = fetchIncomingConnectionsList();

    try {
      final res = await prefetchProfiles(
        firstTime: _firstTime,
        noMatch: _noMatch,
      );
      IncomingConnectionsListResponse? reveal;
      String? revealError;
      try {
        reveal = await revealFuture;
      } catch (e) {
        revealError = serverErrorText(e);
      }
      if (!mounted) return;
      setState(() {
        _response = res;
        _incomingIds = {
          for (final profile in reveal?.profiles ?? const <FullProfileDto>[])
            profile.id,
        };
        _revealTotal = reveal?.total ?? _incomingIds.length;
        _revealError = revealError;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = serverErrorText(e);
        if (e is ApiException && e.statusCode == 429) {
          _error = 'Daily limit reached (${e.statusCode})';
        }
      });
    }
  }

  Map<String, int> _typeCounts(List<FullProfileDto> profiles) {
    final counts = <String, int>{};
    for (final profile in profiles) {
      final type = profile.profileType.isEmpty
          ? '(empty)'
          : profile.profileType;
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  List<MapEntry<String, int>> _orderedCounts(Map<String, int> counts) {
    final seen = <String>{};
    final ordered = <MapEntry<String, int>>[];
    for (final type in _typeOrder) {
      final n = counts[type];
      if (n != null) {
        ordered.add(MapEntry(type, n));
        seen.add(type);
      }
    }
    for (final entry in counts.entries) {
      if (!seen.contains(entry.key)) ordered.add(entry);
    }
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _response?.profiles ?? const <FullProfileDto>[];
    final meta = _response?.meta;
    final counts = _typeCounts(profiles);
    final ordered = _orderedCounts(counts);
    final incomingInDeck = profiles.where((p) => _incomingIds.contains(p.id)).length;

    return AppScaffold(
      title: 'Prefetch debug',
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const AppText(
                      'firstime',
                      variant: AppTextVariant.body,
                    ),
                    subtitle: AppText(
                      'Woman-first dump (gated first-time mix)',
                      variant: AppTextVariant.caption,
                      color: AppColors.textSecondaryOf(context),
                    ),
                    value: _firstTime,
                    onChanged: _loading
                        ? null
                        : (v) => setState(() => _firstTime = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const AppText(
                      'no_match',
                      variant: AppTextVariant.body,
                    ),
                    subtitle: AppText(
                      'Fill from incoming when the user has no matches',
                      variant: AppTextVariant.caption,
                      color: AppColors.textSecondaryOf(context),
                    ),
                    value: _noMatch,
                    onChanged: _loading
                        ? null
                        : (v) => setState(() => _noMatch = v),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'Fetch prefetch',
                    icon: Icons.refresh_rounded,
                    isLoading: _loading,
                    onPressed: _loading ? null : _fetch,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AppText(
                      _error!,
                      variant: AppTextVariant.bodySmall,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ],
                  if (meta != null) ...[
                    const SizedBox(height: 16),
                    AppText(
                      '${profiles.length} profiles',
                      variant: AppTextVariant.title,
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      'tier ${meta.tier} · limit ${meta.actionsLimit} · '
                      'skips ${meta.skipsCount} · connects ${meta.connectsCount}',
                      variant: AppTextVariant.caption,
                      color: AppColors.textSecondaryOf(context),
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      _revealError != null
                          ? 'reveal failed: $_revealError'
                          : 'reveal $_revealTotal · incoming in this batch $incomingInDeck',
                      variant: AppTextVariant.caption,
                      color: _revealError != null
                          ? Theme.of(context).colorScheme.error
                          : AppColors.textSecondaryOf(context),
                    ),
                    const SizedBox(height: 12),
                    AppText(
                      '${counts.length} profile type${counts.length == 1 ? '' : 's'}',
                      variant: AppTextVariant.body,
                      fontWeight: FontWeight.w600,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in ordered)
                          _TypeCountChip(type: entry.key, count: entry.value),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppText(
                      'Users (${profiles.length})',
                      variant: AppTextVariant.body,
                      fontWeight: FontWeight.w600,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          if (!_loading && _response != null && profiles.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: AppText(
                  'No profiles returned.',
                  variant: AppTextVariant.bodySmall,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemCount: profiles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return _ProfileRow(
                    index: index,
                    profile: profiles[index],
                    isIncoming: _incomingIds.contains(profiles[index].id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TypeCountChip extends StatelessWidget {
  const _TypeCountChip({required this.type, required this.count});

  final String type;
  final int count;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: AppText(
        '$type  $count',
        variant: AppTextVariant.label,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.index,
    required this.profile,
    required this.isIncoming,
  });

  final int index;
  final FullProfileDto profile;
  final bool isIncoming;

  @override
  Widget build(BuildContext context) {
    final photo = profile.photos.isEmpty ? null : profile.photos.first;
    final bits = <String>[
      if (profile.profileType.isNotEmpty) profile.profileType,
      if (profile.age != null) '${profile.age}',
      if (profile.country != null) profile.country!.country,
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          AppText(
            '${index + 1}',
            variant: AppTextVariant.caption,
            color: AppColors.textSecondaryOf(context),
          ),
          const SizedBox(width: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              width: 44,
              height: 44,
              child: photo == null
                  ? ColoredBox(
                      color: AppColors.surfaceOf(context),
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    )
                  : AppCachedImage(
                      url: photo.displayUrl,
                      blurHash: photo.blurHash,
                      width: 44,
                      height: 44,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: AppText(
                        profile.name.isEmpty ? '(no name)' : profile.name,
                        variant: AppTextVariant.body,
                        fontWeight: FontWeight.w600,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isIncoming) ...[
                      const SizedBox(width: 6),
                      const _IncomingTag(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                AppText(
                  bits.isEmpty ? 'id ${profile.id}' : bits.join(' · '),
                  variant: AppTextVariant.caption,
                  color: AppColors.textSecondaryOf(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AppText(
            '#${profile.id}',
            variant: AppTextVariant.caption,
            color: AppColors.textSecondaryOf(context),
          ),
        ],
      ),
    );
  }
}

class _IncomingTag extends StatelessWidget {
  const _IncomingTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const AppText(
        'incoming',
        variant: AppTextVariant.label,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    );
  }
}
