import 'package:fairytrail/api/models/chat_models.dart';
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

Future<List<MatchDto>> fetchMatches({String? timestamp}) async {
  final ts = timestamp ?? EndPoints.matchesSyncEpoch;
  final response = await HttpClient.instance.request(
    path: EndPoints.matchesSince(ts),
    method: HttpMethod.get,
    requiresAuth: true,
  );
  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected matches response',
      payload: data,
    );
  }
  final list = data['matches'];
  if (list is! List) return const [];
  return list
      .whereType<Map>()
      .map((e) => MatchDto.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

Future<List<ActivityChatDto>> fetchActivityChats() async {
  final response = await HttpClient.instance.request(
    path: EndPoints.activityChats,
    method: HttpMethod.get,
    requiresAuth: true,
  );
  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected activity chats response',
      payload: data,
    );
  }
  final list = data['activityChats'];
  if (list is! List) return const [];
  return list
      .whereType<Map>()
      .map((e) => ActivityChatDto.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

Future<int> fetchUnreadCount() async {
  final response = await HttpClient.instance.request(
    path: EndPoints.unread,
    method: HttpMethod.get,
    requiresAuth: true,
  );
  final data = response.data;
  if (data is! Map) return 0;
  return (data['unreadMessagesCount'] as num?)?.toInt() ?? 0;
}

Future<List<ChatMessageDto>> fetchMatchMessages({
  required int profileId,
}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.matchMessages(profileId),
    method: HttpMethod.get,
    requiresAuth: true,
  );
  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected messages response',
      payload: data,
    );
  }
  final list = data['messages'];
  if (list is! List) return const [];
  return list
      .whereType<Map>()
      .map((e) => ChatMessageDto.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

Future<ChatMessageDto> sendMatchMessage({
  required int profileId,
  required String id,
  required String message,
}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.matchMessages(profileId),
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'id': id, 'message': message},
  );
  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected send response',
      payload: data,
    );
  }
  final msg = data['message'];
  if (msg is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Missing message in response',
      payload: data,
    );
  }
  return ChatMessageDto.fromJson(Map<String, dynamic>.from(msg));
}

Future<void> markMatchSeen({required int profileId}) async {
  await HttpClient.instance.request(
    path: EndPoints.matchSeen(profileId),
    method: HttpMethod.post,
    requiresAuth: true,
  );
}

class ActivityMessagesPage {
  const ActivityMessagesPage({
    required this.messages,
    this.nextCursor,
    this.hasMore = false,
  });

  final List<ActivityChatMessageDto> messages;
  final String? nextCursor;
  final bool hasMore;
}

Future<ActivityMessagesPage> fetchActivityMessages({
  required int activityId,
  String? cursor,
}) async {
  final path = cursor == null || cursor.isEmpty
      ? EndPoints.activityMessages(activityId)
      : '${EndPoints.activityMessages(activityId)}?cursor=${Uri.encodeQueryComponent(cursor)}';

  final response = await HttpClient.instance.request(
    path: path,
    method: HttpMethod.get,
    requiresAuth: true,
  );
  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected activity messages response',
      payload: data,
    );
  }
  final list = data['messages'];
  return ActivityMessagesPage(
    messages: list is List
        ? list
              .whereType<Map>()
              .map(
                (e) => ActivityChatMessageDto.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
        : const [],
    nextCursor: data['nextCursor'] as String?,
    hasMore: data['hasMore'] as bool? ?? false,
  );
}

Future<ActivityChatMessageDto> sendActivityMessage({
  required int activityId,
  required String id,
  required String message,
}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.activityMessages(activityId),
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'id': id, 'message': message},
  );
  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected send response',
      payload: data,
    );
  }
  final msg = data['message'];
  if (msg is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Missing message in response',
      payload: data,
    );
  }
  return ActivityChatMessageDto.fromJson(Map<String, dynamic>.from(msg));
}

Future<void> markActivitySeen({required int activityId}) async {
  await HttpClient.instance.request(
    path: EndPoints.activitySeen(activityId),
    method: HttpMethod.post,
    requiresAuth: true,
  );
}

Future<ActivityChatDto> joinActivityChat({required int activityId}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.activityJoinChat(activityId),
    method: HttpMethod.post,
    requiresAuth: true,
  );
  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected join chat response',
      payload: data,
    );
  }
  final chat = data['activityChat'];
  if (chat is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Missing activityChat in response',
      payload: data,
    );
  }
  return ActivityChatDto.fromJson(Map<String, dynamic>.from(chat));
}

Future<void> leaveActivityChat({required int activityId}) async {
  await HttpClient.instance.request(
    path: EndPoints.activityLeaveChat(activityId),
    method: HttpMethod.delete,
    requiresAuth: true,
  );
}

Future<void> unmatchProfile({required int profileId}) async {
  await HttpClient.instance.request(
    path: EndPoints.profilesUnmatch,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'profileId': profileId},
  );
}

Future<FullProfileDto> viewProfile({required int profileId}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.profileView(profileId),
    method: HttpMethod.get,
    requiresAuth: true,
  );
  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected profile response',
      payload: data,
    );
  }
  final profile = data['profile'];
  if (profile is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Missing profile in response',
      payload: data,
    );
  }
  return FullProfileDto.fromJson(Map<String, dynamic>.from(profile));
}
