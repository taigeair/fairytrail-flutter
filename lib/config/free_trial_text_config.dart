/// Copy for [SilverFreeTrialScreen], loaded from remote config `free_trial_text_json`.
///
/// If JSON cannot be parsed or any required field is missing, [defaults] is used.
class FreeTrialTextConfig {
  const FreeTrialTextConfig({
    required this.appBarTitle,
    required this.headline,
    required this.benefitsHeader,
    required this.priceWithTrial,
    required this.priceWithoutTrial,
    required this.ctaWithTrial,
    required this.ctaWithoutTrial,
    required this.restore,
    required this.timeline,
    required this.features,
  });

  final String appBarTitle;
  final String headline;
  final String benefitsHeader;
  final String priceWithTrial;
  final String priceWithoutTrial;
  final String ctaWithTrial;
  final String ctaWithoutTrial;
  final String restore;
  final List<FreeTrialTimelineText> timeline;
  final List<String> features;

  static const requiredKeys = <String>[
    'appBarTitle',
    'headline',
    'benefitsHeader',
    'priceWithTrial',
    'priceWithoutTrial',
    'ctaWithTrial',
    'ctaWithoutTrial',
    'restore',
    'timeline',
    'features',
  ];

  static const defaults = FreeTrialTextConfig(
    appBarTitle: 'Welcome Offer!',
    headline: 'Here\'s how your free trial works',
    benefitsHeader: 'Silver Plan (75% off of regular price)',
    priceWithTrial: 'Free for {trialDays} days, then {price}/year.',
    priceWithoutTrial: 'Then {price}/year.',
    ctaWithTrial: 'Try for \$0.00',
    ctaWithoutTrial: 'Subscribe',
    restore: 'Restore',
    timeline: [
      FreeTrialTimelineText(
        title: 'Today: start your free trial',
        subtitle: 'Get instant access to Silver benefits',
      ),
      FreeTrialTimelineText(
        title: 'Day {midDay}: keep exploring!',
        subtitle: 'Try out the Silver features',
      ),
      FreeTrialTimelineText(
        title: 'Day {trialDays}: trial ends',
        subtitle: 'You’ll be charged for Silver. You can anytime before',
      ),
    ],
    features: [
      'Unlock who wants to connect',
      'More daily profiles',
      'Undo skips',
      'Free verification',
      'No ads',
    ],
  );

  /// Returns [defaults] when [json] is incomplete or invalid.
  factory FreeTrialTextConfig.fromJson(Map<String, dynamic> json) {
    for (final key in requiredKeys) {
      if (!json.containsKey(key) || json[key] == null) {
        return defaults;
      }
    }

    String? requireString(String key) {
      final value = json[key]?.toString().trim();
      if (value == null || value.isEmpty) return null;
      return value;
    }

    final appBarTitle = requireString('appBarTitle');
    final headline = requireString('headline');
    final benefitsHeader = requireString('benefitsHeader');
    final priceWithTrial = requireString('priceWithTrial');
    final priceWithoutTrial = requireString('priceWithoutTrial');
    final ctaWithTrial = requireString('ctaWithTrial');
    final ctaWithoutTrial = requireString('ctaWithoutTrial');
    final restore = requireString('restore');

    if (appBarTitle == null ||
        headline == null ||
        benefitsHeader == null ||
        priceWithTrial == null ||
        priceWithoutTrial == null ||
        ctaWithTrial == null ||
        ctaWithoutTrial == null ||
        restore == null) {
      return defaults;
    }

    final timelineRaw = json['timeline'];
    if (timelineRaw is! List || timelineRaw.isEmpty) return defaults;

    final timeline = <FreeTrialTimelineText>[];
    for (final item in timelineRaw) {
      if (item is! Map) return defaults;
      final map = Map<String, dynamic>.from(item);
      final title = map['title']?.toString().trim() ?? '';
      final subtitle = map['subtitle']?.toString().trim() ?? '';
      if (title.isEmpty || subtitle.isEmpty) return defaults;
      timeline.add(FreeTrialTimelineText(title: title, subtitle: subtitle));
    }
    if (timeline.isEmpty) return defaults;

    final featuresRaw = json['features'];
    if (featuresRaw is! List || featuresRaw.isEmpty) return defaults;

    final features = <String>[];
    for (final item in featuresRaw) {
      final text = item?.toString().trim() ?? '';
      if (text.isEmpty) return defaults;
      features.add(text);
    }
    if (features.isEmpty) return defaults;

    return FreeTrialTextConfig(
      appBarTitle: appBarTitle,
      headline: headline,
      benefitsHeader: benefitsHeader,
      priceWithTrial: priceWithTrial,
      priceWithoutTrial: priceWithoutTrial,
      ctaWithTrial: ctaWithTrial,
      ctaWithoutTrial: ctaWithoutTrial,
      restore: restore,
      timeline: timeline,
      features: features,
    );
  }

  String resolve(
    String template, {
    required int trialDays,
    required int midDay,
    required String price,
  }) {
    return template
        .replaceAll('{trialDays}', '$trialDays')
        .replaceAll('{midDay}', '$midDay')
        .replaceAll('{price}', price);
  }
}

class FreeTrialTimelineText {
  const FreeTrialTimelineText({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;
}
