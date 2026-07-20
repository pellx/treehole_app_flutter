import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Socket.IO 实时通道（附录 E）
///
/// 同源 path `/node/socket.io`，握手 auth：`session_id` + `session_secret`。
/// 事件：`binding.unbound` / `session.invalidated`。
class RealtimeService {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  /// 与 HTTP API 同源（反代终结 TLS）
  static const _host = 'https://tree.leisure.xin';
  static const _path = '/node/socket.io';

  io.Socket? _socket;
  int? _connectedSessionId;
  bool _handlersBound = false;

  VoidCallback? onBindingUnbound;
  VoidCallback? onSessionInvalidated;

  bool get isConnected => _socket?.connected == true;

  /// 用当前 session 建连；同 session 已连接则跳过。
  void connect({
    required int sessionId,
    required String sessionSecret,
  }) {
    if (sessionSecret.isEmpty) return;
    if (_connectedSessionId == sessionId && isConnected) return;

    disconnect();
    _connectedSessionId = sessionId;

    final socket = io.io(
      _host,
      io.OptionBuilder()
          .setPath(_path)
          .setAuth({
            'session_id': sessionId,
            'session_secret': sessionSecret,
          })
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(20)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .enableForceNew()
          .build(),
    );

    _socket = socket;
    final boundSessionId = sessionId;

    socket.onConnect((_) {
      debugPrint('[Realtime] connected session=$boundSessionId');
    });
    socket.onDisconnect((_) {
      debugPrint('[Realtime] disconnected session=$boundSessionId');
    });
    socket.onConnectError((err) {
      debugPrint('[Realtime] connect error: $err');
    });
    socket.onError((err) {
      debugPrint('[Realtime] error: $err');
    });

    socket.on('binding.unbound', (data) {
      if (_connectedSessionId != boundSessionId) return;
      debugPrint('[Realtime] binding.unbound: $data');
      onBindingUnbound?.call();
    });
    socket.on('session.invalidated', (data) {
      if (_connectedSessionId != boundSessionId) return;
      debugPrint('[Realtime] session.invalidated: $data');
      onSessionInvalidated?.call();
    });
  }

  void disconnect() {
    final socket = _socket;
    _socket = null;
    _connectedSessionId = null;
    if (socket == null) return;
    try {
      socket.clearListeners();
      socket.dispose();
    } catch (e) {
      debugPrint('[Realtime] disconnect: $e');
    }
  }

  /// 仅绑一次回调，避免重复注册
  void bindHandlers({
    required VoidCallback bindingUnbound,
    required VoidCallback sessionInvalidated,
  }) {
    if (_handlersBound) return;
    _handlersBound = true;
    onBindingUnbound = bindingUnbound;
    onSessionInvalidated = sessionInvalidated;
  }
}
