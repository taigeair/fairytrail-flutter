class TrailBookItemDto {
  const TrailBookItemDto({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.isAnonymous,
    required this.createdAt,
    this.userIp = '',
    this.senderLocation = '',
    this.type = 'postcard',
    this.isSenderDeleted = false,
    this.isSenderReported = false,
    this.isSenderUnmatched = false,
  });

  final int id;
  final int senderId;
  final String senderName;
  final String message;
  final bool isAnonymous;
  final DateTime createdAt;
  final String userIp;
  final String senderLocation;
  final String type;
  final bool isSenderDeleted;
  final bool isSenderReported;
  final bool isSenderUnmatched;

  bool get isPostcard => type == 'postcard';

  String get displaySenderName {
    if (isAnonymous ||
        isSenderDeleted ||
        isSenderReported ||
        isSenderUnmatched) {
      return 'Anonymous';
    }
    return senderName;
  }

  factory TrailBookItemDto.fromJson(Map<String, dynamic> json) {
    return TrailBookItemDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      senderId: (json['senderId'] as num?)?.toInt() ?? 0,
      senderName: json['senderName'] as String? ?? '',
      message: json['message'] as String? ?? '',
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      userIp: json['userIp'] as String? ?? '',
      senderLocation: json['senderLocation'] as String? ?? '',
      type: json['type'] as String? ?? 'postcard',
      isSenderDeleted: json['isSenderDeleted'] as bool? ?? false,
      isSenderReported: json['isSenderReported'] as bool? ?? false,
      isSenderUnmatched: json['isSenderUnmatched'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'message': message,
        'isAnonymous': isAnonymous,
        'createdAt': createdAt.toIso8601String(),
        'userIp': userIp,
        'senderLocation': senderLocation,
        'type': type,
        'isSenderDeleted': isSenderDeleted,
        'isSenderReported': isSenderReported,
        'isSenderUnmatched': isSenderUnmatched,
      };
}

class TrailBookListResponse {
  const TrailBookListResponse({
    required this.items,
    required this.hasMore,
    required this.page,
  });

  final List<TrailBookItemDto> items;
  final bool hasMore;
  final int page;

  factory TrailBookListResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final pagination = json['pagination'];
    return TrailBookListResponse(
      items: data is List
          ? data
              .whereType<Map>()
              .map((e) => TrailBookItemDto.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      hasMore: pagination is Map
          ? pagination['hasMore'] as bool? ?? false
          : false,
      page: pagination is Map
          ? (pagination['page'] as num?)?.toInt() ?? 1
          : 1,
    );
  }
}

class UpdatePostcardsResponse {
  const UpdatePostcardsResponse({
    required this.success,
    required this.totalPostcards,
  });

  final bool success;
  final int totalPostcards;

  factory UpdatePostcardsResponse.fromJson(Map<String, dynamic> json) {
    return UpdatePostcardsResponse(
      success: json['success'] as bool? ?? false,
      totalPostcards: (json['total_postcards'] as num?)?.toInt() ?? 0,
    );
  }
}

class TrailBookUnreadResponse {
  const TrailBookUnreadResponse({
    this.postcard,
    this.totalUnread = 0,
  });

  final TrailBookItemDto? postcard;
  final int totalUnread;

  factory TrailBookUnreadResponse.fromJson(Map<String, dynamic> json) {
    final postcards = json['postcards'];
    if (postcards is! Map) {
      return const TrailBookUnreadResponse();
    }
    final item = postcards['postcard'];
    return TrailBookUnreadResponse(
      totalUnread: (postcards['totalUnread'] as num?)?.toInt() ?? 0,
      postcard: item is Map
          ? TrailBookItemDto.fromJson(Map<String, dynamic>.from(item))
          : null,
    );
  }
}
