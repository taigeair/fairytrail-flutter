import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fairytrail/utils/api/end_points.dart';
import 'package:flutter/foundation.dart';

typedef WsEventHandler = void Function(dynamic data);

/// Native WebSocket client for Fairytrail realtime (`/ws?apiToken=`).
class AppWebSocket {
  AppWebSocket(this.apiToken);

  final String apiToken;

  WebSocket? _socket;
  final _handlers = <String, List<WsEventHandler>>{};
  Timer? _reconnectTimer;
  Timer? _heartbeatWatchdog;
  int _reconnectAttempts = 0;
  bool _shouldReconnect = true;
  bool _connecting = false;

  static const _maxReconnectAttempts = 12;

  bool get isConnected => _socket != null;

  /// Correct `wss://host:443/ws?apiToken=…` URI (avoids Dart’s `:0` / `#` quirks).
  Uri get connectionUri {
    final base = Uri.parse(EndPoints.wsBaseUrl);
    final secure = base.scheme == 'wss' || base.scheme == 'https';
    return Uri(
      scheme: secure ? 'wss' : 'ws',
      host: base.host,
      port: base.hasPort
          ? base.port
          : (secure ? 443 : 80),
      path: '/ws',
      queryParameters: {'apiToken': apiToken},
    );
  }

  void on(String type, WsEventHandler handler) {
    _handlers.putIfAbsent(type, () => []).add(handler);
  }

  void off(String type, [WsEventHandler? handler]) {
    if (handler == null) {
      _handlers.remove(type);
      return;
    }
    _handlers[type]?.remove(handler);
  }

  Future<void> connect() async {
    if (_connecting || isConnected) return;
    if (apiToken.isEmpty) return;

    _connecting = true;
    _shouldReconnect = true;
    final uri = connectionUri;
    debugPrint('[WS] connecting to ${uri.replace(queryParameters: {
      'apiToken': '${apiToken.substring(0, 6)}…',
    })}');

    try {
      final socket = await WebSocket.connect(uri.toString());
      if (!_shouldReconnect) {
        await socket.close();
        _connecting = false;
        return;
      }
      _socket = socket;
      _connecting = false;
      _reconnectAttempts = 0;
      debugPrint('[WS] connected');

      socket.listen(
        _onData,
        onDone: _onDone,
        onError: (Object e) {
          debugPrint('[WS] error: $e');
          _cleanupSocket();
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[WS] connect failed: $e');
      _connecting = false;
      _cleanupSocket();
      _scheduleReconnect();
    }
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatWatchdog?.cancel();
    _heartbeatWatchdog = null;
    final s = _socket;
    _socket = null;
    s?.close(1000, 'client disconnect');
  }

  void send(String type, [dynamic data]) {
    final s = _socket;
    if (s == null) return;
    s.add(jsonEncode({
      'type': type,
      if (data != null) 'data': data,
    }));
  }

  void _onData(dynamic raw) {
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is! Map) return;
      final type = decoded['type'] as String?;
      if (type == null) return;

      if (type == 'heartbeat') {
        send('heartbeat');
        _armHeartbeatWatchdog();
        return;
      }

      debugPrint('[WS] event: $type data=${decoded['data']}');

      if (type == 'connected') {
        _armHeartbeatWatchdog();
      }

      final data = decoded['data'];
      final list = _handlers[type];
      if (list == null) return;
      for (final h in List<WsEventHandler>.from(list)) {
        h(data);
      }
    } catch (e) {
      debugPrint('[WS] parse error: $e raw=$raw');
    }
  }

  void _onDone() {
    debugPrint('[WS] closed');
    _cleanupSocket();
    _scheduleReconnect();
  }

  void _cleanupSocket() {
    _heartbeatWatchdog?.cancel();
    _heartbeatWatchdog = null;
    _socket = null;
  }

  void _armHeartbeatWatchdog() {
    _heartbeatWatchdog?.cancel();
    _heartbeatWatchdog = Timer(const Duration(seconds: 90), () {
      debugPrint('[WS] heartbeat timeout — reconnecting');
      _socket?.close();
      _cleanupSocket();
      _scheduleReconnect();
    });
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint(
        '[WS] giving up after $_maxReconnectAttempts attempts '
        '(check that ${EndPoints.wsBaseUrl}/ws is up)',
      );
      return;
    }
    _reconnectTimer?.cancel();
    // 2s, 4s, 8s … capped at 60s — avoid log spam on 502.
    final delayMs = (2000 * (1 << _reconnectAttempts.clamp(0, 5))).clamp(
      2000,
      60000,
    );
    _reconnectAttempts++;
    debugPrint(
      '[WS] reconnect $_reconnectAttempts/$_maxReconnectAttempts in ${delayMs}ms',
    );
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), connect);
  }
}
