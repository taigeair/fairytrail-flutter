/// Copy + image for [ExploreDailyLimitView], from remote config
/// `daily_limit_copy_json` (`_A` / `_B` variants on the server).
///
/// Each field falls back to [defaults] on its own when missing, empty, or invalid.
class DailyLimitCopyConfig {
  const DailyLimitCopyConfig({
    required this.title,
    required this.subtitle,
    required this.subtitleGold,
    required this.upgradeButton,
    required this.activitiesButton,
    this.imageUrl,
  });

  final String title;
  final String subtitle;
  final String subtitleGold;
  final String upgradeButton;
  final String activitiesButton;
  final String? imageUrl;

  static const defaults = DailyLimitCopyConfig(
    title: 'Today\'s limit reached ',
    subtitle: 'Upgrade or wait until tomorrow for more profiles',
    subtitleGold: 'View more profiles tomorrow',
    upgradeButton: 'Unlock more profiles now',
    activitiesButton: 'Meet people in activities',
  );

  static const fallbackAsset = 'assets/explore/mountain-hike.png';

  factory DailyLimitCopyConfig.fromJson(Map<String, dynamic> json) {
    return DailyLimitCopyConfig(
      title: _text(json, 'title', defaults.title),
      subtitle: _text(
        json,
        'subtitle',
        defaults.subtitle,
        aliases: const ['subtitleFree'],
      ),
      subtitleGold: _text(json, 'subtitleGold', defaults.subtitleGold),
      upgradeButton: _text(
        json,
        'upgradeButton',
        defaults.upgradeButton,
        aliases: const ['primaryButton'],
      ),
      activitiesButton: _text(
        json,
        'activitiesButton',
        defaults.activitiesButton,
        aliases: const ['secondaryButton'],
      ),
      imageUrl: httpUrl(
        _optionalText(json, 'imageUrl') ?? _optionalText(json, 'image'),
      ),
    );
  }

  String subtitleFor({required bool isGold}) =>
      isGold ? subtitleGold : subtitle;

  static String _text(
    Map<String, dynamic> json,
    String key,
    String fallback, {
    List<String> aliases = const [],
  }) {
    for (final candidate in [key, ...aliases]) {
      final value = json[candidate]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return fallback;
  }

  static String? _optionalText(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String? httpUrl(String? raw) {
    if (raw == null) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return raw;
  }
}
