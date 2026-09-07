import 'package:fairytrail/constants/profile_status.dart';
import 'package:fairytrail/meetups/meetup_category.dart';

class MeetupDto {
  const MeetupDto({
    required this.id,
    required this.creatorProfileId,
    required this.name,
    required this.category,
    required this.startsAt,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.createdAt,
    required this.memberCount,
    required this.joinedByMe,
    required this.isCreator,
    this.distanceKm,
    this.creatorName,
    this.avatars = const [],
  });

  final int id;
  final int creatorProfileId;
  final String name;
  final MeetupCategory category;
  final DateTime startsAt;
  final double latitude;
  final double longitude;
  final String status;
  final DateTime createdAt;
  final int memberCount;
  final bool joinedByMe;
  final bool isCreator;
  final double? distanceKm;
  final String? creatorName;
  /// Signed photo URLs of joined participants (activity-style stack).
  final List<String> avatars;

  bool get isActive => status == 'active';
  bool get isExpired => status == 'expired';

  /// Hard cap for meetup group chats (matches Atlas `MaxMembers`).
  static const maxMembers = 500;

  bool get isFull => memberCount >= maxMembers;

  factory MeetupDto.fromJson(Map<String, dynamic> json) {
    return MeetupDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      creatorProfileId: (json['creatorProfileId'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      category: MeetupCategory.fromApi(json['category'] as String?),
      startsAt:
          DateTime.tryParse(json['startsAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'active',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      joinedByMe: json['joinedByMe'] == true,
      isCreator: json['isCreator'] == true,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      creatorName: json['creatorName'] as String?,
      avatars: (json['avatars'] as List?)
              ?.whereType<String>()
              .where((u) => u.isNotEmpty)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'creatorProfileId': creatorProfileId,
    'name': name,
    'category': category.apiValue,
    'startsAt': startsAt.toUtc().toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'status': status,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'memberCount': memberCount,
    'joinedByMe': joinedByMe,
    'isCreator': isCreator,
    if (distanceKm != null) 'distanceKm': distanceKm,
    if (creatorName != null) 'creatorName': creatorName,
    'avatars': avatars,
  };

  MeetupDto copyWith({
    bool? joinedByMe,
    int? memberCount,
    String? status,
    List<String>? avatars,
  }) => MeetupDto(
    id: id,
    creatorProfileId: creatorProfileId,
    name: name,
    category: category,
    startsAt: startsAt,
    latitude: latitude,
    longitude: longitude,
    status: status ?? this.status,
    createdAt: createdAt,
    memberCount: memberCount ?? this.memberCount,
    joinedByMe: joinedByMe ?? this.joinedByMe,
    isCreator: isCreator,
    distanceKm: distanceKm,
    creatorName: creatorName,
    avatars: avatars ?? this.avatars,
  );
}

class MeetupMemberDto {
  const MeetupMemberDto({
    required this.profileId,
    required this.userId,
    required this.name,
    required this.joinedAt,
    this.profilePictureUrl,
    this.status,
    this.pendingReason,
    this.accountStatus,
  });

  final int profileId;
  final String userId;
  final String name;
  final DateTime joinedAt;
  final String? profilePictureUrl;
  final String? status;
  final String? pendingReason;
  final String? accountStatus;

  bool get isRestricted => profileUserIsRestricted(
    status: status,
    pendingReason: pendingReason,
    accountStatus: accountStatus,
  );

  String get displayName => isRestricted ? 'Fairytrail User' : name;

  String? get displayPhotoUrl => isRestricted ? null : profilePictureUrl;

  factory MeetupMemberDto.fromJson(Map<String, dynamic> json) {
    return MeetupMemberDto(
      profileId: (json['profileId'] as num?)?.toInt() ?? 0,
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      joinedAt:
          DateTime.tryParse(json['joinedAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      profilePictureUrl: json['profilePictureUrl'] as String?,
      status: _optionalStatus(json['status']),
      pendingReason: _optionalStatus(json['pendingReason']),
      accountStatus: _optionalStatus(json['accountStatus']) ?? 'active',
    );
  }
}

class MeetupMessageUserDto {
  const MeetupMessageUserDto({
    required this.id,
    required this.name,
    required this.profileId,
    required this.status,
    required this.accountStatus,
    this.profilePictureUrl,
    this.pendingReason,
  });

  final String id;
  final String name;
  final int profileId;
  final String status;
  final String accountStatus;
  final String? profilePictureUrl;
  final String? pendingReason;

  bool get isRestricted => profileUserIsRestricted(
    status: status,
    pendingReason: pendingReason,
    accountStatus: accountStatus,
  );

  String get displayName => isRestricted ? 'Fairytrail User' : name;

  String? get displayPhotoUrl => isRestricted ? null : profilePictureUrl;

  factory MeetupMessageUserDto.fromJson(Map<String, dynamic> json) {
    return MeetupMessageUserDto(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      profileId: (json['profileId'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      accountStatus: json['accountStatus'] as String? ?? 'active',
      profilePictureUrl: json['profilePictureUrl'] as String?,
      pendingReason: _optionalStatus(json['pendingReason']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'profileId': profileId,
    'status': status,
    'accountStatus': accountStatus,
    if (profilePictureUrl != null) 'profilePictureUrl': profilePictureUrl,
    if (pendingReason != null) 'pendingReason': pendingReason,
  };
}

String? _optionalStatus(dynamic value) {
  if (value == null) return null;
  if (value is String) return value.isEmpty ? null : value;
  if (value is Map) {
    final nested = value['value'] ?? value['name'];
    if (nested != null) {
      final s = nested.toString();
      return s.isEmpty ? null : s;
    }
  }
  final s = value.toString();
  return s.isEmpty ? null : s;
}

class MeetupMessageDto {
  const MeetupMessageDto({
    required this.id,
    required this.meetupId,
    required this.userId,
    required this.message,
    required this.createdAt,
    required this.seenByMe,
    required this.user,
    this.pending = false,
    this.failed = false,
  });

  final String id;
  final int meetupId;
  final String userId;
  final String message;
  final DateTime createdAt;
  final bool seenByMe;
  final MeetupMessageUserDto user;
  final bool pending;
  final bool failed;

  factory MeetupMessageDto.fromJson(Map<String, dynamic> json) {
    return MeetupMessageDto(
      id: json['id'] as String? ?? '',
      meetupId: (json['meetupId'] as num?)?.toInt() ?? 0,
      userId: json['userId'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      seenByMe: json['seenByMe'] == true,
      user: MeetupMessageUserDto.fromJson(
        Map<String, dynamic>.from(json['user'] as Map? ?? {}),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'meetupId': meetupId,
    'userId': userId,
    'message': message,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'seenByMe': seenByMe,
    'user': user.toJson(),
  };

  MeetupMessageDto copyWith({bool? seenByMe, bool? pending, bool? failed}) =>
      MeetupMessageDto(
        id: id,
        meetupId: meetupId,
        userId: userId,
        message: message,
        createdAt: createdAt,
        seenByMe: seenByMe ?? this.seenByMe,
        user: user,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
      );
}

class MeetupChatDto {
  const MeetupChatDto({
    required this.id,
    required this.meetup,
    required this.createdAt,
    required this.memberCount,
    this.lastMessage,
  });

  final int id;
  final MeetupDto meetup;
  final DateTime createdAt;
  final int memberCount;
  final MeetupMessageDto? lastMessage;

  DateTime get sortAt => lastMessage?.createdAt ?? createdAt;

  factory MeetupChatDto.fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'];
    return MeetupChatDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      meetup: MeetupDto.fromJson(
        Map<String, dynamic>.from(json['meetup'] as Map? ?? {}),
      ),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      lastMessage: last is Map
          ? MeetupMessageDto.fromJson(Map<String, dynamic>.from(last))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'meetup': meetup.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'memberCount': memberCount,
    if (lastMessage != null) 'lastMessage': lastMessage!.toJson(),
  };

  MeetupChatDto copyWith({
    MeetupMessageDto? lastMessage,
    int? memberCount,
    MeetupDto? meetup,
  }) => MeetupChatDto(
    id: id,
    meetup: meetup ?? this.meetup,
    createdAt: createdAt,
    memberCount: memberCount ?? this.memberCount,
    lastMessage: lastMessage ?? this.lastMessage,
  );
}

class MeetupTermsStatus {
  const MeetupTermsStatus({required this.accepted, required this.termsVersion});

  final bool accepted;
  final int termsVersion;

  factory MeetupTermsStatus.fromJson(Map<String, dynamic> json) {
    return MeetupTermsStatus(
      accepted: json['accepted'] == true,
      termsVersion: (json['termsVersion'] as num?)?.toInt() ?? 1,
    );
  }
}
