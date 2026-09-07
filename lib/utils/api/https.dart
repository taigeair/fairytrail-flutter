import 'dart:convert';

import 'package:fairytrail/config/app_version.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum HttpMethod { get, post, put, patch, delete }

/// Result of an HTTP call after JSON parsing.
class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.data,
    required this.rawBody,
  });

  final int statusCode;
  final dynamic data;
  final String rawBody;

  bool get isOk => statusCode >= 200 && statusCode < 300;
}

/// Thrown when the server returns a non-2xx response.
class ApiException implements Exception {
  ApiException({required this.statusCode, required this.message, this.payload});

  final int statusCode;
  final String message;
  final dynamic payload;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Shared HTTP client. All API modules should go through [HttpClient.request].
class HttpClient {
  HttpClient._();

  static final HttpClient instance = HttpClient._();

  String? _authToken;
  bool _isImpersonating = false;
  String _device = 'flutter';
  String _appVersion = AppVersionInfo.version;

  void setAuthToken(String? token) => _authToken = token;

  String? get authToken => _authToken;

  void setImpersonating(bool value) => _isImpersonating = value;

  void setDeviceInfo({required String device, required String appVersion}) {
    _device = device;
    _appVersion = appVersion;
  }

  /// Makes an API request.
  ///
  /// Set [requiresAuth] to `true` to fail fast when no token is available.
  /// Set [attachToken] to attach `X-API-TOKEN` when a token exists (default true).
  Future<ApiResponse> request({
    required String path,
    HttpMethod method = HttpMethod.get,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requiresAuth = false,
    bool attachToken = true,

    /// Override host — used for the web/desktop auth API.
    String? baseUrl,
  }) async {
    final token = await _resolveToken(attachToken: attachToken);

    if (requiresAuth && (token == null || token.isEmpty)) {
      throw ApiException(statusCode: 401, message: 'Authentication required');
    }

    final uri = Uri.parse('${baseUrl ?? EndPoints.baseUrl}$path');
    final requestHeaders = await _buildHeaders(
      extra: headers,
      token: attachToken ? token : null,
    );

    http.Response response;
    final encodedBody = body == null ? null : jsonEncode(body);
    final methodLabel = method.name.toUpperCase();
    final sw = Stopwatch()..start();

    try {
      switch (method) {
        case HttpMethod.get:
          response = await http.get(uri, headers: requestHeaders);
        case HttpMethod.post:
          response = await http.post(
            uri,
            headers: requestHeaders,
            body: encodedBody,
          );
        case HttpMethod.put:
          response = await http.put(
            uri,
            headers: requestHeaders,
            body: encodedBody,
          );
        case HttpMethod.patch:
          response = await http.patch(
            uri,
            headers: requestHeaders,
            body: encodedBody,
          );
        case HttpMethod.delete:
          response = await http.delete(
            uri,
            headers: requestHeaders,
            body: encodedBody,
          );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[API] $methodLabel $path failed (${sw.elapsedMilliseconds}ms): $e',
        );
      }
      rethrow;
    }

    if (kDebugMode) {
      debugPrint(
        '[API] $methodLabel $path → ${response.statusCode} (${sw.elapsedMilliseconds}ms)',
      );
    }

    return _parseResponse(response);
  }

  Future<String?> _resolveToken({required bool attachToken}) async {
    if (!attachToken) return null;
    if (_authToken != null && _authToken!.isNotEmpty) return _authToken;

    final saved = await LocalStorage.instance.getApiToken();
    if (saved != null && saved.isNotEmpty) {
      _authToken = saved;
    }
    return _authToken;
  }

  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? extra,
    String? token,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-DEVICE': _device,
      'X-PLATFORM': defaultTargetPlatform.name,
      'X-VERSION': _appVersion,
    };

    if (_isImpersonating) {
      headers['X-IMPERSONATING'] = 'true';
    }

    if (token != null && token.isNotEmpty) {
      headers['X-API-TOKEN'] = token;
    }

    if (extra != null) {
      headers.addAll(extra);
    }

    return headers;
  }

  ApiResponse _parseResponse(http.Response response) {
    final raw = response.body;
    dynamic data;

    if (raw.isNotEmpty) {
      try {
        data = jsonDecode(raw);
      } catch (_) {
        data = raw;
      }
    }

    final apiResponse = ApiResponse(
      statusCode: response.statusCode,
      data: data,
      rawBody: raw,
    );

    if (!apiResponse.isOk) {
      throw ApiException(
        statusCode: response.statusCode,
        message:
            _errorMessage(data) ?? 'Request failed (${response.statusCode})',
        payload: data,
      );
    }

    return apiResponse;
  }

  String? _errorMessage(dynamic data) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final message = map['message'] ?? map['error'] ?? map['detail'];
      if (message is String && message.isNotEmpty) return message;
      final code = map['code'];
      if (code is String && code.isNotEmpty) return code;
    }
    return null;
  }
}
