import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/billing/billing_plans.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/config/explore_options.dart';
import 'package:fairytrail/config/signup_options.dart';
import 'package:fairytrail/components/explore/keyword_filter_dialog.dart';
import 'package:fairytrail/components/explore/near_me_radius_sheet.dart';
import 'package:fairytrail/components/explore/recently_active_weeks_sheet.dart';
import 'package:fairytrail/explore/explore_controller.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/location/location_service.dart';
import 'package:fairytrail/screens/upgrade/upgrade_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Which picker to open immediately after the filters sheet appears.
enum ExploreFilterFocus {
  nearMe,
  location,
  identity,
  nextDestination,
  recentlyActive,
}

/// Search preferences — list-style UI (label + value rows).
Future<void> showExploreFiltersSheet(
  BuildContext context, {
  required ExploreController controller,
  ExploreFilterFocus? initialFocus,
}) async {
  final before = controller.prefs;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        ExploreFiltersSheet(controller: controller, initialFocus: initialFocus),
  );
  if (!context.mounted) return;
  if (!controller.prefsMatch(before)) {
    AppToast.show(context, message: 'Saved');
  }
}

class ExploreFiltersSheet extends StatefulWidget {
  const ExploreFiltersSheet({
    super.key,
    required this.controller,
    this.initialFocus,
  });

  final ExploreController controller;
  final ExploreFilterFocus? initialFocus;

  @override
  State<ExploreFiltersSheet> createState() => _ExploreFiltersSheetState();
}

class _ExploreFiltersSheetState extends State<ExploreFiltersSheet> {
  ExploreController get c => widget.controller;
  late UserPrefsDto _draft;
  UserPrefsDto get prefs => _draft;
  bool get isGold => AuthScope.of(context).isGold;

  /// Whether location permission is usable for near-me radius.
  bool? _locationOk;
  String? _locationHint;

  bool get _usingRadius => prefs.radiusMiles != null && prefs.radiusMiles! > 0;

  @override
  void initState() {
    super.initState();
    _draft = c.prefs;
    final focus = widget.initialFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _refreshLocationStatus();
      if (!mounted) return;
      if (focus != null) await _openInitialFocus(focus);
    });
  }

  Future<void> _refreshLocationStatus() async {
    final enabled = await LocationService.isServiceEnabled();
    if (!enabled) {
      if (!mounted) return;
      setState(() {
        _locationOk = false;
        _locationHint = 'Turn on Location Services to use Near me.';
      });
      return;
    }
    final permission = await LocationService.checkPermission();
    final ok =
        permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    if (!mounted) return;
    setState(() {
      _locationOk = ok;
      _locationHint = ok ? null : 'Allow location permission to use Near me.';
    });
  }

  Future<void> _openInitialFocus(ExploreFilterFocus focus) async {
    switch (focus) {
      case ExploreFilterFocus.nearMe:
        await _pickRadiusSafe();
      case ExploreFilterFocus.location:
        await _pickCurrentCountries();
      case ExploreFilterFocus.identity:
        await _pickIdentity();
      case ExploreFilterFocus.nextDestination:
        await _pickUpcomingCountries();
      case ExploreFilterFocus.recentlyActive:
        await _pickRecentlyActive();
    }
  }

  @override
  void dispose() {
    // Apply only when the sheet closes (X, swipe dismiss, or leave for upgrade).
    // Defer: updatePrefs → notifyListeners → ExploreScreen.setState must not run
    // while the tree is locked during this sheet's unmount.
    final draft = _draft;
    final controller = c;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.updatePrefs(draft);
    });
    super.dispose();
  }

  void _setDraft(UserPrefsDto next) {
    setState(() => _draft = next);
  }

  void _onGoldTap() {
    HapticsService.selection();
    final navigator = Navigator.of(context, rootNavigator: true);
    Navigator.of(context).pop();
    navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const UpgradeScreen(
          reason: 'keyword_search',
          from: 'explore',
          preferredTier: tierGold,
        ),
      ),
    );
  }

  void _requireGold() {
    if (!isGold) _onGoldTap();
  }

  void _resetToDefaults() {
    HapticsService.selection();
    _setDraft(
      UserPrefsDto(
        matchWith: [for (final o in matchWithOptions) o.$2],
        ageFrom: 18,
        ageTo: 99,
        currentCountries: const [],
        upcomingCountries: const [],
        mobility: const [],
        openTo: const [],
        keyword: '',
        nationalities: const [],
        speaking: const [],
        travelStyles: const [],
      ),
    );
  }

  String _matchWithValue() {
    if (prefs.matchWith.isEmpty) return 'All';
    if (prefs.matchWith.length == matchWithOptions.length) return 'All';
    return '${prefs.matchWith.length}';
  }

  String _ageValue() {
    final a = prefs.ageFrom ?? 18;
    final b = prefs.ageTo ?? 99;
    if (a == 18 && b == 99) return 'All';
    return '$a–$b';
  }

  String _idsValue(List<int> ids) {
    if (ids.isEmpty) return 'All';
    return '${ids.length}';
  }

  String _mobilityValue() {
    if (prefs.mobility.isEmpty ||
        prefs.mobility.length >= exploreMobilityOptions.length) {
      return 'All';
    }
    return '${prefs.mobility.length}';
  }

  String _identityValue() {
    if (prefs.travelStyles.isEmpty ||
        prefs.travelStyles.length >= exploreTravelStyleOptions.length) {
      return 'All';
    }
    return '${prefs.travelStyles.length}';
  }

  String _keywordValue() {
    final k = prefs.keyword.trim();
    return k.isEmpty ? 'All' : '✓';
  }

  Future<void> _pickMatchWith() async {
    final next = await AppMultiSelectSheet.show<String>(
      context,
      title: 'Profile types',
      items: [
        for (final o in matchWithOptions)
          AppMultiSelectItem(value: o.$2, label: o.$1),
      ],
      selected: prefs.matchWith,
      disallowEmpty: true,
    );
    if (next != null) _setDraft(prefs.copyWith(matchWith: next));
  }

  Future<void> _pickAge() async {
    var range = RangeValues(
      (prefs.ageFrom ?? 18).toDouble().clamp(18, 99),
      (prefs.ageTo ?? 99).toDouble().clamp(18, 99),
    );
    final result = await showModalBottomSheet<RangeValues>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AppSafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppText(
                      'Age range',
                      variant: AppTextVariant.title,
                      fontWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 8),
                    AppText(
                      '${range.start.round()} - ${range.end.round()}',
                      variant: AppTextVariant.title,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    RangeSlider(
                      values: range,
                      min: 18,
                      max: 99,
                      divisions: 81,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setLocal(() => range = v),
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      label: 'Done',
                      onPressed: () => Navigator.pop(ctx, range),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result != null) {
      _setDraft(
        prefs.copyWith(
          ageFrom: result.start.round(),
          ageTo: result.end.round(),
        ),
      );
    }
  }

  Future<void> _pickCountries({
    required String title,
    required List<int> selected,
    required void Function(List<int> ids) onDone,
  }) async {
    final next = await AppMultiSelectSheet.show<int>(
      context,
      title: title,
      items: [
        for (final e in c.countries)
          AppMultiSelectItem(value: e.id, label: e.country),
      ],
      selected: selected,
      searchable: true,
    );
    if (next != null) onDone(next);
  }

  Future<void> _pickCurrentCountries() async {
    if (_usingRadius) {
      AppToast.show(context, message: 'Turn off Near me to filter by country.');
      return;
    }
    return _pickCountries(
      title: 'Located in',
      selected: prefs.currentCountries,
      onDone: (ids) => _setDraft(
        prefs.copyWith(currentCountries: ids, clearRadiusMiles: true),
      ),
    );
  }

  Future<void> _pickUpcomingCountries() async {
    if (_usingRadius) {
      AppToast.show(
        context,
        message: 'Turn off Near me to filter by destination.',
      );
      return;
    }
    return _pickCountries(
      title: 'Traveling to',
      selected: prefs.upcomingCountries,
      onDone: (ids) => _setDraft(
        prefs.copyWith(upcomingCountries: ids, clearRadiusMiles: true),
      ),
    );
  }

  Future<void> _pickMobility() async {
    final next = await AppMultiSelectSheet.show<String>(
      context,
      title: 'Work flexibility',
      items: [
        for (final o in exploreMobilityOptions)
          AppMultiSelectItem(value: o.$2, label: o.$1),
      ],
      selected: prefs.mobility,
    );
    if (next != null) _setDraft(prefs.copyWith(mobility: next));
  }

  Future<void> _pickIdentity() async {
    if (!isGold) return _requireGold();
    final next = await AppMultiSelectSheet.show<String>(
      context,
      title: 'Lifestyle',
      items: [
        for (final o in exploreTravelStyleOptions)
          AppMultiSelectItem(value: o.$2, label: o.$1),
      ],
      selected: prefs.travelStyles,
    );
    if (next != null) _setDraft(prefs.copyWith(travelStyles: next));
  }

  Future<void> _pickNationalities() async {
    final next = await AppMultiSelectSheet.show<int>(
      context,
      title: 'Nationality',
      items: [
        for (final e in c.nationalities)
          AppMultiSelectItem(value: e.id, label: e.name),
      ],
      selected: prefs.nationalities,
      searchable: true,
    );
    if (next != null) _setDraft(prefs.copyWith(nationalities: next));
  }

  Future<void> _pickLanguages() async {
    final next = await AppMultiSelectSheet.show<int>(
      context,
      title: 'Speaking',
      items: [
        for (final e in c.languages)
          AppMultiSelectItem(value: e.id, label: e.language),
      ],
      selected: prefs.speaking,
      searchable: true,
    );
    if (next != null) _setDraft(prefs.copyWith(speaking: next));
  }

  Future<void> _pickKeyword() async {
    if (!isGold) return _requireGold();
    final result = await showKeywordFilterDialog(
      context,
      initialValue: prefs.keyword,
    );
    if (!mounted) return;
    if (result != null) _setDraft(prefs.copyWith(keyword: result));
  }

  Future<void> _pickRecentlyActive() async {
    if (!isGold) return _requireGold();
    final selected = await showRecentlyActiveWeeksSheet(
      context,
      currentWeeks: prefs.recentlyActiveWeeks,
    );
    if (!mounted || selected == null) return;
    if (selected == 'off') {
      _setDraft(prefs.copyWith(clearRecentlyActiveWeeks: true));
    } else if (selected is int) {
      _setDraft(prefs.copyWith(recentlyActiveWeeks: selected));
    }
  }

  Future<void> _pickRadiusSafe() async {
    if (!isGold) return _requireGold();

    final selected = await showNearMeRadiusSheet(
      context,
      currentMiles: prefs.radiusMiles,
      locationOk: _locationOk != false,
      locationHint: _locationHint,
    );

    if (!mounted || selected == null) return;

    if (selected == 'enable_location') {
      await _requestLocationForRadius();
      if (!mounted) return;
      if (_locationOk == true) await _pickRadiusSafe();
      return;
    }

    if (selected == 'off') {
      _setDraft(prefs.copyWith(clearRadiusMiles: true));
      return;
    }

    if (selected is int) {
      final ok = await _ensureLocationForRadius();
      if (!mounted || !ok) return;
      _setDraft(
        prefs.copyWith(
          radiusMiles: selected,
          currentCountries: const [],
          upcomingCountries: const [],
        ),
      );
    }
  }

  Future<bool> _ensureLocationForRadius() async {
    await _refreshLocationStatus();
    if (_locationOk != true) {
      return _requestLocationForRadius();
    }

    final outcome = await LocationService.shareCurrentLocation();
    if (!mounted) return false;
    if (outcome.isSuccess) return true;

    await _refreshLocationStatus();
    AppToast.show(
      context,
      message:
          outcome.errorMessage ?? 'Allow location permission to use Near me.',
    );
    setState(() {
      _locationOk = false;
      _locationHint =
          outcome.errorMessage ?? 'Allow location permission to use Near me.';
      if (_usingRadius) {
        _draft = prefs.copyWith(clearRadiusMiles: true);
      }
    });
    return false;
  }

  Future<bool> _requestLocationForRadius() async {
    final outcome = await LocationService.shareCurrentLocation();
    if (!mounted) return false;
    await _refreshLocationStatus();
    if (outcome.isSuccess) {
      setState(() {
        _locationOk = true;
        _locationHint = null;
      });
      return true;
    }

    final permanently =
        outcome.result == LocationShareResult.permissionPermanentlyDenied;
    final open = await AppDialog.confirm(
      context,
      title: 'Location needed',
      message:
          outcome.errorMessage ?? 'Allow location permission to use Near me.',
      confirmLabel: permanently ? 'Open Settings' : 'Try again',
      cancelLabel: 'Not now',
    );
    if (!mounted) return false;
    if (open && permanently) {
      await LocationService.openAppSettings();
    } else if (open) {
      return _requestLocationForRadius();
    }
    setState(() {
      _locationOk = false;
      _locationHint = 'Allow location permission to use Near me.';
      if (_usingRadius) {
        _draft = prefs.copyWith(clearRadiusMiles: true);
      }
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final divider = theme.dividerColor.withValues(alpha: 0.55);
    final height = MediaQuery.sizeOf(context).height * 0.92;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: AppText(
                    'Filters',
                    variant: AppTextVariant.headline,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AppButton(
                  label: 'Reset to default',
                  variant: AppButtonVariant.text,
                  isExpanded: false,
                  onPressed: _resetToDefaults,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                _SectionHeader('Standard', muted),
                _PrefsRow(
                  title: "Profile types",
                  description: 'Individuals, couples, and families',
                  tag: _matchWithValue(),
                  onTap: _pickMatchWith,
                  showDivider: true,
                  dividerColor: divider,
                ),
                _PrefsRow(
                  title: 'Age range',
                  description: 'Does not apply to couples and families.',
                  tag: _ageValue(),
                  onTap: _pickAge,
                  showDivider: true,
                  dividerColor: divider,
                ),
                _PrefsRow(
                  title: 'Located in',
                  description: _usingRadius
                      ? 'Disabled while Near me is on'
                      : 'Where people are currently based',
                  tag: _usingRadius ? 'Off' : _idsValue(prefs.currentCountries),
                  onTap: _pickCurrentCountries,
                  disabled: _usingRadius,
                  showDivider: true,
                  dividerColor: divider,
                ),
                _PrefsRow(
                  title: 'Traveling to',
                  description: _usingRadius
                      ? 'Disabled while Near me is on'
                      : 'Where people plan to go next',
                  tag: _usingRadius
                      ? 'Off'
                      : _idsValue(prefs.upcomingCountries),
                  onTap: _pickUpcomingCountries,
                  disabled: _usingRadius,
                  showDivider: true,
                  dividerColor: divider,
                ),
                _PrefsRow(
                  title: 'Work flexibility',
                  description: 'Remote, hybrid, or not remote',
                  tag: _mobilityValue(),
                  onTap: _pickMobility,
                  showDivider: true,
                  dividerColor: divider,
                ),
                _PrefsRow(
                  title: 'Nationality',
                  description: 'Where they’re from',
                  tag: _idsValue(prefs.nationalities),
                  onTap: _pickNationalities,
                  showDivider: true,
                  dividerColor: divider,
                ),
                _PrefsRow(
                  title: 'Speaking',
                  description: 'Languages they speak',
                  tag: _idsValue(prefs.speaking),
                  onTap: _pickLanguages,
                  showDivider: false,
                  dividerColor: divider,
                ),
                const SizedBox(height: 20),
                _SectionHeader('Advanced', muted),
                if (!isGold)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: _UpgradeBanner(onTap: _onGoldTap),
                  ),
                _PrefsRow(
                  title: 'Near me',
                  description: _locationOk == false
                      ? (_locationHint ??
                            'Allow location permission to use Near me.')
                      : 'People within a radius of you',
                  tag: labelForRadiusMiles(prefs.radiusMiles),
                  onTap: _pickRadiusSafe,
                  locked: !isGold,
                  showDivider: true,
                  dividerColor: divider,
                ),
                _PrefsRow(
                  title: 'Recently active',
                  description: 'How recently they were active',
                  tag: labelForRecentlyActiveWeeks(prefs.recentlyActiveWeeks),
                  onTap: _pickRecentlyActive,
                  locked: !isGold,
                  showDivider: true,
                  dividerColor: divider,
                ),
                _PrefsRow(
                  title: 'Lifestyle',
                  description: 'How they describe their lifestyle',
                  tag: _identityValue(),
                  onTap: _pickIdentity,
                  locked: !isGold,
                  showDivider: true,
                  dividerColor: divider,
                ),
                _PrefsRow(
                  title: 'Keyword or interest',
                  description: 'e.g. hiking, camping, Bad Bunny, Burning Man',
                  tag: _keywordValue(),
                  onTap: _pickKeyword,
                  locked: !isGold,
                  showDivider: false,
                  dividerColor: divider,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: AppText(
        text,
        variant: AppTextVariant.label,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

class _PrefsRow extends StatelessWidget {
  const _PrefsRow({
    required this.title,
    required this.description,
    required this.tag,
    required this.onTap,
    required this.showDivider,
    required this.dividerColor,
    this.locked = false,
    this.disabled = false,
  });

  final String title;
  final String description;
  final String tag;
  final VoidCallback onTap;
  final bool showDivider;
  final Color dividerColor;
  final bool locked;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final tagBg = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFF0F0F0);
    final tagFg = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final opacity = disabled ? 0.45 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          title,
                          variant: AppTextVariant.label,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        const SizedBox(height: 4),
                        AppText(
                          description,
                          variant: AppTextVariant.caption,
                          fontSize: 13,
                          color: muted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: tagBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: AppText(
                            tag,
                            variant: AppTextVariant.label,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: tagFg,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (locked)
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: muted,
                          )
                        else
                          Icon(
                            Icons.chevron_right_rounded,
                            color: muted.withValues(alpha: 0.7),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showDivider)
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Divider(height: 1, thickness: 0.5, color: dividerColor),
            ),
        ],
      ),
    );
  }
}

class _UpgradeBanner extends StatelessWidget {
  const _UpgradeBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const AppText(
                  'Upgrade',
                  variant: AppTextVariant.label,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppText(
                  'See who\'s near you and recently active',
                  // 'Try more filters with Fairytrail Gold',
                  variant: AppTextVariant.bodySmall,
                  fontSize: 13,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
