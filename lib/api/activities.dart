import 'package:fairytrail/api/models/activity_models.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

Map<String, dynamic> _asMap(dynamic data, {required String label}) {
  if (data is! Map) {
    throw ApiException(
      statusCode: 500,
      message: 'Unexpected $label response',
      payload: data,
    );
  }
  return Map<String, dynamic>.from(data);
}

Future<ActivitiesPageResponse> getActivities({
  String sortBy = 'trending',
  int? lastExplorerCount,
  int? lastId,
}) async {
  final params = <String, String>{'sortBy': sortBy};
  if (lastExplorerCount != null) {
    params['lastExplorerCount'] = '$lastExplorerCount';
  }
  if (lastId != null) params['lastId'] = '$lastId';

  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');

  final response = await HttpClient.instance.request(
    path: '${EndPoints.activities}?$query',
    method: HttpMethod.get,
    requiresAuth: true,
  );

  return ActivitiesPageResponse.fromJson(
    _asMap(response.data, label: 'activities'),
  );
}

Future<ActivitiesPageResponse> searchActivities({
  required String q,
  int? lastExplorerCount,
  int? lastId,
}) async {
  final params = <String, String>{'q': q};
  if (lastExplorerCount != null) {
    params['lastExplorerCount'] = '$lastExplorerCount';
  }
  if (lastId != null) params['lastId'] = '$lastId';

  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');

  final response = await HttpClient.instance.request(
    path: '${EndPoints.activitiesSearch}?$query',
    method: HttpMethod.get,
    requiresAuth: true,
  );

  return ActivitiesPageResponse.fromJson(
    _asMap(response.data, label: 'activity search'),
  );
}

Future<ActivityDto> getActivity(int id) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.activityById(id),
    method: HttpMethod.get,
    requiresAuth: true,
  );
  final data = _asMap(response.data, label: 'activity');
  final activity = data['activity'];
  if (activity is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected activity response',
      payload: data,
    );
  }
  return ActivityDto.fromJson(Map<String, dynamic>.from(activity));
}

Future<List<ActivityDto>> getProfileActivities(int profileId) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.profileActivities(profileId),
    method: HttpMethod.get,
    requiresAuth: true,
  );
  final data = _asMap(response.data, label: 'profile activities');
  final list = data['activities'];
  if (list is! List) return const [];
  return list
      .whereType<Map>()
      .map((e) => ActivityDto.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

Future<void> saveActivity(int id) async {
  await HttpClient.instance.request(
    path: EndPoints.activitiesSave,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'id': id},
  );
}

Future<void> unsaveActivity(int id) async {
  await HttpClient.instance.request(
    path: EndPoints.activitiesUnsave,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'id': id},
  );
}

Future<void> completeActivity({
  required int id,
  required String? completedDate,
}) async {
  await HttpClient.instance.request(
    path: EndPoints.activitiesComplete,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'id': id, 'completedDate': completedDate},
  );
}

Future<ActivityDto> addActivity({
  required String attachmentId,
  required String name,
  int? countryId,
}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.activities,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'attachmentId': attachmentId, 'name': name, 'countryId': countryId},
  );
  final data = _asMap(response.data, label: 'add activity');
  final activity = data['activity'];
  if (activity is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected add activity response',
      payload: data,
    );
  }
  return ActivityDto.fromJson(Map<String, dynamic>.from(activity));
}

Future<ActivityDto> editActivity({
  required int id,
  required String attachmentId,
  required String name,
  int? countryId,
}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.activitiesEdit,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {
      'id': id,
      'attachmentId': attachmentId,
      'name': name,
      'countryId': countryId,
    },
  );
  final data = _asMap(response.data, label: 'edit activity');
  final activity = data['activity'];
  if (activity is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected edit activity response',
      payload: data,
    );
  }
  return ActivityDto.fromJson(Map<String, dynamic>.from(activity));
}

Future<void> reportActivity({
  required int activityId,
  required String reason,
}) async {
  await HttpClient.instance.request(
    path: EndPoints.activitiesReport,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'activityId': activityId, 'reason': reason},
  );
}

Future<SavedExplorersResponse> getActivitySavedExplorers({
  required int activityId,
  int? lastId,
}) async {
  final path = lastId == null
      ? EndPoints.activitySavedExplorers(activityId)
      : '${EndPoints.activitySavedExplorers(activityId)}?lastId=$lastId';

  final response = await HttpClient.instance.request(
    path: path,
    method: HttpMethod.get,
    requiresAuth: true,
  );

  return SavedExplorersResponse.fromJson(
    _asMap(response.data, label: 'saved explorers'),
  );
}

Future<AddActivityPropsResponse> getAddActivityProps() async {
  final response = await HttpClient.instance.request(
    path: EndPoints.addActivityProps,
    method: HttpMethod.get,
    requiresAuth: true,
  );
  return AddActivityPropsResponse.fromJson(
    _asMap(response.data, label: 'add activity props'),
  );
}

/// PATCH `/api/v1/bucket-lists` — retag within own list.
Future<List<ActivityDto>> patchBucketListTag({
  required int activityId,
  required BucketListActivityTag tag,
}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.bucketLists,
    method: HttpMethod.patch,
    requiresAuth: true,
    body: {'id': activityId, 'tag': tag.apiValue},
  );
  final data = _asMap(response.data, label: 'bucket lists');
  final lists = data['bucketLists'];
  if (lists is! List) return const [];

  final activities = <ActivityDto>[];
  for (final item in lists) {
    if (item is! Map) continue;
    final parsed = BucketListDto.fromJson(Map<String, dynamic>.from(item));
    activities.addAll(parsed.activities);
  }
  return activities;
}
