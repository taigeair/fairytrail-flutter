/// Models for Explore (People) + search prefs.
///
/// Hidden from country pickers when present in the API list.
const hiddenCountryNames = {'Bansko Nomad Fest'};

class CountryDto {
  const CountryDto({
    required this.id,
    required this.country,
    this.code,
  });

  final int id;
  final String country;
  final String? code;

  factory CountryDto.fromJson(Map<String, dynamic> json) => CountryDto(
    id: (json['id'] as num?)?.toInt() ?? 0,
    country: json['country'] as String? ?? '',
    code: json['code'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'country': country,
    if (code != null) 'code': code,
  };

  /// Parses API country lists, excluding [hiddenCountryNames].
  static List<CountryDto> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => CountryDto.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => !hiddenCountryNames.contains(c.country))
        .toList();
  }
}

class LanguageDto {
  const LanguageDto({required this.id, required this.language});

  final int id;
  final String language;

  factory LanguageDto.fromJson(Map<String, dynamic> json) => LanguageDto(
    id: (json['id'] as num?)?.toInt() ?? 0,
    language: json['language'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'id': id, 'language': language};
}

class NationalityDto {
  const NationalityDto({required this.id, required this.name, this.country});

  final int id;
  final String name;
  final String? country;

  factory NationalityDto.fromJson(Map<String, dynamic> json) => NationalityDto(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    country: json['country'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (country != null) 'country': country,
  };
}

class ProfilePhotoDto {
  const ProfilePhotoDto({
    required this.attachmentId,
    required this.url,
    this.thumbnailUrl,
    this.blurHash,
  });

  final String attachmentId;
  final String url;
  final String? thumbnailUrl;
  final String? blurHash;

  factory ProfilePhotoDto.fromJson(Map<String, dynamic> json) =>
      ProfilePhotoDto(
        attachmentId: json['attachmentId'] as String? ?? '',
        url: json['url'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String?,
        blurHash: json['blurHash'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'attachmentId': attachmentId,
    'url': url,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    if (blurHash != null) 'blurHash': blurHash,
  };

  String get displayUrl =>
      (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) ? thumbnailUrl! : url;

  /// Full-size render (720px) — use for anything larger than a small avatar,
  /// since [thumbnailUrl] is only 128px and blurs when scaled up.
  String get fullUrl => url.isNotEmpty ? url : (thumbnailUrl ?? '');
}

class UpcomingDestinationDto {
  const UpcomingDestinationDto({
    required this.id,
    required this.name,
    this.type = 'country',
  });

  final int id;
  final String name;
  final String type;

  factory UpcomingDestinationDto.fromJson(Map<String, dynamic> json) =>
      UpcomingDestinationDto(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? 'country',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type};
}

class FullProfileDto {
  const FullProfileDto({
    required this.id,
    required this.name,
    required this.profileType,
    required this.photos,
    required this.isVerified,
    required this.status,
    this.country,
    this.age,
    this.occupation,
    this.mobility,
    this.storyTime,
    this.upcomingDestinations = const [],
    this.visitedCountries = const [],
    this.nationalities = const [],
    this.languages = const [],
    this.topWishes,
    this.myValues,
    this.thingsILove,
    this.kindestThings,
    this.whatImDoingNow,
    this.instagram,
    this.travelStyle,
    this.motives = const [],
    this.sexuality,
    this.openTo = const [],
    this.totalKindness = 0,
  });

  final int id;
  final String name;
  final String profileType;
  final List<ProfilePhotoDto> photos;
  final bool isVerified;
  final String status;
  final CountryDto? country;
  final int? age;
  final String? occupation;
  final String? mobility;
  final String? storyTime;
  final List<UpcomingDestinationDto> upcomingDestinations;
  final List<UpcomingDestinationDto> visitedCountries;
  final List<NationalityDto> nationalities;
  final List<LanguageDto> languages;
  final String? topWishes;
  final String? myValues;
  final String? thingsILove;
  final String? kindestThings;
  final String? whatImDoingNow;
  final String? instagram;
  final String? travelStyle;
  final List<String> motives;
  final String? sexuality;
  final List<String> openTo;
  final int totalKindness;

  factory FullProfileDto.fromJson(Map<String, dynamic> json) {
    return FullProfileDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      profileType: json['profileType'] as String? ?? '',
      isVerified: json['isVerified'] as bool? ?? false,
      status: json['status'] as String? ?? '',
      photos: (json['photos'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ProfilePhotoDto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      country: json['country'] is Map
          ? CountryDto.fromJson(
              Map<String, dynamic>.from(json['country'] as Map),
            )
          : null,
      age: (json['age'] as num?)?.toInt(),
      occupation: json['occupation'] as String?,
      mobility: json['mobility'] as String?,
      storyTime: json['storyTime'] as String?,
      upcomingDestinations: (json['upcomingDestinations'] as List? ?? [])
          .whereType<Map>()
          .map(
            (e) =>
                UpcomingDestinationDto.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
      visitedCountries: (json['visitedCountries'] as List? ?? [])
          .whereType<Map>()
          .map(
            (e) =>
                UpcomingDestinationDto.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
      nationalities: (json['nationalities'] as List? ?? [])
          .whereType<Map>()
          .map((e) => NationalityDto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      languages: (json['languages'] as List? ?? [])
          .whereType<Map>()
          .map((e) => LanguageDto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      topWishes: json['topWishes'] as String?,
      myValues: json['myValues'] as String?,
      thingsILove: json['thingsILove'] as String?,
      kindestThings: json['kindestThings'] as String?,
      whatImDoingNow: json['whatImDoingNow'] as String?,
      instagram: json['instagram'] as String?,
      travelStyle: json['travelStyle'] as String?,
      motives: (json['motives'] as List? ?? []).whereType<String>().toList(),
      sexuality: json['sexuality'] as String?,
      openTo: (json['openTo'] as List? ?? []).whereType<String>().toList(),
      totalKindness: (json['total_kindness'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'profileType': profileType,
    'isVerified': isVerified,
    'status': status,
    'photos': photos.map((p) => p.toJson()).toList(),
    if (country != null) 'country': country!.toJson(),
    if (age != null) 'age': age,
    if (occupation != null) 'occupation': occupation,
    if (mobility != null) 'mobility': mobility,
    if (storyTime != null) 'storyTime': storyTime,
    'upcomingDestinations': upcomingDestinations
        .map((d) => d.toJson())
        .toList(),
    'visitedCountries': visitedCountries.map((d) => d.toJson()).toList(),
    'nationalities': nationalities.map((n) => n.toJson()).toList(),
    'languages': languages.map((l) => l.toJson()).toList(),
    if (topWishes != null) 'topWishes': topWishes,
    if (myValues != null) 'myValues': myValues,
    if (thingsILove != null) 'thingsILove': thingsILove,
    if (kindestThings != null) 'kindestThings': kindestThings,
    if (whatImDoingNow != null) 'whatImDoingNow': whatImDoingNow,
    if (instagram != null) 'instagram': instagram,
    if (travelStyle != null) 'travelStyle': travelStyle,
    'motives': motives,
    if (sexuality != null) 'sexuality': sexuality,
    'openTo': openTo,
    'total_kindness': totalKindness,
  };

  FullProfileDto copyWith({
    int? id,
    String? name,
    String? profileType,
    List<ProfilePhotoDto>? photos,
    bool? isVerified,
    String? status,
    CountryDto? country,
    bool clearCountry = false,
    int? age,
    bool clearAge = false,
    String? occupation,
    String? mobility,
    String? storyTime,
    List<UpcomingDestinationDto>? upcomingDestinations,
    List<UpcomingDestinationDto>? visitedCountries,
    List<NationalityDto>? nationalities,
    List<LanguageDto>? languages,
    String? topWishes,
    String? myValues,
    String? thingsILove,
    String? kindestThings,
    String? whatImDoingNow,
    String? instagram,
    String? travelStyle,
    bool clearTravelStyle = false,
    List<String>? motives,
    String? sexuality,
    bool clearSexuality = false,
    List<String>? openTo,
    int? totalKindness,
  }) {
    return FullProfileDto(
      id: id ?? this.id,
      name: name ?? this.name,
      profileType: profileType ?? this.profileType,
      photos: photos ?? this.photos,
      isVerified: isVerified ?? this.isVerified,
      status: status ?? this.status,
      country: clearCountry ? null : (country ?? this.country),
      age: clearAge ? null : (age ?? this.age),
      occupation: occupation ?? this.occupation,
      mobility: mobility ?? this.mobility,
      storyTime: storyTime ?? this.storyTime,
      upcomingDestinations: upcomingDestinations ?? this.upcomingDestinations,
      visitedCountries: visitedCountries ?? this.visitedCountries,
      nationalities: nationalities ?? this.nationalities,
      languages: languages ?? this.languages,
      topWishes: topWishes ?? this.topWishes,
      myValues: myValues ?? this.myValues,
      thingsILove: thingsILove ?? this.thingsILove,
      kindestThings: kindestThings ?? this.kindestThings,
      whatImDoingNow: whatImDoingNow ?? this.whatImDoingNow,
      instagram: instagram ?? this.instagram,
      travelStyle: clearTravelStyle ? null : (travelStyle ?? this.travelStyle),
      motives: motives ?? this.motives,
      sexuality: clearSexuality ? null : (sexuality ?? this.sexuality),
      openTo: openTo ?? this.openTo,
      totalKindness: totalKindness ?? this.totalKindness,
    );
  }

  String? get primaryPhotoUrl => photos.isEmpty ? null : photos.first.fullUrl;
}

class ExploreMetaDto {
  const ExploreMetaDto({
    required this.tier,
    required this.seenAll,
    required this.skipsCount,
    required this.connectsCount,
    required this.actionsLimit,
    this.connectsLimit,
    this.totalConnectsCount,
    this.totalActions,
    this.totalSkips,
    this.totalConnects,
    this.pickupMoneyCountdown,
    this.totalTravelMoney,
    this.freeMoneyMax,
  });

  final String tier;
  final bool seenAll;
  final int skipsCount;
  final int connectsCount;
  final int actionsLimit;
  final int? connectsLimit;
  final int? totalConnectsCount;
  final int? totalActions;
  final int? totalSkips;
  final int? totalConnects;

  /// Next action count when free trail money can be picked up.
  final int? pickupMoneyCountdown;

  /// Current balance in cents (from `travelMoneyInfo.totalTravelMoney`).
  final int? totalTravelMoney;

  /// Max free trail money balance in cents.
  final int? freeMoneyMax;

  factory ExploreMetaDto.fromJson(Map<String, dynamic> json) {
    final travel = json['travelMoneyInfo'];
    final travelMap = travel is Map ? Map<String, dynamic>.from(travel) : null;
    return ExploreMetaDto(
      tier: json['tier'] as String? ?? 'free',
      seenAll: json['seenAll'] as bool? ?? false,
      skipsCount: (json['skipsCount'] as num?)?.toInt() ?? 0,
      connectsCount: (json['connectsCount'] as num?)?.toInt() ?? 0,
      actionsLimit: (json['actionsLimit'] as num?)?.toInt() ?? 0,
      connectsLimit: (json['connectsLimit'] as num?)?.toInt(),
      totalConnectsCount: (json['totalConnectsCount'] as num?)?.toInt(),
      totalActions: (json['totalActions'] as num?)?.toInt(),
      totalSkips: (json['totalSkips'] as num?)?.toInt(),
      totalConnects: (json['totalConnects'] as num?)?.toInt(),
      pickupMoneyCountdown: (travelMap?['pickupMoneyCountdown'] as num?)
          ?.toInt(),
      totalTravelMoney: (travelMap?['totalTravelMoney'] as num?)?.toInt(),
      freeMoneyMax: (travelMap?['freeMoneyMax'] as num?)?.toInt(),
    );
  }

  ExploreMetaDto copyWith({
    String? tier,
    bool? seenAll,
    int? skipsCount,
    int? connectsCount,
    int? actionsLimit,
    int? connectsLimit,
    int? totalConnectsCount,
    int? totalActions,
    int? totalSkips,
    int? totalConnects,
    int? pickupMoneyCountdown,
    int? totalTravelMoney,
    int? freeMoneyMax,
  }) {
    return ExploreMetaDto(
      tier: tier ?? this.tier,
      seenAll: seenAll ?? this.seenAll,
      skipsCount: skipsCount ?? this.skipsCount,
      connectsCount: connectsCount ?? this.connectsCount,
      actionsLimit: actionsLimit ?? this.actionsLimit,
      connectsLimit: connectsLimit ?? this.connectsLimit,
      totalConnectsCount: totalConnectsCount ?? this.totalConnectsCount,
      totalActions: totalActions ?? this.totalActions,
      totalSkips: totalSkips ?? this.totalSkips,
      totalConnects: totalConnects ?? this.totalConnects,
      pickupMoneyCountdown: pickupMoneyCountdown ?? this.pickupMoneyCountdown,
      totalTravelMoney: totalTravelMoney ?? this.totalTravelMoney,
      freeMoneyMax: freeMoneyMax ?? this.freeMoneyMax,
    );
  }

  bool get isPaid => tier == 'silver' || tier == 'gold';
  bool get isGold => tier == 'gold';
  int get totalProfileActions =>
      (totalSkips ?? skipsCount) + (totalConnects ?? connectsCount);
  int get dailyActions => skipsCount + connectsCount;
}

class PrefetchProfilesResponse {
  const PrefetchProfilesResponse({required this.profiles, required this.meta});

  final List<FullProfileDto> profiles;
  final ExploreMetaDto meta;

  factory PrefetchProfilesResponse.fromJson(Map<String, dynamic> json) {
    return PrefetchProfilesResponse(
      profiles: (json['profiles'] as List? ?? [])
          .whereType<Map>()
          .map((e) => FullProfileDto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      meta: ExploreMetaDto.fromJson(
        Map<String, dynamic>.from(json['meta'] as Map? ?? {}),
      ),
    );
  }
}

class UserPrefsDto {
  const UserPrefsDto({
    this.matchWith = const [],
    this.ageFrom,
    this.ageTo,
    this.currentCountries = const [],
    this.upcomingCountries = const [],
    this.mobility = const [],
    this.openTo = const [],
    this.keyword = '',
    this.nationalities = const [],
    this.speaking = const [],
    this.travelStyles = const [],
    this.radiusMiles,
    this.recentlyActiveWeeks,
  });

  final List<String> matchWith;
  final int? ageFrom;
  final int? ageTo;
  final List<int> currentCountries;
  final List<int> upcomingCountries;
  final List<String> mobility;
  final List<String> openTo;
  final String keyword;
  final List<int> nationalities;
  final List<int> speaking;
  final List<String> travelStyles;

  /// Near-me radius in miles; null = off.
  final int? radiusMiles;

  /// Active within N weeks; null = off. Allowed: 1, 2, 4, 8.
  final int? recentlyActiveWeeks;

  factory UserPrefsDto.fromJson(Map<String, dynamic> json) => UserPrefsDto(
    matchWith: (json['matchWith'] as List? ?? [])
        .map((e) => e.toString())
        .toList(),
    ageFrom: (json['ageFrom'] as num?)?.toInt(),
    ageTo: (json['ageTo'] as num?)?.toInt(),
    currentCountries: (json['currentCountries'] as List? ?? [])
        .map((e) => (e as num).toInt())
        .toList(),
    upcomingCountries: (json['upcomingCountries'] as List? ?? [])
        .map((e) => (e as num).toInt())
        .toList(),
    mobility: (json['mobility'] as List? ?? [])
        .map((e) => e.toString())
        .toList(),
    openTo: (json['openTo'] as List? ?? []).map((e) => e.toString()).toList(),
    keyword: json['keyword'] as String? ?? '',
    nationalities: (json['nationalities'] as List? ?? [])
        .map((e) => (e as num).toInt())
        .toList(),
    speaking: (json['speaking'] as List? ?? [])
        .map((e) => (e as num).toInt())
        .toList(),
    travelStyles: (json['travelStyles'] as List? ?? [])
        .map((e) => e.toString())
        .toList(),
    radiusMiles: (json['radiusMiles'] as num?)?.toInt(),
    recentlyActiveWeeks: (json['recentlyActiveWeeks'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'matchWith': matchWith,
    'ageFrom': ageFrom,
    'ageTo': ageTo,
    'currentCountries': currentCountries,
    'upcomingCountries': upcomingCountries,
    'mobility': mobility,
    'openTo': openTo,
    'keyword': keyword,
    'nationalities': nationalities,
    'speaking': speaking,
    'travelStyles': travelStyles,
    if (radiusMiles != null) 'radiusMiles': radiusMiles,
    if (recentlyActiveWeeks != null) 'recentlyActiveWeeks': recentlyActiveWeeks,
  };

  UserPrefsDto copyWith({
    List<String>? matchWith,
    int? ageFrom,
    int? ageTo,
    List<int>? currentCountries,
    List<int>? upcomingCountries,
    List<String>? mobility,
    List<String>? openTo,
    String? keyword,
    List<int>? nationalities,
    List<int>? speaking,
    List<String>? travelStyles,
    int? radiusMiles,
    int? recentlyActiveWeeks,
    bool clearAgeFrom = false,
    bool clearAgeTo = false,
    bool clearRadiusMiles = false,
    bool clearRecentlyActiveWeeks = false,
  }) {
    return UserPrefsDto(
      matchWith: matchWith ?? this.matchWith,
      ageFrom: clearAgeFrom ? null : (ageFrom ?? this.ageFrom),
      ageTo: clearAgeTo ? null : (ageTo ?? this.ageTo),
      currentCountries: currentCountries ?? this.currentCountries,
      upcomingCountries: upcomingCountries ?? this.upcomingCountries,
      mobility: mobility ?? this.mobility,
      openTo: openTo ?? this.openTo,
      keyword: keyword ?? this.keyword,
      nationalities: nationalities ?? this.nationalities,
      speaking: speaking ?? this.speaking,
      travelStyles: travelStyles ?? this.travelStyles,
      radiusMiles: clearRadiusMiles ? null : (radiusMiles ?? this.radiusMiles),
      recentlyActiveWeeks: clearRecentlyActiveWeeks
          ? null
          : (recentlyActiveWeeks ?? this.recentlyActiveWeeks),
    );
  }
}

class GetPrefsResponse {
  const GetPrefsResponse({
    required this.userPrefs,
    required this.countries,
    required this.languages,
    required this.nationalitiesList,
  });

  final UserPrefsDto userPrefs;
  final List<CountryDto> countries;
  final List<LanguageDto> languages;
  final List<NationalityDto> nationalitiesList;

  factory GetPrefsResponse.fromJson(Map<String, dynamic> json) {
    return GetPrefsResponse(
      userPrefs: UserPrefsDto.fromJson(
        Map<String, dynamic>.from(json['userPrefs'] as Map? ?? {}),
      ),
      countries: CountryDto.listFromJson(json['countries']),
      languages: (json['languages'] as List? ?? [])
          .whereType<Map>()
          .map((e) => LanguageDto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      nationalitiesList: (json['nationalitiesList'] as List? ?? [])
          .whereType<Map>()
          .map((e) => NationalityDto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class ConnectProfileResponse {
  const ConnectProfileResponse({required this.code});

  final String code; // match | sent

  factory ConnectProfileResponse.fromJson(Map<String, dynamic> json) =>
      ConnectProfileResponse(code: json['code'] as String? ?? 'sent');

  bool get isMatch => code == 'match';
}

class IncomingConnectionsResponse {
  const IncomingConnectionsResponse({required this.total, this.firstProfile});

  final int total;
  final FullProfileDto? firstProfile;

  factory IncomingConnectionsResponse.fromJson(Map<String, dynamic> json) {
    final first = json['firstProfile'];
    return IncomingConnectionsResponse(
      total: (json['total'] as num?)?.toInt() ?? 0,
      firstProfile: first is Map
          ? FullProfileDto.fromJson(Map<String, dynamic>.from(first))
          : null,
    );
  }
}

/// Full list from `GET /api/v1/profiles/incoming/list` (Reveal screen).
class IncomingConnectionsListResponse {
  const IncomingConnectionsListResponse({
    required this.profiles,
    required this.total,
  });

  final List<FullProfileDto> profiles;
  final int total;

  factory IncomingConnectionsListResponse.fromJson(Map<String, dynamic> json) {
    return IncomingConnectionsListResponse(
      total: (json['total'] as num?)?.toInt() ?? 0,
      profiles: (json['profiles'] as List? ?? [])
          .whereType<Map>()
          .map((e) => FullProfileDto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
