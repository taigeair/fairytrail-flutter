import 'package:fairytrail/api/models/explore_models.dart';
import 'package:intl/intl.dart';

/// Minimal models for auth / registration API responses.
class UserDto {
  const UserDto({
    required this.id,
    required this.email,
    required this.name,
    this.shortId,
    this.isEmailVerified = false,
    this.accountStatus,
  });

  final String id;
  final String email;
  final String name;
  final String? shortId;
  final bool isEmailVerified;
  final String? accountStatus;

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: _stringField(json['id']),
      email: _stringField(json['email']),
      name: _stringField(json['name']),
      shortId: _stringFieldOrNull(json['shortId']),
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
      accountStatus: _stringFieldOrNull(json['accountStatus']),
    );
  }

  static String _stringField(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static String? _stringFieldOrNull(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    if (value is Map) {
      final nested = value['value'] ?? value['name'];
      if (nested != null) return nested.toString();
    }
    return value.toString();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    if (shortId != null) 'shortId': shortId,
    'isEmailVerified': isEmailVerified,
    if (accountStatus != null) 'accountStatus': accountStatus,
  };
}

/// Received connect/skip counts used for Photo Epicness (Truth Serum score).
class ActionsCountDto {
  const ActionsCountDto({
    this.skipsCount = 0,
    this.connectsCount = 0,
    this.totalCount = 0,
  });

  final int skipsCount;
  final int connectsCount;
  final int totalCount;

  factory ActionsCountDto.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ActionsCountDto();
    final skips = (json['skipsCount'] as num?)?.toInt() ?? 0;
    final connects = (json['connectsCount'] as num?)?.toInt() ?? 0;
    return ActionsCountDto(
      skipsCount: skips,
      connectsCount: connects,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? skips + connects,
    );
  }

  Map<String, dynamic> toJson() => {
    'skipsCount': skipsCount,
    'connectsCount': connectsCount,
    'totalCount': totalCount,
  };
}

class ProfileMetaDto {
  const ProfileMetaDto({
    required this.id,
    required this.isProfileCompleted,
    required this.photosCount,
    required this.status,
    this.matchWithCount = 0,
    this.isLocationSet = false,
    this.tier = 'gated',
    this.tierIsCancelled = false,
    this.tierValidUntil,
    this.profileType,
    this.age,
    this.photoUrl,
    this.photoBlurHash,
    this.travelStyle,
    this.mobility,
    this.totalKindness = 0,
    this.totalTravelMoney = 0,
    this.totalPostcards = 1,
    this.isTruthSerumPurchased = false,
    this.totalNumberOfActions,
    this.country,
  });

  final int id;
  final bool isProfileCompleted;
  final int photosCount;
  final String status;
  final int matchWithCount;
  final bool isLocationSet;

  /// `gated` | `free` | `silver` | `gold`
  final String tier;
  final bool tierIsCancelled;
  final DateTime? tierValidUntil;
  final String? profileType;
  final int? age;
  final String? photoUrl;
  final String? photoBlurHash;
  final String? travelStyle;
  final String? mobility;
  final int totalKindness;

  /// Balance in dollars (API `total_travelmoney`).
  final double totalTravelMoney;

  /// Remaining postcard send credits (API `total_postcards`).
  final int totalPostcards;

  /// Whether Truth Serum (Photo Epicness) has been unlocked.
  final bool isTruthSerumPurchased;

  /// Received skips/connects — inputs for the Photo Epicness score.
  final ActionsCountDto? totalNumberOfActions;

  final CountryDto? country;

  /// Profile country ISO-2 (e.g. `US`), if known.
  String? get countryCode {
    final code = country?.code?.trim();
    if (code == null || code.isEmpty) return null;
    return code.toUpperCase();
  }

  bool get isGold => tier == 'gold';
  bool get isPaid => tier == 'silver' || tier == 'gold';

  /// Client-side Photo Epicness score. Null when locked.
  String? get photoEpicnessScore {
    if (!isTruthSerumPurchased) return null;
    final actions = totalNumberOfActions;
    final skips = actions?.skipsCount ?? 0;
    if (skips == 0) return '50';
    final score = (((actions?.connectsCount ?? 0) / skips) * 10000).round();
    return score == 0
        ? '1000'
        : NumberFormat.decimalPattern('en_US').format(score);
  }

  factory ProfileMetaDto.fromJson(Map<String, dynamic> json) {
    final tierRaw = json['tier'];
    final photo = json['photo'];
    String? photoUrl;
    String? photoBlurHash;
    if (photo is Map) {
      photoUrl = photo['url'] as String? ?? photo['thumbnailUrl'] as String?;
      photoBlurHash = photo['blurHash'] as String?;
    }
    final actionsRaw = json['totalNumberOfActions'];
    final countryRaw = json['country'];
    return ProfileMetaDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      isProfileCompleted: json['isProfileCompleted'] as bool? ?? false,
      photosCount: (json['photosCount'] as num?)?.toInt() ?? 0,
      status: UserDto._stringFieldOrNull(json['status']) ?? '',
      matchWithCount: (json['matchWithCount'] as num?)?.toInt() ?? 0,
      isLocationSet: json['isLocationSet'] as bool? ?? false,
      tier: _tierValueFromJson(tierRaw),
      tierIsCancelled: _tierIsCancelledFromJson(tierRaw),
      tierValidUntil: _tierValidUntilFromJson(tierRaw),
      profileType: json['profileType'] as String?,
      age: (json['age'] as num?)?.toInt(),
      photoUrl: photoUrl,
      photoBlurHash: photoBlurHash,
      travelStyle: json['travelStyle'] as String?,
      mobility: json['mobility'] as String?,
      totalKindness: (json['total_kindness'] as num?)?.toInt() ?? 0,
      totalTravelMoney: (json['total_travelmoney'] as num?)?.toDouble() ?? 0,
      totalPostcards: (json['total_postcards'] as num?)?.toInt() ?? 1,
      isTruthSerumPurchased: json['is_truth_serum_purchased'] as bool? ?? false,
      totalNumberOfActions: actionsRaw is Map
          ? ActionsCountDto.fromJson(Map<String, dynamic>.from(actionsRaw))
          : null,
      country: countryRaw is Map
          ? CountryDto.fromJson(Map<String, dynamic>.from(countryRaw))
          : null,
    );
  }

  static String _tierValueFromJson(dynamic tier) {
    if (tier is Map) return tier['value'] as String? ?? 'gated';
    if (tier is String && tier.isNotEmpty) return tier;
    return 'gated';
  }

  static bool _tierIsCancelledFromJson(dynamic tier) {
    if (tier is Map) return tier['isCancelled'] as bool? ?? false;
    return false;
  }

  static DateTime? _tierValidUntilFromJson(dynamic tier) {
    if (tier is! Map) return null;
    final raw = tier['validUntil'];
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'isProfileCompleted': isProfileCompleted,
    'photosCount': photosCount,
    'status': status,
    'matchWithCount': matchWithCount,
    'isLocationSet': isLocationSet,
    'tier': {
      'value': tier,
      'isCancelled': tierIsCancelled,
      if (tierValidUntil != null)
        'validUntil': tierValidUntil!.toIso8601String(),
    },
    if (profileType != null) 'profileType': profileType,
    if (age != null) 'age': age,
    if (photoUrl != null)
      'photo': {
        'url': photoUrl,
        if (photoBlurHash != null) 'blurHash': photoBlurHash,
      },
    if (travelStyle != null) 'travelStyle': travelStyle,
    if (mobility != null) 'mobility': mobility,
    'total_kindness': totalKindness,
    'total_travelmoney': totalTravelMoney,
    'total_postcards': totalPostcards,
    'is_truth_serum_purchased': isTruthSerumPurchased,
    if (totalNumberOfActions != null)
      'totalNumberOfActions': totalNumberOfActions!.toJson(),
  };

  ProfileMetaDto copyWith({
    int? id,
    bool? isProfileCompleted,
    int? photosCount,
    String? status,
    int? matchWithCount,
    bool? isLocationSet,
    String? tier,
    bool? tierIsCancelled,
    DateTime? tierValidUntil,
    String? profileType,
    int? age,
    String? photoUrl,
    String? photoBlurHash,
    String? travelStyle,
    String? mobility,
    int? totalKindness,
    double? totalTravelMoney,
    int? totalPostcards,
    bool? isTruthSerumPurchased,
    ActionsCountDto? totalNumberOfActions,
    CountryDto? country,
  }) {
    return ProfileMetaDto(
      id: id ?? this.id,
      isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
      photosCount: photosCount ?? this.photosCount,
      status: status ?? this.status,
      matchWithCount: matchWithCount ?? this.matchWithCount,
      isLocationSet: isLocationSet ?? this.isLocationSet,
      tier: tier ?? this.tier,
      tierIsCancelled: tierIsCancelled ?? this.tierIsCancelled,
      tierValidUntil: tierValidUntil ?? this.tierValidUntil,
      profileType: profileType ?? this.profileType,
      age: age ?? this.age,
      photoUrl: photoUrl ?? this.photoUrl,
      photoBlurHash: photoBlurHash ?? this.photoBlurHash,
      travelStyle: travelStyle ?? this.travelStyle,
      mobility: mobility ?? this.mobility,
      totalKindness: totalKindness ?? this.totalKindness,
      totalTravelMoney: totalTravelMoney ?? this.totalTravelMoney,
      totalPostcards: totalPostcards ?? this.totalPostcards,
      isTruthSerumPurchased:
          isTruthSerumPurchased ?? this.isTruthSerumPurchased,
      totalNumberOfActions: totalNumberOfActions ?? this.totalNumberOfActions,
      country: country ?? this.country,
    );
  }
}

class LoginSuccessResponse {
  const LoginSuccessResponse({
    required this.user,
    required this.apiToken,
    required this.profileMeta,
    this.accountRestored = false,
  });

  final UserDto user;
  final String apiToken;
  final ProfileMetaDto profileMeta;
  final bool accountRestored;

  factory LoginSuccessResponse.fromJson(Map<String, dynamic> json) {
    return LoginSuccessResponse(
      user: UserDto.fromJson(
        Map<String, dynamic>.from(json['user'] as Map? ?? {}),
      ),
      apiToken: json['apiToken'] as String? ?? '',
      profileMeta: ProfileMetaDto.fromJson(
        Map<String, dynamic>.from(json['profileMeta'] as Map? ?? {}),
      ),
      accountRestored: json['accountRestored'] as bool? ?? false,
    );
  }
}

class EmailCheckResponse {
  const EmailCheckResponse({required this.isEmailExists, this.apiToken});

  final bool isEmailExists;
  final String? apiToken;

  factory EmailCheckResponse.fromJson(Map<String, dynamic> json) {
    return EmailCheckResponse(
      isEmailExists: json['isEmailExists'] as bool? ?? false,
      apiToken: json['apiToken'] as String?,
    );
  }
}

class RegistrationSuccessResponse {
  const RegistrationSuccessResponse({
    required this.userId,
    required this.apiToken,
    this.otpExpiresAt,
  });

  final String userId;
  final String apiToken;
  final String? otpExpiresAt;

  factory RegistrationSuccessResponse.fromJson(Map<String, dynamic> json) {
    return RegistrationSuccessResponse(
      userId: json['userId'] as String? ?? '',
      apiToken: json['apiToken'] as String? ?? '',
      otpExpiresAt: json['otpExpiresAt'] as String?,
    );
  }
}

class UserInfoResponse {
  const UserInfoResponse({required this.user, required this.profileMeta});

  final UserDto user;
  final ProfileMetaDto profileMeta;

  factory UserInfoResponse.fromJson(Map<String, dynamic> json) {
    return UserInfoResponse(
      user: UserDto.fromJson(
        Map<String, dynamic>.from(json['user'] as Map? ?? {}),
      ),
      profileMeta: ProfileMetaDto.fromJson(
        Map<String, dynamic>.from(json['profileMeta'] as Map? ?? {}),
      ),
    );
  }
}

class SignedUploadUrl {
  const SignedUploadUrl({
    required this.uploadUrl,
    required this.attachmentId,
    this.expiresAt,
  });

  final String uploadUrl;
  final String attachmentId;
  final String? expiresAt;

  factory SignedUploadUrl.fromJson(Map<String, dynamic> json) {
    return SignedUploadUrl(
      uploadUrl: json['uploadUrl'] as String? ?? '',
      attachmentId: json['attachmentId'] as String? ?? '',
      expiresAt: json['expiresAt'] as String?,
    );
  }
}

class RegistrationRequest {
  const RegistrationRequest({
    required this.name,
    required this.profileType,
    required this.mobility,
    required this.storyTime,
    this.email,
    this.age,
    this.totalPostcards = 1,
    this.deviceMetadata = const {},
  });

  final String name;
  final String profileType;
  final String mobility;
  final String storyTime;
  final String? email;
  final int? age;
  final int totalPostcards;
  final Map<String, dynamic> deviceMetadata;

  Map<String, dynamic> toJson() => {
    'name': name,
    'profileType': profileType,
    'mobility': mobility,
    'storyTime': storyTime,
    'email': email,
    'age': age,
    'total_postcards': totalPostcards,
    'deviceMetadata': deviceMetadata,
  };

  factory RegistrationRequest.fromJson(Map<String, dynamic> json) {
    return RegistrationRequest(
      name: json['name'] as String? ?? '',
      profileType: json['profileType'] as String? ?? '',
      mobility: json['mobility'] as String? ?? '',
      storyTime: json['storyTime'] as String? ?? '',
      email: json['email'] as String?,
      age: (json['age'] as num?)?.toInt(),
      totalPostcards: (json['total_postcards'] as num?)?.toInt() ?? 1,
      deviceMetadata: Map<String, dynamic>.from(
        json['deviceMetadata'] as Map? ?? {},
      ),
    );
  }
}
