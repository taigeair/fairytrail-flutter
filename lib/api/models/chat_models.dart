import 'package:fairytrail/api/models/activity_models.dart';
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/api/models/meetup_models.dart';
import 'package:fairytrail/constants/profile_status.dart';

class ChatProfileDto {
  const ChatProfileDto({
    required this.id,
    required this.name,
    this.previewUrl,
    this.blurHash,
    this.status,
    this.pendingReason,
    this.accountStatus,
    this.profileType,
    this.country,
  });

  final int id;
  final String name;
  final String? previewUrl;
  final String? blurHash;
  final String? status;
  final String? pendingReason;
  final String? accountStatus;
  final String? profileType;
  final CountryDto? country;

  /// Deleted / disabled / paused / nudity-risk pending — show placeholder, don't open profile.
  bool get isRestricted => profileUserIsRestricted(
    status: status,
    pendingReason: pendingReason,
    accountStatus: accountStatus,
  );

  String get displayName => isRestricted ? 'Fairytrail User' : name;

  String? get displayPhotoUrl => isRestricted ? null : previewUrl;

  String? get displayBlurHash => isRestricted ? null : blurHash;

  factory ChatProfileDto.fromJson(Map<String, dynamic> json) => ChatProfileDto(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    previewUrl: json['previewUrl'] as String?,
    blurHash: json['blurHash'] as String?,
    status: _statusString(json['status']),
    pendingReason: _pendingReasonString(json['pendingReason']),
    accountStatus: _statusString(json['accountStatus']),
    profileType: json['profileType'] as String?,
    country: json['country'] is Map
        ? CountryDto.fromJson(Map<String, dynamic>.from(json['country'] as Map))
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (previewUrl != null) 'previewUrl': previewUrl,
    if (blurHash != null) 'blurHash': blurHash,
    if (status != null) 'status': status,
    if (pendingReason != null) 'pendingReason': pendingReason,
    if (accountStatus != null) 'accountStatus': accountStatus,
    if (profileType != null) 'profileType': profileType,
    if (country != null) 'country': country!.toJson(),
  };
}

String? _statusString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value.isEmpty ? null : value;
  if (value is Map) {
    final nested = value['value'] ?? value['name'];
    if (nested != null) return nested.toString();
  }
  return value.toString();
}

String? _pendingReasonString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value.isEmpty ? null : value;
  if (value is Map) {
    final nested = value['value'] ?? value['name'];
    if (nested != null) return nested.toString();
  }
  return value.toString();
}

class ChatMessageDto {
  const ChatMessageDto({
    required this.id,
    required this.matchId,
    required this.userId,
    required this.message,
    required this.createdAt,
    this.seenByMe = false,
    this.seenByOther = false,
    this.pending = false,
    this.failed = false,
  });

  final String id;
  final int matchId;
  final String userId;
  final String message;
  final DateTime createdAt;
  final bool seenByMe;
  final bool seenByOther;
  final bool pending;
  final bool failed;

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) => ChatMessageDto(
    id: json['id'] as String? ?? '',
    matchId: (json['matchId'] as num?)?.toInt() ?? 0,
    userId: json['userId'] as String? ?? '',
    message: json['message'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    seenByMe: json['seenByMe'] as bool? ?? false,
    seenByOther: json['seenByOther'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'matchId': matchId,
    'userId': userId,
    'message': message,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'seenByMe': seenByMe,
    'seenByOther': seenByOther,
  };

  ChatMessageDto copyWith({
    bool? seenByMe,
    bool? seenByOther,
    bool? pending,
    bool? failed,
    String? message,
  }) => ChatMessageDto(
    id: id,
    matchId: matchId,
    userId: userId,
    message: message ?? this.message,
    createdAt: createdAt,
    seenByMe: seenByMe ?? this.seenByMe,
    seenByOther: seenByOther ?? this.seenByOther,
    pending: pending ?? this.pending,
    failed: failed ?? this.failed,
  );
}

class MatchDto {
  const MatchDto({
    required this.id,
    required this.profile,
    required this.createdAt,
    this.lastMessage,
    this.canBeDeleted = false,
  });

  final int id;
  final ChatProfileDto profile;
  final DateTime createdAt;
  final ChatMessageDto? lastMessage;
  final bool canBeDeleted;

  factory MatchDto.fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'];
    return MatchDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      profile: ChatProfileDto.fromJson(
        Map<String, dynamic>.from(json['profile'] as Map? ?? {}),
      ),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      lastMessage: last is Map
          ? ChatMessageDto.fromJson(Map<String, dynamic>.from(last))
          : null,
      canBeDeleted: json['canBeDeleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'profile': profile.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (lastMessage != null) 'lastMessage': lastMessage!.toJson(),
    'canBeDeleted': canBeDeleted,
  };

  MatchDto copyWith({
    int? id,
    ChatProfileDto? profile,
    DateTime? createdAt,
    ChatMessageDto? lastMessage,
    bool? canBeDeleted,
  }) => MatchDto(
    id: id ?? this.id,
    profile: profile ?? this.profile,
    createdAt: createdAt ?? this.createdAt,
    lastMessage: lastMessage ?? this.lastMessage,
    canBeDeleted: canBeDeleted ?? this.canBeDeleted,
  );

  /// Local-only stub so chat can open before the matches inbox is ready.
  factory MatchDto.provisional({
    required int profileId,
    required String name,
    String? previewUrl,
    String? blurHash,
    CountryDto? country,
  }) => MatchDto(
    id: 0,
    profile: ChatProfileDto(
      id: profileId,
      name: name,
      previewUrl: previewUrl,
      blurHash: blurHash,
      country: country,
    ),
    createdAt: DateTime.now(),
  );

  DateTime get sortAt => lastMessage?.createdAt ?? createdAt;
}

class ActivityChatMessageUserDto {
  const ActivityChatMessageUserDto({
    required this.id,
    required this.name,
    required this.profileId,
    this.profilePictureUrl,
    this.status,
    this.pendingReason,
    this.accountStatus,
  });

  final String id;
  final String name;
  final int profileId;
  final String? profilePictureUrl;
  final String? status;
  final String? pendingReason;
  final String? accountStatus;

  /// Deleted / disabled / paused / nudity-risk pending — show placeholder, don't open profile.
  bool get isRestricted => profileUserIsRestricted(
    status: status,
    pendingReason: pendingReason,
    accountStatus: accountStatus,
  );

  String get displayName => isRestricted ? 'Fairytrail User' : name;

  String? get displayPhotoUrl => isRestricted ? null : profilePictureUrl;

  factory ActivityChatMessageUserDto.fromJson(Map<String, dynamic> json) {
    return ActivityChatMessageUserDto(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      profileId: (json['profileId'] as num?)?.toInt() ?? 0,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      status: _statusString(json['status']),
      pendingReason: _pendingReasonString(json['pendingReason']),
      accountStatus: _statusString(json['accountStatus']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'profileId': profileId,
    if (profilePictureUrl != null) 'profilePictureUrl': profilePictureUrl,
    if (status != null) 'status': status,
    if (pendingReason != null) 'pendingReason': pendingReason,
    if (accountStatus != null) 'accountStatus': accountStatus,
  };
}

class ActivityChatMessageDto {
  const ActivityChatMessageDto({
    required this.id,
    required this.activityChatId,
    required this.userId,
    required this.message,
    required this.createdAt,
    this.seenByMe = false,
    this.user,
    this.pending = false,
    this.failed = false,
  });

  final String id;
  final int activityChatId;
  final String userId;
  final String message;
  final DateTime createdAt;
  final bool seenByMe;
  final ActivityChatMessageUserDto? user;
  final bool pending;
  final bool failed;

  factory ActivityChatMessageDto.fromJson(Map<String, dynamic> json) {
    final userRaw = json['user'];
    return ActivityChatMessageDto(
      id: json['id'] as String? ?? '',
      activityChatId: (json['activityChatId'] as num?)?.toInt() ?? 0,
      userId: json['userId'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      seenByMe: json['seenByMe'] as bool? ?? false,
      user: userRaw is Map
          ? ActivityChatMessageUserDto.fromJson(
              Map<String, dynamic>.from(userRaw),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'activityChatId': activityChatId,
    'userId': userId,
    'message': message,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'seenByMe': seenByMe,
    if (user != null) 'user': user!.toJson(),
  };

  ActivityChatMessageDto copyWith({
    bool? seenByMe,
    bool? pending,
    bool? failed,
  }) => ActivityChatMessageDto(
    id: id,
    activityChatId: activityChatId,
    userId: userId,
    message: message,
    createdAt: createdAt,
    seenByMe: seenByMe ?? this.seenByMe,
    user: user,
    pending: pending ?? this.pending,
    failed: failed ?? this.failed,
  );
}

class ActivityChatDto {
  const ActivityChatDto({
    required this.id,
    required this.activity,
    required this.createdAt,
    required this.memberCount,
    this.lastMessage,
  });

  final int id;
  final ActivityDto activity;
  final DateTime createdAt;
  final int memberCount;
  final ActivityChatMessageDto? lastMessage;

  factory ActivityChatDto.fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'];
    return ActivityChatDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      activity: ActivityDto.fromJson(
        Map<String, dynamic>.from(json['activity'] as Map? ?? {}),
      ),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      lastMessage: last is Map
          ? ActivityChatMessageDto.fromJson(Map<String, dynamic>.from(last))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'activity': activity.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'memberCount': memberCount,
    if (lastMessage != null) 'lastMessage': lastMessage!.toJson(),
  };

  ActivityChatDto copyWith({
    ActivityChatMessageDto? lastMessage,
    int? memberCount,
  }) => ActivityChatDto(
    id: id,
    activity: activity,
    createdAt: createdAt,
    memberCount: memberCount ?? this.memberCount,
    lastMessage: lastMessage ?? this.lastMessage,
  );

  DateTime get sortAt => lastMessage?.createdAt ?? createdAt;
}

enum InboxItemKind { match, activity, meetup }

class InboxItem {
  const InboxItem.match(this.match)
    : activityChat = null,
      meetupChat = null,
      kind = InboxItemKind.match;
  const InboxItem.activity(this.activityChat)
    : match = null,
      meetupChat = null,
      kind = InboxItemKind.activity;
  const InboxItem.meetup(this.meetupChat)
    : match = null,
      activityChat = null,
      kind = InboxItemKind.meetup;

  final InboxItemKind kind;
  final MatchDto? match;
  final ActivityChatDto? activityChat;
  final MeetupChatDto? meetupChat;

  DateTime get sortAt => switch (kind) {
    InboxItemKind.match => match!.sortAt,
    InboxItemKind.activity => activityChat!.sortAt,
    InboxItemKind.meetup => meetupChat!.sortAt,
  };

  String get title => switch (kind) {
    InboxItemKind.match => match!.profile.displayName,
    InboxItemKind.activity => activityChat!.activity.displayTitle,
    InboxItemKind.meetup => meetupChat!.meetup.name,
  };

  String? get previewText => switch (kind) {
    InboxItemKind.match => match!.lastMessage?.message,
    InboxItemKind.activity => activityChat!.lastMessage?.message,
    InboxItemKind.meetup => meetupChat!.lastMessage?.message,
  };

  /// Unread only when the latest message is from someone else and not seen yet.
  bool hasUnreadFor(String? currentUserId) {
    if (kind == InboxItemKind.match) {
      final last = match!.lastMessage;
      if (last == null) return false;
      if (currentUserId != null && last.userId == currentUserId) return false;
      return !last.seenByMe;
    }
    if (kind == InboxItemKind.activity) {
      final last = activityChat!.lastMessage;
      if (last == null) return false;
      if (currentUserId != null && last.userId == currentUserId) return false;
      return !last.seenByMe;
    }
    final last = meetupChat!.lastMessage;
    if (last == null) return false;
    if (currentUserId != null && last.userId == currentUserId) return false;
    return !last.seenByMe;
  }
}
