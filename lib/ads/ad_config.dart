import 'package:flutter/foundation.dart';

abstract final class AdConfig {
  static const iosAppId = 'ca-app-pub-6934920539705824~5474526835';
  static const androidAppId = 'ca-app-pub-6934920539705824~4836502085';

  static const _iosInterstitial = 'ca-app-pub-6934920539705824/1461003439';
  static const _androidInterstitial = 'ca-app-pub-6934920539705824/4845568886';
  static const _iosRewarded = 'ca-app-pub-6934920539705824/5153402132';
  static const _androidRewarded = 'ca-app-pub-6934920539705824/5682286684';

  static const testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static String interstitialUnitId(TargetPlatform platform) {
    if (kDebugMode) return testInterstitial;
    return platform == TargetPlatform.iOS
        ? _iosInterstitial
        : _androidInterstitial;
  }

  static String rewardedUnitId(TargetPlatform platform) {
    if (kDebugMode) return testRewarded;
    return platform == TargetPlatform.iOS ? _iosRewarded : _androidRewarded;
  }

  static const bannerKeywords = ['travel'];

  static const rewardedKeywords = [
    'luggage',
    'esim',
    'travel',
    'digital nomad',
    'tourist',
    'tourist destination',
    'tourist attraction',
    'tourist activity',
    'flights',
    'hotels',
    'vacation',
    'accommodation',
    'backpacking',
    'itinerary',
    'passport',
    'visa',
    'resort',
    'excursion',
    'tour guide',
    'road trip',
    'layover',
    'jet lag',
    'currency exchange',
    'travel insurance',
    'hostel',
    'airbnb',
    'all-inclusive',
    'cruise',
    'travel adapter',
    'souvenir',
    'sightseeing',
    'photography',
    'travel blog',
    'tours',
    'international',
    'meet locals',
    'travel apps',
    'packing list',
    'carry-on',
    'budget travel',
    'luxury travel',
    'travel hacks',
    'eco-tourism',
    'remote work',
    'wifi hotspot',
    'language learning',
    'airport transfer',
    'solo travel',
    'solo female travel',
    'solo adventure',
    'self-guided tour',
    'make friends',
    'meetup events',
    'travel community',
    'hiking',
    'adventure',
    'travel journal',
    'solo travel apps',
    'travel dating',
    'dating tips',
    'travel romance',
    'dating app',
    'matchmaking',
    'travel friends',
    'singles cruises',
    'expat',
    'international dating',
  ];
}
