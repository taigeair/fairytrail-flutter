import 'package:fairytrail/api/models/trail_book_models.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

Future<bool> sendPostcard({
  required int receiverId,
  required String message,
  required bool isAnonymous,
  String senderLocation = '',
}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.sendCareNote,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {
      'receiverId': receiverId,
      'message': message,
      'isAnonymous': isAnonymous,
      'type': 'postcard',
      'senderLocation': senderLocation,
    },
  );

  final data = response.data;
  if (data is Map && data['success'] == true) return true;
  // Some responses are empty / 204-ish after success.
  if (response.statusCode >= 200 && response.statusCode < 300) return true;
  throw ApiException(
    statusCode: response.statusCode,
    message: 'Failed to send postcard',
    payload: data,
  );
}

Future<UpdatePostcardsResponse> updatePostcardsCredits({
  required Map<String, dynamic> transaction,
  required String productIdentifier,
  String location = '',
}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.updatePostcards,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {
      'transaction': transaction,
      'location': location,
      'productIdentifier': productIdentifier,
    },
  );

  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected update-postcards response',
      payload: data,
    );
  }
  return UpdatePostcardsResponse.fromJson(Map<String, dynamic>.from(data));
}

Future<TrailBookListResponse> fetchTrailBook({int page = 1}) async {
  final response = await HttpClient.instance.request(
    path: '${EndPoints.trailBook}?page=$page',
    method: HttpMethod.get,
    requiresAuth: true,
  );

  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected trail-book response',
      payload: data,
    );
  }
  return TrailBookListResponse.fromJson(Map<String, dynamic>.from(data));
}

Future<TrailBookItemDto> fetchTrailBookItem(int id) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.trailBookById(id),
    method: HttpMethod.get,
    requiresAuth: true,
  );

  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected trail-book item response',
      payload: data,
    );
  }
  final nested = data['data'];
  if (nested is Map) {
    return TrailBookItemDto.fromJson(Map<String, dynamic>.from(nested));
  }
  return TrailBookItemDto.fromJson(Map<String, dynamic>.from(data));
}

Future<void> deleteTrailBookItem(int postcardId) async {
  await HttpClient.instance.request(
    path: EndPoints.trailBookDelete,
    method: HttpMethod.put,
    requiresAuth: true,
    body: {'postcardId': postcardId},
  );
}

Future<void> reportTrailBookItem({
  required int trailbookId,
  required String reason,
}) async {
  await HttpClient.instance.request(
    path: EndPoints.trailBookReport,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'trailbookId': trailbookId, 'reason': reason},
  );
}

Future<void> markTrailBookRead(int trailBookId) async {
  await HttpClient.instance.request(
    path: EndPoints.trailBookMarkRead,
    method: HttpMethod.put,
    requiresAuth: true,
    body: {'trailBookId': trailBookId},
  );
}

Future<void> markAllTrailBookRead() async {
  await HttpClient.instance.request(
    path: EndPoints.trailBookMarkAllRead,
    method: HttpMethod.put,
    requiresAuth: true,
  );
}

Future<TrailBookUnreadResponse> fetchTrailBookUnread() async {
  final response = await HttpClient.instance.request(
    path: EndPoints.trailBookUnread,
    method: HttpMethod.get,
    requiresAuth: true,
  );

  final data = response.data;
  if (data is! Map) return const TrailBookUnreadResponse();
  final map = Map<String, dynamic>.from(data);
  // API: `{ success, data: { postcards: { totalUnread, postcard } } }`
  final nested = map['data'];
  if (nested is Map) {
    return TrailBookUnreadResponse.fromJson(Map<String, dynamic>.from(nested));
  }
  return TrailBookUnreadResponse.fromJson(map);
}
