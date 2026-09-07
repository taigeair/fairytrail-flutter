import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';

Future<PrefetchProfilesResponse> prefetchProfiles({
  bool firstTime = false,
  bool noMatch = false,
}) async {
  final params = <String>[];
  if (firstTime) params.add('firstime=true');
  if (noMatch) params.add('no_match=true');
  final query = params.isEmpty ? '' : '?${params.join('&')}';
  final path = '${EndPoints.profilesPrefetch}$query';

  final response = await HttpClient.instance.request(
    path: path,
    method: HttpMethod.get,
    requiresAuth: true,
  );

  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected prefetch response',
      payload: data,
    );
  }

  return PrefetchProfilesResponse.fromJson(Map<String, dynamic>.from(data));
}

Future<ConnectProfileResponse> connectProfile({
  required int profileId,
  String source = 'explore',
}) async {
  await LocalStorage.instance.setHasInitiatedConnectForAdminPopup();

  final response = await HttpClient.instance.request(
    path: EndPoints.profilesConnect,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'profileId': profileId, 'source': source},
  );

  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected connect response',
      payload: data,
    );
  }

  return ConnectProfileResponse.fromJson(Map<String, dynamic>.from(data));
}

Future<IncomingConnectionsResponse> fetchIncomingConnections() async {
  final response = await HttpClient.instance.request(
    path: EndPoints.profilesIncoming,
    method: HttpMethod.get,
    requiresAuth: true,
  );

  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected incoming connections response',
      payload: data,
    );
  }

  return IncomingConnectionsResponse.fromJson(Map<String, dynamic>.from(data));
}

/// Full Reveal list (paid). Separate from banner `/profiles/incoming`.
Future<IncomingConnectionsListResponse> fetchIncomingConnectionsList() async {
  final response = await HttpClient.instance.request(
    path: EndPoints.profilesIncomingList,
    method: HttpMethod.get,
    requiresAuth: true,
  );

  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected incoming list response',
      payload: data,
    );
  }

  return IncomingConnectionsListResponse.fromJson(
    Map<String, dynamic>.from(data),
  );
}

Future<void> skipProfile({
  required int profileId,
  String source = 'explore',
}) async {
  await HttpClient.instance.request(
    path: EndPoints.profilesSkip,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'profileId': profileId, 'source': source},
  );
}

Future<void> undoSkipProfile({required int profileId}) async {
  await HttpClient.instance.request(
    path: EndPoints.profilesUndoSkip,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'profileId': profileId},
  );
}

/// Block & report a profile (RN `apiPostProfilesReport`).
Future<void> reportProfile({
  required int profileId,
  required String reason,
  String? description,
  bool blockOnly = false,
}) async {
  await HttpClient.instance.request(
    path: EndPoints.profilesReport,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {
      'profileId': profileId,
      'reason': reason,
      'blockOnly': blockOnly,
      if (description != null && description.isNotEmpty)
        'description': description,
    },
  );
}

/// Connection / block status vs another profile (RN `apiGetProfilesStatus`).
///
/// Returns values like `connect`, `sent`, `connected`, `blocked`, `blocked_by`.
Future<String> getProfileStatus(int profileId) async {
  final response = await HttpClient.instance.request(
    path: '${EndPoints.profilesStatus}?id=$profileId',
    method: HttpMethod.get,
    requiresAuth: true,
  );
  final data = response.data;
  if (data is Map && data['status'] is String) {
    return data['status'] as String;
  }
  return '';
}
