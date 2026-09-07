import 'package:fairytrail/api/edit_profile_props.dart';
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/config/upcoming_destinations.dart';
import 'package:fairytrail/screens/signup/signup_step_scaffold.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Step 8 — which country do you want to go to next.
///
/// - [openToAll] / Anywhere → empty destinations on the backend
/// - Specific countries → stored as upcoming destinations (max 5)
class SignupDestinationStep extends StatefulWidget {
  const SignupDestinationStep({
    super.key,
    required this.selectedIds,
    required this.openToAll,
    required this.onChanged,
    required this.onOpenToAllChanged,
    required this.onContinue,
    this.isLoading = false,
  });

  final Set<int> selectedIds;
  final bool openToAll;
  final ValueChanged<Set<int>> onChanged;
  final ValueChanged<bool> onOpenToAllChanged;
  final VoidCallback onContinue;
  final bool isLoading;

  @override
  State<SignupDestinationStep> createState() => _SignupDestinationStepState();
}

class _SignupDestinationStepState extends State<SignupDestinationStep> {
  static const _maxCountries = 5;

  final _searchController = TextEditingController();
  List<CountryDto> _countries = [];
  /// Fixed display order: selected first when the list is loaded.
  List<CountryDto> _ordered = [];
  bool _loadingList = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await getEditProfileProps();
      if (!mounted) return;
      final countries = UpcomingDestinations.realCountries(res.countries);
      setState(() {
        _countries = countries;
        _ordered = selectedFirst(
          countries,
          (c) => !widget.openToAll && widget.selectedIds.contains(c.id),
        );
        _loadingList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = serverErrorText(e);
        _loadingList = false;
      });
    }
  }

  bool get _canContinue =>
      widget.openToAll || widget.selectedIds.isNotEmpty;

  void _selectAnywhere() {
    widget.onOpenToAllChanged(true);
    widget.onChanged({});
  }

  void _toggleCountry(CountryDto c) {
    final base = widget.openToAll
        ? <int>{}
        : Set<int>.from(widget.selectedIds);

    final selected = base.contains(c.id);
    if (selected) {
      base.remove(c.id);
    } else {
      if (base.length >= _maxCountries) {
        AppToast.show(context, message: 'Limit is $_maxCountries');
        return;
      }
      base.add(c.id);
    }
    widget.onOpenToAllChanged(false);
    widget.onChanged(base);
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchController.text.trim().toLowerCase();
    final source = _ordered.isEmpty ? _countries : _ordered;
    final filtered = q.isEmpty
        ? source
        : [
            for (final c in source)
              if (c.country.toLowerCase().contains(q)) c,
          ];

    final showAnywhere = q.isEmpty ||
        UpcomingDestinations.anywhereLabel.toLowerCase().contains(q) ||
        UpcomingDestinations.openToAllLabel.toLowerCase().contains(q);

    return SignupStepScaffold(
      step: 8,
      title: 'Upcoming destinations',
      subtitle: 'Where do you want to travel to next?',
      canContinue: _canContinue,
      isLoading: widget.isLoading,
      onContinue: widget.onContinue,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: AppTextField(
              controller: _searchController,
              hint: 'Search countries',
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AppText(
                _error!,
                variant: AppTextVariant.bodySmall,
                color: AppColors.primary,
              ),
            ),
          Expanded(
            child: _loadingList
                ? const AppLoading()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    itemCount: filtered.length + (showAnywhere ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (showAnywhere && index == 0) {
                        return SignupOptionTile(
                          label: UpcomingDestinations.anywhereLabel,
                          subtitle:
                              '${UpcomingDestinations.openToAllLabel}',
                          selected: widget.openToAll,
                          icon: Icons.public_rounded,
                          onTap: _selectAnywhere,
                        );
                      }

                      final c = filtered[index - (showAnywhere ? 1 : 0)];
                      final selected = !widget.openToAll &&
                          widget.selectedIds.contains(c.id);
                      return SignupOptionTile(
                        label: c.country,
                        selected: selected,
                        onTap: () => _toggleCountry(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
