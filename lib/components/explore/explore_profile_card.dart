import 'dart:async';

import 'package:fairytrail/api/activities.dart';
import 'package:fairytrail/api/models/activity_models.dart';
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/components/explore/explore_profile_actions.dart';
import 'package:fairytrail/components/profile/kindness_info_dialog.dart';
import 'package:fairytrail/config/explore_options.dart';
import 'package:fairytrail/config/registration_options.dart';
import 'package:fairytrail/config/signup_options.dart';
import 'package:fairytrail/config/upcoming_destinations.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/screens/profile/profile_bucket_list_screen.dart';
import 'package:fairytrail/screens/shell/shell_chrome.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/theme/app_shadows.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Profile preview matching RN Explore `ProfilePreviewContent` + header details.
class ExploreProfileCard extends StatefulWidget {
  const ExploreProfileCard({
    super.key,
    required this.profile,
    this.scrollController,
    this.bottomInset = 100,
    this.topInset = 0,
    this.onMore,
    this.onUndo,
    this.canUndo = false,
    this.messages,
    this.chrome,
  });

  final FullProfileDto profile;
  final ScrollController? scrollController;
  final double bottomInset;
  final double topInset;
  final VoidCallback? onMore;
  final VoidCallback? onUndo;
  final bool canUndo;

  /// Captured when this card is shown above [MessagesScope] (e.g. profile view).
  final MessagesController? messages;
  final ShellChromeController? chrome;

  @override
  State<ExploreProfileCard> createState() => _ExploreProfileCardState();
}

class _ExploreProfileCardState extends State<ExploreProfileCard> {
  List<ActivityDto> _bucketListActivities = const [];
  int _loadGeneration = 0;
  bool _photoPinchActive = false;

  FullProfileDto get profile => widget.profile;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBucketList());
  }

  @override
  void didUpdateWidget(covariant ExploreProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) {
      _bucketListActivities = const [];
      _photoPinchActive = false;
      unawaited(_loadBucketList());
    }
  }

  Future<void> _loadBucketList() async {
    final profileId = widget.profile.id;
    if (profileId <= 0) return;
    final generation = ++_loadGeneration;
    try {
      final activities = await getProfileActivities(profileId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _bucketListActivities = activities);
    } catch (_) {
      // Bucket list is optional profile content; keep the profile usable when
      // the endpoint is unavailable or the feature is disabled.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final photoUrl = profile.primaryPhotoUrl;
    final photoSize = MediaQuery.sizeOf(context).width - 40;

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: ListView(
        controller: widget.scrollController,
        physics: _photoPinchActive
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
        padding: EdgeInsets.fromLTRB(
          20,
          widget.topInset + 6,
          20,
          widget.bottomInset,
        ),
        children: [
          // Name + meta | ⋯
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    AppText(
                      profile.name,
                      variant: AppTextVariant.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (profile.country case final country?
                            when country.country.isNotEmpty)
                          _MetaChip(
                            icon: Icons.location_on,
                            label: country.country,
                          ),
                        _MetaChip(
                          icon: Icons.luggage_outlined,
                          label: labelForTravelStyle(profile.travelStyle),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.onUndo != null || widget.onMore != null) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onUndo != null)
                      ExploreUndoButton(
                        enabled: widget.canUndo,
                        onPressed: widget.onUndo!,
                      ),
                    if (widget.onMore != null)
                      ExploreMoreButton(onPressed: widget.onMore!),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Square photo (RN: width - 40)
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: AppShadows.of(context),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: photoSize,
                height: photoSize,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (photoUrl != null && photoUrl.isNotEmpty)
                      _PhotoPager(
                        photos: profile.photos,
                        onPinchActiveChanged: (active) {
                          if (_photoPinchActive == active) return;
                          setState(() => _photoPinchActive = active);
                        },
                      )
                    else
                      ColoredBox(
                        color: const Color(0x54F398AE),
                        child: Icon(
                          Icons.person_outline,
                          size: 64,
                          color: muted,
                        ),
                      ),
                    if (profile.isVerified)
                      const Positioned(
                        top: 12,
                        left: 12,
                        child: _VerifiedBadge(),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          if (_has(profile.storyTime))
            _Section(
              title: 'Most adventurous experience',
              body: profile.storyTime!,
            ),
          if (_has(profile.topWishes))
            _Section(title: 'Top wishes', body: profile.topWishes!),
          if (_has(profile.whatImDoingNow))
            _Section(
              title: "What I'm doing now",
              body: profile.whatImDoingNow!,
            ),
          // if (profile.country != null)
          //   _Section(title: 'Current Location', body: profile.country!.country),
          _Section(
            title: 'Upcoming destinations',
            body: UpcomingDestinations.displayLabel(
              profile.upcomingDestinations,
            ),
          ),
          if (_has(profile.occupation))
            _Section(title: 'Work', body: profile.occupation!.trim()),
          if (_hasDetails(profile)) _ProfileDetailsRow(profile: profile),
          if (_has(profile.myValues))
            _Section(title: 'Values', body: profile.myValues!),
          if (_has(profile.thingsILove))
            _Section(title: 'Things I love', body: profile.thingsILove!),
          if (_has(profile.kindestThings))
            _Section(
              title: "Kindest thing I've done",
              body: profile.kindestThings!,
            ),
          if (profile.nationalities.isNotEmpty)
            _Section(
              title: 'Nationality',
              body: profile.nationalities.map((n) => n.name).join(', '),
            ),
          _Section(
            title: 'Languages',
            body: profile.languages.isEmpty
                ? 'English'
                : profile.languages.map((l) => l.language).join(', '),
          ),
          _Section(
            title: 'Kindness',
            body: '${profile.totalKindness}',
            showKindnessInfo: true,
          ),
          if (_has(profile.instagram))
            _Section(title: 'Instagram', body: _ig(profile.instagram!)),
          if (_bucketListActivities.isNotEmpty)
            _BucketListPreview(
              activities: _bucketListActivities,
              onTap: () => ProfileBucketListScreen.open(
                context,
                profileId: profile.id,
                profileName: profile.name,
                activities: _bucketListActivities,
                messages: widget.messages,
                chrome: widget.chrome,
              ),
            ),
        ],
      ),
    );
  }

  bool _has(String? v) => v != null && v.trim().isNotEmpty;

  bool _hasDetails(FullProfileDto profile) {
    return (profile.mobility != null && profile.mobility!.isNotEmpty) ||
        profile.age != null ||
        (profile.sexuality != null && profile.sexuality!.isNotEmpty) ||
        profile.profileType.isNotEmpty;
  }

  String _ig(String value) {
    final v = value.trim().toLowerCase();
    return v.startsWith('@') ? v : '@$v';
  }
}

class _ProfileDetailsRow extends StatelessWidget {
  const _ProfileDetailsRow({required this.profile});

  final FullProfileDto profile;

  String? get _workStyle {
    final m = profile.mobility;
    if (m == null || m.isEmpty) return null;
    return m == 'remote' ? 'Fully Remote' : labelForMobility(m);
  }

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      if (_workStyle != null) ('Work flexibility', _workStyle!),
      if (profile.profileType.isNotEmpty)
        ('Profile type', labelForProfileType(profile.profileType)),
      if (profile.age != null) ('Age', '${profile.age}'),
      if (labelForSexuality(profile.sexuality) case final sexuality?)
        ('Orientation', sexuality),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 24),
              _Section(title: items[i].$1, body: items[i].$2, padBottom: false),
            ],
          ],
        ),
      ),
    );
  }
}

class _BucketListPreview extends StatelessWidget {
  const _BucketListPreview({required this.activities, required this.onTap});

  final List<ActivityDto> activities;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.lightHighlightSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: AppText(
                        'Bucket list',
                        variant: AppTextVariant.body,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AppText(
                  activities.map((activity) => activity.name).join(', '),
                  variant: AppTextVariant.bodySmall,
                  fontSize: 16,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  color: AppColors.textSecondaryOf(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Swipeable photos (RN: `SwiperFlatList` in `ProfilePreviewContent`).
class _PhotoPager extends StatefulWidget {
  const _PhotoPager({required this.photos, required this.onPinchActiveChanged});

  final List<ProfilePhotoDto> photos;
  final ValueChanged<bool> onPinchActiveChanged;

  @override
  State<_PhotoPager> createState() => _PhotoPagerState();
}

class _PhotoPagerState extends State<_PhotoPager> {
  int _page = 0;
  final Set<int> _activePointers = <int>{};
  bool _pinchActive = false;

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (_activePointers.length < 2 || _pinchActive) return;
    setState(() => _pinchActive = true);
    widget.onPinchActiveChanged(true);
  }

  void _handlePointerEnd(PointerEvent event) {
    _activePointers.remove(event.pointer);
    // Keep both parent scrollables disabled until every finger has lifted. If
    // they are re-enabled when the first finger lifts, that remaining pointer
    // can unexpectedly swipe the photo or scroll the profile.
    if (_activePointers.isNotEmpty || !_pinchActive) return;
    setState(() => _pinchActive = false);
    widget.onPinchActiveChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;

    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePointerDown,
          onPointerUp: _handlePointerEnd,
          onPointerCancel: _handlePointerEnd,
          child: PageView.builder(
            physics: _pinchActive
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: photos.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final photo = photos[i];
              final url = photo.fullUrl;
              if (url.isEmpty) {
                return const ColoredBox(color: Color(0x54F398AE));
              }
              return _ZoomableProfilePhoto(
                key: ValueKey('${photo.attachmentId}-$url'),
                url: url,
                thumbnailUrl: photo.thumbnailUrl,
                blurHash: photo.blurHash,
              );
            },
          ),
        ),
        if (photos.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < photos.length; i++)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page
                          ? AppColors.white
                          : AppColors.white.withValues(alpha: 0.45),
                      boxShadow: const [
                        BoxShadow(color: Color(0x40000000), blurRadius: 2),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ZoomableProfilePhoto extends StatefulWidget {
  const _ZoomableProfilePhoto({
    super.key,
    required this.url,
    this.thumbnailUrl,
    this.blurHash,
  });

  final String url;
  final String? thumbnailUrl;
  final String? blurHash;

  @override
  State<_ZoomableProfilePhoto> createState() => _ZoomableProfilePhotoState();
}

class _ZoomableProfilePhotoState extends State<_ZoomableProfilePhoto>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _resetController;
  Animation<Matrix4>? _resetAnimation;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _resetController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
        )..addListener(() {
          final animation = _resetAnimation;
          if (animation != null) {
            _transformationController.value = animation.value;
          }
        });
  }

  void _resetZoom() {
    _resetAnimation =
        Matrix4Tween(
          begin: _transformationController.value.clone(),
          end: Matrix4.identity(),
        ).animate(
          CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
        );
    _resetController.forward(from: 0);
  }

  @override
  void dispose() {
    _resetController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 1,
      maxScale: 4,
      // One-finger drags belong to the photo pager/profile scroll. Pinching
      // still zooms around the focal point without competing for those drags.
      panEnabled: false,
      scaleEnabled: true,
      onInteractionStart: (_) => _resetController.stop(),
      onInteractionEnd: (_) => _resetZoom(),
      clipBehavior: Clip.hardEdge,
      child: SizedBox.expand(
        child: AppCachedImage(
          url: widget.url,
          thumbnailUrl: widget.thumbnailUrl,
          blurHash: widget.blurHash,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.75);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        AppText(
          label,
          variant: AppTextVariant.label,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ],
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 14, color: AppColors.white),
          SizedBox(width: 4),
          AppText(
            'Verified',
            variant: AppTextVariant.caption,
            color: AppColors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.body,
    this.padBottom = true,
    this.showKindnessInfo = false,
  });

  final String title;
  final String body;
  final bool padBottom;
  final bool showKindnessInfo;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.5);
    return Padding(
      padding: EdgeInsets.only(bottom: padBottom ? 18 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(
                title,
                variant: AppTextVariant.caption,
                color: muted,
                fontWeight: FontWeight.w600,
              ),
              if (showKindnessInfo) ...[
                const SizedBox(width: 3),
                KindnessInfoIcon(color: muted),
              ],
            ],
          ),
          const SizedBox(height: 4),
          AppText(body, variant: AppTextVariant.body),
        ],
      ),
    );
  }
}
