import 'dart:typed_data';

import 'package:fairytrail/api/models/auth_models.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';
import 'package:http/http.dart' as http;

/// POST /api/v1/attachments → signed S3 URL
Future<SignedUploadUrl> createAttachment({required String filename}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.attachments,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {'filename': filename},
  );

  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected attachment response',
      payload: data,
    );
  }

  return SignedUploadUrl.fromJson(Map<String, dynamic>.from(data));
}

/// PUT bytes directly to S3 signed URL (no app auth headers).
Future<void> uploadBytesToSignedUrl({
  required String uploadUrl,
  required Uint8List bytes,
  String contentType = 'image/jpeg',
}) async {
  final response = await http.put(
    Uri.parse(uploadUrl),
    headers: {'Content-Type': contentType},
    body: bytes,
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Photo upload failed (${response.statusCode})',
    );
  }
}

/// POST /api/v1/profile-photos
Future<void> attachProfilePhotos({
  required List<String> attachmentIds,
  Map<String, dynamic>? exifData,
}) async {
  await HttpClient.instance.request(
    path: EndPoints.profilePhotos,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {
      'attachments': attachmentIds,
      'exifData': exifData ?? {},
    },
  );
}
