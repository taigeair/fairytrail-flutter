import 'dart:async';

import 'package:fairytrail/analytics/analytics_service.dart';
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/api/prefs.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/billing/billing_plans.dart';
import 'package:fairytrail/config/explore_options.dart';
import 'package:fairytrail/config/signup_options.dart';
import 'package:fairytrail/config/upcoming_destinations.dart';
import 'package:fairytrail/components/explore/keyword_filter_dialog.dart';
import 'package:fairytrail/components/explore/near_me_radius_sheet.dart';
import 'package:fairytrail/components/explore/recently_active_weeks_sheet.dart';
import 'package:fairytrail/location/location_service.dart';
import 'package:fairytrail/screens/upgrade/upgrade_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class SearchPrefsScreen extends StatefulWidget {
  const SearchPrefsScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SearchPrefsScreen()));
  }

  @override
  State<SearchPrefsScreen> createState() => _SearchPrefsScreenState();
}

class _SearchPrefsScreenState extends State<SearchPrefsScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  UserPrefsDto _prefs = const UserPrefsDto();
  List<CountryDto> _countries = [];
  List<LanguageDto> _languages = [];
  List<NationalityDto> _nationalities = [];

  bool get _isGold => AuthScope.of(context).isGold;

  bool get _usingRadius =>
      _prefs.radiusMiles != null && _prefs.radiusMiles! > 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await getPrefs();
      if (!mounted) return;
      setState(() {
        _prefs = _normalize(res.userPrefs);
        _countries = UpcomingDestinations.realCountries(res.countries);
        _languages = res.languages;
        _nationalities = res.nationalitiesList;
        _loading = false;
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = serverErrorText(e);
        _loading = false;
      });
    }
  }

  UserPrefsDto _normalize(UserPrefsDto prefs) {
    var next = prefs;
    if (next.matchWith.isEmpty) {
      next = next.copyWith(matchWith: [for (final o in matchWithOptions) o.$2]);
    }
    if (next.mobility.isEmpty) {
      next = next.copyWith(
        mobility: [for (final o in exploreMobilityOptions) o.$2],
      );
    }
    return next.copyWith(ageFrom: next.ageFrom ?? 18, ageTo: next.ageTo ?? 99);
  }

  void _update(UserPrefsDto next) {
    setState(() {
      _prefs = next;
      _dirty = true;
    });
  }

  Future<bool> _saveIfNeeded() async {
    if (!_dirty) return true;
    setState(() => _saving = true);
    try {
      var toSave = _prefs.copyWith(openTo: const []);
      if (!_isGold) {
        toSave = toSave.copyWith(
          keyword: '',
          travelStyles: const [],
          clearRecentlyActiveWeeks: true,
          clearRadiusMiles: true,
        );
      }
      if (toSave.radiusMiles != null && toSave.radiusMiles! > 0) {
        final outcome = await LocationService.shareCurrentLocation();
        if (!outcome.isSuccess) {
          if (!mounted) return false;
          setState(() => _saving = false);
          AppToast.show(
            context,
            message:
                outcome.errorMessage ??
                'Allow location permission to use Near me.',
          );
          return false;
        }
        toSave = toSave.copyWith(
          currentCountries: const [],
          upcomingCountries: const [],
        );
      }
      await putPrefs(toSave);
      if (!mounted) return true;
      setState(() {
        _dirty = false;
        _saving = false;
      });
      unawaited(AnalyticsService.instance.logEvent('updated_search_pref'));
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _saving = false);
      AppToast.show(context, message: serverErrorText(e));
      return false;
    }
  }

  Future<void> _onBack() async {
    final ok = await _saveIfNeeded();
    if (!mounted || !ok) return;
    Navigator.of(context).pop();
  }

  void _requireGold() {
    UpgradeScreen.open(
      context,
      reason: 'keyword_search',
      from: 'profile_prefs',
      preferredTier: tierGold,
    );
  }

  String _countLabel(int count, {bool allWhenEmpty = true}) {
    if (count == 0 && allWhenEmpty) return 'All';
    if (count == 0) return 'None';
    return '$count';
  }

  Future<void> _pickMatchWith() async {
    final next = await AppMultiSelectSheet.show<String>(
      context,
      title: 'Profile types',
      items: [
        for (final o in matchWithOptions)
          AppMultiSelectItem(value: o.$2, label: o.$1),
      ],
      selected: _prefs.matchWith,
      disallowEmpty: true,
    );
    if (next != null) _update(_prefs.copyWith(matchWith: next));
  }

  Future<void> _pickAge() async {
    var range = RangeValues(
      (_prefs.ageFrom ?? 18).toDouble().clamp(18, 99),
      (_prefs.ageTo ?? 99).toDouble().clamp(18, 99),
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
                      '${range.start.round()} – ${range.end.round()}',
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
      _update(
        _prefs.copyWith(
          ageFrom: result.start.round(),
          ageTo: result.end.round(),
        ),
      );
    }
  }

  Future<void> _pickCountries({
    required String title,
    required List<int> selected,
    required ValueChanged<List<int>> onDone,
  }) async {
    final next = await AppMultiSelectSheet.show<int>(
      context,
      title: title,
      items: [
        for (final c in _countries)
          AppMultiSelectItem(value: c.id, label: c.country),
      ],
      selected: selected,
      searchable: true,
    );
    if (next != null) onDone(next);
  }

  Future<void> _pickMobility() async {
    final next = await AppMultiSelectSheet.show<String>(
      context,
      title: 'Work flexibility',
      items: [
        for (final o in exploreMobilityOptions)
          AppMultiSelectItem(value: o.$2, label: o.$1),
      ],
      selected: _prefs.mobility,
      disallowEmpty: true,
    );
    if (next != null) _update(_prefs.copyWith(mobility: next));
  }

  Future<void> _pickIdentity() async {
    if (!_isGold) return _requireGold();
    final next = await AppMultiSelectSheet.show<String>(
      context,
      title: 'Lifestyle',
      items: [
        for (final o in exploreTravelStyleOptions)
          AppMultiSelectItem(value: o.$2, label: o.$1),
      ],
      selected: _prefs.travelStyles,
    );
    if (next != null) _update(_prefs.copyWith(travelStyles: next));
  }

  Future<void> _pickKeyword() async {
    if (!_isGold) return _requireGold();
    final result = await showKeywordFilterDialog(
      context,
      initialValue: _prefs.keyword,
    );
    if (!mounted) return;
    if (result != null) _update(_prefs.copyWith(keyword: result));
  }

  Future<void> _pickRecentlyActive() async {
    if (!_isGold) return _requireGold();
    final selected = await showRecentlyActiveWeeksSheet(
      context,
      currentWeeks: _prefs.recentlyActiveWeeks,
    );
    if (!mounted || selected == null) return;
    if (selected == 'off') {
      _update(_prefs.copyWith(clearRecentlyActiveWeeks: true));
    } else if (selected is int) {
      _update(_prefs.copyWith(recentlyActiveWeeks: selected));
    }
  }

  Future<void> _pickRadius() async {
    if (!_isGold) return _requireGold();

    final serviceEnabled = await LocationService.isServiceEnabled();
    final permission = await LocationService.checkPermission();
    final locationOk =
        serviceEnabled &&
        (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse);

    final selected = await showNearMeRadiusSheet(
      context,
      currentMiles: _prefs.radiusMiles,
      locationOk: locationOk,
      locationHint: !serviceEnabled
          ? 'Turn on Location Services to use Near me.'
          : (locationOk ? null : 'Allow location permission to use Near me.'),
    );
    if (!mounted || selected == null) return;
    if (selected == 'enable_location') {
      final outcome = await LocationService.shareCurrentLocation();
      if (!mounted) return;
      if (!outcome.isSuccess) {
        AppToast.show(
          context,
          message:
              outcome.errorMessage ??
              'Allow location permission to use Near me.',
        );
        return;
      }
      await _pickRadius();
      return;
    }
    if (selected == 'off') {
      _update(_prefs.copyWith(clearRadiusMiles: true));
      return;
    }
    if (selected is int) {
      final outcome = await LocationService.shareCurrentLocation();
      if (!mounted) return;
      if (!outcome.isSuccess) {
        AppToast.show(
          context,
          message:
              outcome.errorMessage ??
              'Allow location permission to use Near me.',
        );
        return;
      }
      _update(
        _prefs.copyWith(
          radiusMiles: selected,
          currentCountries: const [],
          upcomingCountries: const [],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onBack();
      },
      child: AppScaffold(
        title: 'Filters',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _onBack,
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
        body: _loading
            ? const Center(child: AppLoading())
            : _error != null
            ? AppEmptyView(
                title: 'Couldn’t load preferences',
                subtitle: _error,
                actionLabel: 'Retry',
                onAction: _load,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  AppText(
                    'These filters control who you see in Explore.',
                    variant: AppTextVariant.caption,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  const SizedBox(height: 16),
                  AppText(
                    'Standard filters',
                    variant: AppTextVariant.label,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  const SizedBox(height: 8),
                  _PrefRow(
                    label: 'Profile types',
                    value: _prefs.matchWith.length >= matchWithOptions.length
                        ? 'All'
                        : _countLabel(_prefs.matchWith.length),
                    onTap: _pickMatchWith,
                  ),
                  _PrefRow(
                    label: 'Age range',
                    value:
                        (_prefs.ageFrom ?? 18) == 18 &&
                            (_prefs.ageTo ?? 99) == 99
                        ? 'All'
                        : '${_prefs.ageFrom ?? 18}–${_prefs.ageTo ?? 99}',
                    onTap: _pickAge,
                  ),
                  _PrefRow(
                    label: 'Located in',
                    value: _usingRadius
                        ? 'Off'
                        : _countLabel(_prefs.currentCountries.length),
                    onTap: () {
                      if (_usingRadius) {
                        AppToast.show(
                          context,
                          message: 'Turn off Near me to filter by country.',
                        );
                        return;
                      }
                      _pickCountries(
                        title: 'Located in',
                        selected: _prefs.currentCountries,
                        onDone: (ids) => _update(
                          _prefs.copyWith(
                            currentCountries: ids,
                            clearRadiusMiles: true,
                          ),
                        ),
                      );
                    },
                  ),
                  _PrefRow(
                    label: 'Traveling to',
                    value: _usingRadius
                        ? 'Off'
                        : _countLabel(_prefs.upcomingCountries.length),
                    onTap: () {
                      if (_usingRadius) {
                        AppToast.show(
                          context,
                          message: 'Turn off Near me to filter by destination.',
                        );
                        return;
                      }
                      _pickCountries(
                        title: 'Traveling to',
                        selected: _prefs.upcomingCountries,
                        onDone: (ids) => _update(
                          _prefs.copyWith(
                            upcomingCountries: ids,
                            clearRadiusMiles: true,
                          ),
                        ),
                      );
                    },
                  ),
                  _PrefRow(
                    label: 'Work flexibility',
                    value:
                        _prefs.mobility.isEmpty ||
                            _prefs.mobility.length >=
                                exploreMobilityOptions.length
                        ? 'All'
                        : _countLabel(_prefs.mobility.length),
                    onTap: _pickMobility,
                  ),
                  _PrefRow(
                    label: 'Nationality',
                    value: _countLabel(_prefs.nationalities.length),
                    onTap: () async {
                      final next = await AppMultiSelectSheet.show<int>(
                        context,
                        title: 'Nationality',
                        items: [
                          for (final n in _nationalities)
                            AppMultiSelectItem(value: n.id, label: n.name),
                        ],
                        selected: _prefs.nationalities,
                        searchable: true,
                      );
                      if (next != null) {
                        _update(_prefs.copyWith(nationalities: next));
                      }
                    },
                  ),
                  _PrefRow(
                    label: 'Speaking',
                    value: _countLabel(_prefs.speaking.length),
                    onTap: () async {
                      final next = await AppMultiSelectSheet.show<int>(
                        context,
                        title: 'Speaking',
                        items: [
                          for (final l in _languages)
                            AppMultiSelectItem(value: l.id, label: l.language),
                        ],
                        selected: _prefs.speaking,
                        searchable: true,
                      );
                      if (next != null) {
                        _update(_prefs.copyWith(speaking: next));
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  AppText(
                    'Advanced filters',
                    variant: AppTextVariant.label,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  const SizedBox(height: 8),
                  _PrefRow(
                    label: 'Near me',
                    value: labelForRadiusMiles(_prefs.radiusMiles),
                    locked: !_isGold,
                    onTap: _pickRadius,
                  ),
                  _PrefRow(
                    label: 'Recently active',
                    value: labelForRecentlyActiveWeeks(
                      _prefs.recentlyActiveWeeks,
                    ),
                    locked: !_isGold,
                    onTap: _pickRecentlyActive,
                  ),
                  _PrefRow(
                    label: 'Lifestyle',
                    value:
                        _prefs.travelStyles.isEmpty ||
                            _prefs.travelStyles.length >=
                                exploreTravelStyleOptions.length
                        ? 'All'
                        : _countLabel(
                            _prefs.travelStyles.length,
                            allWhenEmpty: false,
                          ),
                    locked: !_isGold,
                    onTap: _pickIdentity,
                  ),
                  _PrefRow(
                    label: 'Keyword',
                    value: _prefs.keyword.trim().isEmpty
                        ? 'All'
                        : _prefs.keyword.trim(),
                    locked: !_isGold,
                    onTap: _pickKeyword,
                  ),
                ],
              ),
      ),
    );
  }
}

class _PrefRow extends StatelessWidget {
  const _PrefRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.locked = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(child: AppText(label, variant: AppTextVariant.body)),
            Spacer(),
            if (locked) ...[
              Icon(
                Icons.lock_outline,
                size: 16,
                color: AppColors.textSecondaryOf(context),
              ),
              const SizedBox(width: 6),
            ],
            AppText(
              value,
              variant: AppTextVariant.caption,
              color: AppColors.blue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}
