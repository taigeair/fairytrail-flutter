import 'package:fairytrail/api/models/explore_models.dart';

enum BucketListActivityTag {
  currentYear('current_year'),
  upcoming('upcoming'),
  completed('completed');

  const BucketListActivityTag(this.apiValue);
  final String apiValue;

  static BucketListActivityTag fromApi(String? raw) {
    switch (raw) {
      case 'current_year':
        return BucketListActivityTag.currentYear;
      case 'completed':
        return BucketListActivityTag.completed;
      case 'upcoming':
      default:
        return BucketListActivityTag.upcoming;
    }
  }
}

class ActivityPhotoDto {
  const ActivityPhotoDto({
    required this.attachmentId,
    required this.url,
    this.thumbnailUrl,
  });

  final String attachmentId;
  final String url;
  final String? thumbnailUrl;

  factory ActivityPhotoDto.fromJson(Map<String, dynamic> json) =>
      ActivityPhotoDto(
        attachmentId: json['attachmentId'] as String? ?? '',
        url: json['url'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'attachmentId': attachmentId,
    'url': url,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
  };

  String get displayUrl =>
      (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) ? thumbnailUrl! : url;
}

class ActivityDto {
  const ActivityDto({
    required this.id,
    required this.photo,
    required this.name,
    this.country,
    this.explorerCount = 0,
    this.memberCount = 0,
    this.isSaved = false,
    this.avatars = const [],
    this.completedDate,
    this.isEditable = false,
    this.tag = BucketListActivityTag.upcoming,
  });

  final int id;
  final ActivityPhotoDto photo;
  final String name;
  final CountryDto? country;
  final int explorerCount;
  final int memberCount;
  final bool isSaved;
  final List<String> avatars;
  final String? completedDate;
  final bool isEditable;
  final BucketListActivityTag tag;

  String get displayTitle {
    final c = country?.country;
    if (c == null || c.isEmpty) return name;
    return '$name, $c';
  }

  factory ActivityDto.fromJson(Map<String, dynamic> json) {
    final photoRaw = json['photo'];
    final countryRaw = json['country'];
    final avatarsRaw = json['avatars'];
    final chatRaw = json['activityChat'] ?? json['chat'];
    return ActivityDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      photo: photoRaw is Map
          ? ActivityPhotoDto.fromJson(Map<String, dynamic>.from(photoRaw))
          : const ActivityPhotoDto(attachmentId: '', url: ''),
      name: json['name'] as String? ?? '',
      country: countryRaw is Map
          ? CountryDto.fromJson(Map<String, dynamic>.from(countryRaw))
          : null,
      explorerCount: (json['explorerCount'] as num?)?.toInt() ?? 0,
      memberCount:
          (json['memberCount'] as num?)?.toInt() ??
          (json['chatMemberCount'] as num?)?.toInt() ??
          (chatRaw is Map ? (chatRaw['memberCount'] as num?)?.toInt() ?? 0 : 0),
      isSaved: json['isSaved'] as bool? ?? false,
      avatars: avatarsRaw is List
          ? avatarsRaw.whereType<String>().where((s) => s.isNotEmpty).toList()
          : const [],
      completedDate: json['completedDate'] as String?,
      isEditable: json['isEditable'] as bool? ?? false,
      tag: BucketListActivityTag.fromApi(json['tag'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'photo': photo.toJson(),
    'name': name,
    if (country != null) 'country': country!.toJson(),
    'explorerCount': explorerCount,
    'memberCount': memberCount,
    'isSaved': isSaved,
    'avatars': avatars,
    if (completedDate != null) 'completedDate': completedDate,
    'isEditable': isEditable,
    'tag': tag.apiValue,
  };

  ActivityDto copyWith({
    int? id,
    ActivityPhotoDto? photo,
    String? name,
    CountryDto? country,
    int? explorerCount,
    int? memberCount,
    bool? isSaved,
    List<String>? avatars,
    String? completedDate,
    bool clearCompletedDate = false,
    bool? isEditable,
    BucketListActivityTag? tag,
  }) {
    return ActivityDto(
      id: id ?? this.id,
      photo: photo ?? this.photo,
      name: name ?? this.name,
      country: country ?? this.country,
      explorerCount: explorerCount ?? this.explorerCount,
      memberCount: memberCount ?? this.memberCount,
      isSaved: isSaved ?? this.isSaved,
      avatars: avatars ?? this.avatars,
      completedDate: clearCompletedDate
          ? null
          : (completedDate ?? this.completedDate),
      isEditable: isEditable ?? this.isEditable,
      tag: tag ?? this.tag,
    );
  }
}

class ActivitiesPageResponse {
  const ActivitiesPageResponse({
    required this.activities,
    this.lastExplorerCount,
    this.lastId,
    this.snapshotDate,
    this.hasMore = false,
  });

  final List<ActivityDto> activities;
  final int? lastExplorerCount;
  final int? lastId;
  final String? snapshotDate;
  final bool hasMore;

  factory ActivitiesPageResponse.fromJson(Map<String, dynamic> json) {
    final list = json['activities'];
    return ActivitiesPageResponse(
      activities: list is List
          ? list
                .whereType<Map>()
                .map((e) => ActivityDto.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
      lastExplorerCount: (json['lastExplorerCount'] as num?)?.toInt(),
      lastId: (json['lastId'] as num?)?.toInt(),
      snapshotDate: json['snapshotDate'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

class SavedExplorerDto {
  const SavedExplorerDto({
    required this.id,
    required this.name,
    this.previewUrl,
    this.blurHash,
    this.accountStatus,
  });

  final int id;
  final String name;
  final String? previewUrl;
  final String? blurHash;
  final String? accountStatus;

  /// Paused accounts show as Fairytrail User (no profile open).
  bool get isRestricted => accountStatus == 'paused';

  String get displayName => isRestricted ? 'Fairytrail User' : name;

  String? get displayPhotoUrl => isRestricted ? null : previewUrl;

  factory SavedExplorerDto.fromJson(Map<String, dynamic> json) =>
      SavedExplorerDto(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        previewUrl: json['previewUrl'] as String?,
        blurHash: json['blurHash'] as String?,
        accountStatus: json['accountStatus'] as String?,
      );
}

class SavedExplorersResponse {
  const SavedExplorersResponse({
    required this.explorers,
    this.lastId,
    this.hasMore = false,
  });

  final List<SavedExplorerDto> explorers;
  final int? lastId;
  final bool hasMore;

  factory SavedExplorersResponse.fromJson(Map<String, dynamic> json) {
    final list = json['explorers'];
    return SavedExplorersResponse(
      explorers: list is List
          ? list
                .whereType<Map>()
                .map(
                  (e) =>
                      SavedExplorerDto.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const [],
      lastId: (json['lastId'] as num?)?.toInt(),
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

class AddActivityPropsResponse {
  const AddActivityPropsResponse({required this.countries});

  final List<CountryDto> countries;

  factory AddActivityPropsResponse.fromJson(Map<String, dynamic> json) {
    return AddActivityPropsResponse(
      countries: CountryDto.listFromJson(json['countries']),
    );
  }
}

class BucketListDto {
  const BucketListDto({required this.id, required this.activities});

  final int id;
  final List<ActivityDto> activities;

  factory BucketListDto.fromJson(Map<String, dynamic> json) {
    final list = json['activities'];
    return BucketListDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      activities: list is List
          ? list
                .whereType<Map>()
                .map((e) => ActivityDto.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
    );
  }
}
