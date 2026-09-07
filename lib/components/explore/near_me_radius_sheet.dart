import 'package:fairytrail/config/explore_options.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Discrete stops: Off + [exploreRadiusMilesOptions].
const _radiusStops = <int?>[null, ...exploreRadiusMilesOptions];

/// Opens Near me radius picker with a snapping slider.
///
/// Returns:
/// - `'off'` — clear radius
/// - `'enable_location'` — request location then re-open
/// - `int` — miles selected
/// - `null` — dismissed
Future<Object?> showNearMeRadiusSheet(
  BuildContext context, {
  required int? currentMiles,
  required bool locationOk,
  String? locationHint,
}) {
  return showModalBottomSheet<Object>(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _NearMeRadiusSheet(
      currentMiles: currentMiles,
      locationOk: locationOk,
      locationHint: locationHint,
    ),
  );
}

class _NearMeRadiusSheet extends StatefulWidget {
  const _NearMeRadiusSheet({
    required this.currentMiles,
    required this.locationOk,
    this.locationHint,
  });

  final int? currentMiles;
  final bool locationOk;
  final String? locationHint;

  @override
  State<_NearMeRadiusSheet> createState() => _NearMeRadiusSheetState();
}

class _NearMeRadiusSheetState extends State<_NearMeRadiusSheet> {
  late double _index;

  @override
  void initState() {
    super.initState();
    _index = _indexForMiles(widget.currentMiles).toDouble();
  }

  static int _indexForMiles(int? miles) {
    if (miles == null || miles <= 0) return 0;
    final i = exploreRadiusMilesOptions.indexOf(miles);
    return i < 0 ? 0 : i + 1;
  }

  int? get _selectedMiles => _radiusStops[_index.round()];

  String get _label {
    final miles = _selectedMiles;
    if (miles == null) return 'Off';
    return '$miles mi';
  }

  void _onChanged(double value) {
    final snapped = value.round().toDouble();
    // Can't select a radius without location — snap back to Off or keep.
    if (snapped > 0 && !widget.locationOk) {
      setState(() => _index = 0);
      return;
    }
    setState(() => _index = snapped);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    final maxIndex = (_radiusStops.length - 1).toDouble();

    return AppSafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppText(
              'Near me',
              variant: AppTextVariant.title,
              fontWeight: FontWeight.w700,
            ),
            const SizedBox(height: 4),
            AppText(
              'People within a radius of you',
              variant: AppTextVariant.caption,
              color: muted,
            ),
            if (!widget.locationOk) ...[
              const SizedBox(height: 10),
              AppText(
                widget.locationHint ??
                    'Allow location permission to use Near me.',
                variant: AppTextVariant.caption,
                color: AppColors.primary,
                textAlign: TextAlign.center,
              ),
            ],
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
                divisions: _radiusStops.length - 1,
                onChanged: _onChanged,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final stop in _radiusStops)
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
            if (!widget.locationOk) ...[
              AppButton(
                label: 'Enable location',
                onPressed: () => Navigator.pop(context, 'enable_location'),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Turn off',
                variant: AppButtonVariant.text,
                onPressed: () => Navigator.pop(context, 'off'),
              ),
            ] else
              AppButton(
                label: 'Done',
                onPressed: () {
                  Navigator.pop(context, _selectedMiles ?? 'off');
                },
              ),
          ],
        ),
      ),
    );
  }
}
