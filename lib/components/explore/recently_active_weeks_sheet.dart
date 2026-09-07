import 'package:fairytrail/config/explore_options.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Discrete stops: Off + [exploreRecentlyActiveWeeksOptions].
const _weeksStops = <int?>[null, ...exploreRecentlyActiveWeeksOptions];

/// Opens Recently active weeks picker with a snapping slider (same UX as Near me).
///
/// Returns:
/// - `'off'` — clear filter
/// - `int` — weeks selected (1, 2, 4, or 8)
/// - `null` — dismissed
Future<Object?> showRecentlyActiveWeeksSheet(
  BuildContext context, {
  required int? currentWeeks,
}) {
  return showModalBottomSheet<Object>(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _RecentlyActiveWeeksSheet(currentWeeks: currentWeeks),
  );
}

class _RecentlyActiveWeeksSheet extends StatefulWidget {
  const _RecentlyActiveWeeksSheet({required this.currentWeeks});

  final int? currentWeeks;

  @override
  State<_RecentlyActiveWeeksSheet> createState() =>
      _RecentlyActiveWeeksSheetState();
}

class _RecentlyActiveWeeksSheetState extends State<_RecentlyActiveWeeksSheet> {
  late double _index;

  @override
  void initState() {
    super.initState();
    _index = _indexForWeeks(widget.currentWeeks).toDouble();
  }

  static int _indexForWeeks(int? weeks) {
    if (weeks == null || weeks <= 0) return 0;
    final i = exploreRecentlyActiveWeeksOptions.indexOf(weeks);
    return i < 0 ? 0 : i + 1;
  }

  int? get _selectedWeeks => _weeksStops[_index.round()];

  String get _label => labelForRecentlyActiveWeeks(_selectedWeeks);

  void _onChanged(double value) {
    setState(() => _index = value.round().toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    final maxIndex = (_weeksStops.length - 1).toDouble();

    return AppSafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppText(
              'Recently active',
              variant: AppTextVariant.title,
              fontWeight: FontWeight.w700,
            ),
            const SizedBox(height: 4),
            AppText(
              'How recently they were active',
              variant: AppTextVariant.caption,
              color: muted,
            ),
            const SizedBox(height: 20),
            AppText(
              _label,
              variant: AppTextVariant.title,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.primary.withValues(alpha: 0.18),
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primary.withValues(alpha: 0.12),
                trackHeight: 4,
              ),
              child: Slider(
                value: _index.clamp(0, maxIndex),
                min: 0,
                max: maxIndex,
                divisions: _weeksStops.length - 1,
                onChanged: _onChanged,
              ),
            ),
            Padding(
              // Match the Slider's default 24 px track inset so each label is
              // centered directly beneath its corresponding tick mark.
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final stop in _weeksStops)
                    AppText(
                      stop == null ? 'Off' : '$stop',
                      variant: AppTextVariant.caption,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Done',
              onPressed: () {
                Navigator.pop(context, _selectedWeeks ?? 'off');
              },
            ),
          ],
        ),
      ),
    );
  }
}
