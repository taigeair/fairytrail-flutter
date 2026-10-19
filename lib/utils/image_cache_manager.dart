import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

/// Cache manager for all network images.
///
/// The default manager's HTTP client has no timeouts and only runs 10
/// downloads at a time. On a flaky network stalled requests never fail, so
/// they hold every slot and queued images stay stuck even after the
/// connection recovers. Timing out lets them fail, free the slot, and retry.
final CacheManager appImageCacheManager = CacheManager(
  Config(
    'fairytrailImageCache',
    fileService: HttpFileService(httpClient: _TimeoutClient()),
  ),
);

class _TimeoutClient extends http.BaseClient {
  static const _responseTimeout = Duration(seconds: 20);
  static const _idleTimeout = Duration(seconds: 15);

  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request).timeout(_responseTimeout);
    return http.StreamedResponse(
      response.stream.timeout(
        _idleTimeout,
        onTimeout: (sink) {
          sink.addError(
            TimeoutException('Image download stalled', _idleTimeout),
          );
          sink.close();
        },
      ),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
