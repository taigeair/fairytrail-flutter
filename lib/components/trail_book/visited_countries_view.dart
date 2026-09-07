import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/data/maps/world_map.dart';
import 'package:country/country.dart' as iso;
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

class VisitedCountriesView extends StatelessWidget {
  const VisitedCountriesView({
    required this.countries,
    required this.visitedIds,
    required this.onChanged,
    super.key,
  });

  final List<CountryDto> countries;
  final Set<int> visitedIds;
  final ValueChanged<Set<int>> onChanged;

  static String _normalized(String value) => value
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String? _isoCode(CountryDto country) {
    final target = _normalized(country.country);
    for (final item in iso.Countries.values) {
      final names = <String>[
        item.isoShortName,
        item.isoLongName,
        if (item.isoShortNameLowerCase != null) item.isoShortNameLowerCase!,
        ...item.unofficialNames,
      ];
      if (names.any((name) => _normalized(name) == target)) {
        return item.alpha2.toLowerCase();
      }
    }

    const aliases = <String, String>{
      'bolivia': 'bo',
      'brunei': 'bn',
      'capeverde': 'cv',
      'congodemocraticrepublic': 'cd',
      'congorepublic': 'cg',
      'czechrepublic': 'cz',
      'ivorycoast': 'ci',
      'laos': 'la',
      'macedonia': 'mk',
      'moldova': 'md',
      'palestine': 'ps',
      'russia': 'ru',
      'southkorea': 'kr',
      'syria': 'sy',
      'taiwan': 'tw',
      'tanzania': 'tz',
      'unitedstates': 'us',
      'vaticancity': 'va',
      'venezuela': 've',
      'vietnam': 'vn',
    };
    return aliases[target];
  }

  Map<String, Color> _mapColors(Color visitedColor) => {
    for (final country in countries)
      if (visitedIds.contains(country.id) && _isoCode(country) != null)
        _isoCode(country)!: visitedColor,
  };

  void _toggleCountry(String isoCode) {
    final match = countries
        .where((country) => _isoCode(country) == isoCode.toLowerCase())
        .firstOrNull;
    if (match == null) return;
    final next = {...visitedIds};
    next.contains(match.id) ? next.remove(match.id) : next.add(match.id);
    onChanged(next);
  }

  Future<void> _editCountries(BuildContext context) async {
    final result = await AppMultiSelectSheet.show<int>(
      context,
      title: 'Countries visited',
      items: [
        for (final c in countries)
          AppMultiSelectItem(value: c.id, label: c.country),
      ],
      selected: visitedIds.toList(),
      searchable: true,
      searchHint: 'Search countries',
      heightFactor: 0.9,
    );
    if (result != null) onChanged(result.toSet());
  }

  @override
  Widget build(BuildContext context) {
    final visitedPercentage = countries.isEmpty
        ? 0.0
        : visitedIds.length / countries.length * 100;
    final percentageLabel = visitedPercentage == 0
        ? '0%'
        : visitedPercentage < 1
        ? '${visitedPercentage.toStringAsFixed(1)}%'
        : '${visitedPercentage.round()}%';
    final unvisited = AppColors.isDark(context)
        ? const Color(0xFF4B4F5A)
        : const Color(0xFFD7D9DE);
    final visitedColor = AppColors.isDark(context)
        ? AppColors.textPrimaryOf(context)
        : AppColors.primary;
    final mapBorder = AppColors.isDark(context)
        ? const Color(0xFF252832)
        : Theme.of(context).scaffoldBackgroundColor;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
      children: [
        AppText(
          '$percentageLabel of the world visited',
          variant: AppTextVariant.title,
          fontSize: 22,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        AppText(
          '${visitedIds.length} of ${countries.length} countries & territories',
          variant: AppTextVariant.body,
          textAlign: TextAlign.center,
          color: AppColors.textSecondaryOf(context),
        ),
        const SizedBox(height: 20),
        AppText(
          'Fairytrail World Map',
          variant: AppTextVariant.bodySmall,
          textAlign: TextAlign.center,
          color: AppColors.textSecondaryOf(context),
        ),
        Container(
          height: 230,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Transform.scale(
            scaleX: 1.12,
            child: Column(
              children: [
                Expanded(
                  child: SimpleMap(
                    instructions: SMapWorld.instructions,
                    defaultColor: unvisited,
                    colors: _mapColors(visitedColor),
                    countryBorder: CountryBorder(color: mapBorder, width: 0.7),
                    callback: (code, _, _) => _toggleCountry(code),
                  ),
                ),
                _AntarcticaMapRegion(
                  color: _mapColors(visitedColor)['aq'] ?? unvisited,
                  borderColor: mapBorder,
                  onTap: () => _toggleCountry('aq'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: visitedColor),
            const SizedBox(width: 6),
            const Text('Visited'),
            const SizedBox(width: 20),
            _LegendDot(color: unvisited),
            const SizedBox(width: 6),
            const Text('Not visited'),
          ],
        ),
        const SizedBox(height: 28),
        AppText(
          'Fill map with every place you’ve explored',
          variant: AppTextVariant.body,
          textAlign: TextAlign.center,
          color: AppColors.textSecondaryOf(context),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => _editCountries(context),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add visited countries'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

class _AntarcticaMapRegion extends StatelessWidget {
  const _AntarcticaMapRegion({
    required this.color,
    required this.borderColor,
    required this.onTap,
  });

  final Color color;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: SizedBox(
      height: 28,
      width: double.infinity,
      child: CustomPaint(
        painter: _AntarcticaPainter(color: color, borderColor: borderColor),
      ),
    ),
  );
}

class _AntarcticaPainter extends CustomPainter {
  const _AntarcticaPainter({required this.color, required this.borderColor});

  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.42)
      ..lineTo(size.width * 0.16, size.height * 0.25)
      ..lineTo(size.width * 0.27, size.height * 0.34)
      ..lineTo(size.width * 0.36, size.height * 0.18)
      ..lineTo(size.width * 0.47, size.height * 0.31)
      ..lineTo(size.width * 0.58, size.height * 0.15)
      ..lineTo(size.width * 0.69, size.height * 0.29)
      ..lineTo(size.width * 0.79, size.height * 0.22)
      ..lineTo(size.width * 0.9, size.height * 0.42)
      ..lineTo(size.width * 0.84, size.height * 0.67)
      ..lineTo(size.width * 0.71, size.height * 0.74)
      ..lineTo(size.width * 0.62, size.height * 0.62)
      ..lineTo(size.width * 0.5, size.height * 0.78)
      ..lineTo(size.width * 0.38, size.height * 0.64)
      ..lineTo(size.width * 0.25, size.height * 0.73)
      ..lineTo(size.width * 0.14, size.height * 0.61)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _AntarcticaPainter oldDelegate) =>
      color != oldDelegate.color || borderColor != oldDelegate.borderColor;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.borderOf(context)),
    ),
  );
}
