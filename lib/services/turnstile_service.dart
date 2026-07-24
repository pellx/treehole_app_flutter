import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/local.dart';

/// Turnstile 验证服务 — 通过服务器托管的页面加载 Turnstile
class TurnstileService {
  TurnstileService._();
  static final TurnstileService instance = TurnstileService._();

  static const _pageUrl = 'https://tree.leisure.xin/turnstile.html';

  Completer<String?>? _completer;
  WebViewController? _controller;

  /// 配置 WebViewController 并加载 Turnstile 页面
  void bindController(WebViewController controller) {
    _controller = controller;
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('TurnstileChannel', onMessageReceived: _onMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onWebResourceError: (err) =>
            debugPrint('[TurnstileService] Resource error: '
                '${err.errorType} — ${err.description}'),
      ))
      ..loadRequest(Uri.parse(_pageUrl));
  }

  void _onMessage(JavaScriptMessage msg) {
    final c = _completer;
    if (c == null || c.isCompleted) return;
    try {
      final data = jsonDecode(msg.message) as Map<String, dynamic>;
      final status = data['status'];
      if (status == 'success') {
        c.complete(data['token'] as String?);
      } else {
        c.complete(null);
      }
    } catch (_) {
      if (!c.isCompleted) c.complete(null);
    }
  }

  /// 获取 Turnstile token，最多等 45 秒
  Future<String?> getToken() async {
    if (_controller == null) return null;
    _completer = Completer<String?>();

    await _controller!.runJavaScript('''
      (function() {
        var sitekey = '$kTurnstileSiteKey';

        function doRender() {
          if (typeof turnstile === 'undefined') return;
          try {
            turnstile.reset();
          } catch(e) {
            try {
              turnstile.render('#turnstile-widget', {
                sitekey: sitekey,
                callback: function(token) {
                  TurnstileChannel.postMessage(JSON.stringify({status: 'success', token: token}));
                },
                'error-callback': function() {
                  TurnstileChannel.postMessage(JSON.stringify({status: 'error'}));
                },
                'expired-callback': function() { turnstile.reset(); }
              });
            } catch(e2) {
              TurnstileChannel.postMessage(JSON.stringify({status: 'error', message: 'render failed: ' + e2.message}));
            }
          }
        }

        if (typeof turnstile !== 'undefined') {
          doRender();
        } else {
          var attempts = 0;
          var interval = setInterval(function() {
            attempts++;
            if (typeof turnstile !== 'undefined') {
              clearInterval(interval);
              doRender();
            } else if (attempts >= 90) {
              clearInterval(interval);
              TurnstileChannel.postMessage(JSON.stringify({status: 'error', message: 'Turnstile script load timeout (45s)'}));
            }
          }, 500);
        }
      })();
    ''');

    return _completer!.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () => null,
    );
  }
}
