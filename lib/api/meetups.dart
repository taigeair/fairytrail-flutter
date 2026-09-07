import 'package:fairytrail/api/models/meetup_models.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

Future<MeetupTermsStatus> fetchMeetupTermsStatus() async {
  final res = await HttpClient.instance.request(
    path: EndPoints.meetupTerms,
    requiresAuth: true,
    baseUrl: EndPoints.atlasUrl,
  );
  return MeetupTermsStatus.fromJson(Map<String, dynamic>.from(res.data as Map));
}

Future<MeetupTermsStatus> acceptMeetupTerms() async {
  final res = await HttpClient.instance.request(
    path: EndPoints.meetupTermsAccept,
    method: HttpMethod.post,
    requiresAuth: true,
    baseUrl: EndPoints.atlasUrl,
  );
  return MeetupTermsStatus.fromJson(Map<String, dynamic>.from(res.data as Map));
}

Future<List<MeetupDto>> fetchNearbyMeetups({
  required double latitude,
  required double longitude,
}) async {
  final res = await HttpClient.instance.request(
    path:
        '${EndPoints.meetups}?lat=$latitude&lng=$longitude',
    requiresAuth: true,
    baseUrl: EndPoints.atlasUrl,
  );
  final list = (res.data as Map?)?['meetups'];
  if (list is! List) return const [];
  return list
      .whereType<Map>()
      .map((e) => MeetupDto.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

Future<MeetupDto> fetchMeetup(int id) async {
  final res = await HttpClient.instance.request(
    path: EndPoints.meetupById(id),
    requiresAuth: true,
    baseUrl: EndPoints.atlasUrl,
  );
  return MeetupDto.fromJson(
    Map<String, dynamic>.from((res.data as Map)['meetup'] as Map),
  );
}

Future<MeetupDto> createMeetup({
  required String name,
  required String category,
  required DateTime startsAt,
  required double latitude,
  required double longitude,
}) async {
  final res = await HttpClient.instance.request(
    path: EndPoints.meetups,
    method: HttpMethod.post,
    requiresAuth: true,
    baseUrl: EndPoints.atlasUrl,
    body: {
      'name': name,
      'category': category,
      'startsAt': startsAt.toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    },
  );
  return MeetupDto.fromJson(
    Map<String, dynamic>.from((res.data as Map)['meetup'] as Map),
  );
}

Future<void> deleteMeetup(int id) async {
  await HttpClient.instance.request(
    path: EndPoints.meetupById(id),
    method: HttpMethod.delete,
    requiresAuth: true,
    baseUrl: EndPoints.atlasUrl,
  );
}

Future<MeetupDto> joinMeetup(int id) async {
  final res = await HttpClient.instance.request(
    path: EndPoints.meetupJoin(id),
    method: HttpMethod.post,
    requiresAuth: true,
    baseUrl: EndPoints.atlasUrl,
  );
  return MeetupDto.fromJson(
    Map<String, dynamic>.from((res.data as Map)['meetup'] as Map),
  );
}

Future<void> leaveMeetup(int id) async {
  await HttpClient.instance.request(
    path: EndPoints.meetupLeave(id),
    method: HttpMethod.delete,
    requiresAuth: true,
    baseUrl: EndPoints.atlasUrl,
  );
}

Future<List<MeetupMemberDto>> fetchMeetupMembers(int id) async {
  final res = await HttpClient.instance.request(
    path: EndPoints.meetupMembers(id),
    requiresAuth: true,
    baseUrl: EndPoints.atlasUrl,
  );
  final list = (res.data as Map?)?['members'];
  if (list is! List) return const [];
  return list
      .whereType<Map>()
      .map((e) => MeetupMemberDto.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

Future<void> reportMeetup({required int id, required String reason}) async {
  await HttpClient.instance.request(
    path: EndPoints.meetupReport(id),
    method: HttpMethod.post,
    requiresAuth: true,
    baseUrl: EndPoints.atlasUrl,
    body: {'reason': reason},
  );
}

Future<List<MeetupChatDto>> fetchMeetupChats() async {
  final res = await HttpClient.instance.request(
    path: EndPoints.meetupChats,
    requiresAuth: true,
    baseUrl: EndPoints.atlasUrl,
  );
  final list = (res.data as Map?)?['meetupChats'];
  if (list is! List) return const [];
  return list
      .whereType<Map>()
      .map((e) => MeetupChatDto.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

class MeetupMessagesPage {
  const MeetupMessagesPage({
    required this.messages,
    required this.hasMore,
    this.nextCursor,
  });

  final List<MeetupMessageDto> messages;
  final bool hasMore;
  final String? nextCursor;
}

Future<MeetupMessagesPage> fetchMeetupMessages(
  int meetupId, {
  String? cursor,
}) async {
  final path = cursor == null || cursor.isEmpty
      ? EndPoints.meetupMessages(meetupId)
      : '${EndPoints.meetupMessages(meetupId)}?cursor=${Uri.encodeQueryComponent(cursor)}';
  final res = await HttpClient.instance.request(
    path: path,
    requiresAuth: true,
    baseUrl: EndPoints.atlasUrl,
  );
  final data = res.data as Map? ?? {};
  final list = data['messages'];
  final messages = list is List
      ? list
            .whereType<Map>()
            .map((e) => MeetupMessageDto.fromJson(Map<String, dynamic>.from(e)))
            .toList()
      : <MeetupMessageDto>[];
  return MeetupMessagesPage(
    messages: messages,
    hasMore: data['hasMore'] == true,
    nextCursor: data['nextCursor'] as String?,
  );
}

Future<MeetupMessageDto> sendMeetupMessage({
  required int meetupId,
  required String id,
  required String message,
}) async {
  final res = await HttpClient.instance.request(
    path: EndPoints.meetupMessages(meetupId),
    method: HttpMethod.post,
    requiresAuth: true,
    baseUrl: EndPoints.atlasUrl,
    body: {'id': id, 'message': message},
  );
  return MeetupMessageDto.fromJson(
    Map<String, dynamic>.from((res.data as Map)['message'] as Map),
  );
}

Future<void> markMeetupSeen(int meetupId) async {
  await HttpClient.instance.request(
    path: EndPoints.meetupSeen(meetupId),
    method: HttpMethod.post,
    requiresAuth: true,
    baseUrl: EndPoints.atlasUrl,
  );
}
