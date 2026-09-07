import 'dart:async';

import 'package:fairytrail/api/edit_profile_props.dart';
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/config/upcoming_destinations.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/screens/upgrade/upgrade_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

List<CountryDto>? _countriesCache;
Future<List<CountryDto>>? _countriesLoading;

Future<List<CountryDto>> _loadFilterCountries() {
  final cached = _countriesCache;
  if (cached != null) return Future.value(cached);

  return _countriesLoading ??= getEditProfileProps()
      .then((props) {
        final list = UpcomingDestinations.realCountries(props.countries);
        _countriesCache = list;
        return list;
      })
      .whenComplete(() => _countriesLoading = null);
}

/// Filter 1:1 matches in the Messages tab by partner country.
///
/// Opens for everyone (like Explore filters). Selecting a country requires
/// paid — free users get the upgrade paywall when they tap the filter row.
Future<void> showMatchCountryFilterSheet(
  BuildContext context, {
  required MessagesController controller,
}) async {
  HapticsService.selection();
  // Warm the cache without blocking the sheet from opening.
  unawaited(_loadFilterCountries());

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _MatchCountryFilterSheet(controller: controller),
  );
}

class _MatchCountryFilterSheet extends StatelessWidget {
  const _MatchCountryFilterSheet({required this.controller});

  final MessagesController controller;

  String _countryLabel(int? countryId, List<CountryDto> countries) {
    if (countryId == null) return 'Any';
    for (final c in countries) {
      if (c.id == countryId) return c.country;
    }
    return controller.matchCountryFilterName ?? 'Any';
  }

  Future<void> _onCountryRowTap(BuildContext context) async {
    HapticsService.selection();
    if (!AuthScope.of(context).isPaid) {
      // Same flow as Explore advanced filters: close sheet → paywall.
      final navigator = Navigator.of(context, rootNavigator: true);
      Navigator.of(context).pop();
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const UpgradeScreen(
            reason: 'match_country_filter',
            from: 'messages',
          ),
        ),
      );
      return;
    }
    await _pickCountry(context);
  }

  Future<void> _pickCountry(BuildContext context) async {
    try {
      final countries = await _loadFilterCountries();
      if (!context.mounted) return;
      final result = await _showCountryPickerSheet(
        context,
        countries: countries,
        selectedId: controller.matchCountryFilterId,
      );
      if (result == null) return;
      final name = result.countryId == null
          ? null
          : countries
                .where((c) => c.id == result.countryId)
                .map((c) => c.country)
                .firstOrNull;
      controller.setMatchCountryFilter(result.countryId, countryName: name);
    } catch (_) {
      if (!context.mounted) return;
      AppToast.show(context, message: 'Couldn’t load countries.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final divider = theme.dividerColor.withValues(alpha: 0.55);
    final isDark = theme.brightness == Brightness.dark;
    final tagBg = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFF0F0F0);
    final tagFg = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final countries = _countriesCache ?? const <CountryDto>[];
    final locked = !AuthScope.of(context).isPaid;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final selectedId = controller.matchCountryFilterId;
        final tag = _countryLabel(selectedId, countries);

        return AppSafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: AppText(
                        'Filter your connections',
                        variant: AppTextVariant.headline,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (controller.hasMatchCountryFilter)
                      AppButton(
                        label: 'Clear filter',
                        variant: AppButtonVariant.text,
                        isExpanded: false,
                        onPressed: () {
                          HapticsService.selection();
                          controller.clearMatchCountryFilter();
                          Navigator.pop(context);
                        },
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              // Same row layout as Explore filters (_PrefsRow).
              InkWell(
                onTap: () => unawaited(_onCountryRowTap(context)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppText(
                              'Location',
                              variant: AppTextVariant.label,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            const SizedBox(height: 4),
                            AppText(
                              'People currently in this country',
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
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Divider(height: 1, thickness: 0.5, color: divider),
              ),
              const SizedBox(height: 28),
            ],
          ),
        );
      },
    );
  }
}

class _CountryPickerResult {
  const _CountryPickerResult({this.countryId});

  final int? countryId;
}

Future<_CountryPickerResult?> _showCountryPickerSheet(
  BuildContext context, {
  required List<CountryDto> countries,
  int? selectedId,
}) {
  return showModalBottomSheet<_CountryPickerResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) =>
        _CountryPickerSheet(countries: countries, selectedId: selectedId),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({
    required this.countries,
    required this.selectedId,
  });

  final List<CountryDto> countries;
  final int? selectedId;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  List<CountryDto> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.countries;
    return [
      for (final c in widget.countries)
        if (c.country.toLowerCase().contains(q)) c,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final maxH = MediaQuery.sizeOf(context).height * 0.72;

    return AppSafeArea(
      child: SizedBox(
        height: maxH,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppText(
                  'Current country',
                  variant: AppTextVariant.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppTextField(
                hint: 'Search countries',
                maxLength: 20,
                prefixIcon: const Icon(Icons.search),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              onTap: () {
                HapticsService.selection();
                Navigator.pop(context, const _CountryPickerResult());
              },
              title: const AppText('Any', variant: AppTextVariant.body),
              trailing: widget.selectedId == null
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
            ),
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: AppColors.borderOf(context).withValues(alpha: 0.35),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: visible.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppColors.borderOf(context).withValues(alpha: 0.35),
                ),
                itemBuilder: (context, index) {
                  final country = visible[index];
                  final selected = widget.selectedId == country.id;
                  return ListTile(
                    onTap: () {
                      HapticsService.selection();
                      Navigator.pop(
                        context,
                        _CountryPickerResult(countryId: country.id),
                      );
                    },
                    title: AppText(
                      country.country,
                      variant: AppTextVariant.body,
                    ),
                    trailing: selected
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.primary,
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
